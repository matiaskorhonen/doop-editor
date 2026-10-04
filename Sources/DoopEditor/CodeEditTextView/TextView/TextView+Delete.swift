//
//  TextView+Delete.swift
//  CodeEditTextView
//
//  Created by Khan Winter on 8/24/23.
//

import AppKit

extension TextView {
    open override func deleteBackward(_ sender: Any?) {
        delete(direction: .backward, destination: .character)
    }

    open override func deleteBackwardByDecomposingPreviousCharacter(_ sender: Any?) {
        delete(direction: .backward, destination: .character, decomposeCharacters: true)
    }

    open override func deleteForward(_ sender: Any?) {
        delete(direction: .forward, destination: .character)
    }

    open override func deleteWordBackward(_ sender: Any?) {
        delete(direction: .backward, destination: .word)
    }

    open override func deleteWordForward(_ sender: Any?) {
        delete(direction: .forward, destination: .word)
    }

    open override func deleteToBeginningOfLine(_ sender: Any?) {
        delete(direction: .backward, destination: .line)
    }

    open override func deleteToEndOfLine(_ sender: Any?) {
        delete(direction: .forward, destination: .line)
    }

    open override func deleteToBeginningOfParagraph(_ sender: Any?) {
        delete(direction: .backward, destination: .line)
    }

    open override func deleteToEndOfParagraph(_ sender: Any?) {
        delete(direction: .forward, destination: .line)
    }

    /// Two cursors on one line both extend over the same text when deleting by word or line. Replacing those
    /// overlapping ranges one after the other deletes the shared text twice, and the second range then reaches
    /// past the end of the shortened string. Folds each selection that overlaps its predecessor into it.
    /// Expects `selectionManager.textSelections` sorted by location.
    private func mergeOverlappingSelections() {
        var merged: [TextSelectionManager.TextSelection] = []
        for selection in selectionManager.textSelections {
            if let last = merged.last, selection.range.location < last.range.upperBound {
                last.range = last.range.union(selection.range)
            } else {
                merged.append(selection)
            }
        }
        selectionManager.textSelections = merged
    }

    private func delete(
        direction: TextSelectionManager.Direction,
        destination: TextSelectionManager.Destination,
        decomposeCharacters: Bool = false
    ) {
        /// Extend each selection by a distance specified by `destination`, then update both storage and the selection.
        for textSelection in selectionManager.textSelections {
            guard textSelection.range.isEmpty else { continue }
            let extendedRange = selectionManager.rangeOfSelection(
                from: textSelection.range.location,
                direction: direction,
                destination: destination
            )
            guard extendedRange.location >= 0 else { continue }
            textSelection.range.formUnion(extendedRange)
        }
        selectionManager.textSelections.sort(by: { $0.range.location < $1.range.location })
        mergeOverlappingSelections()
        KillRing.shared.kill(
            strings: selectionManager.textSelections.map(\.range).compactMap({ textStorage.substring(from: $0) })
        )
        replaceCharacters(in: selectionManager.textSelections.map(\.range), with: "")
        unmarkTextIfNeeded()
    }
}
