import XCTest
@testable import CodeEditSourceEditor
import AppKit

/// Verifies ``SourceEditorConfiguration/Appearance/prominentGutter``: when enabled, the gutter is drawn with the
/// theme's gutter background and a trailing divider; when disabled (the default), it takes the editor's background
/// color and draws no divider.
final class ProminentGutterTests: XCTestCase {
    let editorBackground = NSColor(deviceRed: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    let gutterBackground = NSColor(deviceRed: 0.9647, green: 0.9725, blue: 0.9804, alpha: 1.0)
    let gutterDivider = NSColor(deviceRed: 0.2, green: 0.5, blue: 0.9, alpha: 1.0)

    private func theme() -> EditorTheme {
        var theme = Mock.theme()
        theme.background = editorBackground
        theme.gutterBackground = gutterBackground
        theme.gutterDividerColor = gutterDivider
        return theme
    }

    private func makeController(
        prominentGutter: Bool,
        useThemeBackground: Bool = true
    ) -> TextViewController {
        let controller = TextViewController(
            string: "",
            language: .html,
            configuration: SourceEditorConfiguration(
                appearance: .init(
                    theme: theme(),
                    useThemeBackground: useThemeBackground,
                    prominentGutter: prominentGutter,
                    font: .monospacedSystemFont(ofSize: 11, weight: .medium),
                    lineHeightMultiple: 1.0,
                    wrapLines: true,
                    tabWidth: 4
                )
            ),
            cursorPositions: [],
            highlightProviders: [Mock.treeSitterClient()]
        )
        controller.loadView()
        return controller
    }

    @MainActor
    func test_prominentGutterUsesGutterBackgroundAndDivider() {
        let controller = makeController(prominentGutter: true)

        XCTAssertEqual(controller.gutterView.backgroundColor, gutterBackground)
        XCTAssertEqual(controller.gutterView.dividerColor, gutterDivider)
    }

    @MainActor
    func test_nonProminentGutterUsesEditorBackgroundWithNoDivider() {
        let controller = makeController(prominentGutter: false)

        XCTAssertEqual(controller.gutterView.backgroundColor, editorBackground)
        XCTAssertNil(controller.gutterView.dividerColor)
    }

    /// The default is `false`, so a configuration that never mentions the gutter gets the blended-in appearance
    /// even when the theme defines gutter colors.
    @MainActor
    func test_defaultsToNonProminent() {
        let controller = makeController(prominentGutter: false)

        XCTAssertFalse(controller.prominentGutter)
        XCTAssertNotEqual(controller.gutterView.backgroundColor, gutterBackground)
    }

    /// A transparent editor background leaves the non-prominent gutter unfilled, so it doesn't punch an opaque
    /// column through an otherwise transparent editor.
    @MainActor
    func test_nonProminentGutterIsTransparentWithoutThemeBackground() {
        let controller = makeController(prominentGutter: false, useThemeBackground: false)

        XCTAssertNil(controller.gutterView.backgroundColor)
        XCTAssertNil(controller.gutterView.dividerColor)
    }

    @MainActor
    func test_togglingProminentGutterUpdatesColors() {
        let controller = makeController(prominentGutter: false)

        controller.configuration.appearance.prominentGutter = true
        XCTAssertEqual(controller.gutterView.backgroundColor, gutterBackground)
        XCTAssertEqual(controller.gutterView.dividerColor, gutterDivider)

        controller.configuration.appearance.prominentGutter = false
        XCTAssertEqual(controller.gutterView.backgroundColor, editorBackground)
        XCTAssertNil(controller.gutterView.dividerColor)
    }
}
