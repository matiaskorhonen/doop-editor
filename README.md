# DoopEditor

A SwiftPM monorepo containing customized forks of the CodeEdit editor components used by [Doop](https://github.com/matiaskorhonen/doop).

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

Each subdirectory is a git subtree imported from its respective fork's `custom` branch.

## Upstream forks

| Subtree | Source | Branch |
|---|---|---|
| `CodeEditSourceEditor/` | `matiaskorhonen/CodeEditSourceEditor` | `custom` |
| `CodeEditTextView/` | `matiaskorhonen/CodeEditTextView` | `custom` |
| `CodeEditLanguages/` | `matiaskorhonen/CodeEditLanguages` | `custom` |

## Bootstrapping

### Import the subtrees

```bash
git subtree add --prefix=CodeEditSourceEditor \
  https://github.com/matiaskorhonen/CodeEditSourceEditor.git custom

git subtree add --prefix=CodeEditTextView \
  https://github.com/matiaskorhonen/CodeEditTextView.git custom

git subtree add --prefix=CodeEditLanguages \
  https://github.com/matiaskorhonen/CodeEditLanguages.git custom
```

### Pull upstream changes

```bash
git subtree pull --prefix=CodeEditSourceEditor \
  https://github.com/matiaskorhonen/CodeEditSourceEditor.git custom

git subtree pull --prefix=CodeEditTextView \
  https://github.com/matiaskorhonen/CodeEditTextView.git custom

git subtree pull --prefix=CodeEditLanguages \
  https://github.com/matiaskorhonen/CodeEditLanguages.git custom
```

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

## Notes

- The root `Package.swift` is the source of truth for the package graph.
- This monorepo is optimized for Doop development and is not intended for clean upstream contribution.
