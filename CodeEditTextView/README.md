# CodeEditTextView

A text editor specialized for displaying and editing code documents. Features include basic text editing, extremely fast initial layout, support for handling large documents, customization options for code documents.

> [!IMPORTANT]
> This package contains a text view suitable for replacing `NSTextView` in some, ***specific*** cases. If you want a text view that can handle things like: right-to-left text, custom layout elements, or feature parity with the system text view, consider using [STTextView](https://github.com/krzyzanowskim/STTextView) or [NSTextView](https://developer.apple.com/documentation/appkit/nstextview). The `TextView` exported by this library is designed to lay out documents made up of lines of text. It also does not attempt to reason about the contents of the document. If you're looking to edit *source code* (indentation, syntax highlighting) consider using the parent library [CodeEditSourceEditor](https://github.com/CodeEditApp/CodeEditSourceEditor).

## Documentation

This package is fully documented [here](https://codeeditapp.github.io/CodeEditTextView/documentation/codeedittextview/).

## Usage

This package exports a primary `TextView` class. The `TextView` class is an `NSView` subclass that can be embedded in a scroll view or used standalone. It parses and renders lines of a document and handles mouse and keyboard events for text editing. It also renders styled strings for use cases like syntax highlighting.

```swift
import CodeEditTextView
import AppKit

class ViewController: NSViewController, TextViewDelegate {
    private var scrollView: NSScrollView!
    private var textView: TextView!
    
    var text: String = "func helloWorld() {\n\tprint(\"hello world\")\n}"
    var font: NSFont!
    var textColor: NSColor!
    
    override func loadView() {
        textView = TextView(
            string: text,
            font: font,
            textColor: textColor,
            lineHeightMultiplier: 1.0,
            wrapLines: true,
            isEditable: true,
            isSelectable: true,
            letterSpacing: 1.0,
            delegate: self
        )
        textView.translatesAutoresizingMaskIntoConstraints = false

        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.documentView = textView
        self.view = scrollView
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        textView.updateFrameIfNeeded()
    }
}
```

## Dependencies

Special thanks to [Matt Massicotte](https://bsky.app/profile/massicotte.org) for the great work he's done!

| Package | Source | Author |
| :- | :- | :- |
| `TextStory` | [GitHub](https://github.com/ChimeHQ/TextStory) | [Matt Massicotte](https://bsky.app/profile/massicotte.org) |
| `swift-collections` | [GitHub](https://github.com/apple/swift-collections.git) | [Apple](https://github.com/apple) |

## License

Licensed under the [MIT license](https://github.com/CodeEditApp/CodeEdit/blob/main/LICENSE.md).
