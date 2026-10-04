import XCTest
import AppKit
@testable import DoopEditor

/// Randomized, seeded sessions of editing against a real ``TextViewController``, checking the
/// invariants that a crash or hang would otherwise be the first sign of breaking.
///
/// Modelled on Doop's `DoopStressUITests`, but in-process: operations call the same `TextView`
/// responder methods a keystroke does, so hundreds of them run in seconds, and the checks can look
/// at the layout manager's line storage, which a UI test can't.
///
/// Opt-in, because they are randomized and turn up crashes that are not yet fixed: a flaky `swift test` helps nobody.
///
///     DOOP_STRESS=1 swift test --filter StressTests
///
/// Knobs:
/// - `DOOP_STRESS_STEPS`: operations per session (default 400).
/// - `DOOP_STRESS_SEED`: replays a session. Every run prints its seed, and a failure repeats it.
/// - `DOOP_STRESS_VERBOSE=1`: prints each step before it runs, for a crash that never reaches the trace.
final class StressTests: XCTestCase {
    private var window: NSWindow!
    private var controller: TextViewController!
    private var textView: TextView { controller.textView }

    private func skipUnlessOptedIn() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["DOOP_STRESS"] == "1",
            "The stress tests are opt-in; set DOOP_STRESS=1 to run them.")
    }
    private var verbose: Bool { ProcessInfo.processInfo.environment["DOOP_STRESS_VERBOSE"] == "1" }

    override func setUpWithError() throws {
        // The first broken invariant is the cause; what follows is fallout from the corrupted state.
        continueAfterFailure = false
        controller = Mock.textViewController(theme: Mock.theme())
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = controller
        controller.view.frame = NSRect(x: 0, y: 0, width: 600, height: 400)
        controller.view.layoutSubtreeIfNeeded()
    }

    override func tearDown() {
        window.contentViewController = nil
        controller = nil
        window = nil
        super.tearDown()
    }

    // MARK: - Tests

    /// Random typing, deleting, movement, multi-cursor edits, indenting and undo/redo, with the
    /// editor's invariants checked after every step.
    func testRandomizedSession() throws {
        try skipUnlessOptedIn()
        let environment = ProcessInfo.processInfo.environment
        let steps = environment["DOOP_STRESS_STEPS"].flatMap(Int.init) ?? 400
        let seed = Self.seed(from: environment)
        var random = SeededGenerator(seed: seed)
        FileHandle.standardError.write(Data("Stress seed: \(seed) — replay with DOOP_STRESS_SEED=\(seed)\n".utf8))

        controller.setText(Self.document(lines: 40, salt: Int(seed % 100)))
        textView.selectionManager.setSelectedRange(NSRange(location: 0, length: 0))

        var trace: [String] = []
        for step in 1...steps {
            let operation = Operation.allCases.randomElement(using: &random)!
            trace.append("\(step): \(operation)")
            if verbose { FileHandle.standardError.write(Data("step \(step): \(operation)\n".utf8)) }
            perform(operation, using: &random)
            settle()
            checkInvariants(
                "step \(step) (\(operation), seed \(seed)). Last steps:\n"
                    + trace.suffix(15).joined(separator: "\n")
            )
        }
    }

    /// Whatever random edits were made, undoing all of them restores the original text and
    /// redoing all of them restores the final text.
    func testUndoRedoRoundTrip() throws {
        try skipUnlessOptedIn()
        let environment = ProcessInfo.processInfo.environment
        let seed = Self.seed(from: environment)
        var random = SeededGenerator(seed: seed)
        FileHandle.standardError.write(Data("Stress seed: \(seed) — replay with DOOP_STRESS_SEED=\(seed)\n".utf8))

        for round in 1...40 {
            let original = Self.document(lines: 5 + round, salt: round)
            controller.setText(original)
            textView.selectionManager.setSelectedRange(NSRange(location: 0, length: 0))
            let undoManager = textView._undoManager!
            while undoManager.canUndo { undoManager.undo() }
            undoManager.removeAllActions()

            var trace: [String] = []
            for step in 1...Int.random(in: 5...60, using: &random) {
                let operation = Self.editOperations.randomElement(using: &random)!
                trace.append("\(step): \(operation)")
                perform(operation, using: &random)
            }
            let edited = textView.string
            let context = "round \(round), seed \(seed). Steps:\n" + trace.joined(separator: "\n")

            var undos = 0
            while undoManager.canUndo, undos < 10_000 {
                undoManager.undo()
                undos += 1
            }
            XCTAssertEqual(textView.string, original, "Undoing everything didn't restore the text; \(context)")
            checkInvariants("after undoing, \(context)")

            var redos = 0
            while undoManager.canRedo, redos < 10_000 {
                undoManager.redo()
                redos += 1
            }
            XCTAssertEqual(textView.string, edited, "Redoing everything didn't restore the edits; \(context)")
            checkInvariants("after redoing, \(context)")
        }
    }

    /// A big document edited and indented while highlighting is still catching up.
    func testLargeDocumentSession() throws {
        try skipUnlessOptedIn()
        let seed = Self.seed(from: ProcessInfo.processInfo.environment)
        var random = SeededGenerator(seed: seed)
        FileHandle.standardError.write(Data("Stress seed: \(seed) — replay with DOOP_STRESS_SEED=\(seed)\n".utf8))

        controller.setText(Self.document(lines: 20_000, salt: 7))
        textView.selectionManager.setSelectedRange(NSRange(location: 0, length: 0))
        checkInvariants("after loading 20,000 lines")

        for round in 1...30 {
            let operation = Operation.allCases.randomElement(using: &random)!
            perform(operation, using: &random)
            // Deliberately settle only briefly: edits landing mid-parse is the point.
            RunLoop.main.run(until: Date().addingTimeInterval(0.002))
            checkInvariants("large document, round \(round) (\(operation), seed \(seed))")
        }
        settle()
        checkInvariants("large document, after settling")
    }

    // MARK: - Operations

    private enum Operation: CaseIterable {
        case typeWords, typeMultiline, paste, pasteUnicode, pasteLarge
        case backspace, forwardDelete, deleteWord, deleteLine, selectAllDelete
        case moveArrows, moveByWord, moveToEdges, selectThenType, selectLines
        case undo, redo, undoBurst, redoBurst
        case addCursors, multiCursorType
        case indent, dedent, moveLinesUp, moveLinesDown
    }

    /// The operations that change the text, for the undo/redo round trip.
    private static let editOperations: [Operation] = [
        .typeWords, .typeMultiline, .paste, .pasteUnicode, .backspace, .forwardDelete, .deleteWord,
        .deleteLine, .selectThenType, .multiCursorType, .indent, .dedent, .moveLinesUp, .moveLinesDown,
    ]

    private static let words = [
        "lorem", "ipsum", "dolor", "sit", "amet", "Doop", "script", "editor", "undo",
        "naïve", "café", "日本語", "🙂", "über", "x", "42", "a-b_c", "TAB\tstop", "{", "}", "(", "\"",
    ]

    private func perform(_ operation: Operation, using random: inout SeededGenerator) {
        switch operation {
        case .typeWords:
            type(phrase(using: &random, count: Int.random(in: 1...12, using: &random)))
        case .typeMultiline:
            type(
                (0..<Int.random(in: 2...6, using: &random)).map { _ in
                    phrase(using: &random, count: Int.random(in: 1...6, using: &random))
                }.joined(separator: "\n"))
        case .paste:
            replaceSelections(
                with: (0..<Int.random(in: 1...30, using: &random)).map { _ in
                    phrase(using: &random, count: Int.random(in: 0...10, using: &random))
                }.joined(separator: "\n"))
        case .pasteUnicode:
            replaceSelections(
                with: "emoji 👨‍👩‍👧‍👦 🇫🇮 e\u{301} \u{200B}zero-width\r\ncrlf line\rcr line\n\tmixed\u{2028}separator")
        case .pasteLarge:
            replaceSelections(
                with: Self.document(
                    lines: Int.random(in: 500...3000, using: &random), salt: Int(random.next() % 1000)))
        case .backspace:
            for _ in 0..<Int.random(in: 1...20, using: &random) { textView.deleteBackward(nil) }
        case .forwardDelete:
            for _ in 0..<Int.random(in: 1...10, using: &random) { textView.deleteForward(nil) }
        case .deleteWord:
            textView.deleteWordBackward(nil)
        case .deleteLine:
            textView.deleteToBeginningOfLine(nil)
        case .selectAllDelete:
            textView.selectAll(nil)
            textView.deleteBackward(nil)
        case .moveArrows:
            for _ in 0..<Int.random(in: 1...15, using: &random) {
                [textView.moveLeft, textView.moveRight, textView.moveUp, textView.moveDown]
                    .randomElement(using: &random)!(nil)
            }
        case .moveByWord:
            for _ in 0..<Int.random(in: 1...6, using: &random) {
                (Bool.random(using: &random) ? textView.moveWordLeft : textView.moveWordRight)(nil)
            }
        case .moveToEdges:
            [
                textView.moveToBeginningOfDocument, textView.moveToEndOfDocument,
                textView.moveToLeftEndOfLine, textView.moveToRightEndOfLine,
            ].randomElement(using: &random)!(nil)
        case .selectThenType:
            for _ in 0..<Int.random(in: 1...8, using: &random) {
                (Bool.random(using: &random)
                    ? textView.moveWordLeftAndModifySelection : textView.moveWordRightAndModifySelection)(nil)
            }
            type(phrase(using: &random, count: 2))
        case .selectLines:
            textView.moveUpAndModifySelection(nil)
            textView.moveDownAndModifySelection(nil)
            textView.moveDownAndModifySelection(nil)
        case .undo:
            textView.undoManager?.undo()
        case .redo:
            textView.undoManager?.redo()
        case .undoBurst:
            for _ in 0..<Int.random(in: 3...25, using: &random) { textView.undoManager?.undo() }
        case .redoBurst:
            for _ in 0..<Int.random(in: 3...25, using: &random) { textView.undoManager?.redo() }
        case .addCursors:
            for _ in 0..<Int.random(in: 1...5, using: &random) {
                if Bool.random(using: &random) { textView.addCursorAbove() } else { textView.addCursorBelow() }
            }
        case .multiCursorType:
            for _ in 0..<Int.random(in: 1...3, using: &random) { textView.addCursorBelow() }
            type(phrase(using: &random, count: 2))
            textView.deleteBackward(nil)
            textView.cancelOperation(nil)
        case .indent:
            syncCursorPositions()
            controller.handleIndent(inwards: false)
        case .dedent:
            syncCursorPositions()
            controller.handleIndent(inwards: true)
        case .moveLinesUp:
            syncCursorPositions()
            controller.moveLinesUp()
        case .moveLinesDown:
            syncCursorPositions()
            controller.moveLinesDown()
        }
    }

    // MARK: - Invariants

    /// What must hold after any sequence of edits. Each of these has been, or is one step from,
    /// a crash or a hang.
    private func checkInvariants(_ context: String, file: StaticString = #filePath, line: UInt = #line) {
        let storageLength = textView.textStorage.length
        let lineStorage = textView.layoutManager.lineStorage
        XCTAssertEqual(
            lineStorage.length, storageLength,
            "Line storage disagrees with the text storage at \(context)", file: file, line: line)
        XCTAssertGreaterThanOrEqual(
            lineStorage.count, 1, "Line storage is empty at \(context)", file: file, line: line)
        if storageLength > 0 {
            XCTAssertNotNil(
                lineStorage.getLine(atOffset: storageLength - 1),
                "No line holds the last character at \(context)", file: file, line: line)
        }
        for selection in textView.selectionManager.textSelections {
            XCTAssertTrue(
                selection.range.location >= 0 && selection.range.upperBound <= storageLength,
                "Selection \(selection.range) is outside 0..\(storageLength) at \(context)",
                file: file, line: line)
        }
        XCTAssertFalse(
            textView.selectionManager.textSelections.isEmpty, "No selection at \(context)",
            file: file, line: line)
    }

    // MARK: - Helpers

    private static func seed(from environment: [String: String]) -> UInt64 {
        environment["DOOP_STRESS_SEED"].flatMap(UInt64.init) ?? UInt64.random(in: 1...UInt64.max)
    }

    /// Lets async highlighting and layout deliver their results to the main thread.
    private func settle() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.001))
        textView.layoutManager.layoutLines(in: textView.visibleRect.isEmpty ? textView.frame : textView.visibleRect)
    }

    /// Types one character at a time, which is what grouping, auto-indent and bracket handling react to.
    private func type(_ string: String) {
        for character in string {
            textView.insertText(String(character))
        }
    }

    private func replaceSelections(with string: String) {
        textView.replaceCharacters(in: textView.selectionManager.textSelections.map(\.range), with: string)
    }

    private func syncCursorPositions() {
        controller.cursorPositions = textView.selectionManager.textSelections.map {
            CursorPosition(range: $0.range)
        }
    }

    private func phrase(using random: inout SeededGenerator, count: Int) -> String {
        (0..<count).map { _ in Self.words.randomElement(using: &random)! }.joined(separator: " ")
    }

    /// A deterministic document with duplicate and unsorted lines.
    private static func document(lines: Int, salt: Int) -> String {
        (0..<lines).map { index in
            let word = words[(index * 7 + salt) % words.count].replacingOccurrences(of: "\t", with: " ")
            return "Line \((index * 31 + salt) % 97) \(word) Zed"
        }.joined(separator: "\n")
    }
}

/// SplitMix64, so a failing session can be replayed from its printed seed.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_133F_5EB3
        return z ^ (z >> 31)
    }
}

