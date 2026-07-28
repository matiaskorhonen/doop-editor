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

    /// Regression test: a line taller than the viewport is handled by a branch of `layoutLines(in:)` that used to
    /// only *add* missing fragment views, never move existing ones. When a line above it changed height, the tall
    /// line shifted down but its already-placed fragments stayed put, drawing on top of the content above them.
    @Test
    func fragmentsOfHugeLineFollowHeightChangeOfLineAbove() throws {
        let textView = TextView(string: "A\n" + String(repeating: "a", count: 400_000), wrapLines: true)
        textView.frame = NSRect(x: 0, y: 0, width: 800, height: 600)

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        scrollView.documentView = textView

        let layoutManager = try #require(textView.layoutManager)
        layoutManager.setNeedsLayout()

        let visibleRect = NSRect(x: 0, y: 0, width: 800, height: 600)
        layoutManager.layoutLines(in: visibleRect)

        let firstLine = try #require(layoutManager.textLineForIndex(0))
        let tallLine = try #require(layoutManager.textLineForIndex(1))

        // The branch under test only runs for lines taller than the whole layout window.
        #expect(tallLine.height > visibleRect.height + (layoutManager.verticalLayoutPadding * 2))

        var placedBefore = 0
        for fragment in tallLine.data.lineFragments
        where layoutManager.viewReuseQueue.getView(forKey: fragment.data.id) != nil {
            placedBefore += 1
        }
        #expect(placedBefore > 0, "The tall line should already have fragment views placed.")

        let firstLineHeightBefore = firstLine.height
        let tallLineYPosBefore = tallLine.yPos

        // Grow the *first* line so everything below it shifts down.
        textView.textStorage.replaceCharacters(
            in: NSRange(location: 0, length: 1),
            with: String(repeating: "b", count: 3000)
        )
        layoutManager.layoutLines(in: visibleRect)

        let firstLineAfter = try #require(layoutManager.textLineForIndex(0))
        let tallLineAfter = try #require(layoutManager.textLineForIndex(1))
        #expect(firstLineAfter.height > firstLineHeightBefore, "The first line should have grown taller.")
        #expect(tallLineAfter.yPos > tallLineYPosBefore, "The tall line should have shifted down.")

        for fragment in tallLineAfter.data.lineFragments {
            guard let view = layoutManager.viewReuseQueue.getView(forKey: fragment.data.id) else { continue }
            let expectedY = tallLineAfter.yPos + fragment.yPos
            #expect(
                abs(view.frame.origin.y - expectedY) < 0.5,
                "Fragment view sits at \(view.frame.origin.y), expected \(expectedY)."
            )
            #expect(
                fragment.data.documentRange == fragment.range.translate(location: tallLineAfter.range.location),
                "Fragment's document range is stale after the edit above it."
            )
        }
    }
}
