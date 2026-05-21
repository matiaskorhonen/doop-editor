# DoopEditor monorepo

A SwiftPM monorepo with customized forks of CodeEdit components, used as dependencies for Doop.

## Repository structure

```
DoopEditor/
├── Package.swift              # Root package manifest — source of truth
├── CodeEditSourceEditor/      # git subtree from matiaskorhonen/CodeEditSourceEditor@custom
├── CodeEditTextView/          # git subtree from matiaskorhonen/CodeEditTextView@custom
└── CodeEditLanguages/         # git subtree from matiaskorhonen/CodeEditLanguages@custom
```

Each subdirectory contains the full imported history from its upstream fork. Each may have its own `Package.swift` left over from the fork — ignore it; only the root `Package.swift` matters.

## Package

- Package name: `DoopEditor`
- Platforms: macOS 13+
- Swift tools version: 5.9+
- Products: `CodeEditSourceEditor`, `CodeEditTextView`, `CodeEditLanguages` libraries

## Key dependencies

- `ChimeHQ/TextStory`, `ChimeHQ/TextFormation` — text editing primitives
- `apple/swift-collections` — data structures
- `tree-sitter/swift-tree-sitter` — tree-sitter Swift bindings (pinned to `0.10.0`)
- Many tree-sitter grammar packages under `CodeEditLanguages`
- `CodeEditLanguages` uses **direct SPM grammar dependencies** — no xcframework

## Working with git subtrees

Pull changes from an upstream fork branch:

```bash
git subtree pull --prefix=CodeEditSourceEditor \
  https://github.com/matiaskorhonen/CodeEditSourceEditor.git custom

git subtree pull --prefix=CodeEditTextView \
  https://github.com/matiaskorhonen/CodeEditTextView.git custom

git subtree pull --prefix=CodeEditLanguages \
  https://github.com/matiaskorhonen/CodeEditLanguages.git custom
```

Changes made inside a subtree directory are regular commits in this repo — no special workflow needed for day-to-day edits.

## Development notes

- This monorepo exists for fast cross-package iteration on Doop. It is **not** intended for upstreaming changes back to CodeEdit.
- The `custom` branches on all three forks are the canonical sources. `CodeEditLanguages/custom` has the `spm-direct-dependencies` changes already merged in.
- Editing across package boundaries (e.g. changing a `CodeEditTextView` API and updating `CodeEditSourceEditor` to match) is done with normal file edits — no package resolution needed.
