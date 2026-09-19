//
//  CGContext+FontSmoothing.swift
//  CodeEditTextView
//

import AppKit
internal import CodeEditTextViewObjC

extension CGContext {
    /// Sets the context's font smoothing style, which has no public Core Graphics API.
    ///
    /// `internal`, not `public`: keeping the Obj-C shim to a single module is what lets the binary
    /// distribution absorb it rather than ship it as its own framework -- see BINARY_DISTRIBUTION.md.
    ///
    /// - Parameter style: The smoothing style to use. `16` is the style AppKit uses for text drawn
    ///                    into a layer-backed view.
    func setHiddenFontSmoothingStyle(_ style: Int32) {
        ContextSetHiddenSmoothingStyle(self, style)
    }
}
