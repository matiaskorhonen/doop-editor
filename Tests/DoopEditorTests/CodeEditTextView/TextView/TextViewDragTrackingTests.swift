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

    /// A mouse event just inside the first character, at `y` in the text view.
    ///
    /// Only the press is passed to `mouseDown` directly. The drags and the mouse up go through the window's event
    /// queue, which round-trips them through screen coordinates - and on a CI runner, whose screen isn't this
    /// Mac's, that can land them a line or two away from where they were aimed. So the queued events aim well
    /// below the last line, where a shift either way still covers every line.
    private func event(_ type: NSEvent.EventType, _ textView: TextView, y: CGFloat) throws -> NSEvent {
        let firstCharacter = try XCTUnwrap(textView.layoutManager.rectForOffset(0))
        let point = textView.convert(CGPoint(x: firstCharacter.minX + 1, y: y), to: nil)
        return try XCTUnwrap(
            NSEvent.mouseEvent(
                with: type,
                location: point,
                modifierFlags: .option,
                timestamp: 0,
                windowNumber: window.windowNumber,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: type == .leftMouseUp ? 0 : 1
            )
        )
    }

    /// The press: the vertical middle of the first line.
    private func pressY(_ textView: TextView) throws -> CGFloat {
        let firstLine = try XCTUnwrap(textView.layoutManager.textLineForIndex(0))
        return firstLine.yPos + firstLine.height / 2
    }

    /// Well below the last line, but inside the text view.
    private func belowTheTextY(_ textView: TextView) -> CGFloat {
        textView.layoutManager.estimatedHeight() + 60
    }

    func test_dragEventsQueuedBeforeTheMouseUpAreAllApplied() throws {
        let textView = makeTextView(string: "1\n\n2\n\n3")

        for _ in 0..<4 {
            window.postEvent(try event(.leftMouseDragged, textView, y: belowTheTextY(textView)), atStart: false)
        }
        window.postEvent(try event(.leftMouseUp, textView, y: belowTheTextY(textView)), atStart: false)

        textView.mouseDown(with: try event(.leftMouseDown, textView, y: try pressY(textView)))

        XCTAssertEqual(
            textView.selectionManager.textSelections.map(\.range),
            [0, 2, 3, 5, 6].map { NSRange(location: $0, length: 0) }
        )
        XCTAssertNil(textView.mouseDragAnchor)
    }

    /// The live button state still ends a drag whose mouse up never arrives - once the queue is empty.
    func test_aDragWithNoMouseUpEndsOnceTheQueueIsEmpty() throws {
        let textView = makeTextView(string: "1\n\n2\n\n3")
        window.postEvent(try event(.leftMouseDragged, textView, y: belowTheTextY(textView)), atStart: false)

        textView.mouseDown(with: try event(.leftMouseDown, textView, y: try pressY(textView)))

        XCTAssertEqual(
            textView.selectionManager.textSelections.map(\.range),
            [0, 2, 3, 5, 6].map { NSRange(location: $0, length: 0) }
        )
        XCTAssertNil(textView.mouseDragAnchor)
    }
}
