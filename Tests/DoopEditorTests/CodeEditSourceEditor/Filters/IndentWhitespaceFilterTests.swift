import Testing
import AppKit
@testable import DoopEditor

/// The two filters that make an indent behave like one unit rather than a run of spaces:
/// ``DeleteWhitespaceFilter`` on backspace and ``TabReplacementFilter`` on tab.
///
/// Both run on every keystroke in an indented document, and neither had a test. They are driven
/// here through `TextViewController` — `deleteBackward` and `insertText` — rather than by calling
/// `processMutation` directly, because the filter chain, the text interface and the indent option
/// all have to line up for either to fire, and calling the filter alone would skip all three.
@Suite
@MainActor
struct IndentWhitespaceFilterTests {
    private func controller(
        _ text: String,
        indentOption: IndentOption = .spaces(count: 4)
    ) -> TextViewController {
        let controller = Mock.textViewController(theme: Mock.theme())
        let window = NSWindow()
        window.contentViewController = controller
        controller.loadView()
        window.setFrame(NSRect(x: 0, y: 0, width: 1000, height: 1000), display: false)
        controller.configuration.behavior.indentOption = indentOption
        controller.setText(text)
        return controller
    }

    private func backspace(_ controller: TextViewController, at location: Int) {
        controller.textView.selectionManager.setSelectedRange(NSRange(location: location, length: 0))
        controller.textView.deleteBackward(nil)
    }

    // MARK: - Deleting indentation

    /// A cursor at one indent level deletes the whole level, not one space of it.
    @Test
    func backspaceAtAnIndentColumnDeletesAWholeIndent() {
        let controller = controller("    text")

        backspace(controller, at: 4)

        #expect(controller.textView.string == "text")
    }

    /// From two levels in, backspace takes back one level and leaves the other.
    @Test
    func backspaceDeletesOneIndentLevelAtATime() {
        let controller = controller("        text")

        backspace(controller, at: 8)
        #expect(controller.textView.string == "    text")

        backspace(controller, at: 4)
        #expect(controller.textView.string == "text")
    }

    /// Indentation that is not a whole number of levels — six spaces where the unit is four —
    /// deletes back to the nearest column rather than a full unit, so the next backspace starts
    /// from an aligned position.
    @Test
    func backspaceDeletesBackToTheNearestIndentColumn() {
        let controller = controller("      text")

        backspace(controller, at: 6)
        #expect(controller.textView.string == "    text")

        backspace(controller, at: 4)
        #expect(controller.textView.string == "text")
    }

    /// The filter works on the whole leading run, so a cursor inside the indentation deletes from
    /// the end of that run rather than from where the cursor sits.
    @Test
    func backspaceInsideTheIndentDeletesFromTheEndOfTheRun() {
        let controller = controller("        text")

        backspace(controller, at: 2)

        #expect(controller.textView.string == "    text")
    }

    /// Only the leading whitespace is an indent. Spaces between words are just spaces, and
    /// backspace takes one of them.
    @Test
    func backspaceInTrailingWhitespaceDeletesOneCharacter() {
        let controller = controller("    one   two")

        backspace(controller, at: 9)

        #expect(controller.textView.string == "    one  two")
    }

    /// Backspacing over ordinary text is untouched by the filter.
    @Test
    func backspaceAfterTextDeletesOneCharacter() {
        let controller = controller("    text")

        backspace(controller, at: 8)

        #expect(controller.textView.string == "    tex")
    }

    /// With tab indentation the filter stands down — one tab is already one indent, so the
    /// ordinary single-character delete is the right behaviour.
    @Test
    func backspaceWithTabIndentationDeletesOneCharacter() {
        let controller = controller("\t\ttext", indentOption: .tab)

        backspace(controller, at: 2)

        #expect(controller.textView.string == "\ttext")
    }

    /// The filter only claims single-character deletions, so deleting a selection still removes
    /// exactly what was selected.
    @Test
    func deletingASelectionInsideTheIndentRemovesTheSelection() {
        let controller = controller("        text")

        controller.textView.selectionManager.setSelectedRange(NSRange(location: 2, length: 4))
        controller.textView.deleteBackward(nil)

        #expect(controller.textView.string == "    text")
    }

    /// A one-space indent unit means every space is its own level, which is the degenerate case
    /// of the modulo that picks how much to delete.
    @Test
    func backspaceWithASingleSpaceIndentDeletesOneSpace() {
        let controller = controller("   text", indentOption: .spaces(count: 1))

        backspace(controller, at: 3)

        #expect(controller.textView.string == "  text")
    }

    /// Indentation on a later line is leading whitespace too — the filter looks at the line the
    /// cursor is on, not the document.
    @Test
    func backspaceAppliesToIndentationOnAnyLine() {
        let controller = controller("one\n    two")

        backspace(controller, at: 8)

        #expect(controller.textView.string == "one\ntwo")
    }

    // MARK: - Inserting a tab

    /// Tab inserts the configured indent unit rather than a tab character.
    @Test
    func tabInsertsTheIndentUnit() {
        let controller = controller("text")
        controller.textView.selectionManager.setSelectedRange(NSRange(location: 0, length: 0))

        controller.textView.insertText("\t")

        #expect(controller.textView.string == "    text")
    }

    /// With tab indentation configured, a tab stays a tab.
    @Test
    func tabStaysATabWhenIndentingWithTabs() {
        let controller = controller("text", indentOption: .tab)
        controller.textView.selectionManager.setSelectedRange(NSRange(location: 0, length: 0))

        controller.textView.insertText("\t")

        #expect(controller.textView.string == "\ttext")
    }

    /// The substitution is the configured width, not a fixed four.
    @Test
    func tabInsertsTheConfiguredNumberOfSpaces() {
        let controller = controller("text", indentOption: .spaces(count: 2))
        controller.textView.selectionManager.setSelectedRange(NSRange(location: 0, length: 0))

        controller.textView.insertText("\t")

        #expect(controller.textView.string == "  text")
    }
}
