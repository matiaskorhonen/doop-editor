# DoopEditor

A code editor for macOS, built from customized forks of the
[CodeEdit](https://github.com/CodeEditApp) editor components and used by
[Doop](https://github.com/matiaskorhonen/doop). It is a single module, `DoopEditor`.

See [UPSTREAM.md](UPSTREAM.md) for where the code came from, and
[BINARY_DISTRIBUTION.md](BINARY_DISTRIBUTION.md) for how it is released as a prebuilt XCFramework.

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

The three directories under `Sources/DoopEditor` divide the module by layer, and each corresponds
to one of the upstream CodeEdit packages -- which keeps diffs against the forks readable. They are
one module: there is no boundary between them and nothing to import.

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

MIT. The root [LICENSE](LICENSE) is the upstream CodeEdit licence, and covers all three original
packages.

[THIRD-PARTY-LICENSES.md](THIRD-PARTY-LICENSES.md) carries the licences of everything this
repository redistributes: the tree-sitter highlight queries bundled as resources, copied from the
grammar repositories and from nvim-treesitter, and — in the prebuilt XCFramework, which links them
statically — every dependency. Regenerate it with `Scripts/generate-licenses.swift` after changing
a dependency; `Scripts/build-xcframeworks.sh` fails if it doesn't match `Package.resolved`.

## Notes

- `Package.swift` is the source of truth for the package graph.
- This repository is optimized for Doop development and is not intended for upstream contribution.
