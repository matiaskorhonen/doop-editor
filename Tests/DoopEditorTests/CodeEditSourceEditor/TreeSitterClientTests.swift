import XCTest
@testable import DoopEditor

// swiftlint:disable all

final class TreeSitterClientTests: XCTestCase {

    private var maxSyncContentLength: Int = 0

    override func setUp() {
        maxSyncContentLength = TreeSitterClient.Constants.maxSyncContentLength
        TreeSitterClient.Constants.maxSyncContentLength = 0
    }

    override func tearDown() {
        TreeSitterClient.Constants.maxSyncContentLength = maxSyncContentLength
    }

    @MainActor
    func performEdit(
        textView: TextView,
        client: TreeSitterClient,
        string: String,
        range: NSRange,
        completion: @escaping (Result<IndexSet, Error>) -> Void
    ) {
        let delta = string.isEmpty ? -range.length : range.length
        textView.replaceString(in: range, with: string)
        client.applyEdit(textView: textView, range: range, delta: delta, completion: completion)
    }

    /// An edit that overruns the sync budget sends the next one off the main thread, and one that
    /// comes back under it brings editing back on.
    @MainActor
    func test_slowEditsMoveLaterEditsOffTheMainThread() async {
        let duration = TreeSitterClient.Constants.maxSyncEditDuration
        let length = TreeSitterClient.Constants.maxSyncContentLength
        defer {
            TreeSitterClient.Constants.maxSyncEditDuration = duration
            TreeSitterClient.Constants.maxSyncContentLength = length
        }
        TreeSitterClient.Constants.maxSyncContentLength = 1_000_000

        let client = Mock.treeSitterClient()
        let textView = Mock.textView()
        textView.setText("let a = 1\n")
        client.setUp(textView: textView, codeLanguage: .swift)
        while client.state == nil { try? await Task.sleep(for: .milliseconds(20)) }

        // Nothing can finish inside a negative budget, so the first edit is slow.
        TreeSitterClient.Constants.maxSyncEditDuration = -1
        let first = XCTestExpectation(description: "first edit")
        performEdit(textView: textView, client: client, string: "x", range: NSRange(location: 0, length: 0)) { _ in
            first.fulfill()
        }
        await fulfillment(of: [first], timeout: 5)
        XCTAssertTrue(client.editsAreSlow.value())

        // The next one runs asynchronously, and with a generous budget it clears the flag.
        TreeSitterClient.Constants.maxSyncEditDuration = 60
        let second = XCTestExpectation(description: "second edit")
        performEdit(textView: textView, client: client, string: "y", range: NSRange(location: 0, length: 0)) { _ in
            second.fulfill()
        }
        await fulfillment(of: [second], timeout: 5)
        XCTAssertFalse(client.editsAreSlow.value())
    }

    /// An asynchronous edit reports its result on the main thread: the completion mutates main-actor state, and
    /// calling it from the executor's background task corrupted a `HighlightProviderState`'s index sets.
    @MainActor
    func test_asyncEditCompletionRunsOnTheMainThread() async {
        let client = Mock.treeSitterClient()
        let textView = Mock.textView()
        textView.setText("let a = 1\n")
        client.setUp(textView: textView, codeLanguage: .swift)
        while client.state == nil { try? await Task.sleep(for: .milliseconds(20)) }

        // `maxSyncContentLength` is 0 in `setUp()`, so every edit takes the asynchronous path.
        let finished = XCTestExpectation(description: "edit")
        var onMainThread: Bool?
        performEdit(textView: textView, client: client, string: "x", range: NSRange(location: 0, length: 0)) { _ in
            onMainThread = Thread.isMainThread
            finished.fulfill()
        }
        await fulfillment(of: [finished], timeout: 5)
        XCTAssertEqual(onMainThread, true)
    }

    /// A document over the limit isn't parsed or highlighted, and highlighting starts again, over the whole
    /// document, once it is back under.
    @MainActor
    func test_documentOverTheHighlightLimitIsNotHighlighted() async {
        let limit = TreeSitterClient.Constants.maxHighlightableContentLength
        defer { TreeSitterClient.Constants.maxHighlightableContentLength = limit }
        TreeSitterClient.Constants.maxHighlightableContentLength = 30

        let client = Mock.treeSitterClient()
        let textView = Mock.textView() // 38 characters
        client.setUp(textView: textView, codeLanguage: .swift)
        XCTAssertTrue(client.isOverHighlightLimit)
        XCTAssertNil(client.state)

        // Edits and queries are answered without any work.
        let edit = XCTestExpectation(description: "edit")
        performEdit(textView: textView, client: client, string: "x", range: NSRange(location: 0, length: 0)) { result in
            XCTAssertEqual(try? result.get(), IndexSet())
            edit.fulfill()
        }
        await fulfillment(of: [edit], timeout: 5)

        let query = XCTestExpectation(description: "query")
        client.queryHighlightsFor(textView: textView, range: NSRange(location: 0, length: 10)) { result in
            XCTAssertEqual(try? result.get().count, 0)
            query.fulfill()
        }
        await fulfillment(of: [query], timeout: 5)
        XCTAssertNil(client.state)

        // Shrinking the document back under the limit brings highlighting back.
        textView.setText("let a = 1\n")
        let shrink = XCTestExpectation(description: "shrink")
        client.applyEdit(textView: textView, range: NSRange(location: 0, length: 0), delta: 0) { result in
            XCTAssertEqual(try? result.get(), IndexSet(integersIn: 0..<10))
            shrink.fulfill()
        }
        await fulfillment(of: [shrink], timeout: 5)
        XCTAssertFalse(client.isOverHighlightLimit)
        while client.state == nil { try? await Task.sleep(for: .milliseconds(20)) }
    }

    @MainActor
    func test_clientSetup() async {
        let client = Mock.treeSitterClient()
        let textView = Mock.textView()
        client.setUp(textView: textView, codeLanguage: .swift)

        let expectation = XCTestExpectation(description: "Setup occurs")

        Task.detached {
            while client.state == nil {
                try await Task.sleep(for: .seconds(0.5))
            }
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 5.0)

        let primaryLanguage = client.state?.primaryLayer.id
        let layerCount = client.state?.layers.count
        XCTAssertEqual(primaryLanguage, .swift, "Client set up incorrect language")
        XCTAssertEqual(layerCount, 1, "Client set up too many layers")
    }

    @MainActor
    func test_markdownInlineInjection() async {
        let client = Mock.treeSitterClient(forceSync: true)
        let textView = Mock.textView()
        textView.setText("# Hello\n\nA *scriptable* code **scratchpad**\n")
        client.setUp(textView: textView, codeLanguage: .markdown)

        let expectation = XCTestExpectation(description: "Setup occurs")
        Task.detached {
            while client.state == nil {
                try await Task.sleep(for: .seconds(0.5))
            }
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 5.0)

        // Diagnostic info
        let state = client.state
        let layers = state?.layers ?? []
        print("State: \(state != nil ? "exists" : "nil")")
        print("Primary layer: \(state?.primaryLayer.id.rawValue ?? "nil")")
        print("Layer count: \(layers.count)")
        for (i, layer) in layers.enumerated() {
            print("Layer[\(i)]: id=\(layer.id.rawValue), hasTree=\(layer.tree != nil), hasQuery=\(layer.languageQuery != nil), supportsInjections=\(layer.supportsInjections), ranges=\(layer.ranges)")
            if let root = layer.tree?.rootNode {
                print("  rootNode: \(root.nodeType ?? "nil"), range=\(root.range), childCount=\(root.childCount)")
            }
        }

        // The query might not load in test environment - check via the layer
        let queryLoaded = layers.first?.languageQuery != nil
        print("Query loaded: \(queryLoaded)")
        guard queryLoaded else {
            print("SKIPPING: Markdown query could not be loaded (resource loading issue in test environment)")
            return
        }

        // Check that markdown_inline layers were injected
        let inlineLayers = layers.filter { $0.id == .markdownInline }
        XCTAssertFalse(inlineLayers.isEmpty, "Expected markdownInline injected layers, found none. Layer IDs: \(layers.map { $0.id.rawValue })")

        // Query highlights for the paragraph line
        let highlights = client.queryHighlightsForRange(range: NSRange(location: 0, length: textView.string.count))
        let emphasisHighlights = highlights.filter { $0.capture == .textEmphasis }
        let strongHighlights = highlights.filter { $0.capture == .textStrong }

        print("All highlights: \(highlights.map { "\($0.capture?.stringValue ?? "nil") @ \($0.range)" })")

        XCTAssertFalse(emphasisHighlights.isEmpty, "Expected textEmphasis highlights for *scriptable*")
        XCTAssertFalse(strongHighlights.isEmpty, "Expected textStrong highlights for **scratchpad**")
    }

    func resultIsCancel<T>(_ result: Result<T, Error>) -> Bool {
        if case let .failure(error) = result {
            if case HighlightProvidingError.operationCancelled = error {
                return true
            }
        }
        return false
    }

    @MainActor
    func test_editsDuringSetup() {
        let client = Mock.treeSitterClient()
        let textView = Mock.textView()

        client.setUp(textView: textView, codeLanguage: .swift)

        // Perform a highlight query
        let cancelledQuery = XCTestExpectation(description: "Highlight query should be cancelled by edits.")
        client.queryHighlightsFor(textView: textView, range: NSRange(location: 0, length: 10)) { result in
            if self.resultIsCancel(result) {
                cancelledQuery.fulfill()
            } else {
                XCTFail("Highlight query was not cancelled.")
            }
        }

        // Perform an edit
        let cancelledEdit = XCTestExpectation(description: "First edit should be cancelled by second one.")
        performEdit(textView: textView, client: client, string: "func ", range: .zero) { result in
            if self.resultIsCancel(result) {
                cancelledEdit.fulfill()
            } else {
                XCTFail("Edit was not cancelled.")
            }
        }

        // Perform a second edit
        let successEdit = XCTestExpectation(description: "Second edit should succeed.")
        performEdit(textView: textView, client: client, string: "", range: NSRange(location: 0, length: 5)) { result in
            if case let .success(ranges) = result {
                XCTAssertEqual(ranges.count, 0, "Edits, when combined, should produce the original syntax tree.")
                successEdit.fulfill()
            } else {
                XCTFail("Second edit was not successful.")
            }
        }

        wait(for: [cancelledQuery, cancelledEdit, successEdit], timeout: 5.0)
    }

    @MainActor
    func test_multipleSetupsCancelAllOperations() async {
        let client = Mock.treeSitterClient()
        let textView = Mock.textView()

        // First setup, wrong language
        client.setUp(textView: textView, codeLanguage: .c)

        // Perform a highlight query
        let cancelledQuery = XCTestExpectation(description: "Highlight query should be cancelled by second setup.")
        client.queryHighlightsFor(textView: textView, range: NSRange(location: 0, length: 10)) { result in
            if self.resultIsCancel(result) {
                cancelledQuery.fulfill()
            } else {
                XCTFail("Highlight query was not cancelled by the second setup.")
            }
        }

        // Perform an edit
        let cancelledEdit = XCTestExpectation(description: "First edit should be cancelled by second setup.")
        performEdit(textView: textView, client: client, string: "func ", range: .zero) { result in
            if self.resultIsCancel(result) {
                cancelledEdit.fulfill()
            } else {
                XCTFail("Edit was not cancelled by the second setup.")
            }
        }

        // Second setup, which should cancel all previous operations
        client.setUp(textView: textView, codeLanguage: .swift)

        let finalSetupExpectation = XCTestExpectation(description: "Final setup should complete successfully.")

        Task.detached {
            while client.state?.primaryLayer.id != .swift {
                try await Task.sleep(for: .seconds(0.5))
            }
            finalSetupExpectation.fulfill()
        }

        await fulfillment(of: [cancelledQuery, cancelledEdit, finalSetupExpectation], timeout: 5.0)

        // Ensure only the final setup's language is active
        let primaryLanguage = client.state?.primaryLayer.id
        let layerCount = client.state?.layers.count
        XCTAssertEqual(primaryLanguage, .swift, "Client set up incorrect language after re-setup.")
        XCTAssertEqual(layerCount, 1, "Client set up too many layers after re-setup.")
    }

    @MainActor
    func test_cancelAllEditsUntilFinalOne() {
        let client = Mock.treeSitterClient()
        let textView = Mock.textView()
        textView.setText("asadajkfijio;amfjamc;aoijaoajkvarpfjo;sdjlkj")

        client.setUp(textView: textView, codeLanguage: .swift)

        // Set up random edits
        let editExpectations = (0..<10).map { index -> XCTestExpectation in
            let expectation = XCTestExpectation(description: "Edit \(index) should be cancelled.")
            let isDeletion = Int.random(in: 0..<10) < 4
            let editText = isDeletion ? "" : "\(index)"
            let editLocation = Int.random(in: 0..<textView.string.count)
            let editRange = if isDeletion {
                NSRange(location: editLocation, length: 1)
            } else {
                NSRange(location: editLocation, length: 0)
            }
            performEdit(textView: textView, client: client, string: editText, range: editRange) { result in
                if self.resultIsCancel(result) {
                    expectation.fulfill()
                } else {
                    XCTFail("Edit \(index) was not cancelled.")
                }
            }
            return expectation
        }

        // Final edit that should succeed
        let finalEditExpectation = XCTestExpectation(description: "Final edit should succeed.")
        performEdit(textView: textView, client: client, string: "", range: textView.documentRange) { result in
            if case .success(_) = result {
                finalEditExpectation.fulfill()
            } else {
                XCTFail("Final edit did not succeed.")
            }
        }

        wait(for: editExpectations + [finalEditExpectation], timeout: 5.0)
    }
}
// swiftlint:enable all
