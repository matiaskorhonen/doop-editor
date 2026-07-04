import SwiftUI
import CodeEditSourceEditor
import CodeEditLanguages
import CodeEditTextView

struct SourceEditorView: View {
    @Environment(\.colorScheme)
    var colorScheme

    @Binding var document: DoopEditorExampleDocument
    let fileURL: URL?

    @State private var language: CodeLanguage = .default
    @State private var theme: EditorTheme = .light
    @State private var editorState = SourceEditorState(
        cursorPositions: [CursorPosition(line: 1, column: 1)]
    )

    @State private var font: NSFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
    @AppStorage("wrapLines") private var wrapLines: Bool = true
    @AppStorage("systemCursor") private var useSystemCursor: Bool = false

    @State private var indentOption: IndentOption = .spaces(count: 4)

    @AppStorage("showGutter") private var showGutter: Bool = true
    @State private var invisibleCharactersConfig: InvisibleCharactersConfiguration = .empty
    @State private var warningCharacters: Set<UInt16> = []

    @State private var isInLongParse = false

    @State private var treeSitterClient = TreeSitterClient()

    private func contentInsets(proxy: GeometryProxy) -> NSEdgeInsets {
        NSEdgeInsets(top: proxy.safeAreaInsets.top, left: showGutter ? 0 : 1, bottom: 28.0, right: 0)
    }

    init(document: Binding<DoopEditorExampleDocument>, fileURL: URL?) {
        self._document = document
        self.fileURL = fileURL
    }

    var body: some View {
        GeometryReader { proxy in
            SourceEditor(
                document.text,
                language: language,
                configuration: SourceEditorConfiguration(
                    appearance: .init(theme: theme, font: font, wrapLines: wrapLines),
                    behavior: .init(
                        indentOption: indentOption
                    ),
                    layout: .init(contentInsets: contentInsets(proxy: proxy)),
                    peripherals: .init(
                        showGutter: showGutter,
                        invisibleCharactersConfiguration: invisibleCharactersConfig,
                        warningCharacters: warningCharacters
                    )
                ),
                state: $editorState
            )
            .overlay(alignment: .bottom) {
                SourceEditorStatusBar(
                    fileURL: fileURL,
                    document: $document,
                    wrapLines: $wrapLines,
                    useSystemCursor: $useSystemCursor,
                    state: $editorState,
                    isInLongParse: $isInLongParse,
                    language: $language,
                    theme: $theme,
                    showGutter: $showGutter,
                    indentOption: $indentOption,
                    invisibles: $invisibleCharactersConfig,
                    warningCharacters: $warningCharacters
                )
            }
            .ignoresSafeArea()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onReceive(NotificationCenter.default.publisher(for: TreeSitterClient.Constants.longParse)) { _ in
                withAnimation(.easeIn(duration: 0.1)) {
                    isInLongParse = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: TreeSitterClient.Constants.longParseFinished)) { _ in
                withAnimation(.easeIn(duration: 0.1)) {
                    isInLongParse = false
                }
            }
            .onChange(of: colorScheme) { newValue in
                theme = newValue == .dark ? .dark : .light
            }
        }
    }
}
