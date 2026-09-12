//
//  TextSelectionManager+MultiCursor.swift
//  CodeEditTextView
//

import AppKit

public extension TextSelectionManager {
    /// Adds a cursor one line above the topmost selection, or one line below the bottommost one.
    ///
    /// The new cursor takes the column of the selection it grows from - its suggested x position when it has one,
    /// so a column of cursors keeps the column it started in even while passing over short lines, and the offset's
    /// own x position otherwise. Lines too short to reach that column get a cursor at their end, matching what
    /// option-dragging a column does.
    ///
    /// Does nothing when there is no line to grow into, or when the line above or below can't be laid out.
    ///
    /// - Parameter up: Set to `true` to add a cursor above the topmost selection, `false` to add one below the
    ///                 bottommost selection.
    /// - Returns: The offset of the added cursor, or `nil` if no cursor was added.
    @discardableResult
    func addCursor(up: Bool) -> Int? {
        guard let layoutManager else { return nil }

        // Grow the column from its own edge, so repeated calls keep extending it in one direction.
        let anchor = up
            ? textSelections.min(by: { $0.range.location < $1.range.location })
            : textSelections.max(by: { $0.range.max < $1.range.max })
        guard let anchor else { return nil }

        // The first cursor of a column is the one to return to when it collapses.
        if textSelections.count == 1 {
            columnAnchor = anchor
        }

        let offset = up ? anchor.range.location : anchor.range.max
        guard let originRect = layoutManager.rectForOffset(offset) else { return nil }

        let xPos = anchor.suggestedXPos ?? originRect.minX
        let lineHeight = layoutManager.estimateLineHeight()
        let targetPoint = CGPoint(
            x: xPos,
            y: up ? originRect.minY - (lineHeight / 2) : originRect.maxY + (lineHeight / 2)
        )

        // The line fragment being grown into is usually laid out already - it's next to a visible cursor - but a
        // cursor on the first or last laid out line is the case where it isn't.
        var newOffset = layoutManager.textOffsetAtPoint(targetPoint)
        if newOffset == nil {
            _ = layoutManager.layoutLines(
                in: NSRect(
                    x: 0,
                    y: targetPoint.y - lineHeight,
                    width: layoutManager.maxLineWidth,
                    height: lineHeight * 2
                )
            )
            newOffset = layoutManager.textOffsetAtPoint(targetPoint)
        }

        // A cursor on the first or last line has no line to grow into: the point lands in the same line fragment,
        // or past the end of the document, which resolves to the document's end rather than failing.
        guard let newOffset,
              let newRect = layoutManager.rectForOffset(newOffset),
              newRect.minY != originRect.minY else {
            return nil
        }

        addCursor(at: newOffset, suggestedXPos: xPos)
        return newOffset
    }

    /// Adds a cursor at an offset, keeping the column it was created in.
    /// - Parameters:
    ///   - offset: The offset to place the cursor at.
    ///   - suggestedXPos: The x position vertical movement should stick to.
    func addCursor(at offset: Int, suggestedXPos: CGFloat?) {
        let existing = Set(textSelections.map(\.range))
        addSelectedRange(NSRange(location: offset, length: 0))

        // `addSelectedRange` ignores a duplicate and merges an adjacent range into an existing selection, so only
        // the selection it actually created gets the column - and it makes one at most.
        if let added = textSelections.first(where: { !existing.contains($0.range) }) {
            added.suggestedXPos = suggestedXPos
        }
    }

    /// Collapses multiple selections down to a single cursor.
    ///
    /// Keeps the cursor the column grew from when one is known - the selection that existed before
    /// ``addCursor(up:)`` was first called - and the topmost selection otherwise, which is where a column created
    /// by option-dragging starts.
    ///
    /// - Returns: `true` if there was more than one selection to collapse.
    @discardableResult
    func collapseSelections() -> Bool {
        guard textSelections.count > 1 else { return false }
        let anchor = textSelections.first(where: { $0 === columnAnchor }) ?? textSelections[0]
        setSelectedRange(NSRange(location: anchor.range.location, length: 0))
        return true
    }
}
