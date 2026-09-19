# ``DoopEditor``

An Xcode-inspired code editor view, with syntax highlighting powered by tree-sitter.

## Overview

![logo](codeeditsourceeditor-logo)

DoopEditor is a customised fork of three [CodeEdit](https://github.com/CodeEditApp) packages —
`CodeEditTextView`, `CodeEditLanguages` and `CodeEditSourceEditor` — combined into a single module.
It is built for [Doop](https://github.com/matiaskorhonen/doop) and is not intended for upstream
contribution.

![banner](preview)

The module is a layered stack:

- **Text rendering and editing.** ``TextView`` is an `NSView` subclass that lays out and edits lines
  of a document without reasoning about their contents. It handles extremely fast initial layout and
  large documents, and renders styled strings for uses like syntax highlighting.
- **Grammars and queries.** ``CodeLanguage`` serves one tree-sitter grammar per supported language,
  with its highlight queries. Each grammar is a SwiftPM package dependency — there is no
  `xcframework`.
- **The editor.** ``SourceEditor`` (SwiftUI) and ``TextViewController`` (AppKit) wire the two
  together, adding syntax highlighting, indentation, find and replace, bracket matching and more.

Only this module is public. `SwiftTreeSitter`, `TextStory` and `TextFormation` are implementation
details and appear nowhere in the public API, which is what lets the binary distribution ship a
single XCFramework. See `BINARY_DISTRIBUTION.md` in the repository.

## Dependencies

Special thanks to [Matt Massicotte](https://bsky.app/profile/massicotte.org) for the great work he's
done on [SwiftTreeSitter](https://github.com/tree-sitter/swift-tree-sitter), which this module is
built on.

## Topics

### Editor

- <doc:SourceEditorView>
- ``SourceEditor``
- ``SourceEditorConfiguration``
- ``SourceEditorState``
- ``TextViewController``
- ``GutterView``
- ``EditorTheme``
- ``CursorPosition``

### Text Coordinators

- <doc:TextViewCoordinators>
- ``TextViewCoordinator``
- ``CombineCoordinator``

### Languages

- <doc:Add-Languages>
- <doc:Update-Languages>
- ``CodeLanguage``
- ``TreeSitterLanguage``
- ``TreeSitterModel``

### Text View

- ``TextView``
- ``CEUndoManager``

### Text Layout

- ``TextLayoutManager``
- ``TextLine``
- ``LineFragment``

### Text Selection

- ``TextSelectionManager``
- ``TextSelectionManager/TextSelection``
- ``CursorView``

### Supporting Types

- ``TextLineStorage``
- ``HorizontalEdgeInsets``
- ``LineEnding``
- ``LineBreakStrategy``
