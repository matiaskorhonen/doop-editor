import XCTest
@testable import CodeEditTextView

/// Tests for the nested event-tracking loop `mouseDown` enters to follow a selection drag
/// (`TextView+Mouse.trackSelectionDrag`).
final class TextViewMouseTrackingTests: XCTestCase {
    private var window: NSWindow!

    private func makeTextView(string: String = "hello world\nsecond line") -> TextView {
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

    private func makeLeftMouseEvent(_ type: NSEvent.EventType, at point: NSPoint, clickCount: Int = 1) throws -> NSEvent {
        try XCTUnwrap(
            NSEvent.mouseEvent(
                with: type,
                location: point,
                modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber,
                context: nil,
                eventNumber: 0,
                clickCount: clickCount,
                pressure: 1
            )
        )
    }

    override func tearDown() {
        window = nil
        super.tearDown()
    }

    /// `trackSelectionDrag` used to loop until it dequeued a `.leftMouseUp` and had no other exit, so anything
    /// else that consumed the mouse up — a drag-and-drop session's own event loop, a modal sheet — left it
    /// spinning at its autoscroll cadence forever, reapplying the last drag position to the selection.
    ///
    /// No mouse button is physically held during a test run, so `NSEvent.pressedMouseButtons` reports the drag
    /// is over and the loop must give up rather than wait for a mouse up that will never arrive.
    ///
    /// - Note: If this regresses, this test *hangs* rather than failing: it blocks the main thread inside
    ///         `mouseDown`, which is exactly the editor-freezing symptom being guarded against.
    func test_selectionDragTrackingTerminatesWithoutAMouseUp() throws {
        let textView = makeTextView()
        let event = try makeLeftMouseEvent(.leftMouseDown, at: NSPoint(x: 20, y: 10))

        let start = Date()
        textView.mouseDown(with: event)
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertLessThan(elapsed, 1.0, "expected the tracking loop to bail out promptly, not spin waiting for a mouse up")
        XCTAssertNil(textView.mouseDragAnchor, "expected the drag anchor to be cleared when tracking gives up")
    }

    /// A drag-and-drop session runs its own event loop and consumes the mouse up, so the tracking loop has to
    /// stand down as soon as one starts rather than competing with it for the selection.
    func test_selectionDragTrackingStopsOnceADragAndDropSessionStarts() throws {
        let textView = makeTextView()
        textView.isDragging = true
        defer { textView.isDragging = false }

        let event = try makeLeftMouseEvent(.leftMouseDown, at: NSPoint(x: 20, y: 10))

        let start = Date()
        textView.mouseDown(with: event)
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertLessThan(elapsed, 1.0, "expected tracking to yield to the drag-and-drop session immediately")
        XCTAssertNil(textView.mouseDragAnchor)
    }

    /// The autoscroll timer only ever runs during a drag-and-drop session, when `processDragEvent` ignores
    /// events anyway, so it must not be relied on to update the selection.
    func test_autoscrollTimerIsClearedOnMouseUp() throws {
        let textView = makeTextView()
        textView.setUpMouseAutoscrollTimer()
        XCTAssertNotNil(textView.mouseDragTimer)

        textView.mouseUp(with: try makeLeftMouseEvent(.leftMouseUp, at: NSPoint(x: 20, y: 10)))

        XCTAssertNil(textView.mouseDragTimer, "expected mouseUp to tear down the autoscroll timer")
        XCTAssertNil(textView.mouseDragAnchor)
    }
}
