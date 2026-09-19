//
//  TextView+TextFormation.swift
//  CodeEditSourceEditor
//
//  Created by Khan Winter on 10/14/23.
//

import Foundation
import CodeEditTextView
import TextStory

extension TextView: TextStoring {
    public var length: Int {
        textStorage.length
    }

    public func substring(from range: NSRange) -> String? {
        return textStorage.substring(from: range)
    }

    /// Applies the mutation to the text view.
    ///
    /// If the mutation is empty it will be ignored.
    ///
    /// - Parameter mutation: The mutation to apply.
    public func applyMutation(_ mutation: TextMutation) {
        guard !mutation.isEmpty else { return }
        _undoManager?.registerMutation(mutation)
        textStorage.replaceCharacters(in: mutation.range, with: mutation.string)
        selectionManager.didReplaceCharacters(
            in: mutation.range,
            replacementLength: (mutation.string as NSString).length
        )
        layoutManager.invalidateLayoutForRange(mutation.range)
    }
}
