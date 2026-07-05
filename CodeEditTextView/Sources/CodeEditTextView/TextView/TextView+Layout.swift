//
//  TextView+Layout.swift
//  CodeEditTextView
//
//  Created by Khan Winter on 6/15/24.
//

import Foundation

extension TextView {
    override public func layout() {
        super.layout()
        layoutManager.layoutLines()
        selectionManager.updateSelectionViews(skipTimerReset: true)
    }

    open override class var isCompatibleWithResponsiveScrolling: Bool {
        true
    }

    open override func prepareContent(in rect: NSRect) {
        needsLayout = true
        super.prepareContent(in: rect)
    }

    override public func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if isSelectable {
            selectionManager.drawSelections(in: dirtyRect)
        }
        emphasisManager?.updateLayerBackgrounds()
    }

    override open var isFlipped: Bool {
        true
    }

    override public var visibleRect: NSRect {
        if let scrollView {
            var rect = scrollView.documentVisibleRect
            rect.origin.y += scrollView.contentInsets.top
            return rect.pixelAligned
        } else {
            return super.visibleRect
        }
    }

    public var visibleTextRange: NSRange? {
        let minY = max(visibleRect.minY, 0)
        let maxY = min(visibleRect.maxY, layoutManager.estimatedHeight())
        guard let minYLine = layoutManager.textLineForPosition(minY),
              let maxYLine = layoutManager.textLineForPosition(maxY) else {
            return nil
        }
        return NSRange(
            location: minYLine.range.location,
            length: (maxYLine.range.location - minYLine.range.location) + maxYLine.range.length
        )
    }

    public func updatedViewport(_ newRect: CGRect) {
        // This is invoked from both live scrolling and live window resizing (both fire bounds/frame-change
        // notifications on the scroll view's clip view). During a live resize drag this can fire dozens of
        // times per second; with `wrapLines` on, each call re-typesets every visible line for the new width.
        // That's cheap for ordinary lines, but expensive for a document containing one huge unbreakable line
        // (e.g. base64 content), and doing that on every tick of a drag makes the whole thing stutter. Skip
        // rewrapping only in that case, and let `viewDidEndLiveResize()` catch up once the drag finishes.
        if isInLiveResizeDrag && hasVisibleLineExceedingLiveResizeThreshold(in: newRect) {
            return
        }

        if !updateFrameIfNeeded() {
            layoutManager.layoutLines()
        }
        inputContext?.invalidateCharacterCoordinates()
    }

    /// Checks whether any line currently visible in `rect` is long enough that retypesetting it on every tick
    /// of a live resize drag would be expensive. See `TextView.liveResizeReflowLineLengthThreshold`.
    func hasVisibleLineExceedingLiveResizeThreshold(in rect: CGRect) -> Bool {
        layoutManager.linesStartingAt(rect.minY, until: rect.maxY).contains { linePosition in
            linePosition.range.length > Self.liveResizeReflowLineLengthThreshold
        }
    }

    /// Updates the view's frame if needed depending on wrapping lines, a new maximum width, or changed available size.
    /// - Returns: Whether or not the view was updated.
    @discardableResult
    public func updateFrameIfNeeded() -> Bool {
        var availableSize = scrollView?.contentSize ?? .zero
        availableSize.height -= (scrollView?.contentInsets.top ?? 0) + (scrollView?.contentInsets.bottom ?? 0)

        let extraHeight = availableSize.height * overscrollAmount
        let newHeight = max(layoutManager.estimatedHeight() + extraHeight, availableSize.height, 0)
        let newWidth = layoutManager.estimatedWidth()

        var didUpdate = false

        if newHeight >= availableSize.height && frame.size.height != newHeight {
            frame.size.height = newHeight
            // No need to update layout after height adjustment
        }

        if wrapLines && frame.size.width != availableSize.width {
            frame.size.width = availableSize.width
            didUpdate = true
        } else if !wrapLines && frame.size.width != max(newWidth, availableSize.width) {
            frame.size.width = max(newWidth, availableSize.width)
            didUpdate = true
        }

        if didUpdate {
            needsLayout = true
            needsDisplay = true
            layoutManager.setNeedsLayout()
        }

        if isSelectable {
            selectionManager?.updateSelectionViews()
        }

        return didUpdate
    }
}
