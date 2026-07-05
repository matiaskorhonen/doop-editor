//
//  TextView+Lifecycle.swift
//  CodeEditTextView
//
//  Created by Khan Winter on 4/7/25.
//

import AppKit

extension TextView {
    override public func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        layoutManager.layoutLines()
    }

    override public func viewWillMove(toSuperview newSuperview: NSView?) {
        super.viewWillMove(toSuperview: newSuperview)
        guard let clipView = newSuperview as? NSClipView,
              let scrollView = enclosingScrollView ?? clipView.enclosingScrollView else {
            return
        }

        setUpScrollListeners(scrollView: scrollView)
    }

    override public func viewWillStartLiveResize() {
        super.viewWillStartLiveResize()
        isInLiveResizeDrag = true
    }

    override public func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        isInLiveResizeDrag = false
        // `updatedViewport(_:)` ignores frame/bounds changes while `isInLiveResizeDrag` is true (see
        // TextView+Layout.swift), so this is what rewraps the text for the final width once the drag ends.
        updateFrameIfNeeded()
    }
}
