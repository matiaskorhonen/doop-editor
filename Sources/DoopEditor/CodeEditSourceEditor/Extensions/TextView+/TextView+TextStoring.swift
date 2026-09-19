//
//  TextView+TextStoring.swift
//  DoopEditor
//
//  Created by Khan Winter on 10/14/23.
//

import Foundation
internal import TextStory

/// The text-mutation primitives the filters edit a ``TextView`` through.
///
/// `TextView` deliberately does not conform to TextStory's `TextStoring`: a conformance of a public
/// type to a third-party protocol is public, and cannot be made internal, so it would put TextStory
/// into this module's public `.swiftinterface`. Nothing outside this module needs any of it, so
/// these are plain internal methods, and ``TextViewTextInterface`` carries the conformance
/// TextFormation's filters ask for. See BINARY_DISTRIBUTION.md.
extension TextView {
    var length: Int {
        textStorage.length
    }

    func substring(from range: NSRange) -> String? {
        return textStorage.substring(from: range)
    }

    /// Applies the mutation to the text view.
    ///
    /// If the mutation is empty it will be ignored.
    ///
    /// - Parameter mutation: The mutation to apply.
    func applyMutation(_ mutation: TextMutation) {
        guard !mutation.isEmpty else { return }
        _undoManager?.registerMutation(mutation)
        textStorage.replaceCharacters(in: mutation.range, with: mutation.string)
        selectionManager.didReplaceCharacters(
            in: mutation.range,
            replacementLength: (mutation.string as NSString).length
        )
        layoutManager.invalidateLayoutForRange(mutation.range)
    }

    /// Replaces a range with a string. Mirrors `TextStoring`'s protocol-extension default.
    func replaceString(in range: NSRange, with string: String) {
        applyMutation(TextMutation(string: string, range: range, limit: length))
    }

    /// Inserts a string at a location. Mirrors `TextStoring`'s protocol-extension default.
    func insertString(_ string: String, at location: Int) {
        applyMutation(TextMutation(string: string, range: NSRange(location: location, length: 0), limit: length))
    }
}
