//
//  TextLayoutManager+ensureLayout.swift
//  CodeEditTextView
//
//  Created by Khan Winter on 4/7/25.
//

import AppKit

extension TextLayoutManager {
    /// Contains all data required to perform layout on a text line.
    private struct LineLayoutData {
        let minY: CGFloat
        let maxY: CGFloat
        let maxWidth: CGFloat
    }

    // MARK: - Layout Lines

    /// Lays out all visible lines
    ///
    /// ## Overview Of The Layout Routine
    ///
    /// The basic premise of this method is that it loops over all lines in the given rect (defaults to the visible
    /// rect), checks if the line needs a layout calculation, and performs layout on the line if it does.
    ///
    /// The thing that makes this layout method so fast is the second point, checking if a line needs layout. To
    /// determine if a line needs a layout pass, the layout manager can check three things:
    /// - **1** Was the line laid out under the assumption of a different maximum layout width?
    ///   For instance, if a line was previously broken by the line wrapping setting, it won’t need to wrap once the
    ///   line wrapping is disabled. This will detect that, and cause the lines to be recalculated.
    /// - **2** Was the line previously not visible? This is determined by keeping a set of visible line IDs. If the
    ///   line does not appear in that set, we can assume it was previously off screen and may need layout.
    /// - **3** Is the line's cached height still the sum of its line fragments? If it isn't, the line's fragments
    ///   were rebuilt by an edit (lines inserted or deleted) without the height in storage being updated yet.
    ///
    /// Once it has been determined that a line needs layout, we perform layout by recalculating it's line fragments,
    /// removing all old line fragment views, and creating new ones for the line.
    ///
    /// Lines that pass all three checks aren't skipped entirely, they get a cheap fragment-view re-sync instead.
    /// Typesetting produces every fragment of a line, but only the fragments inside the layout window get views, so
    /// which fragments need a view changes as the window scrolls or the line shifts, without the line itself ever
    /// needing layout again.
    ///
    /// ## Laziness
    ///
    /// At the end of the layout pass, we clean up any old lines by updating the set of visible line IDs and fragment
    /// IDs. Any IDs that no longer appear in those sets are removed to save resources. This facilitates the text view's
    /// ability to only render text that is visible and saves tons of resources (similar to the lazy loading of
    /// collection or table views).
    ///
    /// The other important lazy attribute is the line iteration. Line iteration is done lazily. As we iterate
    /// through lines and potentially update their heights, the next line is only queried for *after* the updates are
    /// finished.
    ///
    /// ## Reentry
    ///
    /// An important thing to note is that this method cannot be reentered. If a layout pass has begun while a layout
    /// pass is already ongoing, internal data structures will be broken. In debug builds, this is checked with a simple
    /// boolean and assertion.
    ///
    /// To help ensure this property, all view modifications are performed within a `CATransaction`. This guarantees
    /// that macOS calls `layout` on any related views only after we’ve finished inserting and removing line fragment
    /// views. Otherwise, inserting a line fragment view could trigger a layout pass prematurely and cause this method
    /// to re-enter.
    /// - Warning: This is probably not what you're looking for. If you need to invalidate layout, or update lines, this
    ///            is not the way to do so. This should only be called when macOS performs layout.
    @discardableResult
    public func layoutLines(in rect: NSRect? = nil) -> Set<TextLine.ID> { // swiftlint:disable:this function_body_length
        guard let visibleRect = rect ?? delegate?.visibleRect,
              !isInTransaction,
              let textStorage else {
            return []
        }

        // The macOS may call `layout` on the textView while we're laying out fragment views. This ensures the view
        // tree modifications caused by this method are atomic, so macOS won't call `layout` while we're already doing
        // that
        CATransaction.begin()
        layoutLock.lock()

        let minY = max(visibleRect.minY - verticalLayoutPadding, 0)
        let maxY = max(visibleRect.maxY + verticalLayoutPadding, 0)
        let originalHeight = lineStorage.height
        var usedFragmentIDs = Set<LineFragment.ID>()
        let forceLayout: Bool = needsLayout
        var newVisibleLines: Set<TextLine.ID> = []
        var yContentAdjustment: CGFloat = 0
        var maxFoundLineWidth = maxLineWidth

#if DEBUG
        var laidOutLines: Set<TextLine.ID> = []
#endif
        // Layout all lines, fetching lines lazily as they are laid out.
        for linePosition in linesStartingAt(minY, until: maxY).lazy {
            guard linePosition.yPos < maxY else { continue }
            // Three ways to determine if a line needs to be re-calculated.
            let linePositionNeedsLayout = linePosition.data.needsLayout(maxWidth: maxLineLayoutWidth)
            let wasNotVisible = !visibleLineIds.contains(linePosition.data.id)
            let lineNotEntirelyLaidOut = linePosition.height != linePosition.data.lineFragments.height

            defer { newVisibleLines.insert(linePosition.data.id) }

            func fullLineLayout() {
                let yAdjustment = layoutLine(
                    linePosition,
                    usedFragmentIDs: &usedFragmentIDs,
                    textStorage: textStorage,
                    yRange: minY..<maxY,
                    maxFoundLineWidth: &maxFoundLineWidth
                )
                yContentAdjustment += yAdjustment
#if DEBUG
                laidOutLines.insert(linePosition.data.id)
#endif
            }

            if forceLayout || linePositionNeedsLayout || wasNotVisible || lineNotEntirelyLaidOut {
                fullLineLayout()
            } else {
                // The line's typesetting is up to date, but its fragment *views* may not be. `layoutLineViews`
                // only places fragments that intersected the layout window at the time the line was laid out, so
                // a wrapped line can hold fragments that never got a view: a line first laid out with its lower
                // half below the window keeps that hole for as long as it stays visible, and the checks above
                // won't catch it (its typesetting and total height are both correct). The blank space that
                // leaves reads as a line with a far too large line height.
                //
                // This re-syncs which fragments have views, and repositions the views that already exist for
                // when a line above changed height. No re-typesetting: the checks above ruled that out, and the
                // lazy line iteration means this line's `yPos` already accounts for any height change above it.
                placeVisibleFragments(
                    linePosition,
                    layoutData: LineLayoutData(minY: minY, maxY: maxY, maxWidth: maxLineLayoutWidth),
                    laidOutFragmentIDs: &usedFragmentIDs
                )
            }
        }

        // Enqueue any lines not used in this layout pass.
        viewReuseQueue.enqueueViews(notInSet: usedFragmentIDs)

        // Update the visible lines with the new set.
        visibleLineIds = newVisibleLines

        // The delegate methods below may call another layout pass, make sure we don't send it into a loop of forced
        // layout.
        needsLayout = false

        // Commit the view tree changes we just made.
        layoutLock.unlock()
        CATransaction.commit()

        if maxFoundLineWidth > maxLineWidth {
            maxLineWidth = maxFoundLineWidth
        }

        if yContentAdjustment != 0 {
            delegate?.layoutManagerYAdjustment(yContentAdjustment)
        }

        if originalHeight != lineStorage.height || layoutView?.frame.size.height != lineStorage.height {
            delegate?.layoutManagerHeightDidUpdate(newHeight: lineStorage.height)
        }

#if DEBUG
        return laidOutLines
#else
        return []
#endif
    }

    // MARK: - Layout Single Line

    private func layoutLine(
        _ linePosition: TextLineStorage<TextLine>.TextLinePosition,
        usedFragmentIDs: inout Set<LineFragment.ID>,
        textStorage: NSTextStorage,
        yRange: Range<CGFloat>,
        maxFoundLineWidth: inout CGFloat
    ) -> CGFloat {
        let lineSize = layoutLineViews(
            linePosition,
            textStorage: textStorage,
            layoutData: LineLayoutData(minY: yRange.lowerBound, maxY: yRange.upperBound, maxWidth: maxLineLayoutWidth),
            laidOutFragmentIDs: &usedFragmentIDs
        )
        let wasLineHeightChanged = lineSize.height != linePosition.height
        var yContentAdjustment: CGFloat = 0.0

        if wasLineHeightChanged {
            lineStorage.update(
                atOffset: linePosition.range.location,
                delta: 0,
                deltaHeight: lineSize.height - linePosition.height
            )

            if linePosition.yPos < yRange.lowerBound {
                // Adjust the scroll position by the difference between the new height and old.
                yContentAdjustment += lineSize.height - linePosition.height
            }
        }
        if maxFoundLineWidth < lineSize.width {
            maxFoundLineWidth = lineSize.width
        }

        return yContentAdjustment
    }

    /// Lays out a single text line.
    /// - Parameters:
    ///   - position: The line position from storage to use for layout.
    ///   - textStorage: The text storage object to use for text info.
    ///   - layoutData: The information required to perform layout for the given line.
    ///   - laidOutFragmentIDs: Updated by this method as line fragments are laid out.
    /// - Returns: A `CGSize` representing the max width and total height of the laid out portion of the line.
    private func layoutLineViews(
        _ position: TextLineStorage<TextLine>.TextLinePosition,
        textStorage: NSTextStorage,
        layoutData: LineLayoutData,
        laidOutFragmentIDs: inout Set<LineFragment.ID>
    ) -> CGSize {
        let lineDisplayData = TextLine.DisplayData(
            maxWidth: layoutData.maxWidth,
            lineHeightMultiplier: lineHeightMultiplier,
            estimatedLineHeight: estimateLineHeight(),
            breakStrategy: lineBreakStrategy
        )

        let line = position.data
        if let renderDelegate {
            renderDelegate.prepareForDisplay(
                textLine: line,
                displayData: lineDisplayData,
                range: position.range,
                stringRef: textStorage,
                markedRanges: markedTextManager.markedRanges(in: position.range),
                attachments: attachments.getAttachmentsStartingIn(position.range)
            )
        } else {
            line.prepareForDisplay(
                displayData: lineDisplayData,
                range: position.range,
                stringRef: textStorage,
                markedRanges: markedTextManager.markedRanges(in: position.range),
                attachments: attachments.getAttachmentsStartingIn(position.range)
            )
        }

        if position.range.isEmpty {
            return CGSize(width: 0, height: estimateLineHeight())
        }

        var height: CGFloat = 0
        var width: CGFloat = 0
        for lineFragmentPosition in line.lineFragments {
            let lineFragment = lineFragmentPosition.data
            lineFragment.documentRange = lineFragmentPosition.range.translate(location: position.range.location)

            // A single wrapped line can produce a huge number of fragments (e.g. one long line of minified or
            // base64 content). Only create/place views for fragments that actually intersect the visible range:
            // each placement is an `addSubview(positioned:relativeTo:)` call, which reorders the layout view's
            // entire subview array, so placing every fragment of such a line is O(n^2) in fragment count. Height
            // and width are still accumulated below from the already-computed fragment metadata, no view needed.
            //
            // Fragments outside the range are deliberately left out of `laidOutFragmentIDs` (rather than marked
            // used regardless): if a fragment already has a view but is no longer visible, this lets
            // `viewReuseQueue.enqueueViews(notInSet:)` reclaim it instead of leaking one subview per fragment
            // ever scrolled past on a line taller than a viewport. `placeVisibleFragments` re-places fragments
            // that scroll back into range later without re-typesetting the line.
            let fragmentMinY = position.yPos + lineFragmentPosition.yPos
            let fragmentMaxY = fragmentMinY + lineFragment.scaledHeight
            if fragmentMaxY >= layoutData.minY && fragmentMinY <= layoutData.maxY {
                layoutFragmentView(
                    inLine: position,
                    for: lineFragmentPosition,
                    at: fragmentMinY
                )
                laidOutFragmentIDs.insert(lineFragment.id)
            }

            width = max(width, lineFragment.width)
            height += lineFragment.scaledHeight
        }

        return CGSize(width: width, height: height)
    }

    /// Syncs fragment views for the fragments of this line that intersect `layoutData`'s visible range, without
    /// re-typesetting the line. Used from ``layoutLines(in:)`` for every line that doesn't need a full layout pass:
    /// `layoutLineViews` only placed fragments visible in whatever window was current when the line was last
    /// typeset, so as the visible window moves within the same still-visible line, newly-revealed fragments need
    /// to be placed here instead of being silently skipped.
    ///
    /// Fragments that already have a view are repositioned rather than skipped, since a line's `yPos` shifts
    /// whenever a line above it changes height. Leaving them put drew the same line at two offsets at once, the
    /// old fragments overlapping the content above. `documentRange` is refreshed for the same reason: an edit
    /// above this line shifts its `range.location`, and the renderer reads `documentRange` to place invisibles
    /// and selections.
    /// - Parameters:
    ///   - position: The line position to sync fragment views for.
    ///   - layoutData: The current visible range and layout width.
    ///   - laidOutFragmentIDs: Updated with the IDs of fragments left with a placed view in the visible range.
    private func placeVisibleFragments(
        _ position: TextLineStorage<TextLine>.TextLinePosition,
        layoutData: LineLayoutData,
        laidOutFragmentIDs: inout Set<LineFragment.ID>
    ) {
        let line = position.data
        for lineFragmentPosition in line.lineFragments {
            let lineFragment = lineFragmentPosition.data
            let fragmentMinY = position.yPos + lineFragmentPosition.yPos
            let fragmentMaxY = fragmentMinY + lineFragment.scaledHeight
            guard fragmentMaxY >= layoutData.minY && fragmentMinY <= layoutData.maxY else { continue }

            laidOutFragmentIDs.insert(lineFragment.id)
            lineFragment.documentRange = lineFragmentPosition.range.translate(location: position.range.location)

            if let view = viewReuseQueue.getView(forKey: lineFragment.id) {
                // This runs for every visible line on every layout pass, and most passes don't move anything.
                // Only touch the view's frame when it actually needs to move.
                let origin = CGPoint(x: edgeInsets.left, y: fragmentMinY)
                if view.frame.origin != origin {
                    view.frame.origin = origin
                }
            } else {
                layoutFragmentView(inLine: position, for: lineFragmentPosition, at: fragmentMinY)
            }
        }
    }

    // MARK: - Layout Fragment

    /// Lays out a line fragment view for the given line fragment at the specified y value.
    /// - Parameters:
    ///   - lineFragment: The line fragment position to lay out a view for.
    ///   - yPos: The y value at which the line should begin.
    private func layoutFragmentView(
        inLine line: TextLineStorage<TextLine>.TextLinePosition,
        for lineFragment: TextLineStorage<LineFragment>.TextLinePosition,
        at yPos: CGFloat
    ) {
        let fragmentRange = lineFragment.range.translate(location: line.range.location)
        let view = viewReuseQueue.getOrCreateView(forKey: lineFragment.data.id) {
            renderDelegate?.lineFragmentView(for: lineFragment.data) ?? LineFragmentView()
        }
        view.translatesAutoresizingMaskIntoConstraints = true // Small optimization for lots of subviews
        view.setLineFragment(lineFragment.data, fragmentRange: fragmentRange, renderer: lineFragmentRenderer)
        view.frame.origin = CGPoint(x: edgeInsets.left, y: yPos)
        layoutView?.addSubview(view, positioned: .below, relativeTo: nil)
        view.needsDisplay = true
    }
}
