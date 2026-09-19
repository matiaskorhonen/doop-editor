import XCTest
@testable import CodeEditTextView

/// Tests for ``TextView/selectColumns(betweenPointA:pointB:)``, the square region option-dragging
/// in the editor creates.
final class TextViewColumnSelectionTests: XCTestCase {
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

    /// The x position just inside the first character of the document, and the x position two
    /// characters in. A real drag starts somewhere *within* a character, not on its leading edge.
    private func columnXPositions(_ textView: TextView) throws -> (start: CGFloat, end: CGFloat) {
        let firstCharacter = try XCTUnwrap(textView.layoutManager.rectForOffset(0))
        let thirdCharacter = try XCTUnwrap(textView.layoutManager.rectForOffset(2))
        return (firstCharacter.minX + 1, thirdCharacter.minX)
    }

    private func lineMidY(_ textView: TextView, line: Int) throws -> CGFloat {
        let position = try XCTUnwrap(textView.layoutManager.textLineForIndex(line))
        return position.yPos + (position.height / 2)
    }

    /// A column two characters wide dragged over blank lines used to drop the blank lines
    /// entirely, leaving the user without a cursor on them.
    func test_columnSelectionKeepsBlankLines() throws {
        let textView = makeTextView(string: "Lorem\n\nIpsum\n\nDolet")
        let columns = try columnXPositions(textView)

        textView.selectColumns(
            betweenPointA: CGPoint(x: columns.start, y: try lineMidY(textView, line: 0)),
            pointB: CGPoint(x: columns.end, y: try lineMidY(textView, line: 4))
        )

        XCTAssertEqual(
            textView.selectionManager.textSelections.map(\.range),
            [
                NSRange(location: 0, length: 2),
                NSRange(location: 6, length: 0),
                NSRange(location: 7, length: 2),
                NSRange(location: 13, length: 0),
                NSRange(location: 14, length: 2)
            ]
        )
    }

    /// A line too short to reach the column keeps a cursor at its end, the same as a blank one.
    func test_columnSelectionKeepsShortLines() throws {
        let textView = makeTextView(string: "Lorem\na\nIpsum")
        let thirdCharacter = try XCTUnwrap(textView.layoutManager.rectForOffset(2))
        let fifthCharacter = try XCTUnwrap(textView.layoutManager.rectForOffset(4))

        textView.selectColumns(
            betweenPointA: CGPoint(x: thirdCharacter.minX, y: try lineMidY(textView, line: 0)),
            pointB: CGPoint(x: fifthCharacter.minX, y: try lineMidY(textView, line: 2))
        )

        XCTAssertEqual(
            textView.selectionManager.textSelections.map(\.range),
            [
                NSRange(location: 2, length: 2),
                NSRange(location: 7, length: 0),
                NSRange(location: 10, length: 2)
            ]
        )
    }

    /// A drag that ends exactly on a line's top edge covers that line: the point is inside it
    /// everywhere else in the layout manager, and the y iterator's upper bound is exclusive.
    func test_columnSelectionIncludesTheLineUnderTheEndPoint() throws {
        let textView = makeTextView(string: "Lorem\n\nIpsum\n\nDolet")
        let lastLine = try XCTUnwrap(textView.layoutManager.textLineForIndex(4))
        let textStart = try XCTUnwrap(textView.layoutManager.rectForOffset(0)).minX

        textView.selectColumns(
            betweenPointA: CGPoint(x: textStart, y: try lineMidY(textView, line: 0)),
            pointB: CGPoint(x: textStart, y: lastLine.yPos)
        )

        XCTAssertEqual(
            textView.selectionManager.textSelections.map(\.range),
            [
                NSRange(location: 0, length: 0),
                NSRange(location: 6, length: 0),
                NSRange(location: 7, length: 0),
                NSRange(location: 13, length: 0),
                NSRange(location: 14, length: 0)
            ]
        )
    }
}
