//
//  TextView+MultiCursor.swift
//  CodeEditTextView
//

import AppKit

extension TextView {
    /// Adds a cursor one line above the topmost cursor, in the same column.
    ///
    /// Repeated calls grow the column upwards. Does nothing when the topmost cursor is on the first line.
    public func addCursorAbove() {
        addCursor(up: true)
    }

    /// Adds a cursor one line below the bottommost cursor, in the same column.
    ///
    /// Repeated calls grow the column downwards. Does nothing when the bottommost cursor is on the last line.
    public func addCursorBelow() {
        addCursor(up: false)
    }

    private func addCursor(up: Bool) {
        guard isSelectable else { return }
        unmarkTextIfNeeded()

        guard let newOffset = selectionManager.addCursor(up: up) else { return }

        // Scroll to the new cursor rather than the selection `scrollSelectionToVisible` picks: that one is always
        // the lowest, which never scrolls up to a cursor added above.
        scrollToRange(NSRange(location: newOffset, length: 0), center: false)
        needsDisplay = true
    }

    /// Collapses a column of cursors back to a single cursor.
    ///
    /// Called for the escape key, which every editor with multiple cursors uses for this.
    override public func cancelOperation(_ sender: Any?) {
        guard selectionManager.collapseSelections() else { return }
        unmarkTextIfNeeded()
        scrollSelectionToVisible()
        needsDisplay = true
    }
}
