# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

DoopEditor is a SwiftPM monorepo with customized forks of three [CodeEdit](https://github.com/CodeEditApp) packages, vendored as dependencies for Doop:

```
DoopEditor/
├── Package.swift              # Root package manifest — source of truth
├── CodeEditTextView/          # Sources/ and Tests/ for the CodeEditTextView target
├── CodeEditLanguages/         # Sources/ and Tests/ for the CodeEditLanguages target
├── CodeEditSourceEditor/      # Sources/ and Tests/ for the CodeEditSourceEditor target
└── Example/                   # Standalone Xcode project exercising CodeEditSourceEditor
```

Each package directory is a git subtree from an upstream fork; see [UPSTREAM.md](UPSTREAM.md) for fork sources and how to pull upstream changes. Editing across package boundaries (e.g. changing a `CodeEditTextView` API and updating `CodeEditSourceEditor` to match) is just normal file edits within this repo — no package resolution or subtree workflow needed for day-to-day work.

This monorepo exists for fast cross-package iteration on Doop. It is **not** intended for upstreaming changes back to CodeEdit — some upstream docs/comments (e.g. `CodeEditLanguages`'s `Add-Languages.md`, which describes an `xcframework`-based workflow) describe a process this fork no longer uses; see below.

## Package

- Package name: `DoopEditor`
- Platforms: macOS 13+
- Swift tools version: 5.9+
- Targets: `CodeEditTextView` (+ `CodeEditTextViewObjC`), `CodeEditLanguages`, `CodeEditSourceEditor` — each an independent library target with its own test target. `CodeEditSourceEditor` depends on the other two.

### Key dependencies

- `ChimeHQ/TextStory`, `ChimeHQ/TextFormation` — text editing primitives underlying `CodeEditTextView`
- `apple/swift-collections` — used for `TextLineStorage`/`RangeStore`'s efficient rope/tree structures
- `tree-sitter/swift-tree-sitter` — tree-sitter Swift bindings (pinned to `0.10.0`)
- One SPM package per supported language grammar (`tree-sitter-swift`, `tree-sitter-rust`, etc.), depended on directly by `CodeEditLanguages` — **no xcframework**, unlike upstream CodeEditLanguages

## Building and testing

```bash
swift build              # build all targets
swift test                # run all tests
swift test --filter CodeEditLanguagesTests   # run one test target
```

The `Example/DoopEditorExample` Xcode project is useful for manually exercising `CodeEditSourceEditor` changes without pulling them into Doop first.

## Architecture

The three packages form a layered stack: `CodeEditTextView` (generic text rendering/editing) → `CodeEditLanguages` (tree-sitter grammar/query lookup) → `CodeEditSourceEditor` (SwiftUI/AppKit code editor that wires the two together with syntax highlighting).

### CodeEditTextView — text rendering engine

`TextView` (`TextView/TextView.swift`) is an `NSView` subclass conforming to `NSTextInputClient`, reading from an `NSTextStorage` (built on `TextStory`). It owns:

- `TextLayoutManager` — lays out lines, backed by `TextLineStorage<TextLine>` (a red-black tree for O(log n) line lookup/insertion), typesets fragments via `Typesetter`, and draws reusable `LineFragmentView`s through a view-reuse queue.
- `TextSelectionManager` — owns `TextSelection`s and renders cursors/highlights.
- `MarkedTextManager` — IME/marked-text ranges.
- `EmphasisManager` — bracket/range emphasis (e.g. bracket-pair highlighting).

Edit flow: a keystroke hits `TextView`, which mutates `NSTextStorage`; `TextLayoutManager` is invalidated and recomputes affected line layout; selection and marked-text state are updated in parallel by their respective managers.

### CodeEditLanguages — grammar and query lookup

`CodeLanguage` is the main public API: a struct with language metadata (id, display name, file extensions, highlight query URL), with static members per supported language (`.swift`, `.python`, etc.) and `detectLanguageFrom(url:)` for extension-based detection. `TreeSitterLanguage` maps each language id to its C tree-sitter parser function (e.g. `tree_sitter_swift()`), and each language has a `Resources/tree-sitter-{lang}/highlights.scm` query file bundled as a package resource. `TreeSitterModel.shared` lazily loads and caches compiled `Query` objects per language (parsing queries is expensive — this is why release builds matter for performance, see the docc warning).

### CodeEditSourceEditor — editor view and highlighting

`SourceEditor` (`SourceEditor/SourceEditor.swift`) is an `NSViewControllerRepresentable` — the public SwiftUI entry point — wrapping `TextViewController` (`Controller/TextViewController.swift`, an `NSViewController` embedding a `CodeEditTextView.TextView`). An AppKit-only API exists too (construct `TextViewController` directly). Configuration (`SourceEditorConfiguration`: appearance/behavior/layout, immutable, triggers `didSetOnController()` on change) is separate from `SourceEditorState` (ephemeral: cursor positions, scroll position, find panel state).

Highlighting is pluggable via the `HighlightProviding` protocol; if no custom providers are passed, `TreeSitterClient` (`TreeSitter/`) is used by default. Edit flow: `Highlighter` (`Highlighting/Highlighter.swift`) is notified of storage edits, asks each `HighlightProviding` instance for `[HighlightRange]`s over the affected range, and `StyledRangeContainer` coalesces overlapping results from multiple providers (handling priority) into a `RangeStore` — an efficient rope-backed range→style map. The `TextViewController` applies the resulting styles as `NSAttributedString` attributes, which flows back down into `CodeEditTextView`'s layout/render cycle.

`TextViewCoordinator` (see `Documentation.docc/TextViewCoordinators.md`) is the extension-point protocol for injecting custom behavior (e.g. autocomplete, combine publishers for cursor state) without threading new bindings/callbacks through `SourceEditor`'s initializer; coordinators can also conform to `CodeEditTextView`'s `TextViewDelegate` to receive low-level text change notifications.
