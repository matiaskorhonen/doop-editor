# CodeEditSourceEditor

An Xcode-inspired code editor view written in Swift powered by tree-sitter for [CodeEdit](https://github.com/CodeEditApp/CodeEdit). Features include syntax highlighting (based on the provided theme), code completion, find and replace, text diff, validation, current line highlighting, minimap, inline messages (warnings and errors), bracket matching, and more.

> [!IMPORTANT]
> **CodeEditSourceEditor is currently in development and it is not ready for production use.**

## Documentation

This package is fully documented [here](https://codeeditapp.github.io/CodeEditSourceEditor/documentation/codeeditsourceeditor/).

## Usage (SwiftUI)

CodeEditSourceEditor provides two APIs for creating an editor: SwiftUI and AppKit. The SwiftUI API provides extremely customizable and flexible configuration options, including two-way bindings for state like cursor positions and scroll position.

For more complex features that require access to the underlying text view or text storage, we've developed the [TextViewCoordinators](https://codeeditapp.github.io/CodeEditSourceEditor/documentation/codeeditsourceeditor/textviewcoordinators) API. Using this API, developers can inject custom behavior into the editor as events happen, without having to work with state or bindings.

```swift
import CodeEditSourceEditor

struct ContentView: View {
    @State var text = "let x = 1.0"
    
   /// Automatically updates with cursor positions, scroll position, find panel text.
    /// Everything in this object is two-way, use it to update cursor positions, scroll position, etc.
    @State var editorState = SourceEditorState()
    
    /// Configure the editor's appearance, features, and editing behavior...
    @State var theme = EditorTheme(...)
    @State var font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    @State var indentOption = .spaces(count: 4)

    /// *Powerful* customization options with our text view coordinators API 
    @State var autoCompleteCoordinator = AutoCompleteCoordinator()

    var body: some View { 
        SourceEditor(
            $text,
            language: language,
            // Tons of customization options, with good defaults to get started quickly.
            configuration: SourceEditorConfiguration(
                appearance: .init(theme: theme, font: font),
                behavior: .init(indentOption: indentOption)
            ),
            state: $editorState,
            coordinators: [autoCompleteCoordinator]
        )
    }
    
    /// Autocompletes "Hello" to "Hello world!" whenever it's typed.
    final class AutoCompleteCoordinator: TextViewCoordinator {
        func prepareCoordinator(controller: TextViewController) { }

        func textViewDidChangeText(controller: TextViewController) {
            for cursorPosition in controller.cursorPositions where cursorPosition.range.location >= 5 {
                let location = cursorPosition.range.location
                let previousRange = NSRange(start: location - 5, end: location)
                let string = (controller.text as NSString).substring(with: previousRange)

                if string.lowercased() == "hello" {
                    controller.textView.replaceCharacters(in: NSRange(location: location, length: 0), with: " world!")
                }
            }
        }
    }
}
```

An AppKit API is also available.

## Dependencies

Special thanks to [Matt Massicotte](https://bsky.app/profile/massicotte.org) for the great work he's done!

| Package | Source | Author |
| :- | :- | :- |
| `SwiftTreeSitter` | [GitHub](https://github.com/tree-sitter/swift-tree-sitter) | [Matt Massicotte](https://bsky.app/profile/massicotte.org) |

## License

Licensed under the [MIT license](https://github.com/CodeEditApp/CodeEdit/blob/main/LICENSE.md).
