//
//  TextViewTextInterface.swift
//  CodeEditSourceEditor
//

import Foundation
import CodeEditTextView
import TextStory
internal import TextFormation

/// Adapts a ``CodeEditTextView/TextView`` to TextFormation's `TextInterface`, which is what the text
/// filters edit through.
///
/// `TextView` used to conform to `TextInterface` itself. A public conformance to a third-party
/// protocol puts that protocol's module into this module's public `.swiftinterface`, which would make
/// every consumer of the binary distribution resolve TextFormation -- and nothing outside these
/// filters needs it. Wrapping the conformance keeps TextFormation an implementation detail, so the
/// binary distribution absorbs it instead of shipping it. See BINARY_DISTRIBUTION.md.
///
/// A class rather than a struct: `Filter.processMutation(_:in:with:)` takes the interface by value,
/// so a struct's mutations to `selectedRange` would be lost.
final class TextViewTextInterface: TextInterface {
    private let textView: TextView

    init(_ textView: TextView) {
        self.textView = textView
    }

    var selectedRange: NSRange {
        get {
            textView
                .selectionManager
                .textSelections
                .sorted(by: { $0.range.lowerBound < $1.range.lowerBound })
                .first?
                .range ?? .zero
        }
        set {
            textView.selectionManager.setSelectedRange(newValue)
        }
    }

    var length: Int {
        textView.length
    }

    func substring(from range: NSRange) -> String? {
        textView.substring(from: range)
    }

    func applyMutation(_ mutation: TextMutation) {
        textView.applyMutation(mutation)
    }
}
