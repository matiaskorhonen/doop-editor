import SwiftUI
import AppKit
import CodeEditTextView

struct RawTextView: View {
    var text: NSTextStorage

    @AppStorage("rawTextView_wrapLines") private var wrapLines: Bool = true
    @AppStorage("rawTextView_edgeInsets") private var enableEdgeInsets: Bool = false
    @AppStorage("rawTextView_systemCursor") private var useSystemCursor: Bool = false
    @AppStorage("rawTextView_selectable") private var isSelectable: Bool = true
    @AppStorage("rawTextView_editable") private var isEditable: Bool = true

    var body: some View {
        RawTextViewRepresentable(
            text: text,
            wrapLines: $wrapLines,
            enableEdgeInsets: $enableEdgeInsets,
            useSystemCursor: $useSystemCursor,
            isSelectable: $isSelectable,
            isEditable: $isEditable
        )
        .padding(.bottom, 28)
        .overlay(alignment: .bottom) {
            RawTextViewStatusBar(
                text: text,
                wrapLines: $wrapLines,
                enableEdgeInsets: $enableEdgeInsets,
                useSystemCursor: $useSystemCursor,
                isSelectable: $isSelectable,
                isEditable: $isEditable
            )
        }
    }
}

struct RawTextViewRepresentable: NSViewControllerRepresentable {
    var text: NSTextStorage
    @Binding var wrapLines: Bool
    @Binding var enableEdgeInsets: Bool
    @Binding var useSystemCursor: Bool
    @Binding var isSelectable: Bool
    @Binding var isEditable: Bool

    func makeNSViewController(context: Context) -> RawTextViewController {
        let controller = RawTextViewController(string: "")
        controller.textView.setTextStorage(text)
        controller.wrapLines = wrapLines
        controller.enableEdgeInsets = enableEdgeInsets
        controller.useSystemCursor = useSystemCursor
        controller.isSelectable = isSelectable
        controller.isEditable = isEditable
        return controller
    }

    func updateNSViewController(_ nsViewController: RawTextViewController, context: Context) {
        nsViewController.wrapLines = wrapLines
        nsViewController.enableEdgeInsets = enableEdgeInsets
        nsViewController.useSystemCursor = useSystemCursor
        nsViewController.isSelectable = isSelectable
        nsViewController.isEditable = isEditable
    }
}
