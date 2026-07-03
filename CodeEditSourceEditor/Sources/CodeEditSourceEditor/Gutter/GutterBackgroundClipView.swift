//
//  GutterBackgroundClipView.swift
//  CodeEditSourceEditor
//
//  Created by Claude on 7/3/26.
//

import AppKit
import CodeEditTextView

/// A clip view used as the source editor's scroll view `contentView`.
///
/// By default, an `NSScrollView`'s elastic/rubber-band overscroll area (visible when scrolling past the top or
/// bottom of the document with a trackpad) is filled with a single flat color. That doesn't match the editor's
/// layout, which has a visually distinct gutter column with its own divider. This view fills the overscroll
/// area with the gutter's background color (and divider) in the gutter's column, and the editor's background
/// color everywhere else, so the bounce area looks like a continuation of the editor rather than a plain
/// rectangle.
///
/// The gutter view itself still draws on top of this wherever it's actually present, so this only becomes
/// visible in the overscroll area above/below the document (or to the side, if scrolled horizontally past the
/// gutter's own frame).
final class GutterBackgroundClipView: NSClipView {
    weak var gutterView: GutterView?

    var editorBackgroundColor: NSColor? {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        if let editorBackgroundColor {
            editorBackgroundColor.setFill()
            dirtyRect.fill()
        }

        guard let gutterView else { return }
        let fillRect = gutterView.backgroundFillRect

        if let gutterColor = gutterView.backgroundColor {
            let gutterColumnRect = NSRect(
                x: gutterView.frame.minX + fillRect.minX,
                y: dirtyRect.minY,
                width: fillRect.width,
                height: dirtyRect.height
            )
            let clippedRect = gutterColumnRect.intersection(dirtyRect)
            if !clippedRect.isEmpty {
                gutterColor.setFill()
                clippedRect.fill()
            }
        }

        if let dividerColor = gutterView.dividerColor {
            let dividerRect = NSRect(
                x: gutterView.frame.minX + fillRect.maxX - GutterView.dividerWidth,
                y: dirtyRect.minY,
                width: GutterView.dividerWidth,
                height: dirtyRect.height
            ).pixelAligned
            let clippedDividerRect = dividerRect.intersection(dirtyRect)
            if !clippedDividerRect.isEmpty {
                dividerColor.setFill()
                clippedDividerRect.fill()
            }
        }
    }
}
