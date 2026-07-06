//
//  TextView+Mouse.swift
//  CodeEditTextView
//
//  Created by Khan Winter on 9/19/23.
//

import AppKit

extension TextView {
    override public func mouseDown(with event: NSEvent) {
        // Set cursor
        guard isSelectable,
              event.type == .leftMouseDown,
              let offset = layoutManager.textOffsetAtPoint(self.convert(event.locationInWindow, from: nil)) else {
            super.mouseDown(with: event)
            return
        }

        if let content = layoutManager.contentRun(at: offset),
           case let .attachment(attachment) = content.data, event.clickCount < 3 {
            handleAttachmentClick(event: event, offset: offset, attachment: attachment)
            return
        }

        switch event.clickCount {
        case 1:
            handleSingleClick(event: event, offset: offset)
        case 2:
            handleDoubleClick(event: event)
        case 3:
            handleTripleClick(event: event)
        default:
            break
        }

        trackSelectionDrag(with: event)
    }

    /// Single click, if control-shift we add a cursor
    /// if shift, we extend the selection to the click location
    /// else we set the cursor
    fileprivate func handleSingleClick(event: NSEvent, offset: Int) {
        cursorSelectionMode = .character

        guard isEditable else {
            super.mouseDown(with: event)
            return
        }
        let eventFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if eventFlags == [.control, .shift] {
            unmarkText()
            selectionManager.addSelectedRange(NSRange(location: offset, length: 0))
        } else if eventFlags.contains(.shift) {
            unmarkText()
            shiftClickExtendSelection(to: offset)
        } else {
            selectionManager.setSelectedRange(NSRange(location: offset, length: 0))
            unmarkTextIfNeeded()
        }
    }

    fileprivate func handleDoubleClick(event: NSEvent) {
        cursorSelectionMode = .word

        guard !event.modifierFlags.contains(.shift) else {
            super.mouseDown(with: event)
            return
        }
        unmarkText()
        selectWord(nil)
    }

    fileprivate func handleTripleClick(event: NSEvent) {
        cursorSelectionMode = .line

        guard !event.modifierFlags.contains(.shift) else {
            super.mouseDown(with: event)
            return
        }
        unmarkText()
        selectLine(nil)
    }

    fileprivate func handleAttachmentClick(event: NSEvent, offset: Int, attachment: AnyTextAttachment) {
        switch event.clickCount {
        case 1:
            selectionManager.setSelectedRange(attachment.range)
        case 2:
            performAttachmentAction(attachment: attachment)
        default:
            break
        }
    }

    func performAttachmentAction(attachment: AnyTextAttachment) {
        let action = attachment.attachment.attachmentAction()
        switch action {
        case .none:
            return
        case .discard:
            layoutManager.attachments.remove(atOffset: attachment.range.location)
            selectionManager.setSelectedRange(NSRange(location: attachment.range.location, length: 0))
        case let .replace(text):
            replaceCharacters(in: attachment.range, with: text)
        }
    }

    override public func mouseUp(with event: NSEvent) {
        mouseDragAnchor = nil
        disableMouseAutoscrollTimer()
        super.mouseUp(with: event)
    }

    override public func mouseDragged(with event: NSEvent) {
        processDragEvent(event)
    }

    /// Tracks a text-selection drag until the mouse button is released.
    ///
    /// AppKit stops delivering `mouseDragged`/`mouseUp` through the normal responder chain once the cursor
    /// leaves the window, and a `Timer` scheduled on the default run loop mode doesn't fire while the mouse is
    /// down (that tracking session runs the run loop in `.eventTracking` mode instead). Both would otherwise
    /// cause the selection to silently stop expanding as soon as the mouse left the view during a drag.
    ///
    /// Pulling events directly from the window with `nextEvent(matching:until:inMode:dequeue:)` sidesteps both
    /// problems: it keeps receiving drag events no matter where the cursor is on screen, and its bounded wait
    /// lets us re-process the last known position on a timer-like cadence so the selection keeps
    /// expanding/autoscrolling even while the mouse is held still outside the view. This mirrors how AppKit's
    /// own text views implement drag-to-select.
    private func trackSelectionDrag(with initialEvent: NSEvent) {
        guard let window else { return }

        let autoscrollInterval: TimeInterval = 0.022 // ~45Hz, matches AppKit's own autoscroll cadence.
        var lastDragEvent: NSEvent?

        while true {
            let event = window.nextEvent(
                matching: [.leftMouseDragged, .leftMouseUp],
                until: Date().addingTimeInterval(autoscrollInterval),
                inMode: .eventTracking,
                dequeue: true
            )

            switch event?.type {
            case .leftMouseUp:
                mouseDragAnchor = nil
                return
            case .leftMouseDragged:
                lastDragEvent = event
                processDragEvent(event!)
            default:
                // Timed out waiting for a new event. Re-process the last known drag position so the selection
                // keeps expanding/autoscrolling while the mouse is held outside the view.
                if let lastDragEvent {
                    processDragEvent(lastDragEvent)
                }
            }
        }
    }

    private func processDragEvent(_ event: NSEvent) {
        guard !(inputContext?.handleEvent(event) ?? false) && isSelectable && !isDragging else {
            return
        }

        // We receive global events because our view received the drag event, but we need to clamp the potentially
        // out-of-bounds positions to a position our layout manager can deal with. The layout manager measures x
        // positions from inside its left edge inset, so the minimum x has to match that inset - clamping to 0
        // produces a position to the left of the first character, which the layout manager can't resolve.
        let locationInWindow = convert(event.locationInWindow, from: nil)
        let locationInView = CGPoint(
            x: max(layoutManager.edgeInsets.left, min(locationInWindow.x, frame.width)),
            y: max(0.0, min(locationInWindow.y, frame.height))
        )

        if mouseDragAnchor == nil {
            mouseDragAnchor = locationInView
            super.mouseDragged(with: event)
        } else {
            guard let mouseDragAnchor,
                  let startPosition = layoutManager.textOffsetAtPoint(mouseDragAnchor),
                  let endPosition = layoutManager.textOffsetAtPoint(locationInView) else {
                return
            }

            let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if modifierFlags.contains(.option) {
                dragColumnSelection(mouseDragAnchor: mouseDragAnchor, locationInView: locationInView)
            } else {
                dragSelection(startPosition: startPosition, endPosition: endPosition, mouseDragAnchor: mouseDragAnchor)
            }

            setNeedsDisplay()
            self.autoscroll(with: event)
        }
    }

    /// Extends the current selection to the offset. Only used when the user shift-clicks a location in the document.
    ///
    /// If the offset is within the selection, trims the selection from the nearest edge (start or end) towards the
    /// clicked offset.
    /// Otherwise, extends the selection to the clicked offset.
    ///
    /// - Parameter offset: The offset clicked on.
    fileprivate func shiftClickExtendSelection(to offset: Int) {
        // Use the last added selection, this is behavior copied from Xcode.
        guard var selectedRange = selectionManager.textSelections.last?.range else { return }
        if selectedRange.contains(offset) {
            if offset - selectedRange.location <= selectedRange.max - offset {
                selectedRange.length -= offset - selectedRange.location
                selectedRange.location = offset
            } else {
                selectedRange.length -= selectedRange.max - offset
            }
        } else {
            selectedRange.formUnion(NSRange(
                start: min(offset, selectedRange.location),
                end: max(offset, selectedRange.max)
            ))
        }
        selectionManager.setSelectedRange(selectedRange)
        setNeedsDisplay()
    }

    // MARK: - Mouse Autoscroll

    /// Sets up a timer that fires at a predetermined period to autoscroll the text view.
    /// Ensure the timer is disabled using ``disableMouseAutoscrollTimer``.
    func setUpMouseAutoscrollTimer() {
        mouseDragTimer?.invalidate()
        // https://cocoadev.github.io/AutoScrolling/ (fired at ~45Hz)
        mouseDragTimer = Timer.scheduledTimer(withTimeInterval: 0.022, repeats: true) { [weak self] _ in
            if let event = self?.window?.currentEvent, event.type == .leftMouseDragged {
                self?.mouseDragged(with: event)
                self?.autoscroll(with: event)
            }
        }
    }

    /// Disables the mouse drag timer started by ``setUpMouseAutoscrollTimer``
    func disableMouseAutoscrollTimer() {
        mouseDragTimer?.invalidate()
        mouseDragTimer = nil
    }

    // MARK: - Drag Selection

    private func dragSelection(startPosition: Int, endPosition: Int, mouseDragAnchor: CGPoint) {
        switch cursorSelectionMode {
        case .character:
            selectionManager.setSelectedRange(
                NSRange(
                    location: min(startPosition, endPosition),
                    length: max(startPosition, endPosition) - min(startPosition, endPosition)
                )
            )

        case .word:
            let startWordRange = findWordBoundary(at: startPosition)
            let endWordRange = findWordBoundary(at: endPosition)

            selectionManager.setSelectedRange(
                NSRange(
                    location: min(startWordRange.location, endWordRange.location),
                    length: max(startWordRange.location + startWordRange.length,
                                endWordRange.location + endWordRange.length) -
                    min(startWordRange.location, endWordRange.location)
                )
            )

        case .line:
            let startLineRange = findLineBoundary(at: startPosition)
            let endLineRange = findLineBoundary(at: endPosition)

            selectionManager.setSelectedRange(
                NSRange(
                    location: min(startLineRange.location, endLineRange.location),
                    length: max(startLineRange.location + startLineRange.length,
                                endLineRange.location + endLineRange.length) -
                    min(startLineRange.location, endLineRange.location)
                )
            )
        }
    }

    private func dragColumnSelection(mouseDragAnchor: CGPoint, locationInView: CGPoint) {
        selectColumns(betweenPointA: mouseDragAnchor, pointB: locationInView)
    }
}
