import SwiftUI

enum EditorMode: String {
    case sourceEditor
    case rawTextView
}

struct ContentView: View {
    @Binding var document: DoopEditorExampleDocument
    let fileURL: URL?

    @AppStorage("editorMode") private var mode: EditorMode = .sourceEditor

    var body: some View {
        Group {
            switch mode {
            case .sourceEditor:
                SourceEditorView(document: $document, fileURL: fileURL)
            case .rawTextView:
                RawTextView(text: document.text)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Picker("Mode", selection: $mode) {
                    Text("Source Editor").tag(EditorMode.sourceEditor)
                    Text("Text View").tag(EditorMode.rawTextView)
                }
                .pickerStyle(.segmented)
            }
        }
    }
}
