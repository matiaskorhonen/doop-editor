//
//  SourceEditorConfiguration+Appearance.swift
//  CodeEditSourceEditor
//
//  Created by Khan Winter on 6/16/25.
//

import AppKit

extension SourceEditorConfiguration {
    /// Configure the appearance of the editor. Font, theme, line height, etc.
    public struct Appearance: Equatable {
        /// The theme for syntax highlighting.
        public var theme: EditorTheme

        /// Determines whether the editor uses the theme's background color, or a transparent background color.
        public var useThemeBackground: Bool = true

        /// Determines whether the gutter is visually distinct from the text view.
        ///
        /// When `true`, the gutter is drawn with the theme's gutter background color and a divider along its
        /// trailing edge. When `false` (the default), the gutter blends into the editor: it uses the editor's
        /// background color and draws no divider.
        public var prominentGutter: Bool = false

        /// The default font.
        public var font: NSFont

        /// The line height multiplier (e.g. `1.2`).
        public var lineHeightMultiple: Double

        /// The amount of space to use between letters, as a percent. Eg: `1.0` = no space, `1.5` = 1/2 a
        /// character's width between characters, etc. Defaults to `1.0`.
        public var letterSpacing: Double = 1.0

        /// Whether lines wrap to the width of the editor.
        public var wrapLines: Bool

        /// If true, uses the system cursor on `>=macOS 14`.
        public var useSystemCursor: Bool = true

        /// The visual tab width in number of spaces.
        public var tabWidth: Int

        /// The type of highlight to use to highlight bracket pairs.
        /// See ``BracketPairEmphasis`` for more information. Defaults to `.flash`.
        public var bracketPairEmphasis: BracketPairEmphasis? = .flash

        /// Create a new appearance configuration object.
        /// - Parameters:
        ///   - theme: The theme for syntax highlighting.
        ///   - useThemeBackground: Determines whether the editor uses the theme's background color, or a transparent
        ///                         background color.
        ///   - prominentGutter: Determines whether the gutter is drawn with the theme's gutter background color and a
        ///                      trailing divider, or blends into the editor's background. Defaults to `false`.
        ///   - font: The default font.
        ///   - lineHeightMultiple: The line height multiplier (e.g. `1.2`).
        ///   - letterSpacing: The amount of space to use between letters, as a percent. Eg: `1.0` = no space, `1.5`
        ///                    = 1/2 of a character's width between characters, etc. Defaults to `1.0`.
        ///   - wrapLines: Whether lines wrap to the width of the editor.
        ///   - useSystemCursor: If true, uses the system cursor on `>=macOS 14`.
        ///   - tabWidth: The visual tab width in number of spaces.
        ///   - bracketPairEmphasis: The type of highlight to use to highlight bracket pairs. See
        ///                          ``BracketPairEmphasis`` for more information. Defaults to `.flash`.
        public init(
            theme: EditorTheme,
            useThemeBackground: Bool = true,
            prominentGutter: Bool = false,
            font: NSFont,
            lineHeightMultiple: Double = 1.2,
            letterSpacing: Double = 1.0,
            wrapLines: Bool,
            useSystemCursor: Bool = true,
            tabWidth: Int = 4,
            bracketPairEmphasis: BracketPairEmphasis? = .flash
        ) {
            self.theme = theme
            self.useThemeBackground = useThemeBackground
            self.prominentGutter = prominentGutter
            self.font = font
            self.lineHeightMultiple = lineHeightMultiple
            self.letterSpacing = letterSpacing
            self.wrapLines = wrapLines
            if #available(macOS 14, *) {
                self.useSystemCursor = useSystemCursor
            } else {
                self.useSystemCursor = false
            }
            self.tabWidth = tabWidth
            self.bracketPairEmphasis = bracketPairEmphasis
        }

        @MainActor
        func didSetOnController(controller: TextViewController, oldConfig: Appearance?) {
            var needsHighlighterInvalidation = false

            if oldConfig?.font != font {
                controller.textView.font = font
                controller.textView.typingAttributes = controller.attributesFor(nil)
                controller.gutterView.font = font.rulerFont
                needsHighlighterInvalidation = true
            }

            needsHighlighterInvalidation = updateColorsIfNeeded(
                controller: controller,
                oldConfig: oldConfig
            ) || needsHighlighterInvalidation

            if oldConfig?.tabWidth != tabWidth {
                controller.paragraphStyle = controller.generateParagraphStyle()
                controller.textView.layoutManager.setNeedsLayout()
                needsHighlighterInvalidation = true
            }

            if oldConfig?.lineHeightMultiple != lineHeightMultiple {
                controller.textView.layoutManager.lineHeightMultiplier = lineHeightMultiple
            }

            if oldConfig?.wrapLines != wrapLines {
                controller.textView.layoutManager.wrapLines = wrapLines
                controller.scrollView.hasHorizontalScroller = !wrapLines
                controller.updateTextInsets()
            }

            // useThemeBackground isn't needed

            if oldConfig?.letterSpacing != letterSpacing {
                controller.textView.letterSpacing = letterSpacing
                needsHighlighterInvalidation = true
            }

            if oldConfig?.bracketPairEmphasis != bracketPairEmphasis {
                controller.emphasizeSelectionPairs()
            }

            // Cant put these in one if sadly
            if #available(macOS 14, *) {
                if oldConfig?.useSystemCursor != useSystemCursor {
                    controller.textView.useSystemCursor = useSystemCursor
                }
            }

            if needsHighlighterInvalidation {
                controller.highlighter?.invalidate()
            }
        }

        /// Applies any color changes the new appearance requires.
        /// - Returns: Whether the highlighter needs to be invalidated for the new colors.
        @MainActor
        private func updateColorsIfNeeded(controller: TextViewController, oldConfig: Appearance?) -> Bool {
            if oldConfig?.theme != theme || oldConfig?.useThemeBackground != useThemeBackground {
                updateControllerNewTheme(controller: controller)
                return true
            }

            if oldConfig?.prominentGutter != prominentGutter {
                // Only the gutter's colors depend on this, and the theme update above already applies them.
                applyGutterColors(controller: controller)
            }

            return false
        }

        private func updateControllerNewTheme(controller: TextViewController) {
            controller.textView.layoutManager.setNeedsLayout()
            controller.textView.textStorage.setAttributes(
                controller.attributesFor(nil),
                range: NSRange(location: 0, length: controller.textView.textStorage.length)
            )
            controller.textView.selectionManager.selectionBackgroundColor = theme.selection
            controller.textView.selectionManager.selectedLineBackgroundColor = getThemeBackground(
                systemAppearance: controller.systemAppearance
            )
            controller.textView.selectionManager.insertionPointColor = theme.insertionPoint
            let editorBackgroundColor: NSColor = if useThemeBackground {
                theme.background
            } else {
                .clear
            }
            controller.textView.enclosingScrollView?.backgroundColor = editorBackgroundColor

            controller.gutterView.textColor = theme.text.color.withAlphaComponent(0.35)
            applySelectedLineColors(controller: controller)

            // Keeps the elastic/rubber-band overscroll area's two-tone fill in sync with the colors above.
            if let backgroundClipView = controller.scrollView.contentView as? GutterBackgroundClipView {
                backgroundClipView.editorBackgroundColor = editorBackgroundColor
            }
            applyGutterColors(controller: controller)

            controller.textView.typingAttributes = controller.attributesFor(nil)
        }

        /// Applies the gutter's background and divider colors.
        ///
        /// A prominent gutter is filled with the theme's gutter background and separated from the text view by a
        /// divider. Otherwise the gutter uses the editor's own background color and draws no divider, so it reads as
        /// part of the text view. When the editor background is transparent, a non-prominent gutter is transparent
        /// too — the gutter gets no fill of its own.
        private func applyGutterColors(controller: TextViewController) {
            if prominentGutter {
                controller.gutterView.backgroundColor = if useThemeBackground {
                    theme.gutterBackground ?? theme.background
                } else {
                    .windowBackgroundColor
                }
                controller.gutterView.dividerColor = theme.gutterDividerColor
            } else {
                controller.gutterView.backgroundColor = useThemeBackground ? theme.background : nil
                controller.gutterView.dividerColor = nil
            }

            // The overscroll area draws the gutter's column itself, so it has to follow the colors above.
            if let backgroundClipView = controller.scrollView.contentView as? GutterBackgroundClipView {
                backgroundClipView.needsDisplay = true
            }
        }

        /// Applies the theme/appearance-derived colors for the selected line highlight to the gutter.
        /// - Note: This does not check ``SourceEditorConfiguration/Behavior/highlightSelectedLine``; callers are
        ///         expected to only call this when the highlight should be visible.
        func applySelectedLineColors(controller: TextViewController) {
            controller.gutterView.selectedLineTextColor = theme.text.color
            controller.gutterView.selectedLineColor = if useThemeBackground {
                theme.lineHighlight
            } else if controller.systemAppearance == .darkAqua {
                NSColor.quaternaryLabelColor
            } else {
                NSColor.selectedTextBackgroundColor.withSystemEffect(.disabled)
            }
        }

        /// Finds the preferred use theme background.
        /// - Returns: The background color to use.
        private func getThemeBackground(systemAppearance: NSAppearance.Name?) -> NSColor {
            if useThemeBackground {
                return theme.lineHighlight
            }

            if systemAppearance == .darkAqua {
                return NSColor.quaternaryLabelColor
            }

            return NSColor.selectedTextBackgroundColor.withSystemEffect(.disabled)
        }
    }
}
