import XCTest
@testable import DoopEditor
import AppKit

/// Clicks in the gutter, and in the strip of padding between the line numbers and the text, reach the text view.
///
/// The gutter floats over the text view's left inset, so a press just before the first character - where an
/// option-drag for a column of cursors starts - used to land on a view that ignored it: the text view never saw
/// the mouse down, set no drag anchor, and the column selection that followed dropped lines.
final class GutterMouseTests: XCTestCase {
    private var window: NSWindow!

    override func tearDown() {
        window = nil
        super.tearDown()
    }

    @MainActor
    private func makeController(string: String) -> TextViewController {
        let controller = TextViewController(
            string: string,
            language: .default,
            configuration: Mock.config(),
            cursorPositions: [],
            highlightProviders: []
        )
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = controller
        window.setContentSize(NSSize(width: 500, height: 400))
        controller.view.layoutSubtreeIfNeeded()
        controller.textView.layoutManager.layoutLines()
        return controller
    }

    /// A left mouse down at `x` in the text view's coordinates, vertically centered on `line`.
    @MainActor
    private func mouseDown(_ controller: TextViewController, x: CGFloat, line: Int) throws -> NSEvent {
        let textView = try XCTUnwrap(controller.textView)
        let linePosition = try XCTUnwrap(textView.layoutManager.textLineForIndex(line))
        let point = textView.convert(CGPoint(x: x, y: linePosition.yPos + linePosition.height / 2), to: nil)
        return try XCTUnwrap(
            NSEvent.mouseEvent(
                with: .leftMouseDown,
                location: point,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: window.windowNumber,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 1
            )
        )
    }

    /// The padding between the line numbers and the text is the gutter's, which a hit test confirms - this is
    /// the premise of the tests below, not a behavior anyone relies on.
    @MainActor
    func test_paddingBeforeTheTextBelongsToTheGutter() throws {
        let controller = makeController(string: "1\n\n2\n\n3")
        let textView = try XCTUnwrap(controller.textView)
        let scrollView = try XCTUnwrap(controller.scrollView)
        let event = try mouseDown(controller, x: textView.layoutManager.edgeInsets.left - 3, line: 0)

        let hit = scrollView.hitTest(try XCTUnwrap(scrollView.superview).convert(event.locationInWindow, from: nil))

        XCTAssertTrue(hit === controller.gutterView)
    }

    @MainActor
    func test_clickInTheGutterPutsTheCursorAtTheStartOfThatLine() throws {
        let controller = makeController(string: "1\n\n2\n\n3")
        let textView = try XCTUnwrap(controller.textView)

        controller.gutterView.mouseDown(
            with: try mouseDown(controller, x: textView.layoutManager.edgeInsets.left - 3, line: 2)
        )

        XCTAssertEqual(textView.selectionManager.textSelections.map(\.range), [NSRange(location: 3, length: 0)])
    }

    /// Over the line numbers themselves, too - a gutter click is a click at the text's leading edge.
    @MainActor
    func test_clickOnALineNumberPutsTheCursorAtTheStartOfThatLine() throws {
        let controller = makeController(string: "Lorem\nIpsum\nDolet")
        let textView = try XCTUnwrap(controller.textView)

        controller.gutterView.mouseDown(with: try mouseDown(controller, x: 5, line: 1))

        XCTAssertEqual(textView.selectionManager.textSelections.map(\.range), [NSRange(location: 6, length: 0)])
    }

    /// The text view resolves a press left of its text inset on its own, the same way it clamps a drag.
    @MainActor
    func test_textViewResolvesAClickLeftOfTheText() throws {
        let controller = makeController(string: "Lorem\nIpsum\nDolet")
        let textView = try XCTUnwrap(controller.textView)

        textView.mouseDown(with: try mouseDown(controller, x: textView.layoutManager.edgeInsets.left - 3, line: 2))

        XCTAssertEqual(textView.selectionManager.textSelections.map(\.range), [NSRange(location: 12, length: 0)])
    }
}
