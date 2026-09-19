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
        liveResizeReflowWorkItem?.cancel()
        liveResizeReflowWorkItem = nil
        liveResizeLastReflowTime = nil
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
        // Reset throttle state so the first tick of this drag always reflows immediately, regardless of
        // when the last drag's last reflow happened (see `scheduleThrottledLiveResizeReflow()` in
        // TextView+Layout.swift). Deliberately does NOT reset `liveResizeLastReflowDuration`: that reflects
        // the cost of the document's current content, not the current drag session, so a second drag on
        // the same huge document doesn't have to rediscover the cost from scratch before widening the
        // throttle interval again.
        liveResizeLastReflowTime = nil
    }

    override public func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        isInLiveResizeDrag = false
        // Cancel any still-pending throttled reflow (see TextView+Layout.swift) before the catch-up call
        // below, so a stale timer can't fire a redundant reflow after the drag has already ended.
        liveResizeReflowWorkItem?.cancel()
        liveResizeReflowWorkItem = nil
        updateFrameIfNeeded()
    }
}
