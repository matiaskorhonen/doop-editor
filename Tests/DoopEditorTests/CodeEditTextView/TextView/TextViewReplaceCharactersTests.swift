import Testing
import AppKit
@testable import DoopEditor

/// Where the cursors end up after ``TextView/replaceCharacters(in:with:)`` rewrites several
/// ranges at once — the offsets ``TextSelectionManager/didReplaceCharacters(in:replacementLength:)``
/// computes as it walks the ranges.
///
/// Each case pins one sign of the length change, because the delta is the whole subject here: a
/// replacement that grows the document, one that shrinks it, and one that leaves it exactly as
/// long. The last is the one that regressed, and the only one where the replaced range's own
/// length has to be subtracted for the arithmetic to come out flat.
@Suite
@MainActor
struct TextViewReplaceCharactersTests {
    /// Three identical ten-character lines. Every line is the same length, so an offset that
    /// drifts by a line reads as an obviously wrong number rather than a plausible one.
    nonisolated private static let document = "LoremIpsum\nLoremIpsum\nLoremIpsum"

    /// The "Ipsum" half of each line: the three selections every test starts from.
    nonisolated private static let selections = [
        NSRange(location: 5, length: 5),
        NSRange(location: 16, length: 5),
        NSRange(location: 27, length: 5)
    ]

    private func textView(selecting ranges: [NSRange] = selections) -> TextView {
        let textView = TextView(string: Self.document)
        textView.selectionManager.setSelectedRanges(ranges)
        return textView
    }

    private func ranges(_ textView: TextView) -> [NSRange] {
        textView.selectionManager.textSelections.map(\.range)
    }

    /// Replacing each selection with a string of its own length leaves the document the same
    /// size, so each cursor should land at the end of the text it replaced and nowhere else.
    ///
    /// Getting this wrong used to walk the last cursor to offset 42 in a 32-character document,
    /// where the next edit trapped in TextStory's `inverseMutation` rather than failing a check.
    @Test
    func replacingWithTheSameLengthLeavesCursorsInPlace() {
        let textView = textView()

        textView.replaceCharacters(in: Self.selections, with: "Ipsum")

        #expect(textView.textStorage.string == Self.document)
        #expect(
            ranges(textView) == [
                NSRange(location: 10, length: 0),
                NSRange(location: 21, length: 0),
                NSRange(location: 32, length: 0)
            ]
        )
    }

    /// The scenario that found it: paste over a column of selections, then type. The typing is
    /// what trapped, because it is the first edit to use the offsets the paste left behind.
    @Test
    func typingAfterASameLengthReplacementLandsOnEveryLine() {
        let textView = textView()

        textView.replaceCharacters(in: Self.selections, with: "Ipsum")
        textView.insertText("x", replacementRange: NSRange(location: NSNotFound, length: 0))

        #expect(textView.textStorage.string == "LoremIpsumx\nLoremIpsumx\nLoremIpsumx")
    }

    /// A longer replacement pushes every later cursor along by what each earlier one added.
    @Test
    func replacingWithALongerStringShiftsLaterCursorsForward() {
        let textView = textView()

        textView.replaceCharacters(in: Self.selections, with: "Dolorem")

        #expect(textView.textStorage.string == "LoremDolorem\nLoremDolorem\nLoremDolorem")
        #expect(
            ranges(textView) == [
                NSRange(location: 12, length: 0),
                NSRange(location: 25, length: 0),
                NSRange(location: 38, length: 0)
            ]
        )
    }

    /// And a shorter one pulls them back.
    @Test
    func replacingWithAShorterStringShiftsLaterCursorsBack() {
        let textView = textView()

        textView.replaceCharacters(in: Self.selections, with: "Sit")

        #expect(textView.textStorage.string == "LoremSit\nLoremSit\nLoremSit")
        #expect(
            ranges(textView) == [
                NSRange(location: 8, length: 0),
                NSRange(location: 17, length: 0),
                NSRange(location: 26, length: 0)
            ]
        )
    }

    /// Deleting the selections outright is the same arithmetic with nothing inserted, and
    /// collapses each cursor to where its selection began.
    @Test
    func replacingWithAnEmptyStringCollapsesCursorsToTheRangeStart() {
        let textView = textView()

        textView.replaceCharacters(in: Self.selections, with: "")

        #expect(textView.textStorage.string == "Lorem\nLorem\nLorem")
        #expect(
            ranges(textView) == [
                NSRange(location: 5, length: 0),
                NSRange(location: 11, length: 0),
                NSRange(location: 17, length: 0)
            ]
        )
    }

    /// Inserting at a column of bare cursors — no selections to replace — is the case the old
    /// arithmetic did handle, kept here so a fix to the others can't quietly break it.
    @Test
    func insertingAtEmptyCursorsShiftsLaterCursorsForward() {
        let textView = textView(selecting: [
            NSRange(location: 5, length: 0),
            NSRange(location: 16, length: 0),
            NSRange(location: 27, length: 0)
        ])

        textView.replaceCharacters(
            in: [
                NSRange(location: 5, length: 0),
                NSRange(location: 16, length: 0),
                NSRange(location: 27, length: 0)
            ],
            with: "-"
        )

        #expect(textView.textStorage.string == "Lorem-Ipsum\nLorem-Ipsum\nLorem-Ipsum")
        #expect(
            ranges(textView) == [
                NSRange(location: 6, length: 0),
                NSRange(location: 18, length: 0),
                NSRange(location: 30, length: 0)
            ]
        )
    }
}
