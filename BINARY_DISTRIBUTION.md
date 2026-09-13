# Binary distribution

DoopEditor ships prebuilt macOS XCFrameworks so that consumers don't have to clone and compile
the 40+ tree-sitter grammar packages. The grammars are statically linked into
`CodeEditLanguages.framework` and are invisible to consumers.

The source package on `main` stays the source of truth; everything here is additive, and
`swift build` / `swift test` work unchanged.

## What ships

Eleven universal (arm64 + x86_64) dynamic frameworks. The set is **discovered from the link
graph**, not hand-written: `Scripts/framework-closure.sh` walks `otool -L` out from the three
products and fails the build if anything they load at runtime wasn't built. That matters
because Xcode decides on its own whether a SwiftPM dependency is absorbed into the framework
using it or promoted to a shared dynamic framework, and that decision is not stable — see
`InternalCollectionsUtilities` below.

| Framework | Why |
|---|---|
| `CodeEditTextView`, `CodeEditLanguages`, `CodeEditSourceEditor` | the products |
| `SwiftTreeSitter` | `Query`, `Language` and `Node` are all over the public API |
| `TreeSitter` | `SwiftTreeSitter` exposes `TreeSitter.TSInputEncoding` publicly |
| `TextStory` | `TextMutation` is in the public API |
| `Internal` | `TextStory` re-exports its `TSYTextStorage` through a public typealias |
| `TextFormation` | `extension TextView: TextInterface` is a public conformance |
| `Rearrange` | in `TextStory`'s public interface |
| `CodeEditTextViewObjC` | never named in an interface, but two frameworks link it |
| `InternalCollectionsUtilities` | promoted to a shared dynamic framework by Xcode (below) |

**Absorbed** into the framework that uses them, and not shipped: the 40 tree-sitter grammars,
`DequeModule`, `ContainersPreview` (which `DequeModule` depends on) and `_RopeModule`.

`InternalCollectionsUtilities` is the awkward one. `CodeEditTextView` uses `DequeModule` and
`CodeEditSourceEditor` uses `_RopeModule`, and both of those depend on it — so Xcode absorbs it
statically when only one of our targets needs it, and promotes it to a shared dynamic framework
once both do. That is also why everything is archived **in a single pass**: archiving each
scheme separately produced frameworks that disagreed with each other about their own link
graph, and the promoted framework was silently absent from the release (SwiftPM package
products keep `SKIP_INSTALL=YES`, so it never reaches the archive and has to be picked out of
the build products). It ships binary-only: built without library evolution, it has no
`.swiftinterface`, which `-create-xcframework` rejects — and no consumer imports it, so the
unusable module is stripped and only the dylib ships.

## How the source is kept distributable

Three properties of the sources make this work, and all three are easy to break accidentally:

1. **`internal import` on implementation-detail imports.** Swift's interface printer emits an
   `import` for *every* module a source file imports, so a plain `import TreeSitterSwift` in
   `CodeLanguage.swift` would put all 40 grammar modules into the public
   `.swiftinterface` — consumers would then need every grammar package, defeating the point.
   `Scripts/check-interface-imports.sh` is a hard gate in the build against this regressing. It
   checks every shipped Swift framework's interface, the third-party ones included.
   It doesn't keep a list of forbidden modules: it forbids every module the build compiled from
   a SwiftPM package (Xcode writes a module map for each into `GeneratedModuleMaps`) that doesn't
   ship with an importable module, and it recognises `@preconcurrency`, `@_exported`,
   `public import` and `import struct X.Y` forms as well as plain imports.
   It needs the `AccessLevelOnImport` feature, enabled in `Package.swift` via
   `resilientSettings`.
2. **`SWIFT_PACKAGE_NAME = DoopEditor`.** The three modules share `package`-access
   declarations, which only resolve across the framework boundary when every framework is
   built with the same package name.
3. **`Bundle.codeEditLanguages`.** `Bundle.module` only exists under SwiftPM; in a framework
   build the `.scm` queries live in the framework's own bundle. See
   `CodeEditLanguages/Sources/CodeEditLanguages/Bundle+CodeEditLanguages.swift`.

A dependency whose types appear in public API has to be rebuilt with library evolution too —
otherwise the compiler refuses the public import. That's why the third-party frameworks above
ship rather than being absorbed. None of them needed source changes.

## Building locally

```bash
Scripts/build-xcframeworks.sh                  # -> build/xcframeworks/*.xcframework{,.zip}
Scripts/generate-binary-manifest.swift v0.9.0  # -> build/binary-package/Package.swift
Scripts/verify-binary-consumption.sh           # builds and runs each product as a consumer would
```

`build-xcframeworks.sh` resolves the package, regenerates the XcodeGen spec from
`Package.swift` and the committed `Package.resolved` -- resolving with
`--force-resolved-versions`, so the binaries are built from exactly the versions pinned there, on
any machine -- archives the whole graph in one pass from a clean build directory, checks interface
hygiene, resolves the framework closure, then packages and checksums everything. It records each
framework's direct dependencies next to its checksum, and
`Scripts/generate-binary-manifest.swift` expands those into each product's target list — a
`.binaryTarget` can't declare dependencies, so a product has to name every framework it needs,
and a hand-maintained list would go stale.

Each build starts from an empty `build/DerivedData/Build`, so a local build is as clean as CI's.
Only `build/DerivedData/SourcePackages`, Xcode's checkouts of the dependencies, is kept between
runs.

`verify-binary-consumption.sh` is the check that matters. It loads the generated `Package.swift`
exactly as it will be published, then builds and runs a throwaway executable per product against
a copy whose binary targets point at the local frameworks, each product on its own. That catches a
broken manifest, a product that doesn't list every framework it needs (a missing module fails the
build, a missing dylib fails the launch), a leaked interface import (the grammar modules aren't
there, so the build fails), and a missing resource (it compiles a tree-sitter `Query` from a `.scm`
file inside the framework bundle).

One setting deserves care: `SKIP_INSTALL` and `BUILD_LIBRARY_FOR_DISTRIBUTION` are set **per
target** in the generated spec, never on the `xcodebuild` command line. Command-line settings
also apply to the SwiftPM dependencies, and swift-collections does not compile with library
evolution enabled (`deinitializer can only be '@inlinable' if the class is
'@_fixed_layout'`). `SKIP_INSTALL` additionally has to be per-target because XcodeGen writes
`SKIP_INSTALL = YES` at target level for framework targets, which overrides the project-level
value — and an archive built with it on contains no framework to package.

Generated and not checked in: `BinaryDistribution/project.json` (written with `JSONEncoder`, which XcodeGen reads as readily as YAML),
`BinaryDistribution/DoopEditorBinary.xcodeproj`, `build/`. Checked in:
`BinaryDistribution/Support/*.h`, the umbrella headers the C and Obj-C frameworks need for
Xcode to emit a module map.

Requires [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

The release is about 48 MB of zips, 18 MB of it `CodeEditLanguages` (the grammars). The builds
are **not** bit-reproducible -- two runs of the same commit produce different checksums, since
timestamps and dSYM UUIDs end up in the archives -- so the checksums in the manifest always
come from the same build that produced the uploaded zips. Don't hand-edit one.

## CI

`.github/workflows/xcframeworks.yml` has three jobs:

- **Prepare release** runs only for a version tag push. It creates the draft release; see below.
- **Build** runs on `macos-26` with read-only permissions. It verifies the source package, builds
  the frameworks, generates the binary package, runs the consumer check against both, and uploads
  the zips and generated package as an expiring workflow artifact. If it fails, `archive.log` is
  kept as an artifact for 7 days.
- **Publish** runs only for a release. It uploads exactly the artifact Build verified, publishes the
  release, and publishes the binary package. It has the write permissions and the
  `BINARY_REPO_TOKEN` secret that Build never sees. Only one Publish runs at a time, across all
  versions, so two releases can't race each other to "Latest" or to doop-editor-binary's `main`.

Runs that only build:

- a push to any branch that changes the workflow file, anything under `Scripts/`, or
  `Package.resolved`;
- a manual run ("Run workflow") on any branch or tag.

Their artifact, `doop-editor-xcframeworks-<short sha>`, expires after 7 days, and its manifest
uses a placeholder `v0.0.0-ci.<run>` version.

### Where the time goes, and the cache

A cold build takes about 45 minutes, and almost none of it is compiling. Measured on
`macos-26`: roughly 19 minutes fetching the 44 dependency repositories -- the tree-sitter
grammars carry large generated parsers, so their git histories are big -- about 10 minutes
creating SwiftPM's 6.7 GB of working copies, and most of the 13-minute `xcodebuild archive`
creating Xcode's own copy of the grammar checkouts. `swift build`, `swift test` and the archive's
actual compilation are a few minutes between them.

The build job caches SwiftPM's repository mirrors (`~/Library/Caches/org.swift.swiftpm`,
~2.7 GB), keyed on `Package.resolved`. The cache only removes the fetch, and only because
`Package.resolved` is committed and the build uses `--force-resolved-versions`. Without pinned
versions SwiftPM updates every mirror from its remote during resolution: a fully warm cache still
took 25 minutes locally, against 7.7 minutes with pinned versions, where all 44 packages came
from the mirrors in 2 seconds. The working copies are unavoidable.

`.build` and Xcode's `DerivedData` are deliberately not cached. Released frameworks should come
from a clean build rather than whatever a previous run left behind, and at 6.7 GB of checkouts
each they would take most of the repository's 10 GB cache allowance.

What a run can restore is limited by GitHub's cache scoping: a run sees caches from its own
branch or tag and from the default branch. Repeated pushes to a branch reuse that branch's cache.
A release tag can only use one saved on `main`. That happens when a build on `main` misses the
cache -- including every push to `main` that changes `Package.resolved`, which saves the cache under
the new key before a release needs it. Entries unused for 7 days are evicted, though, so a release
after a quiet spell builds cold. That's slower, not wrong. Release runs don't save the cache, since a cache
saved on a tag is visible to that tag alone.

## Releasing

Releases are only created from version tags. Push an annotated `vX.Y.Z` tag; its message becomes
the release notes:

```bash
git tag -a --cleanup=verbatim v0.9.0 -m "v0.9.0" -m "## Changes" -m "- What changed"
git push origin v0.9.0
```

Keep `--cleanup=verbatim` if the notes use Markdown headings. By default git deletes every line of a
tag message that starts with `#`, even one given with `-m`, and the heading is lost before the
workflow ever sees it. (Don't combine it with an editor-written message: verbatim also keeps git's
own `#` instruction lines. Use `-m` or `-F notes.md`.)

Don't create the release by hand. This repository has **immutable releases** enabled: once a
release is published its assets can't be added or changed, so the workflow assembles the release
as a draft and publishes it only when it's complete.

1. **Prepare release**: if the tag already has a *published* release, the run stops and does
   nothing further -- with a warning if that release has XCFrameworks but doop-editor-binary has no
   tag for it, since that version is half-published. If doop-editor-binary already has the tag
   while this repository has no published release, it fails: that's out of step and needs a person
   to look. Otherwise it creates a draft titled with the tag, with the tag message's body
   as notes (`Scripts/tag-release-notes.sh`). If the tag has no usable message -- a lightweight tag,
   or a message that's only the version -- it uses GitHub's generated notes instead. `-rc.1` style
   tags become prereleases. A draft left behind by an earlier attempt is reused as-is, including
   any notes edited on it.
2. **Build** builds and verifies the frameworks.
3. **Publish** uploads the zips to the draft, checks that the release's assets are exactly the
   build's (`Scripts/verify-release-assets.sh` compares GitHub's SHA-256 digests with the
   checksums), and publishes it. Only the newest stable version is marked "Latest", so a patch to
   an older version or a prerelease doesn't take that from the current release.
4. **Publish** then commits the generated `Package.swift` and README to
   [doop-editor-binary](https://github.com/matiaskorhonen/doop-editor-binary) and tags it with the
   same version (`Scripts/publish-binary-package.sh`). That repository's `main` only moves to the
   newest stable version; an older patch or a prerelease gets just its tag. "Newest stable" means
   the same thing in both places: `Scripts/newest-stable-version.sh`.

The release notes can be edited on the draft while the build runs, or on the published release
afterwards -- notes stay editable on an immutable release; only its assets and tag are fixed.

The prebuilt package lives in a separate repository rather than on a branch here, so each
repository has exactly one tag per version. SwiftPM strips a leading `v` when it reads tags, so
a `v0.9.0` and a `0.9.0` in the same repository are two tags for one version -- and it silently
resolves whichever it prefers rather than reporting the ambiguity.

The release is published before the binary package because the manifest's download URLs have to
resolve by the time a consumer can see the version, and a draft's assets can't be downloaded
anonymously.

### When something fails

- **Build fails** and the draft stays. How to retry depends on the cause:
  - *Something transient* (a network error, a flaky runner): use "Re-run all jobs". Prepare finds
    the draft and reuses it.
  - *A problem in the source or the scripts*: a re-run won't help, since re-runs always build the
    commit the run started with. Commit the fix, then move the tag to it -- only a published release
    fixes its tag, so the draft doesn't stand in the way:

    ```bash
    git tag -f -a --cleanup=verbatim v0.9.0 -m "v0.9.0" -m "- What changed"
    git push --force origin v0.9.0
    ```

    The new run reuses the draft, *including its notes*, which still come from the first tag's
    message. Edit them on the draft if they changed, or delete the draft before pushing the tag
    again to have them taken from the new message.
- **Publish fails**: use "Re-run failed jobs". It reuses the same artifact, kept 30 days for this,
  so nothing is rebuilt. If the release was already published by the failed attempt, the re-run
  checks that its assets match the artifact and carries on to doop-editor-binary. If even the push
  to doop-editor-binary had landed, the re-run finds the same manifest there and finishes. The usual cause is
  an expired `BINARY_REPO_TOKEN` -- a fine-grained token with **Contents: Read and write** on
  `doop-editor-binary` alone, since the workflow's own `GITHUB_TOKEN` can only write to this
  repository. Renew it, then re-run.
- **Publish is cancelled** while waiting: GitHub keeps only one Publish waiting at a time, so a
  third release pushed at the same moment cancels the waiting one. "Re-run failed jobs" on that run
  publishes it.
- Don't use "Re-run all jobs" once the release is published: Prepare sees the published release and
  stops, as it does for any published release, so the binary package would never be pushed.

### Rehearsing locally

To rehearse a release without pushing anywhere:

```bash
Scripts/build-xcframeworks.sh v0.9.0
Scripts/generate-binary-manifest.swift v0.9.0
Scripts/verify-binary-consumption.sh
git init --bare /tmp/doop-editor-binary.git
Scripts/publish-binary-package.sh v0.9.0 /tmp/doop-editor-binary.git
```
