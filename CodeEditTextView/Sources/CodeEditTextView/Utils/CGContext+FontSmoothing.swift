//
//  CGContext+FontSmoothing.swift
//  CodeEditTextView
//

import AppKit
internal import CodeEditTextViewObjC

extension CGContext {
    /// Sets the context's font smoothing style, which has no public Core Graphics API.
    ///
    /// `package` rather than `internal` so `CodeEditSourceEditor`'s gutter can draw text the same way
    /// without importing `CodeEditTextViewObjC` itself. That keeps the Obj-C shim used by exactly one
    /// module, which lets the binary distribution absorb it instead of shipping it as its own
    /// framework -- see BINARY_DISTRIBUTION.md.
    ///
    /// - Parameter style: The smoothing style to use. `16` is the style AppKit uses for text drawn
    ///                    into a layer-backed view.
    package func setHiddenFontSmoothingStyle(_ style: Int32) {
        ContextSetHiddenSmoothingStyle(self, style)
    }
}
