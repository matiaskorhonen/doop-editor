import XCTest
@testable import DoopEditor

/// Tests for ``TextView/addCursorAbove()``, ``TextView/addCursorBelow()`` and the escape key collapsing a
/// column of cursors back to one.
final class TextViewMultiCursorTests: XCTestCase {
    private var window: NSWindow!

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

        return textView
    }

    override func tearDown() {
        window = nil
        super.tearDown()
    }

    private func setCursor(_ textView: TextView, offset: Int) {
        textView.selectionManager.setSelectedRange(NSRange(location: offset, length: 0))
    }

    private func ranges(_ textView: TextView) -> [NSRange] {
        textView.selectionManager.textSelections.map(\.range)
    }

    func test_addCursorBelowKeepsTheColumn() {
        let textView = makeTextView(string: "Lorem\nIpsum\nDolet")
        setCursor(textView, offset: 2)

        textView.addCursorBelow()
        XCTAssertEqual(ranges(textView), [NSRange(location: 2, length: 0), NSRange(location: 8, length: 0)])

        textView.addCursorBelow()
        XCTAssertEqual(
            ranges(textView),
            [NSRange(location: 2, length: 0), NSRange(location: 8, length: 0), NSRange(location: 14, length: 0)]
        )
    }

    func test_addCursorAboveKeepsTheColumn() {
        let textView = makeTextView(string: "Lorem\nIpsum\nDolet")
        setCursor(textView, offset: 14)

        textView.addCursorAbove()
        textView.addCursorAbove()

        XCTAssertEqual(
            ranges(textView),
            [NSRange(location: 2, length: 0), NSRange(location: 8, length: 0), NSRange(location: 14, length: 0)]
        )
    }

    /// A line too short to reach the column gets a cursor at its end, and the column itself survives - the next
    /// line down goes back to the original column rather than following the short line in.
    func test_addCursorBelowClampsShortLinesWithoutLosingTheColumn() {
        let textView = makeTextView(string: "Lorem ipsum\nAb\nDolet sit")
        setCursor(textView, offset: 8)

        textView.addCursorBelow()
        textView.addCursorBelow()

        XCTAssertEqual(
            ranges(textView),
            [
                NSRange(location: 8, length: 0),  // column 8 of "Lorem ipsum"
                NSRange(location: 14, length: 0),  // the end of "Ab"
                NSRange(location: 23, length: 0),  // column 8 of "Dolet sit"
            ]
        )
    }

    func test_addCursorBelowCoversBlankLines() {
        let textView = makeTextView(string: "Lorem\n\nIpsum")
        setCursor(textView, offset: 2)

        textView.addCursorBelow()
        textView.addCursorBelow()

        XCTAssertEqual(
            ranges(textView),
            [NSRange(location: 2, length: 0), NSRange(location: 6, length: 0), NSRange(location: 9, length: 0)]
        )
    }

    func test_addCursorAboveOnFirstLineDoesNothing() {
        let textView = makeTextView(string: "Lorem\nIpsum")
        setCursor(textView, offset: 2)

        textView.addCursorAbove()

        XCTAssertEqual(ranges(textView), [NSRange(location: 2, length: 0)])
    }

    func test_addCursorBelowOnLastLineDoesNothing() {
        let textView = makeTextView(string: "Lorem\nIpsum")
        setCursor(textView, offset: 8)

        textView.addCursorBelow()

        XCTAssertEqual(ranges(textView), [NSRange(location: 8, length: 0)])
    }

    /// Escape collapses back to the cursor the column grew from, not to the last one added.
    func test_cancelOperationCollapsesToTheColumnAnchor() {
        let textView = makeTextView(string: "Lorem\nIpsum\nDolet")
        setCursor(textView, offset: 8)

        textView.addCursorBelow()
        textView.addCursorAbove()
        XCTAssertEqual(ranges(textView).count, 3)

        textView.cancelOperation(nil)

        XCTAssertEqual(ranges(textView), [NSRange(location: 8, length: 0)])
    }

    /// A column made by option-dragging has no anchor, so it collapses to its topmost cursor.
    func test_cancelOperationCollapsesADraggedColumnToItsTop() {
        let textView = makeTextView(string: "Lorem\nIpsum\nDolet")
        textView.selectionManager.setSelectedRanges([
            NSRange(location: 2, length: 0),
            NSRange(location: 8, length: 0),
            NSRange(location: 14, length: 0),
        ])

        textView.cancelOperation(nil)

        XCTAssertEqual(ranges(textView), [NSRange(location: 2, length: 0)])
    }
}
