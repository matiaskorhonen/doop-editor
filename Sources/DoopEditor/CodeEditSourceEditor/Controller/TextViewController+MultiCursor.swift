//
//  TextViewController+MultiCursor.swift
//  CodeEditSourceEditor
//

import Foundation

extension TextViewController {
    /// Adds a cursor one line above the topmost cursor, in the same column.
    public func addCursorAbove() {
        textView.addCursorAbove()
    }

    /// Adds a cursor one line below the bottommost cursor, in the same column.
    public func addCursorBelow() {
        textView.addCursorBelow()
    }

    /// Collapses a column of cursors back to a single cursor.
    public func collapseCursors() {
        textView.cancelOperation(nil)
    }
}
