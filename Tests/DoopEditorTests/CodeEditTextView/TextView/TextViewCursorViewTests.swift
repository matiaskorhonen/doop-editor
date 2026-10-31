import XCTest
@testable import DoopEditor

/// Every cursor gets a view to draw it.
///
/// ``TextSelectionManager/updateSelectionViews(force:skipTimerReset:)`` used to collect whether anything changed
/// with `didUpdate || repositionCursorSelection(…)`, which short-circuits: once one cursor had been placed, the rest
/// weren't visited. Each update added at most one cursor view, so an option-drag over five lines left only as many
/// cursors on screen as there had happened to be updates since - typing still went to all of them.
final class TextViewCursorViewTests: XCTestCase {
    private var window: NSWindow!

    override func tearDown() {
        window = nil
        super.tearDown()
    }

    private func makeTextView(string: String) -> TextView {
        let textView = TextView(string: string)
        textView.frame = NSRect(x: 0, y: 0, width: 400, height: 200)

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView?.addSubview(textView)
        textView.layoutManager.layoutLines(in: textView.frame)
        // Cursor views are only drawn for the first responder.
        textView.isFirstResponder = true

        return textView
    }

    func test_everyCursorGetsAView() throws {
        let textView = makeTextView(string: "1\n\n2\n\n3")

        textView.selectionManager.setSelectedRanges([0, 2, 3, 5, 6].map { NSRange(location: $0, length: 0) })

        let views = textView.selectionManager.textSelections.map(\.view)
        XCTAssertEqual(views.count, 5)
        XCTAssertTrue(views.allSatisfy { $0?.superview === textView }, "Cursors without a view: \(views)")
        XCTAssertEqual(
            textView.selectionManager.textSelections.map(\.boundingRect.minY),
            try (0..<5).map { try XCTUnwrap(textView.layoutManager.textLineForIndex($0)).yPos }
        )
    }

    /// Adding cursors to ones that already have views places the new ones too, not just the first new one.
    func test_cursorsAddedLaterGetViews() throws {
        let textView = makeTextView(string: "1\n\n2\n\n3")
        textView.selectionManager.setSelectedRanges([NSRange(location: 0, length: 0)])

        textView.selectionManager.setSelectedRanges([0, 2, 3, 5, 6].map { NSRange(location: $0, length: 0) })

        let views = textView.selectionManager.textSelections.map(\.view)
        XCTAssertTrue(views.allSatisfy { $0?.superview === textView }, "Cursors without a view: \(views)")
    }
}
