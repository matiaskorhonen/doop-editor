# DoopEditor

A code editor for macOS, built from customized forks of the
[CodeEdit](https://github.com/CodeEditApp) editor components and used by
[Doop](https://github.com/matiaskorhonen/doop).

It was three packages — `CodeEditTextView`, `CodeEditLanguages` and `CodeEditSourceEditor` — and is
now a single `DoopEditor` module. See [UPSTREAM.md](UPSTREAM.md) for where the code came from, and
[BINARY_DISTRIBUTION.md](BINARY_DISTRIBUTION.md) for why it was merged.

## Structure

```
DoopEditor/
├── Package.swift                          # the package manifest
├── Sources/
│   ├── DoopEditor/                        # the module
│   │   ├── CodeEditTextView/              # text rendering and editing
│   │   ├── CodeEditLanguages/             # tree-sitter grammars and queries
│   │   ├── CodeEditSourceEditor/          # the editor view
│   │   └── Documentation.docc/
│   └── CodeEditTextViewObjC/              # a small Obj-C shim
├── Tests/DoopEditorTests/
└── Example/                               # a standalone Xcode project
```

The three directories under `Sources/DoopEditor` are the former packages, kept apart for
readability. They are one module: there is no boundary between them and nothing to import.

## Requirements

- macOS 13+
- Swift 5.9+
- Xcode 15+

## Usage

```swift
dependencies: [
    .package(url: "https://github.com/matiaskorhonen/doop-editor.git", branch: "main"),
],
```

```swift
.target(
    name: "MyTarget",
    dependencies: [
        .product(name: "DoopEditor", package: "doop-editor"),
    ]
),
```

```swift
import DoopEditor
```

`SwiftTreeSitter`, `TextStory` and `TextFormation` are implementation details and appear nowhere in
the public API, so consumers never resolve or import them.

### Prebuilt binaries

Resolving the source package clones and compiles 40+ tree-sitter grammar repositories, which
dominates a clean build. A prebuilt XCFramework avoids that: the grammars are statically linked in,
so consumers resolve one artifact instead.

The prebuilt package lives in its own repository,
[doop-editor-binary](https://github.com/matiaskorhonen/doop-editor-binary), with a tag for every
release of this one:

```swift
dependencies: [
    .package(url: "https://github.com/matiaskorhonen/doop-editor-binary.git", from: "0.9.0"),
],
```

The product is the same, but SwiftPM names a package after its repository, so the product reference
uses `package: "doop-editor-binary"` instead of `package: "doop-editor"`. See
[BINARY_DISTRIBUTION.md](BINARY_DISTRIBUTION.md) for how the framework is built and released.

## Example app

`Example/` contains a standalone Xcode project (`DoopEditorExample`) that exercises the editor
directly, useful for manually testing changes without pulling them into Doop first.

## License

MIT. The root [LICENSE](LICENSE) covers all three original packages; their own licence files are
preserved in [Licenses/](Licenses/).

## Notes

- `Package.swift` is the source of truth for the package graph.
- This repository is optimized for Doop development and is not intended for upstream contribution.
