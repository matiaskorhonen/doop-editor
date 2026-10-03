//
//  TreeSitterClient.swift
//  CodeEditSourceEditor
//
//  Created by Khan Winter on 9/12/22.
//

import Foundation
internal import SwiftTreeSitter
import OSLog

/// # TreeSitterClient
///
/// ``TreeSitterClient`` is an class that manages a tree-sitter syntax tree and provides an API for notifying that
/// tree of edits and querying the tree. This type also conforms to ``HighlightProviding`` to provide syntax
/// highlighting.
///
/// The APIs this object provides can perform either asynchronously or synchronously. All calls to this object must
/// first be dispatched from the main queue to ensure serial access to internal properties. Any synchronous methods
/// can throw an ``TreeSitterClientExecutor/Error/syncUnavailable`` error if an asynchronous or synchronous call is
/// already being made on the object. In those cases it is up to the caller to decide whether or not to retry
/// asynchronously.
///
/// The only exception to the above rule is the ``HighlightProviding`` conformance methods. The methods for that
/// implementation may return synchronously or asynchronously depending on a variety of factors such as document
/// length, edit length, highlight length and if the object is available for a synchronous call.
public final class TreeSitterClient: HighlightProviding {
    static let logger: Logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "", category: "TreeSitterClient")

    enum TreeSitterClientError: Error {
        case invalidEdit
    }

    // MARK: - Properties

    /// A callback to use to efficiently fetch portions of text.
    var readBlock: Parser.ReadBlock?

    /// A callback used to fetch text for queries.
    var readCallback: SwiftTreeSitter.Predicate.TextProvider?

    /// The internal tree-sitter layer tree object.
    var state: TreeSitterState?

    var executor: TreeSitterExecutor = .init()

    /// The end point of the previous edit.
    private var oldEndPoint: Point?

    internal var pendingEdits: Atomic<[InputEdit]> = Atomic([])

    /// Whether the last edit took longer than ``Constants/maxSyncEditDuration``, which sends the next one off the
    /// main thread. Cleared again when an edit comes back under the limit.
    ///
    /// Some grammars have scanners that read to the end of the document on every reparse (an unclosed Lua long
    /// bracket, for one), so how long an edit takes depends on the text rather than on its length, and the length
    /// checks alone can't keep that off the main thread.
    let editsAreSlow = Atomic(false)

    /// The language last given to ``setUp(textView:codeLanguage:)``, kept so highlighting can start again when a
    /// document that outgrew ``Constants/maxHighlightableContentLength`` shrinks back under it.
    private var codeLanguage: CodeLanguage?

    /// True while the document is over ``Constants/maxHighlightableContentLength`` and nothing is parsed.
    private(set) var isOverHighlightLimit = false

    /// Optional flag to force every operation to be done on the caller's thread.
    var forceSyncOperation: Bool = false

    public init() { }

    // MARK: - Constants

    public enum Constants {
        /// The maximum amount of limits a cursor can match during a query.
        ///
        /// Used to ensure performance in large files, even though we generally limit the query to the visible range.
        /// Neovim encountered this issue and uses 64 for their limit. Helix uses 256 due to issues with some
        /// languages when using 64.
        /// See: [github.com/neovim](https://github.com/neovim/neovim/issues/14897)
        /// And: [github.com/helix-editor](https://github.com/helix-editor/helix/pull/4830)
        public static var matchLimit = 256

        /// The timeout for parsers to re-check if a task is canceled. This constant represents the period between
        /// checks and is directly related to editor responsiveness.
        public static var parserTimeout: TimeInterval = 0.05

        /// The maximum length of an edit before it must be processed asynchronously
        public static var maxSyncEditLength: Int = 1024

        /// The maximum length a document can be before all queries and edits must be processed asynchronously.
        public static var maxSyncContentLength: Int = 1_000_000

        /// How long a synchronous edit may take before later edits are processed asynchronously.
        public static var maxSyncEditDuration: TimeInterval = 0.03

        /// The maximum length a document can be before it is no longer highlighted at all.
        ///
        /// Every edit re-runs the language's query over the whole tree to look for injections, so the cost of an
        /// edit grows with the document: about 1.1µs per character in a release build, which is roughly 280ms per
        /// edit at this limit and nearly a second at 800,000 characters. Past the limit the client stops parsing and
        /// returns no highlights, until the document shrinks back under it or a new language is set.
        public static var maxHighlightableContentLength: Int = 250_000

        /// The maximum length a query can be before it must be performed asynchronously.
        public static var maxSyncQueryLength: Int = 4096

        /// The number of characters to read in a read block.
        ///
        /// This has diminishing returns on the number of times the read block is called as this number gets large.
        public static let charsToReadInBlock: Int = 4096

        /// The duration before a long parse notification is sent.
        public static var longParseTimeout: Duration = .seconds(0.5)

        /// The notification name sent when a long parse is detected.
        public static let longParse: Notification.Name = .init("CodeEditSourceEditor.longParseNotification")

        /// The notification name sent when a long parse is finished.
        public static let longParseFinished: Notification.Name = .init(
            "CodeEditSourceEditor.longParseFinishedNotification"
        )

        /// The duration tasks sleep before checking if they're runnable.
        ///
        /// Lower than 1ms starts causing bad lock contention, much higher reduces responsiveness with diminishing
        /// returns on CPU efficiency.
        public static let taskSleepDuration: Duration = .milliseconds(10)
    }

    // MARK: - HighlightProviding

    /// Set up the client with a text view and language.
    /// - Parameters:
    ///   - textView: The text view to use as a data source.
    ///               A weak reference will be kept for the lifetime of this object.
    ///   - codeLanguage: The language to use for parsing.
    public func setUp(textView: TextView, codeLanguage: CodeLanguage) {
        Self.logger.debug("TreeSitterClient setting up with language: \(codeLanguage.id.rawValue, privacy: .public)")

        self.codeLanguage = codeLanguage
        if textView.documentRange.length > Constants.maxHighlightableContentLength {
            stopHighlighting()
            return
        }
        isOverHighlightLimit = false

        let readBlock = textView.createReadBlock()
        let readCallback = textView.createReadCallback()
        self.readBlock = readBlock
        self.readCallback = readCallback

        let operation = { [weak self] in
            let state = TreeSitterState(
                codeLanguage: codeLanguage,
                readCallback: readCallback,
                readBlock: readBlock
            )
            self?.state = state
        }

        executor.cancelAll(below: .all)
        if forceSyncOperation {
            executor.execSync(operation)
        } else {
            executor.execAsync(priority: .reset, operation: operation, onCancel: {})
        }
    }

    /// Drops the parse state and anything queued against it, and answers every later edit and query with nothing.
    private func stopHighlighting() {
        isOverHighlightLimit = true
        executor.cancelAll(below: .all)
        pendingEdits.mutate { $0.removeAll() }
        oldEndPoint = nil
        state = nil
    }

    // MARK: - HighlightProviding

    /// Notifies the highlighter of an edit and in exchange gets a set of indices that need to be re-highlighted.
    /// The returned `IndexSet` should include all indexes that need to be highlighted, including any inserted text.
    /// - Parameters:
    ///   - textView: The text view to use.
    ///   - range: The range of the edit.
    ///   - delta: The length of the edit, can be negative for deletions.
    ///   - completion: The function to call with an `IndexSet` containing all Indices to invalidate.
    public func applyEdit(
        textView: TextView,
        range: NSRange,
        delta: Int,
        completion: @escaping @MainActor (Result<IndexSet, Error>) -> Void
    ) {
        if textView.documentRange.length > Constants.maxHighlightableContentLength {
            if !isOverHighlightLimit {
                stopHighlighting()
            }
            completion(.success(IndexSet()))
            return
        } else if isOverHighlightLimit, let codeLanguage {
            // The document came back under the limit. Parse it from scratch and highlight all of it.
            setUp(textView: textView, codeLanguage: codeLanguage)
            completion(.success(IndexSet(integersIn: 0..<textView.documentRange.length)))
            return
        }

        let oldEndPoint: Point = self.oldEndPoint ?? textView.pointForLocation(range.max) ?? .zero
        guard let edit = InputEdit(range: range, delta: delta, oldEndPoint: oldEndPoint, textView: textView) else {
            completion(.failure(TreeSitterClientError.invalidEdit))
            return
        }

        let operation = { [weak self] in
            let start = ContinuousClock.now
            let invalidated = self?.applyEdit(edit: edit) ?? IndexSet()
            let elapsed = start.duration(to: .now)
            self?.editsAreSlow.mutate { $0 = elapsed > .seconds(Constants.maxSyncEditDuration) }
            return invalidated
        }

        let longEdit = range.length > Constants.maxSyncEditLength
        let longDocument = textView.documentRange.length > Constants.maxSyncContentLength
        let execAsync = longEdit || longDocument || editsAreSlow.value()

        if !execAsync || forceSyncOperation {
            let result = executor.execSync(operation)
            if case .success(let invalidatedRanges) = result {
                DispatchQueue.dispatchMainIfNot { completion(.success(invalidatedRanges)) }
                return
            }
        }

        if !forceSyncOperation {
            executor.cancelAll(below: .reset) // Cancel all edits, add it to the pending edit queue
            executor.execAsync(
                priority: .edit,
                operation: { completion(.success(operation())) },
                onCancel: { [weak self] in
                    self?.pendingEdits.mutate { edits in
                        edits.append(edit)
                    }
                    DispatchQueue.dispatchMainIfNot {
                        completion(.failure(HighlightProvidingError.operationCancelled))
                    }
                }
            )
        }
    }

    /// Called before an edit is sent. We use this to set the ``oldEndPoint`` variable so tree-sitter knows where
    /// the document used to end.
    /// - Parameters:
    ///   - textView: The text view used.
    ///   - range: The range that will be edited.
    public func willApplyEdit(textView: TextView, range: NSRange) {
        oldEndPoint = textView.pointForLocation(range.max)
    }

    /// Initiates a highlight query.
    /// - Parameters:
    ///   - textView: The text view to use.
    ///   - range: The range to limit the highlights to.
    ///   - completion: Called when the query completes.
    public func queryHighlightsFor(
        textView: TextView,
        range: NSRange,
        completion: @escaping @MainActor (Result<[HighlightRange], Error>) -> Void
    ) {
        if isOverHighlightLimit {
            completion(.success([]))
            return
        }

        let operation = { [weak self] in
            return (self?.queryHighlightsForRange(range: range) ?? []).sorted {
                if $0.range.location != $1.range.location {
                    return $0.range.location < $1.range.location
                }
                return $0.range.length > $1.range.length
            }
        }

        let longQuery = range.length > Constants.maxSyncQueryLength
        let longDocument = textView.documentRange.length > Constants.maxSyncContentLength
        let execAsync = longQuery || longDocument

        if !execAsync || forceSyncOperation {
            let result = executor.execSync(operation)
            if case .success(let highlights) = result {
                DispatchQueue.dispatchMainIfNot { completion(.success(highlights)) }
                return
            }
        }

        if !forceSyncOperation {
            executor.execAsync(
                priority: .access,
                operation: {
                    DispatchQueue.dispatchMainIfNot { completion(.success(operation())) }
                },
                onCancel: {
                    DispatchQueue.dispatchMainIfNot {
                        completion(.failure(HighlightProvidingError.operationCancelled))
                    }
                }
            )
        }
    }
}
