import XCTest
@testable import CodeEditSourceEditor
import AppKit

/// Verifies that the editor's theme background reaches the trailing edge of the scroll view regardless of the
/// system's "Show scroll bars" setting.
///
/// With legacy scrollers `NSScrollView` takes a ~15pt strip out of its content along the trailing edge and
/// lets `NSScroller` fill it with a system color, so a themed editor visibly stops short of the window edge.
/// ``EditorScrollView`` pins the style to `.overlay` so no strip is reserved.
///
/// Whether the host machine prefers overlay or legacy scrollers depends on a system setting (and on whether a
/// mouse is attached), so these tests push the scroll view towards legacy explicitly instead of relying on
/// whatever the machine or CI runner happens to be set to.
final class EditorScrollerStyleTests: XCTestCase {
    var controller: TextViewController!

    let editorBackground = NSColor(deviceRed: 0.16, green: 0.17, blue: 0.21, alpha: 1.0)

    override func setUpWithError() throws {
        controller = Mock.textViewController(theme: Mock.theme())
        controller.loadView()
    }

    override func tearDownWithError() throws {
        controller = nil
    }

    private func assertColor(
        _ color: NSColor?,
        approximatelyEquals expected: NSColor,
        tolerance: CGFloat = 0.02,
        _ message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let actual = try XCTUnwrap(color?.usingColorSpace(.deviceRGB), message, file: file, line: line)
        let expectedRGB = expected.usingColorSpace(.deviceRGB) ?? expected
        XCTAssertEqual(actual.redComponent, expectedRGB.redComponent, accuracy: tolerance, message, file: file, line: line)
        XCTAssertEqual(actual.greenComponent, expectedRGB.greenComponent, accuracy: tolerance, message, file: file, line: line)
        XCTAssertEqual(actual.blueComponent, expectedRGB.blueComponent, accuracy: tolerance, message, file: file, line: line)
    }

    /// AppKit assigns `scrollerStyle` itself — when the scroll view enters a window and whenever the system
    /// preference changes — which is what made the wrong-colored strip come and go.
    func test_scrollerStyleStaysOverlayWhenAppKitAssignsLegacy() throws {
        let scrollView = try XCTUnwrap(controller.scrollView)
        XCTAssertTrue(scrollView is EditorScrollView, "the editor should use an EditorScrollView")
        XCTAssertEqual(scrollView.scrollerStyle, .overlay)

        scrollView.scrollerStyle = .legacy

        XCTAssertEqual(scrollView.scrollerStyle, .overlay, "assigning .legacy must not stick")
    }

    /// Overlay scrollers float above the content instead of taking space from it, so the document view keeps
    /// the scroll view's full width.
    func test_contentKeepsFullWidth() throws {
        let scrollView = try XCTUnwrap(controller.scrollView)
        scrollView.frame = NSRect(x: 0, y: 0, width: 400, height: 300)
        scrollView.hasVerticalScroller = true
        // A no-op on EditorScrollView; on a plain NSScrollView this is what reserves the trailing strip, so
        // it keeps these tests meaningful whatever the host's "Show scroll bars" setting is.
        scrollView.scrollerStyle = .legacy
        scrollView.layoutSubtreeIfNeeded()
        scrollView.tile()

        XCTAssertEqual(
            scrollView.contentView.frame.width,
            scrollView.frame.width,
            accuracy: 0.01,
            "no trailing strip should be reserved for a scroller"
        )
    }

    /// The regression itself: the trailing edge of a rendered editor must be the theme's background color.
    func test_trailingEdgeUsesEditorBackground() throws {
        var configuration = Mock.config()
        configuration.appearance.theme.background = editorBackground
        controller.configuration = configuration

        let scrollView = try XCTUnwrap(controller.scrollView)
        scrollView.frame = NSRect(x: 0, y: 0, width: 400, height: 300)
        scrollView.hasVerticalScroller = true
        // A no-op on EditorScrollView; on a plain NSScrollView this is what reserves the trailing strip, so
        // it keeps these tests meaningful whatever the host's "Show scroll bars" setting is.
        scrollView.scrollerStyle = .legacy
        scrollView.layoutSubtreeIfNeeded()
        scrollView.tile()

        let rep = try XCTUnwrap(scrollView.bitmapImageRepForCachingDisplay(in: scrollView.bounds))
        scrollView.cacheDisplay(in: scrollView.bounds, to: rep)

        let sampleX = rep.pixelsWide - 2
        for y in [rep.pixelsHigh / 2, rep.pixelsHigh - 4] {
            try assertColor(
                rep.colorAt(x: sampleX, y: y),
                approximatelyEquals: editorBackground,
                "trailing edge at y=\(y) should match the editor background"
            )
        }
    }
}
