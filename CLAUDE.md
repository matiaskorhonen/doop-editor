# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

DoopEditor is a SwiftPM package built from customized forks of three [CodeEdit](https://github.com/CodeEditApp) packages, vendored for Doop:

```
DoopEditor/
├── Package.swift                       # the manifest — source of truth
├── Sources/
│   ├── DoopEditor/                     # the module
│   │   ├── CodeEditTextView/           # text rendering and editing
│   │   ├── CodeEditLanguages/          # tree-sitter grammars and queries
│   │   ├── CodeEditSourceEditor/       # the editor view
│   │   └── Documentation.docc/
│   └── CodeEditTextViewObjC/           # Obj-C shim for one private CoreGraphics call
├── Tests/DoopEditorTests/              # one test target, same three directories
└── Example/                            # standalone Xcode project exercising the editor
```

The three directories under `Sources/DoopEditor` were once three separate modules. **They are one module now** — there is no boundary between them, nothing to import, and no `package` access level. Keep the directories as they are: they are how the code stays navigable, and they keep diffs against the upstream forks readable.

The forks were git subtrees. They are **severed**: imported once in May 2026, never pulled, and the directory prefixes `git subtree pull` needs no longer exist. See [UPSTREAM.md](UPSTREAM.md). Some upstream docs and comments describe processes this fork no longer uses (e.g. `Documentation.docc/Add-Languages.md`, which describes an `xcframework`-based workflow).

## Package

- Package name: `DoopEditor`
- Platforms: macOS 13+
- Swift tools version: 5.9+
- One library product, `DoopEditor`, from one target of the same name (plus the `CodeEditTextViewObjC` target it absorbs), with one test target.

### Key dependencies

- `ChimeHQ/TextStory`, `ChimeHQ/TextFormation` — text editing primitives
- `apple/swift-collections` — `_RopeModule`, for `RangeStore`'s rope
- `tree-sitter/swift-tree-sitter` — tree-sitter Swift bindings (pinned to `0.10.0`)
- One SPM package per supported language grammar (`tree-sitter-swift`, `tree-sitter-rust`, etc.) — **no xcframework**, unlike upstream CodeEditLanguages

None of these may appear in the public API. See below.

## Building and testing

```bash
swift build      # build the module
swift test       # run all tests (245 XCTest + 107 swift-testing cases)
```

`Package.resolved` is committed. The XCFramework build and its CI resolve with
`--force-resolved-versions`, so after changing a dependency in `Package.swift`, run
`swift package resolve` (or `swift package update`) and commit the updated `Package.resolved`
alongside it.

Scripts in this repo are shell scripts or Swift scripts (`#!/usr/bin/env swift`) -- never Python or other languages. Keep shell scripts compatible with macOS's bash 3.2 (no associative arrays).

The `Example/DoopEditorExample` Xcode project is useful for manually exercising changes without pulling them into Doop first.

## Binary distribution

`Scripts/build-xcframeworks.sh` builds the module as **one** universal macOS XCFramework for
release, statically absorbing every dependency — the 36 grammars, TextStory, TextFormation,
SwiftTreeSitter, TreeSitter and the rest. See [BINARY_DISTRIBUTION.md](BINARY_DISTRIBUTION.md).

Three things in the sources exist for that pipeline and are easy to break by accident:

- **`internal import`** on every third-party import — the grammars, `SwiftTreeSitter`,
  `TreeSitter`, `TextStory`, `TextFormation`, `_RopeModule`, `CodeEditTextViewObjC`. Swift's
  interface printer emits an `import` for every module a file imports, used publicly or not, so a
  plain `import` puts the module into the public `.swiftinterface` and forces consumers of the
  binary to resolve it. Adding a grammar means adding an `internal import` in `CodeLanguage.swift`.
  `Scripts/check-interface-imports.sh` gates this. The `AccessLevelOnImport` feature it needs
  is enabled by `resilientSettings` in `Package.swift`.
- **No public API naming a third-party type**, which `internal import` does not prevent on its own.
  A public signature mentioning one puts the module back into the interface, and so does a public
  conformance of a public type to a third-party protocol — a conformance can't be made internal, so
  wrap it instead (`TextViewTextInterface` carries TextFormation's `TextInterface` so `TextView`
  doesn't; `CodeLanguage.isHighlightable` reports what a `SwiftTreeSitter.Query` would have).
  This is the constraint that lets the release be a single framework: keep it and it stays one.
- **`Bundle.codeEditLanguages`**, not `Bundle.module`, for the `.scm` query lookup —
  `Bundle.module` doesn't exist in a framework build.

## Architecture

The module is a layered stack, one directory per layer: `CodeEditTextView/` (generic text rendering/editing) → `CodeEditLanguages/` (tree-sitter grammar/query lookup) → `CodeEditSourceEditor/` (SwiftUI/AppKit code editor that wires the two together with syntax highlighting). The layering is a convention now, not a compiler-enforced boundary.

### CodeEditTextView/ — text rendering engine

`TextView` (`TextView/TextView.swift`) is an `NSView` subclass conforming to `NSTextInputClient`, reading from an `NSTextStorage` (built on `TextStory`). It owns:

- `TextLayoutManager` — lays out lines, backed by `TextLineStorage<TextLine>` (a red-black tree for O(log n) line lookup/insertion), typesets fragments via `Typesetter`, and draws reusable `LineFragmentView`s through a view-reuse queue.
- `TextSelectionManager` — owns `TextSelection`s and renders cursors/highlights.
- `MarkedTextManager` — IME/marked-text ranges.
- `EmphasisManager` — bracket/range emphasis (e.g. bracket-pair highlighting).

Edit flow: a keystroke hits `TextView`, which mutates `NSTextStorage`; `TextLayoutManager` is invalidated and recomputes affected line layout; selection and marked-text state are updated in parallel by their respective managers.

### CodeEditLanguages/ — grammar and query lookup

`CodeLanguage` is the main public API: a struct with language metadata (id, display name, file extensions, highlight query URL), with static members per supported language (`.swift`, `.python`, etc.) and `detectLanguageFrom(url:)` for extension-based detection. `TreeSitterLanguage` maps each language id to its C tree-sitter parser function (e.g. `tree_sitter_swift()`), and each language has a `Resources/tree-sitter-{lang}/highlights.scm` query file bundled as a package resource. `TreeSitterModel.shared` lazily loads and caches compiled `Query` objects per language; parsing a query is expensive, which is why release builds matter for performance (see the docc warning). That API is internal, since `Query` is a `SwiftTreeSitter` type — `CodeLanguage.isHighlightable` is the public way to ask whether a language has a working grammar and query.

### CodeEditSourceEditor/ — editor view and highlighting

`SourceEditor` (`SourceEditor/SourceEditor.swift`) is an `NSViewControllerRepresentable` — the public SwiftUI entry point — wrapping `TextViewController` (`Controller/TextViewController.swift`, an `NSViewController` embedding a `TextView`). An AppKit-only API exists too (construct `TextViewController` directly). Configuration (`SourceEditorConfiguration`: appearance/behavior/layout, immutable, triggers `didSetOnController()` on change) is separate from `SourceEditorState` (ephemeral: cursor positions, scroll position, find panel state).

Highlighting is pluggable via the `HighlightProviding` protocol; if no custom providers are passed, `TreeSitterClient` (`TreeSitter/`) is used by default. Edit flow: `Highlighter` (`Highlighting/Highlighter.swift`) is notified of storage edits, asks each `HighlightProviding` instance for `[HighlightRange]`s over the affected range, and `StyledRangeContainer` coalesces overlapping results from multiple providers (handling priority) into a `RangeStore` — an efficient rope-backed range→style map. The `TextViewController` applies the resulting styles as `NSAttributedString` attributes, which flows back down into the layout/render cycle.

`TextViewCoordinator` (see `Documentation.docc/TextViewCoordinators.md`) is the extension-point protocol for injecting custom behavior (e.g. autocomplete, combine publishers for cursor state) without threading new bindings/callbacks through `SourceEditor`'s initializer; coordinators can also conform to `TextViewDelegate` to receive low-level text change notifications.
