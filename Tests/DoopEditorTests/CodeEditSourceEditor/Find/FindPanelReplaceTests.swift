import Testing
import AppKit
@testable import DoopEditor

/// Replacing matches from the find panel, over a real ``TextViewController`` target.
///
/// The existing `FindPanelTests` cover the find half against a mock target. Replace is the half
/// that does arithmetic: every replacement whose text differs in length from the match moves every
/// later match, and the offsets have to be carried without a re-search. A sign error there does
/// not throw — it quietly replaces the wrong span of the document.
///
/// These use the real controller rather than a mock because the controller is what registers for
/// `TextView.textDidChangeNotification`, and that observer re-runs `find()` in the middle of a
/// replace. Any test of the offset bookkeeping that skips it is testing a code path the app
/// never takes.
@Suite
@MainActor
struct FindPanelReplaceTests {
    private func controller(_ text: String) -> TextViewController {
        let controller = Mock.textViewController(theme: Mock.theme())
        let window = NSWindow()
        window.contentViewController = controller
        controller.loadView()
        window.setFrame(NSRect(x: 0, y: 0, width: 1000, height: 1000), display: false)
        controller.setText(text)
        return controller
    }

    private func viewModel(
        _ controller: TextViewController,
        find: String,
        replace: String
    ) -> FindPanelViewModel {
        let viewModel = controller.findViewController!.viewModel
        viewModel.findText = find
        viewModel.replaceText = replace
        viewModel.find()
        return viewModel
    }

    private func text(_ controller: TextViewController) -> String {
        controller.textView.string
    }

    // MARK: - Replace all

    /// The replacement is shorter than the match, so every later match slides left as the document
    /// shrinks. Three matches means two chances to accumulate the error.
    @Test
    func replaceAllWithShorterText() {
        let controller = controller("alpha one alpha two alpha")
        let viewModel = viewModel(controller, find: "alpha", replace: "a")

        #expect(viewModel.matchCount == 3)
        viewModel.replaceAll()

        #expect(text(controller) == "a one a two a")
    }

    /// The replacement is longer, so every later match slides right. This is the direction that
    /// catches a sign error: getting it backwards eats the text between the matches.
    @Test
    func replaceAllWithLongerText() {
        let controller = controller("a one a two a")
        let viewModel = viewModel(controller, find: "a", replace: "alpha")

        viewModel.replaceAll()

        #expect(text(controller) == "alpha one alpha two alpha")
    }

    /// Equal lengths leave every later match exactly where it was. Nothing should move, which
    /// makes this the case where an off-by-one shows up as a clean one-character shift.
    @Test
    func replaceAllWithSameLengthText() {
        let controller = controller("cat dog cat dog cat")
        let viewModel = viewModel(controller, find: "cat", replace: "cow")

        viewModel.replaceAll()

        #expect(text(controller) == "cow dog cow dog cow")
    }

    /// Deleting every match is the extreme of the shrinking case: each replacement removes its
    /// whole span, so the later offsets move by the full match length every time.
    @Test
    func replaceAllWithEmptyStringDeletesMatches() {
        let controller = controller("a-b-c-d")
        let viewModel = viewModel(controller, find: "-", replace: "")

        viewModel.replaceAll()

        #expect(text(controller) == "abcd")
    }

    /// Adjacent matches share a boundary, so there is no untouched text between them to absorb a
    /// bad offset — the result is wrong text rather than text in the wrong place.
    @Test
    func replaceAllWithAdjacentMatches() {
        let controller = controller("aaaa")
        let viewModel = viewModel(controller, find: "a", replace: "bb")

        #expect(viewModel.matchCount == 4)
        viewModel.replaceAll()

        #expect(text(controller) == "bbbbbbbb")
    }

    /// Replacing everything leaves nothing to find, and no current match to point at.
    @Test
    func replaceAllClearsTheMatchState() {
        let controller = controller("x y x")
        let viewModel = viewModel(controller, find: "x", replace: "z")

        viewModel.replaceAll()

        #expect(viewModel.matchCount == 0)
        #expect(viewModel.currentFindMatchIndex == nil)
    }

    /// The whole run is one undo group, so one ⌘Z puts the document back. Replace-all is the
    /// clearest case where per-edit undo would be useless.
    @Test
    func replaceAllIsASingleUndoGroup() {
        let original = "alpha one alpha two alpha"
        let controller = controller(original)
        let viewModel = viewModel(controller, find: "alpha", replace: "beta")

        controller.textView._undoManager?.clearStack()
        viewModel.replaceAll()
        #expect(text(controller) == "beta one beta two beta")

        controller.textView.undoManager?.undo()
        #expect(text(controller) == original)
    }

    /// Replace-all with no matches must not touch the document.
    @Test
    func replaceAllWithNoMatchesDoesNothing() {
        let controller = controller("nothing to see")
        let viewModel = viewModel(controller, find: "absent", replace: "x")

        #expect(viewModel.matchCount == 0)
        viewModel.replaceAll()

        #expect(text(controller) == "nothing to see")
    }

    // MARK: - Replace one

    /// Replacing one match leaves the others alone and takes the replaced one off the list.
    @Test
    func replaceOneLeavesTheOtherMatches() {
        let controller = controller("cat dog cat")
        let viewModel = viewModel(controller, find: "cat", replace: "cow")
        viewModel.currentFindMatchIndex = 0

        viewModel.replace()

        #expect(text(controller) == "cow dog cat")
    }
}
