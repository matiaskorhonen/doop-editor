# DoopEditor

A SwiftPM monorepo containing customized forks of the [CodeEdit](https://github.com/CodeEditApp) editor components, used by [Doop](https://github.com/matiaskorhonen/doop).

## Structure

```
DoopEditor/
├── Package.swift              # Root package manifest (source of truth)
├── CodeEditSourceEditor/      # Fork of CodeEditSourceEditor
│   ├── Sources/
│   └── Tests/
├── CodeEditTextView/          # Fork of CodeEditTextView
│   ├── Sources/
│   └── Tests/
└── CodeEditLanguages/         # Fork of CodeEditLanguages
    ├── Sources/
    └── Tests/
```

Each subdirectory is a git subtree. See [UPSTREAM.md](UPSTREAM.md) for the exact upstream sources, branches, and how to bootstrap or update the subtrees.

## Requirements

- macOS 13+
- Swift 5.9+
- Xcode 15+

## Usage

Add DoopEditor as a SwiftPM dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/matiaskorhonen/doop-editor.git", branch: "main"),
],
```

Then add the products you need to your target:

```swift
.target(
    name: "MyTarget",
    dependencies: [
        .product(name: "CodeEditSourceEditor", package: "doop-editor"),
        // Optionally also:
        // .product(name: "CodeEditTextView", package: "doop-editor"),
        // .product(name: "CodeEditLanguages", package: "doop-editor"),
    ]
),
```

`CodeEditSourceEditor` is the top-level component and pulls in `CodeEditTextView` and `CodeEditLanguages` transitively. Depend on the lower-level libraries directly only if you need them without the editor.

### Prebuilt binaries

Resolving the source package clones and compiles 40+ tree-sitter grammar repositories, which
dominates a clean build. Prebuilt XCFrameworks avoid that: the grammars are statically linked
into `CodeEditLanguages`, so consumers resolve a handful of artifacts instead.

The prebuilt manifest lives on the [`binary`](https://github.com/matiaskorhonen/doop-editor/tree/binary)
branch and is what version tags point at:

```swift
dependencies: [
    .package(url: "https://github.com/matiaskorhonen/doop-editor.git", from: "0.1.0"),
],
```

Product names are identical to the source package, so switching between the two needs no other
changes. See [BINARY_DISTRIBUTION.md](BINARY_DISTRIBUTION.md) for how the frameworks are built
and released.

## Example app

The `Example/` directory contains a standalone Xcode project (`DoopEditorExample`) that exercises `CodeEditSourceEditor` directly, useful for manually testing changes without pulling them into Doop first.

## License

Each vendored package retains its original MIT license. See [LICENSE.md](LICENSE.md) for the full text of each.

## Notes

- The root `Package.swift` is the source of truth for the package graph.
- This monorepo is optimized for Doop development and is not intended for clean upstream contribution.
