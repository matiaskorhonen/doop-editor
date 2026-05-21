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

## Notes

- `CodeEditLanguages` uses direct SPM tree-sitter grammar dependencies — the old `CodeLanguagesContainer.xcframework.zip` is not used.
- The root `Package.swift` is the source of truth for the package graph. Each subtree may contain its own `Package.swift` from the upstream fork, which is kept in place to ease future subtree pulls but is not used during normal monorepo development.
- This monorepo is optimized for Doop development and is not intended for clean upstream contribution.
