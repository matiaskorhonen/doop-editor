import Testing
import AppKit
@testable import CodeEditTextView

@Suite
@MainActor
struct TextLayoutManagerMaxWidthTests {
    /// A delegate that records the widths reported by ``TextLayoutManagerDelegate/layoutManagerMaxWidthDidChange``.
    private final class WidthRecordingDelegate: NSObject, TextLayoutManagerDelegate {
        var reportedWidths: [CGFloat] = []
        var viewportSize: CGSize
        var visibleRect: NSRect

        init(viewportSize: CGSize, visibleRect: NSRect) {
            self.viewportSize = viewportSize
            self.visibleRect = visibleRect
        }

        func layoutManagerHeightDidUpdate(newHeight: CGFloat) { }

        func layoutManagerMaxWidthDidChange(newWidth: CGFloat) {
            reportedWidths.append(newWidth)
        }

        func layoutManagerTypingAttributes() -> [NSAttributedString.Key: Any] { [:] }

        func textViewportSize() -> CGSize { viewportSize }

        func layoutManagerYAdjustment(_ yAdjustment: CGFloat) { }
    }

    /// Regression test: laying out lines has to grow ``TextLayoutManager/maxLineWidth`` to the widest line it laid
    /// out. `layoutLine` used to shadow its `inout maxFoundLineWidth` parameter with a local `var`, so every width
    /// it found was written to the copy and discarded. `maxLineWidth` then stayed at `0` forever, which with
    /// `wrapLines == false` left the document no wider than the viewport and made horizontal scrolling impossible.
    @Test
    func layoutGrowsMaxLineWidthToWidestLine() throws {
        let longLine = String(repeating: "a", count: 200)
        let textView = TextView(string: "short\n\(longLine)", wrapLines: false)
        textView.frame = NSRect(x: 0, y: 0, width: 100, height: 100)

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        scrollView.documentView = textView

        let layoutManager = try #require(textView.layoutManager)
        layoutManager.setNeedsLayout()
        layoutManager.layoutLines(in: NSRect(x: 0, y: 0, width: 100, height: 100))

        // Both lines are laid out (they're well within the layout window), so the widest one determines the
        // document's width. It has to be wider than the viewport, otherwise there'd be nothing to scroll to.
        let expectedWidth = try #require(
            layoutManager.textLineForIndex(1)?.data.lineFragments.first?.data.width
        )
        #expect(expectedWidth > 100)
        #expect(layoutManager.maxLineWidth == expectedWidth)
        #expect(layoutManager.estimatedWidth() == expectedWidth + layoutManager.edgeInsets.horizontal)

        // ...and the text view's frame grows to fit it, which is what makes the scroll view scroll horizontally.
        textView.updateFrameIfNeeded()
        #expect(textView.frame.width == expectedWidth + layoutManager.edgeInsets.horizontal)
    }

    /// The delegate has to be told about the new width, since that's what drives the text view's frame update and
    /// therefore the horizontal scroll extent.
    @Test
    func layoutNotifiesDelegateOfNewMaxWidth() throws {
        let textStorage = NSTextStorage(string: String(repeating: "a", count: 200))
        let layoutView = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        let delegate = WidthRecordingDelegate(
            viewportSize: CGSize(width: 100, height: 100),
            visibleRect: NSRect(x: 0, y: 0, width: 100, height: 100)
        )
        let layoutManager = TextLayoutManager(
            textStorage: textStorage,
            lineHeightMultiplier: 1.0,
            wrapLines: false,
            textView: layoutView,
            delegate: delegate
        )

        layoutManager.setNeedsLayout()
        layoutManager.layoutLines(in: NSRect(x: 0, y: 0, width: 100, height: 100))

        #expect(delegate.reportedWidths.last == layoutManager.maxLineWidth)
        #expect(try #require(delegate.reportedWidths.last) > 100)
    }

    /// The width only ever grows during a layout pass — a pass that lays out only narrow lines must not shrink the
    /// document back down and yank the horizontal scroll position with it.
    @Test
    func layoutOfNarrowerLinesDoesNotShrinkMaxLineWidth() throws {
        let longLine = String(repeating: "a", count: 200)
        let textView = TextView(string: "\(longLine)\nshort", wrapLines: false)
        textView.frame = NSRect(x: 0, y: 0, width: 100, height: 100)

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        scrollView.documentView = textView

        let layoutManager = try #require(textView.layoutManager)
        layoutManager.setNeedsLayout()
        layoutManager.layoutLines(in: NSRect(x: 0, y: 0, width: 100, height: 100))

        let widestWidth = layoutManager.maxLineWidth
        #expect(widestWidth > 100)

        // Lay out only the second, much shorter line.
        let shortLinePosition = try #require(layoutManager.textLineForIndex(1))
        layoutManager.setNeedsLayout()
        layoutManager.layoutLines(
            in: NSRect(x: 0, y: shortLinePosition.yPos, width: 100, height: shortLinePosition.height)
        )

        #expect(layoutManager.maxLineWidth == widestWidth)
    }
}
