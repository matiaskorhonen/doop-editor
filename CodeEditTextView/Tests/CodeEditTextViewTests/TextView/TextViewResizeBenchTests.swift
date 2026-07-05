import XCTest
@testable import CodeEditTextView

final class TextViewResizeBenchTests: XCTestCase {
    /// Sets up a text view + scroll view pair and lays out `string` as a single line, ready to simulate a
    /// live-resize drag against.
    private func makeResizableTextView(string: String) -> (textView: TextView, scrollView: NSScrollView) {
        let textView = TextView(string: string, wrapLines: true)
        textView.frame = NSRect(x: 0, y: 0, width: 800, height: 600)

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        scrollView.documentView = textView

        // Establish initial layout so later calls measure a live resize, not startup cost.
        textView.layoutManager.setNeedsLayout()
        textView.layout()

        return (textView, scrollView)
    }

    /// Simulates `tickCount` ticks of a live window resize drag: on each tick, mimics the window edge moving
    /// 1pt by directly perturbing the text view's frame width, then posts the notification that
    /// `TextView+Setup.setUpScrollListeners` observes on the scroll view's clip view, which is what a real
    /// drag fires (dozens of times per second) via `NSView.frameDidChangeNotification`.
    private func simulateLiveResizeTicks(_ tickCount: Int, textView: TextView, scrollView: NSScrollView) {
        for i in 0..<tickCount {
            textView.frame.size.width = 800 - CGFloat(i)
            NotificationCenter.default.post(name: NSView.frameDidChangeNotification, object: scrollView.contentView)
        }
    }

    // MARK: - Heuristic unit tests

    func test_thresholdHeuristicIsFalseForShortLines() {
        let (textView, _) = makeResizableTextView(string: "hello world")
        XCTAssertFalse(textView.hasVisibleLineExceedingLiveResizeThreshold(in: textView.visibleRect))
    }

    func test_thresholdHeuristicIsTrueForLinesOverThreshold() {
        let string = String(repeating: "a", count: TextView.liveResizeReflowLineLengthThreshold + 1)
        let (textView, _) = makeResizableTextView(string: string)
        XCTAssertTrue(textView.hasVisibleLineExceedingLiveResizeThreshold(in: textView.visibleRect))
    }

    // MARK: - Integration: short lines keep reflowing live

    /// A document under the character threshold should keep rewrapping on every tick of a live resize drag,
    /// not just once at drag-end: `updateFrameIfNeeded()` re-syncs `frame.size.width` to the scroll view's
    /// (unchanged, 800pt-wide) content size on every tick that isn't skipped, correcting the width we
    /// perturbed in `simulateLiveResizeTicks`. If ticks were being skipped, that correction wouldn't happen
    /// until `viewDidEndLiveResize`, and the frame would be left at the last perturbed (779pt) width.
    func test_shortLineKeepsReflowingDuringLiveResizeDrag() {
        let (textView, scrollView) = makeResizableTextView(string: "hello world")

        textView.viewWillStartLiveResize()
        simulateLiveResizeTicks(20, textView: textView, scrollView: scrollView)

        XCTAssertEqual(
            textView.frame.size.width,
            scrollView.contentSize.width,
            "expected a short line's width to be re-synced (i.e. reflowed) on every tick of the drag, not just at drag-end"
        )
    }

    // MARK: - Integration: long lines defer to drag-end

    /// Simulates dragging a window edge while viewing a document containing one huge, unbreakable line
    /// (e.g. base64-encoded content), with line wrapping on. Each tick of a live window resize used to be
    /// forwarded unconditionally into `updatedViewport` -> `updateFrameIfNeeded` -> a synchronous
    /// `layoutManager.layoutLines()` call. `updatedViewport` now skips that work while `isInLiveResizeDrag`
    /// is true *and* a visible line is over `TextView.liveResizeReflowLineLengthThreshold`, deferring the
    /// rewrap to a single call once `viewDidEndLiveResize()` fires.
    func test_liveResizeOfHugeSingleLineOnlyRetypesetsOnceAtDragEnd() {
        let string = String(repeating: "a", count: 400_000)
        let (textView, scrollView) = makeResizableTextView(string: string)

        textView.viewWillStartLiveResize()

        let resizeTickCount = 20
        let dragStart = Date()
        simulateLiveResizeTicks(resizeTickCount, textView: textView, scrollView: scrollView)
        let dragElapsed = Date().timeIntervalSince(dragStart)
        let perTick = dragElapsed / Double(resizeTickCount)

        // A single frame budget is ~16ms. Before this fix, each tick fully re-typeset the huge line
        // (~0.2-0.25s per TypesetterBenchTests), so a real drag (dozens of ticks) turned into seconds of
        // blocked main thread. With the fix, ticks during the drag should be cheap no-ops.
        XCTAssertLessThan(
            perTick,
            0.05,
            "expected resize ticks mid-drag to be cheap (deferred to drag-end); got \(perTick)s/tick over " +
            "\(resizeTickCount) ticks (total \(dragElapsed)s)"
        )

        // Skipped ticks never called `updateFrameIfNeeded()`, so the frame is left at the last perturbed
        // width rather than re-synced to the scroll view's actual content width.
        XCTAssertEqual(textView.frame.size.width, 800 - CGFloat(resizeTickCount - 1))

        // Ending the drag marks the layout stale and triggers the deferred rewrap on the next layout pass
        // (mimicked here by calling `layout()` directly, as AppKit's own display cycle would): allowed to be
        // as expensive as a single full typeset of the huge line, but only once.
        let endStart = Date()
        textView.viewDidEndLiveResize()
        textView.layout()
        let endElapsed = Date().timeIntervalSince(endStart)
        XCTAssertLessThan(endElapsed, 1.0, "expected the drag-end catch-up relayout to run once, got \(endElapsed)s")
        XCTAssertEqual(textView.frame.size.width, scrollView.contentSize.width)
    }

    // MARK: - Integration: long lines debounce during a paused-but-still-live drag

    /// If the user pauses mid-drag (ticks stop arriving, but the mouse hasn't been released yet), a huge
    /// line should still catch up once the debounce interval elapses, rather than staying frozen until
    /// `viewDidEndLiveResize()`. This proves both halves of the debounce: ticks arriving in a tight burst are
    /// coalesced (no reflow yet immediately after the burst), and the trailing timer eventually fires on its
    /// own once ticks go quiet.
    func test_longLineReflowsOnceDragPausesBeforeDragEnd() {
        let string = String(repeating: "a", count: 400_000)
        let (textView, scrollView) = makeResizableTextView(string: string)

        let originalInterval = TextView.liveResizeReflowDebounceInterval
        TextView.liveResizeReflowDebounceInterval = 0.02 // keep the test fast
        defer { TextView.liveResizeReflowDebounceInterval = originalInterval }

        textView.viewWillStartLiveResize()
        simulateLiveResizeTicks(5, textView: textView, scrollView: scrollView)

        // Immediately after the burst, coalescing should mean nothing has reflowed yet.
        XCTAssertNotEqual(textView.frame.size.width, scrollView.contentSize.width)

        // Ticks stop (the user pauses mid-drag, before releasing the mouse). After waiting out the
        // debounce interval, the pending reflow should fire on its own, without viewDidEndLiveResize.
        let expectation = expectation(description: "debounced reflow fires")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { expectation.fulfill() }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(
            textView.frame.size.width,
            scrollView.contentSize.width,
            "expected the debounced reflow to fire once the drag paused, before the drag ended"
        )
    }
}
