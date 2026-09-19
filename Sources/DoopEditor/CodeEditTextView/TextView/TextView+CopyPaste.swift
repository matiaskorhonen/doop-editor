//
//  TextView+CopyPaste.swift
//  CodeEditTextView
//
//  Created by Khan Winter on 8/21/23.
//

import AppKit

extension TextView {
    /// Copies the selected text to the general pasteboard as plain text.
    ///
    /// Syntax highlighting is dropped on purpose: code pasted into a rich text editor should arrive
    /// as text, in that editor's own font and color. Use ``copyWithHighlighting(_:)`` to keep the
    /// highlighting.
    @objc open func copy(_ sender: AnyObject) {
        copySelection(withHighlighting: false)
    }

    /// Copies the selected text to the general pasteboard with its syntax highlighting intact.
    ///
    /// The pasteboard gets RTF alongside the plain string, so a rich text target keeps the editor's
    /// colors and font while a plain one is unaffected.
    @objc open func copyWithHighlighting(_ sender: AnyObject) {
        copySelection(withHighlighting: true)
    }

    /// Writes the selected text to a pasteboard, with or without syntax highlighting.
    ///
    /// Each selection becomes its own pasteboard item, in the order the selections appear in the
    /// document.
    ///
    /// - Parameters:
    ///   - pasteboard: The pasteboard to write to. Defaults to the general pasteboard.
    ///   - withHighlighting: Whether to write the text's attributes as well as its characters.
    ///                       Highlighted text is written as an `NSAttributedString`, which carries
    ///                       RTF and plain string representations; plain text is written as a
    ///                       string alone.
    public func copySelection(to pasteboard: NSPasteboard = .general, withHighlighting: Bool) {
        guard let ranges = selectionManager?.textSelections.map({ $0.range }), !ranges.isEmpty else {
            return
        }

        let items: [any NSPasteboardWriting] = ranges.map { range in
            let substring = textStorage.attributedSubstring(from: range)
            return withHighlighting ? highlightedItem(for: substring) : substring.string as NSString
        }

        pasteboard.clearContents()
        pasteboard.writeObjects(items)
    }

    /// Prepares a highlighted substring for the pasteboard.
    ///
    /// The editor's background is painted onto the copied text: a theme's foreground colors are
    /// chosen against it, and a dark theme's text is unreadable when it lands on a white page
    /// without it. A transparent editor background is left alone.
    private func highlightedItem(for substring: NSAttributedString) -> NSAttributedString {
        guard let background = enclosingScrollView?.backgroundColor,
              background.alphaComponent > 0 else {
            return substring
        }

        let copy = NSMutableAttributedString(attributedString: substring)
        copy.addAttribute(
            .backgroundColor,
            value: background,
            range: NSRange(location: 0, length: copy.length)
        )
        return copy
    }

    @objc open func paste(_ sender: AnyObject) {
        guard let stringContents = NSPasteboard.general.string(forType: .string) else { return }
        insertText(stringContents, replacementRange: NSRange(location: NSNotFound, length: 0))
    }

    @objc open func cut(_ sender: AnyObject) {
        copy(sender)
        deleteBackward(sender)
    }

    @objc open func delete(_ sender: AnyObject) {
        deleteBackward(sender)
    }
}
