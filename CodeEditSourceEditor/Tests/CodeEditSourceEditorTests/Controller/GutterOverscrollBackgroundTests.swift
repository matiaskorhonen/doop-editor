import XCTest
@testable import CodeEditSourceEditor
import AppKit

/// Verifies that `GutterBackgroundClipView` — the source editor's scroll view `contentView` — fills the
/// elastic/rubber-band overscroll area above the top of the document with the gutter's background color in
/// the gutter's column, and the editor's background color everywhere else, instead of a single flat color
/// that ignores the gutter.
///
/// These tests exercise a bare `GutterBackgroundClipView` with no `documentView` attached, rather than a live
/// `NSScrollView`/`NSClipView` pair. A real, in-use `NSClipView` clamps any `bounds` change to stay within its
/// document view's frame (that's exactly the constraint elastic scrolling temporarily overrides at the AppKit
/// level), which makes it impossible to deterministically force an overscrolled `bounds.origin` from a unit
/// test. A detached clip view has nothing to constrain against, so `bounds` can be set freely — letting us
/// test the fill logic in `GutterBackgroundClipView.draw(_:)` directly and deterministically.
final class GutterOverscrollBackgroundTests: XCTestCase {
    var controller: TextViewController!

    let editorBackground = NSColor(deviceRed: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    let gutterBackground = NSColor(deviceRed: 0.9647, green: 0.9725, blue: 0.9804, alpha: 1.0)
    let dividerColor = NSColor(deviceRed: 0.2, green: 0.5, blue: 0.9, alpha: 1.0)

    override func setUpWithError() throws {
        controller = Mock.textViewController(theme: Mock.theme())
        controller.loadView()

        // The gutter's real geometry depends on text layout timing that's irrelevant to what's being tested
        // here (the clip view's background fill), so it's set directly to a known size: wide enough to give
        // a gutter column, tall enough to span well past any viewport used below.
        controller.gutterView.frame = NSRect(x: 0, y: 0, width: 60, height: 2000)
        controller.gutterView.backgroundColor = gutterBackground
        controller.gutterView.backgroundEdgeInsets = GutterView.EdgeInsets(leading: 0, trailing: 8)
        controller.gutterView.dividerColor = dividerColor
    }

    /// Creates a detached clip view (no `documentView`, not installed in any `NSScrollView`) wired to the
    /// mock gutter, with `bounds.origin.y` shifted to simulate a given elastic overscroll amount above the
    /// top of the document.
    private func makeOverscrolledClipView(
        overscrollAmount: CGFloat,
        viewportSize: NSSize = NSSize(width: 400, height: 300)
    ) -> GutterBackgroundClipView {
        let clipView = GutterBackgroundClipView(frame: NSRect(origin: .zero, size: viewportSize))
        clipView.gutterView = controller.gutterView
        clipView.editorBackgroundColor = editorBackground
        clipView.bounds.origin.y = -overscrollAmount
        return clipView
    }

    private func render(_ clipView: GutterBackgroundClipView) throws -> NSBitmapImageRep {
        let rep = try XCTUnwrap(clipView.bitmapImageRepForCachingDisplay(in: clipView.bounds))
        clipView.cacheDisplay(in: clipView.bounds, to: rep)
        return rep
    }

    private func pixelColor(_ rep: NSBitmapImageRep, viewBounds: NSRect, at point: NSPoint) throws -> NSColor {
        let fractionX = (point.x - viewBounds.minX) / viewBounds.width
        let fractionY = (point.y - viewBounds.minY) / viewBounds.height
        let pixelX = Int(fractionX * CGFloat(rep.pixelsWide))
        let pixelY = Int(fractionY * CGFloat(rep.pixelsHigh))
        return try XCTUnwrap(rep.colorAt(x: pixelX, y: pixelY)).usingColorSpace(.deviceRGB) ?? .black
    }

    private func assertColor(
        _ color: NSColor,
        approximatelyEquals expected: NSColor,
        tolerance: CGFloat = 0.05,
        _ message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expectedRGB = expected.usingColorSpace(.deviceRGB) ?? expected
        XCTAssertEqual(color.redComponent, expectedRGB.redComponent, accuracy: tolerance, message, file: file, line: line)
        XCTAssertEqual(color.greenComponent, expectedRGB.greenComponent, accuracy: tolerance, message, file: file, line: line)
        XCTAssertEqual(color.blueComponent, expectedRGB.blueComponent, accuracy: tolerance, message, file: file, line: line)
    }

    /// Saves a screenshot to the temporary directory for manual visual inspection, and returns its path.
    @discardableResult
    private func saveScreenshot(_ rep: NSBitmapImageRep, name: String) throws -> URL {
        let data = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).png")
        try data.write(to: url)
        return url
    }

    func test_overscrollAboveTopFillsGutterColumnWithGutterBackground() throws {
        let clipView = makeOverscrolledClipView(overscrollAmount: 60)
        let rep = try render(clipView)
        try saveScreenshot(rep, name: "gutter_overscroll_top")

        // Sample near the very top of the bounce area (well above the document's first line at y == 0).
        let bounceY = clipView.bounds.minY + 4

        let gutterColumnPoint = NSPoint(x: controller.gutterView.frame.midX, y: bounceY)
        let editorColumnPoint = NSPoint(x: controller.gutterView.frame.maxX + 30, y: bounceY)

        let gutterPixel = try pixelColor(rep, viewBounds: clipView.bounds, at: gutterColumnPoint)
        let editorPixel = try pixelColor(rep, viewBounds: clipView.bounds, at: editorColumnPoint)

        assertColor(
            gutterPixel,
            approximatelyEquals: gutterBackground,
            "gutter column should show the gutter's background color in the overscroll area"
        )
        assertColor(
            editorPixel,
            approximatelyEquals: editorBackground,
            "editor column should show the editor's background color in the overscroll area"
        )
    }

    func test_normalScrollPositionUnaffectedByFix() throws {
        let clipView = makeOverscrolledClipView(overscrollAmount: 0)
        let rep = try render(clipView)
        try saveScreenshot(rep, name: "gutter_overscroll_none")

        let contentY = clipView.bounds.minY + 6

        let gutterColumnPoint = NSPoint(x: controller.gutterView.frame.midX, y: contentY)
        let editorColumnPoint = NSPoint(x: controller.gutterView.frame.maxX + 30, y: contentY)

        let gutterPixel = try pixelColor(rep, viewBounds: clipView.bounds, at: gutterColumnPoint)
        let editorPixel = try pixelColor(rep, viewBounds: clipView.bounds, at: editorColumnPoint)

        assertColor(gutterPixel, approximatelyEquals: gutterBackground, "gutter column should be unaffected in normal (non-overscrolled) rendering")
        assertColor(editorPixel, approximatelyEquals: editorBackground, "editor column should be unaffected in normal (non-overscrolled) rendering")
    }

    func test_overscrollAboveTopExtendsGutterDivider() throws {
        let clipView = makeOverscrolledClipView(overscrollAmount: 60)
        let rep = try render(clipView)

        let bounceY = clipView.bounds.minY + 4
        let expectedDividerX = controller.gutterView.frame.minX + controller.gutterView.backgroundFillRect.maxX

        let foundDivider = stride(from: expectedDividerX - 2, through: expectedDividerX + 2, by: 0.25).contains { x in
            guard let pixel = try? pixelColor(rep, viewBounds: clipView.bounds, at: NSPoint(x: x, y: bounceY)) else {
                return false
            }
            let expectedRGB = dividerColor.usingColorSpace(.deviceRGB) ?? dividerColor
            return abs(pixel.redComponent - expectedRGB.redComponent) < 0.05
                && abs(pixel.greenComponent - expectedRGB.greenComponent) < 0.05
                && abs(pixel.blueComponent - expectedRGB.blueComponent) < 0.05
        }

        XCTAssertTrue(foundDivider, "gutter divider should extend into the overscroll area near x=\(expectedDividerX)")
    }

    /// `backgroundFillRect` backs both the gutter's own background fill (which also determines where its
    /// divider and line numbers sit) and the overscroll fill in `GutterBackgroundClipView`. This confirms the
    /// refactor that exposed it preserves the exact insets the gutter already relied on.
    func test_backgroundFillRectRespectsEdgeInsetsAndFoldingRibbon() throws {
        let gutterView = try XCTUnwrap(controller.gutterView)

        gutterView.showFoldingRibbon = false
        gutterView.backgroundEdgeInsets = GutterView.EdgeInsets(leading: 3, trailing: 8)
        gutterView.frame.size = NSSize(width: 100, height: 50)

        let rectWithoutRibbon = gutterView.backgroundFillRect
        XCTAssertEqual(rectWithoutRibbon.minX, 3)
        XCTAssertEqual(rectWithoutRibbon.maxX, 92)
        XCTAssertEqual(rectWithoutRibbon.height, 50)

        gutterView.showFoldingRibbon = true
        let rectWithRibbon = gutterView.backgroundFillRect
        XCTAssertLessThan(rectWithRibbon.maxX, rectWithoutRibbon.maxX, "the folding ribbon's width should be excluded from the fill")
    }
}
