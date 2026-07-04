import Testing
import AppKit
@testable import CodeEditTextView

@Suite
@MainActor
struct TextLayoutManagerFragmentViewBenchTests {
    /// Simulates viewing a document containing one huge, unbreakable line (e.g. base64-encoded content) in a
    /// normal-sized viewport. Only the visible slice of that line's fragments should get views; laying out every
    /// fragment of the line regardless of visibility is what caused the O(n^2) `addSubview` hang.
    @Test
    func layoutOfHugeSingleLineOnlyCreatesVisibleFragmentViews() throws {
        let string = String(repeating: "a", count: 400_000)
        let textView = TextView(string: string, wrapLines: true)
        textView.frame = NSRect(x: 0, y: 0, width: 800, height: 600)

        // `wrapLinesWidth` is driven by the enclosing scroll view's content size (TextView+TextLayoutManagerDelegate
        // .textViewportSize()); without one, wrapping is disabled entirely and the line never actually gets split
        // into multiple fragments, so a real scroll view is required to reproduce line wrapping.
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        scrollView.documentView = textView

        let layoutManager = try #require(textView.layoutManager)
        // The text view's initial `layoutLines()` call (during `init`, before it's embedded in the scroll view
        // above) already ran with an infinite wrap width. `TextLine.needsLayout(maxWidth:)` only detects a change
        // between two *finite* widths, so re-laying-out here needs an explicit invalidation.
        layoutManager.setNeedsLayout()
        let visibleRect = NSRect(x: 0, y: 0, width: 800, height: 600)
        let start = Date()
        layoutManager.layoutLines(in: visibleRect)
        let elapsed = Date().timeIntervalSince(start)

        // The line wraps into thousands of fragments (confirmed by the total height below), but the viewport is
        // only 600pt tall, so only the fragments intersecting the visible rect (plus padding) should get views.
        #expect(layoutManager.lineStorage.height > 10_000)
        #expect(textView.subviews.count < 200)
        #expect(elapsed < 1.0)
    }

    /// Regression test: after only placing fragments in the initial visible range, scrolling further into the
    /// same huge line must still place views for newly-visible fragments (they were previously left blank
    /// forever, since a line only re-lays-out in full when it first becomes visible or its typesetting changes)
    /// and must reclaim views for fragments scrolled back out of range (otherwise every fragment ever scrolled
    /// past accumulates as a permanent subview).
    @Test
    func scrollingWithinHugeSingleLinePlacesNewFragmentsAndReclaimsOldOnes() throws {
        let string = String(repeating: "a", count: 400_000)
        let textView = TextView(string: string, wrapLines: true)
        textView.frame = NSRect(x: 0, y: 0, width: 800, height: 600)

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        scrollView.documentView = textView

        let layoutManager = try #require(textView.layoutManager)
        layoutManager.setNeedsLayout()
        layoutManager.layoutLines(in: NSRect(x: 0, y: 0, width: 800, height: 600))

        let totalHeight = layoutManager.lineStorage.height
        #expect(totalHeight > 10_000)

        // Scroll to the middle of the (single, huge) line's content.
        let midY = totalHeight / 2
        layoutManager.layoutLines(in: NSRect(x: 0, y: midY, width: 800, height: 600))

        let placedYPositions = layoutManager.viewReuseQueue.usedViews.values.map(\.frame.origin.y)
        // Fragments near the middle of the document must now have views...
        #expect(placedYPositions.contains { $0 >= midY && $0 <= midY + 600 })
        // ...and fragments from the original top-of-document view must have been reclaimed, not left behind.
        #expect(!placedYPositions.contains { $0 < 300 })
        // The number of live views stays bounded to roughly a viewport's worth, regardless of how far into a
        // 400k-character line we've scrolled.
        #expect(textView.subviews.count < 200)
    }
}
