//
//  EditorScrollView.swift
//  CodeEditSourceEditor
//

import AppKit

/// A scroll view that always uses overlay scrollers.
///
/// The editor draws its theme background edge to edge. Legacy scrollers break that: `NSScrollView` takes a
/// ~15pt strip out of its content along the trailing edge (and the bottom, when lines don't wrap) and lets
/// `NSScroller` fill it with a system color and a hairline divider, so the theme visibly stops short of the
/// window edge.
///
/// Assigning `scrollerStyle` isn't enough to prevent that. `NSScrollView` re-reads
/// `NSScroller.preferredScrollerStyle` on its own — when it's added to a window, and again whenever the system
/// posts `NSPreferredScrollerStyleDidChange` — so an assigned style gets silently replaced. That's what makes
/// the wrong-colored strip look intermittent: it appears for anyone whose "Show scroll bars" setting resolves
/// to "Always", including the common "Automatically based on mouse or trackpad" case where plugging in a mouse
/// flips the preference mid-session, and on CI machines with no trackpad at all.
///
/// Overriding the property instead pins the style for good. Overlay scrollers float above the content rather
/// than taking space from it, so the background reaches the edge and the scroller still appears while
/// scrolling.
final class EditorScrollView: NSScrollView {
    override var scrollerStyle: NSScroller.Style {
        get { .overlay }
        set { } // Ignore AppKit's attempts to sync this with the system preference.
    }
}
