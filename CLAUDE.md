# DoopEditor monorepo

A SwiftPM monorepo with customized forks of [CodeEdit](https://github.com/CodeEditApp) components, used as dependencies for Doop.

## Repository structure

```
DoopEditor/
├── Package.swift              # Root package manifest — source of truth
├── CodeEditSourceEditor/      # Sources/ and Tests/ for the CodeEditSourceEditor target
├── CodeEditTextView/          # Sources/ and Tests/ for the CodeEditTextView target
├── CodeEditLanguages/         # Sources/ and Tests/ for the CodeEditLanguages target
└── Example/                    # Standalone Xcode project exercising CodeEditSourceEditor
```

Each package directory is a git subtree from an upstream fork; see [UPSTREAM.md](UPSTREAM.md) for fork sources and how to pull upstream changes. Editing across package boundaries (e.g. changing a `CodeEditTextView` API and updating `CodeEditSourceEditor` to match) is just normal file edits within this repo — no package resolution or subtree workflow needed for day-to-day work.

## Package

- Package name: `DoopEditor`
- Platforms: macOS 13+
- Swift tools version: 5.9+
- Products/targets: `CodeEditSourceEditor` (depends on `CodeEditTextView` + `CodeEditLanguages`), `CodeEditTextView`, `CodeEditLanguages` — each is an independent library target with its own test target

## Key dependencies

- `ChimeHQ/TextStory`, `ChimeHQ/TextFormation` — text editing primitives
- `apple/swift-collections` — data structures
- `tree-sitter/swift-tree-sitter` — tree-sitter Swift bindings (pinned to `0.10.0`)
- Many tree-sitter grammar packages under `CodeEditLanguages`, added directly as SPM dependencies (no xcframework)

## Building and testing

```bash
swift build              # build all targets
swift test                # run all tests
swift test --filter CodeEditLanguagesTests   # run one test target
```

The `Example/DoopEditorExample` Xcode project is useful for manually exercising `CodeEditSourceEditor` changes without pulling them into Doop first.

## Development notes

- This monorepo exists for fast cross-package iteration on Doop. It is **not** intended for upstreaming changes back to CodeEdit.
