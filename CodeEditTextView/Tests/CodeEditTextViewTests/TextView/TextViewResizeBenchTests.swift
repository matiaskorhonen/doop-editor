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

    // MARK: - Integration: long lines throttle to a steady cadence, not per-tick

    /// Simulates dragging a window edge while viewing a document containing one huge, unbreakable line
    /// (e.g. base64-encoded content), with line wrapping on. Each tick of a live window resize used to be
    /// forwarded unconditionally into `updatedViewport` -> `updateFrameIfNeeded` -> a synchronous
    /// `layoutManager.layoutLines()` call. `updatedViewport` now throttles that work while `isInLiveResizeDrag`
    /// is true *and* a visible line is over `TextView.liveResizeReflowLineLengthThreshold`: the first tick of
    /// the drag reflows immediately, but a tight burst of ticks arriving within one throttle window (as this
    /// test fires, with no real elapsed time between them) coalesces into a single pending trailing reflow
    /// rather than one per tick, keeping the burst itself cheap.
    func test_liveResizeOfHugeSingleLineCoalescesBurstOfTicks() {
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
        // blocked main thread. With the fix, only the first tick of the burst pays that cost (the rest
        // coalesce into one pending trailing reflow), so the average per tick should still be cheap.
        XCTAssertLessThan(
            perTick,
            0.05,
            "expected resize ticks mid-drag to be cheap on average (only the leading tick reflows); got " +
            "\(perTick)s/tick over \(resizeTickCount) ticks (total \(dragElapsed)s)"
        )

        // All ticks after the first were coalesced into a pending trailing reflow rather than reflowing
        // individually, so the frame is left at the last perturbed width rather than re-synced.
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

    /// If the user pauses mid-drag (ticks stop arriving, but the mouse hasn't been released yet), a huge
    /// line should still catch up once the throttle interval elapses, rather than staying frozen until
    /// `viewDidEndLiveResize()`. This proves both halves of the throttle: ticks arriving in a tight burst are
    /// coalesced (no reflow yet immediately after the burst, beyond the leading tick), and the trailing timer
    /// eventually fires on its own once the interval elapses.
    func test_longLineReflowsOnceDragPausesBeforeDragEnd() {
        let string = String(repeating: "a", count: 400_000)
        let (textView, scrollView) = makeResizableTextView(string: string)

        let originalInterval = TextView.liveResizeReflowThrottleInterval
        TextView.liveResizeReflowThrottleInterval = 0.02 // keep the test fast
        defer { TextView.liveResizeReflowThrottleInterval = originalInterval }

        textView.viewWillStartLiveResize()
        simulateLiveResizeTicks(5, textView: textView, scrollView: scrollView)

        // Immediately after the burst, only the leading tick reflowed; the rest coalesced into a pending
        // trailing reflow, so the frame isn't re-synced yet.
        XCTAssertNotEqual(textView.frame.size.width, scrollView.contentSize.width)

        // Ticks stop (the user pauses mid-drag, before releasing the mouse). After waiting out the
        // throttle interval, the pending reflow should fire on its own, without viewDidEndLiveResize.
        let expectation = expectation(description: "throttled reflow fires")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { expectation.fulfill() }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(
            textView.frame.size.width,
            scrollView.contentSize.width,
            "expected the throttled reflow to fire once the drag paused, before the drag ended"
        )
    }

    /// The key difference from a plain debounce: even if ticks *never* go quiet (a real sustained drag),
    /// reflow must still happen at a steady cadence rather than only once the drag ends. Keeps posting
    /// ticks continuously for well over one throttle interval and checks that the throttle's last-reflow
    /// timestamp advances on its own partway through, proving it isn't waiting for the ticking to stop.
    func test_longLineReflowsPeriodicallyDuringContinuousTicking() throws {
        let string = String(repeating: "a", count: 400_000)
        let (textView, scrollView) = makeResizableTextView(string: string)

        let originalInterval = TextView.liveResizeReflowThrottleInterval
        TextView.liveResizeReflowThrottleInterval = 0.05 // keep the test fast
        defer { TextView.liveResizeReflowThrottleInterval = originalInterval }

        textView.viewWillStartLiveResize()

        // First tick reflows immediately (the leading edge) and records the throttle's last-reflow time.
        simulateLiveResizeTicks(1, textView: textView, scrollView: scrollView)
        let firstReflowTime = try XCTUnwrap(textView.liveResizeLastReflowTime)

        // Keep ticking continuously (never letting ticks go quiet) for well over one throttle interval, as
        // a sustained live-resize drag would.
        var tickCount = 0
        let ticker = Timer.scheduledTimer(withTimeInterval: 0.005, repeats: true) { _ in
            tickCount += 1
            textView.frame.size.width = 800 - CGFloat(tickCount % 10)
            NotificationCenter.default.post(name: NSView.frameDidChangeNotification, object: scrollView.contentView)
        }
        defer { ticker.invalidate() }

        let waitedPastThrottleWindow = expectation(description: "wait past one throttle interval while still ticking")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { waitedPastThrottleWindow.fulfill() }
        wait(for: [waitedPastThrottleWindow], timeout: 1.0)
        ticker.invalidate()

        // Even though ticks never stopped, the throttle should have let a later reflow through: proves the
        // fix doesn't wait for the drag to go quiet like a plain debounce would.
        let laterReflowTime = try XCTUnwrap(textView.liveResizeLastReflowTime)
        XCTAssertGreaterThan(laterReflowTime, firstReflowTime)
    }
}
