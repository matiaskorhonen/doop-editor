import Testing
import AppKit
@testable import DoopEditor

@Suite
@MainActor
struct TextViewCopyPasteTests {
    let textView: TextView
    let pasteboard: NSPasteboard

    init() {
        textView = TextView(string: "Lorem Ipsum Dolor")
        textView.textStorage.addAttribute(
            .foregroundColor,
            value: NSColor.systemPurple,
            range: NSRange(location: 0, length: 5)
        )
        // A pasteboard of its own per test, so the suite's parallel cases don't overwrite
        // each other's items — and so a test run never touches the user's clipboard.
        pasteboard = NSPasteboard(name: NSPasteboard.Name("DoopEditorCopyPasteTests-\(UUID().uuidString)"))
        pasteboard.clearContents()
    }

    @Test
    func copyWritesPlainText() {
        textView.selectionManager.setSelectedRange(NSRange(location: 0, length: 11))

        textView.copySelection(to: pasteboard, withHighlighting: false)

        #expect(pasteboard.string(forType: .string) == "Lorem Ipsum")
        #expect(pasteboard.data(forType: .rtf) == nil)
    }

    @Test
    func copyWithHighlightingWritesRichText() {
        textView.selectionManager.setSelectedRange(NSRange(location: 0, length: 11))

        textView.copySelection(to: pasteboard, withHighlighting: true)

        #expect(pasteboard.string(forType: .string) == "Lorem Ipsum")

        let data = pasteboard.data(forType: .rtf)
        #expect(data != nil)

        let pasted = data.flatMap { NSAttributedString(rtf: $0, documentAttributes: nil) }
        let color = pasted?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        #expect(color?.usingColorSpace(.deviceRGB) == NSColor.systemPurple.usingColorSpace(.deviceRGB))
    }

    @Test
    func copyWritesOneItemPerSelection() {
        textView.selectionManager.setSelectedRanges([
            NSRange(location: 0, length: 5),
            NSRange(location: 12, length: 5)
        ])

        textView.copySelection(to: pasteboard, withHighlighting: false)

        #expect(pasteboard.pasteboardItems?.count == 2)
        #expect(pasteboard.pasteboardItems?.map { $0.string(forType: .string) } == ["Lorem", "Dolor"])
    }

    @Test
    func copyWithoutSelectionsLeavesPasteboardAlone() {
        pasteboard.clearContents()
        pasteboard.setString("Untouched", forType: .string)

        textView.copySelection(to: pasteboard, withHighlighting: false)

        #expect(pasteboard.string(forType: .string) == "Untouched")
    }
}
