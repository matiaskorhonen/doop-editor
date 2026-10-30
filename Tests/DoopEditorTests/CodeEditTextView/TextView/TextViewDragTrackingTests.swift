import XCTest
@testable import DoopEditor

/// Tests for the loop ``TextView`` runs from `mouseDown` to track a selection drag.
///
/// When the editor falls behind the pointer, the user can let go of the button while drag events are still
/// queued. The loop used to check the button's live state before dequeuing each event, so it found the button
/// up, gave up, and left the selection wherever processing had got to - an option-drag over five lines ended
/// with cursors on the first three.
final class TextViewDragTrackingTests: XCTestCase {
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

        return textView
    }

    /// A mouse event at the vertical middle of `line`, just inside the first character.
    private func event(
        _ type: NSEvent.EventType,
        _ textView: TextView,
        line: Int,
        modifierFlags: NSEvent.ModifierFlags
    ) throws -> NSEvent {
        let linePosition = try XCTUnwrap(textView.layoutManager.textLineForIndex(line))
        let firstCharacter = try XCTUnwrap(textView.layoutManager.rectForOffset(0))
        let point = textView.convert(
            CGPoint(x: firstCharacter.minX + 1, y: linePosition.yPos + linePosition.height / 2),
            to: nil
        )
        return try XCTUnwrap(
            NSEvent.mouseEvent(
                with: type,
                location: point,
                modifierFlags: modifierFlags,
                timestamp: 0,
                windowNumber: window.windowNumber,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: type == .leftMouseUp ? 0 : 1
            )
        )
    }

    func test_dragEventsQueuedBeforeTheMouseUpAreAllApplied() throws {
        let textView = makeTextView(string: "1\n\n2\n\n3")

        for line in 1...4 {
            window.postEvent(try event(.leftMouseDragged, textView, line: line, modifierFlags: .option), atStart: false)
        }
        window.postEvent(try event(.leftMouseUp, textView, line: 4, modifierFlags: .option), atStart: false)

        textView.mouseDown(with: try event(.leftMouseDown, textView, line: 0, modifierFlags: .option))

        XCTAssertEqual(
            textView.selectionManager.textSelections.map(\.range),
            [0, 2, 3, 5, 6].map { NSRange(location: $0, length: 0) }
        )
        XCTAssertNil(textView.mouseDragAnchor)
    }

    /// The live button state still ends a drag whose mouse up never arrives - once the queue is empty.
    func test_aDragWithNoMouseUpEndsOnceTheQueueIsEmpty() throws {
        let textView = makeTextView(string: "1\n\n2\n\n3")
        window.postEvent(try event(.leftMouseDragged, textView, line: 2, modifierFlags: .option), atStart: false)

        textView.mouseDown(with: try event(.leftMouseDown, textView, line: 0, modifierFlags: .option))

        XCTAssertEqual(
            textView.selectionManager.textSelections.map(\.range),
            [0, 2, 3].map { NSRange(location: $0, length: 0) }
        )
        XCTAssertNil(textView.mouseDragAnchor)
    }
}
