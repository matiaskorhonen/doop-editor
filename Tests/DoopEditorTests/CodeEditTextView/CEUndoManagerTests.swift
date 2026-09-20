import Testing
import AppKit
@testable import DoopEditor

/// What ``CEUndoManager`` puts on its stacks, and when it decides one edit belongs with the last.
///
/// The grouping heuristic is the part worth pinning. It is invisible until it is wrong, and when
/// it is wrong the symptom is not a crash but a user pressing ⌘Z four times to undo one word — or
/// once, and losing a paragraph. Every case below drives the manager through ``TextView`` rather
/// than calling ``CEUndoManager/registerMutation(_:)`` directly, because that is the only path
/// that exists in practice and the inverse mutations come from the real text storage.
@Suite
@MainActor
struct CEUndoManagerTests {
    private func textView(_ string: String = "") -> TextView {
        let textView = TextView(string: string)
        textView.selectionManager.setSelectedRange(
            NSRange(location: (string as NSString).length, length: 0)
        )
        return textView
    }

    private func undoManager(for textView: TextView) -> CEUndoManager {
        // Force-unwrapped deliberately: `TextView.init` always makes one, and a nil here is a
        // regression in its own right rather than something to skip the test over.
        textView._undoManager!
    }

    /// Types at the end of the document one character at a time, the way a keyboard does.
    ///
    /// Grouping is decided per mutation, so a test that inserted "hello" in one call would
    /// register one mutation and prove nothing about whether five would have merged.
    private func type(_ string: String, into textView: TextView) {
        for character in string {
            textView.replaceCharacters(
                in: NSRange(location: textView.textStorage.length, length: 0),
                with: String(character)
            )
        }
    }

    private func text(_ textView: TextView) -> String {
        textView.textStorage.string
    }

    // MARK: - Undo and redo

    /// The baseline: an edit can be undone, and the undone edit can be redone.
    @Test
    func undoRestoresTextAndRedoReappliesIt() {
        let textView = textView()

        type("hello", into: textView)
        #expect(text(textView) == "hello")

        textView.undoManager?.undo()
        #expect(text(textView) == "")

        textView.undoManager?.redo()
        #expect(text(textView) == "hello")
    }

    /// Undoing moves a group from one stack to the other rather than discarding it, so the counts
    /// have to move together. `canUndo`/`canRedo` are what AppKit asks to enable the menu items.
    @Test
    func undoMovesTheGroupOntoTheRedoStack() {
        let textView = textView()
        let manager = undoManager(for: textView)

        type("hello", into: textView)
        #expect(manager.undoCount == 1)
        #expect(manager.redoCount == 0)
        #expect(manager.canUndo)
        #expect(!manager.canRedo)

        manager.undo()
        #expect(manager.undoCount == 0)
        #expect(manager.redoCount == 1)
        #expect(!manager.canUndo)
        #expect(manager.canRedo)

        manager.redo()
        #expect(manager.undoCount == 1)
        #expect(manager.redoCount == 0)
    }

    /// Editing after an undo abandons the branch that was undone. Keeping the redo stack alive
    /// here would let ⌘⇧Z replay an edit against text it was never computed for.
    @Test
    func editingAfterUndoClearsTheRedoStack() {
        let textView = textView()
        let manager = undoManager(for: textView)

        type("hello", into: textView)
        manager.undo()
        #expect(manager.canRedo)

        type("world", into: textView)

        #expect(!manager.canRedo)
        #expect(manager.redoCount == 0)
        #expect(text(textView) == "world")
    }

    /// Undo and redo are symmetric over several groups: the stack unwinds in order, then rewinds
    /// in the same order. Each word is its own group because the space between them breaks it.
    @Test
    func undoAndRedoWalkTheStackInOrder() {
        let textView = textView()
        let manager = undoManager(for: textView)

        type("one two", into: textView)
        let groups = manager.undoCount
        #expect(groups > 1)

        for _ in 0..<groups {
            manager.undo()
        }
        #expect(text(textView) == "")

        for _ in 0..<groups {
            manager.redo()
        }
        #expect(text(textView) == "one two")
    }

    /// Undoing with nothing to undo is a beep, not a crash or an empty group on the redo stack.
    @Test
    func undoingAnEmptyStackChangesNothing() {
        let textView = textView("untouched")
        let manager = undoManager(for: textView)

        manager.undo()

        #expect(text(textView) == "untouched")
        #expect(manager.redoCount == 0)
    }

    /// Undo puts the cursor where the edit was, so the next keystroke lands in the place the user
    /// is looking at. Typing five characters from offset 0 and undoing should collapse back to 0.
    @Test
    func undoPlacesTheCursorAtTheUndoneEdit() {
        let textView = textView()

        type("hello", into: textView)
        undoManager(for: textView).undo()

        #expect(textView.selectionManager.textSelections.map(\.range) == [NSRange(location: 0, length: 0)])
    }

    // MARK: - Automatic grouping

    /// Consecutive characters are one group: typing a word and pressing ⌘Z once removes the word.
    @Test
    func consecutiveTypingFormsOneGroup() {
        let textView = textView()
        let manager = undoManager(for: textView)

        type("hello", into: textView)

        #expect(manager.undoCount == 1)
        manager.undo()
        #expect(text(textView) == "")
    }

    /// A newline ends the group, so undo walks back a line at a time rather than swallowing the
    /// whole document. This is the rule the class documentation leads with.
    ///
    /// The newline opens the new group rather than closing the old one, so the line break goes
    /// back with the text that follows it.
    @Test
    func aNewlineBreaksTheGroup() {
        let textView = textView()
        let manager = undoManager(for: textView)

        type("ab\ncd", into: textView)

        #expect(manager.undoCount > 1)
        manager.undo()
        #expect(text(textView) == "ab")
    }

    /// Whitespace after non-whitespace ends the group, which is what makes undo work a word at a
    /// time. The space opens the new group rather than closing the old one, so it is undone
    /// along with the word it precedes and the first undo leaves "one" behind.
    @Test
    func whitespaceAfterAWordBreaksTheGroup() {
        let textView = textView()
        let manager = undoManager(for: textView)

        type("one two", into: textView)
        #expect(manager.undoCount == 2)

        manager.undo()
        #expect(text(textView) == "one")
    }

    /// An edit somewhere else in the document is a separate group even with no whitespace between
    /// them — two insertions that are not adjacent were two separate intentions.
    @Test
    func aNonSequentialEditBreaksTheGroup() {
        let textView = textView("abcdef")
        let manager = undoManager(for: textView)

        textView.replaceCharacters(in: NSRange(location: 6, length: 0), with: "X")
        textView.replaceCharacters(in: NSRange(location: 0, length: 0), with: "Y")

        #expect(manager.undoCount == 2)
    }

    /// Switching from inserting to deleting breaks the group, so undo does not resurrect text the
    /// user deleted and typed over in a single step.
    @Test
    func switchingBetweenInsertAndDeleteBreaksTheGroup() {
        let textView = textView()
        let manager = undoManager(for: textView)

        type("abc", into: textView)
        let afterTyping = manager.undoCount

        textView.replaceCharacters(in: NSRange(location: 2, length: 1), with: "")

        #expect(manager.undoCount == afterTyping + 1)
    }

    /// Backspacing over a word coalesces the same way typing it does: each deletion is adjacent
    /// to the last, so one ⌘Z brings the whole word back.
    @Test
    func consecutiveDeletionsFormOneGroup() {
        let textView = textView("hello")
        let manager = undoManager(for: textView)

        for location in stride(from: 4, through: 0, by: -1) {
            textView.replaceCharacters(in: NSRange(location: location, length: 1), with: "")
        }
        #expect(text(textView) == "")
        #expect(manager.undoCount == 1)

        manager.undo()
        #expect(text(textView) == "hello")
    }

    // MARK: - Explicit grouping

    /// The contract Doop's find-and-replace depends on: edits made between `beginUndoGrouping` and
    /// `endUndoGrouping` are one undo step even when they are nowhere near each other, which the
    /// automatic heuristic would otherwise split into one group per site.
    ///
    /// See `ScriptManager.replaceText(ranges:values:controller:)` in Doop, which wraps a batch of
    /// disjoint `replaceCharacters` calls in exactly this pair so one ⌘Z reverts the whole run.
    @Test
    func explicitGroupingMergesDisjointEdits() {
        let textView = textView("one two three")
        let manager = undoManager(for: textView)

        manager.beginUndoGrouping()
        // Applied back to front so the earlier ranges stay valid as the text shrinks.
        textView.replaceCharacters(in: NSRange(location: 8, length: 5), with: "C")
        textView.replaceCharacters(in: NSRange(location: 4, length: 3), with: "B")
        textView.replaceCharacters(in: NSRange(location: 0, length: 3), with: "A")
        manager.endUndoGrouping()

        #expect(text(textView) == "A B C")
        #expect(manager.undoCount == 1)

        manager.undo()
        #expect(text(textView) == "one two three")
    }

    /// The group is closed for good: an edit that arrives after `endUndoGrouping` starts a new
    /// group even when it is adjacent to the last one and would otherwise have merged.
    @Test
    func editsAfterEndGroupingStartANewGroup() {
        let textView = textView()
        let manager = undoManager(for: textView)

        manager.beginUndoGrouping()
        type("ab", into: textView)
        manager.endUndoGrouping()

        type("cd", into: textView)

        #expect(manager.undoCount == 2)
        manager.undo()
        #expect(text(textView) == "ab")
    }

    /// Opening a group also breaks from whatever came before it, so a batch never absorbs the
    /// keystroke that happened to precede it.
    @Test
    func beginGroupingBreaksFromPrecedingEdits() {
        let textView = textView()
        let manager = undoManager(for: textView)

        type("ab", into: textView)
        manager.beginUndoGrouping()
        type("cd", into: textView)
        manager.endUndoGrouping()

        #expect(manager.undoCount == 2)
    }

    /// `isGrouping` is public, and nesting is not supported — a second `beginUndoGrouping` is a
    /// no-op rather than something that needs two `end` calls to unwind.
    @Test
    func groupingFlagTracksTheOpenGroup() {
        let manager = undoManager(for: textView())

        #expect(!manager.isGrouping)
        manager.beginUndoGrouping()
        #expect(manager.isGrouping)
        manager.beginUndoGrouping()
        #expect(manager.isGrouping)
        manager.endUndoGrouping()
        #expect(!manager.isGrouping)
    }

    // MARK: - Disabling and clearing

    /// Edits made while the manager is disabled leave the stack untouched.
    ///
    /// This is what `setMarkedText` and `unmarkText` rely on: an IME composing a character
    /// rewrites the marked range on every keystroke, and none of those intermediate states is
    /// an edit the user could meaningfully undo to.
    ///
    /// The two words are typed separately so the second proves registration resumes; they are
    /// deliberately not adjacent, because two adjacent runs would coalesce into one group and
    /// the count could not tell "the first was ignored" apart from "both were merged".
    @Test
    func disabledMutationsAreNotRecorded() {
        let textView = textView()
        let manager = undoManager(for: textView)

        manager.disable()
        type("ignored", into: textView)
        manager.enable()

        #expect(text(textView) == "ignored")
        #expect(manager.undoCount == 0)
        #expect(!manager.canUndo)

        textView.replaceCharacters(in: NSRange(location: 0, length: 0), with: "counted")
        #expect(manager.undoCount == 1)

        // Undoing reaches only the recorded edit; the disabled one is not history to return to.
        manager.undo()
        #expect(text(textView) == "ignored")
        #expect(!manager.canUndo)
    }

    /// `undo` itself respects the disabled flag, so a disabled manager cannot rewrite the document
    /// out from under whatever disabled it.
    @Test
    func aDisabledManagerDoesNotUndo() {
        let textView = textView()
        let manager = undoManager(for: textView)

        type("hello", into: textView)
        manager.disable()
        manager.undo()

        #expect(text(textView) == "hello")
    }

    /// Clearing drops both stacks, which is what a document does when it is reloaded from disk.
    @Test
    func clearStackEmptiesBothStacks() {
        let textView = textView()
        let manager = undoManager(for: textView)

        type("hello", into: textView)
        manager.undo()
        type("world", into: textView)
        manager.undo()
        #expect(manager.canUndo || manager.canRedo)

        manager.clearStack()

        #expect(!manager.canUndo)
        #expect(!manager.canRedo)
        #expect(manager.undoCount == 0)
        #expect(manager.redoCount == 0)
    }

    /// Mutations applied while undoing are the undo, not new history. If they registered, undo
    /// would push its own inverse back onto the stack and ⌘Z would toggle between two states.
    @Test
    func undoingDoesNotRegisterItsOwnMutations() {
        let textView = textView()
        let manager = undoManager(for: textView)

        type("hello", into: textView)
        manager.undo()

        #expect(manager.undoCount == 0)
        #expect(manager.redoCount == 1)
    }
}
