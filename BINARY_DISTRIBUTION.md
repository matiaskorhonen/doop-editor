# Binary distribution

DoopEditor ships prebuilt macOS XCFrameworks so that consumers don't have to clone and compile
the 40+ tree-sitter grammar packages. The grammars are statically linked into
`CodeEditLanguages.framework` and are invisible to consumers.

The source package on `main` stays the source of truth; everything here is additive, and
`swift build` / `swift test` work unchanged.

## What ships

Eleven universal (arm64 + x86_64) dynamic frameworks. The set is **discovered from the link
graph**, not hand-written: `Scripts/framework-closure.py` walks `otool -L` out from the three
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
`DequeModule` and `_RopeModule`.

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
   `Scripts/check-interface-imports.sh` is a hard gate in the build against this regressing.
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
Scripts/build-xcframeworks.sh            # -> build/xcframeworks/*.xcframework{,.zip}
Scripts/verify-binary-consumption.sh     # builds and runs a throwaway consumer package
```

`build-xcframeworks.sh` resolves the package, regenerates the XcodeGen spec from
`Package.swift` and `Package.resolved` (so the binaries are pinned to the same grammar
revisions as the source build), archives the whole graph in one pass, checks interface hygiene,
resolves the framework closure, then packages and checksums everything. It records each
framework's direct dependencies next to its checksum, and
`Scripts/generate-binary-manifest.py` expands those into each product's target list — a
`.binaryTarget` can't declare dependencies, so a product has to name every framework it needs,
and a hand-maintained list would go stale.

`verify-binary-consumption.sh` is the check that matters: it builds a throwaway package
depending *only* on the XCFrameworks and runs it, which catches both a leaked interface import
(the grammar modules aren't there, so resolution fails) and a missing runtime dependency or
resource (it compiles a tree-sitter `Query` from a `.scm` file inside the framework bundle).

One setting deserves care: `SKIP_INSTALL` and `BUILD_LIBRARY_FOR_DISTRIBUTION` are set **per
target** in the generated spec, never on the `xcodebuild` command line. Command-line settings
also apply to the SwiftPM dependencies, and swift-collections does not compile with library
evolution enabled (`deinitializer can only be '@inlinable' if the class is
'@_fixed_layout'`). `SKIP_INSTALL` additionally has to be per-target because XcodeGen writes
`SKIP_INSTALL = YES` at target level for framework targets, which overrides the project-level
value — and an archive built with it on contains no framework to package.

Generated and not checked in: `BinaryDistribution/project.yml`,
`BinaryDistribution/DoopEditorBinary.xcodeproj`, `build/`. Checked in:
`BinaryDistribution/Support/*.h`, the umbrella headers the C and Obj-C frameworks need for
Xcode to emit a module map.

Requires [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

The release is about 48 MB of zips, 18 MB of it `CodeEditLanguages` (the grammars). The builds
are **not** bit-reproducible -- two runs of the same commit produce different checksums, since
timestamps and dSYM UUIDs end up in the archives -- so the checksums in the manifest always
come from the same build that produced the uploaded zips. Don't hand-edit one.

## CI

`.github/workflows/release-binary.yml` has two jobs. **build** runs on `macos-26` with read-only
permissions: it verifies the source package, builds the frameworks, runs the consumer check,
generates the binary package, and uploads the zips and generated package as an expiring workflow
artifact. **publish** runs only for a release, with the write permissions and the
`BINARY_REPO_TOKEN` secret the build job never sees, and publishes exactly the artifact that
build verified.

Runs that don't publish:

- a push to any branch that changes the workflow file;
- a manual run ("Run workflow") with the version left empty, which builds the chosen branch.

Their artifact, `doop-editor-xcframeworks-<short sha>`, expires after 7 days, and its manifest
uses a placeholder `v0.0.0-ci.<run>` version.

## Releasing

Create the release as usual -- for example `gh release create v0.9.0 --notes "..."`, or push a
`vX.Y.Z` tag. A manual run with the version filled in does the same for an existing tag. Then:

1. **build** refuses to start if that version is already published to `doop-editor-binary`,
   then builds and verifies as above;
2. **publish** attaches the zips to the release in this repository -- into your existing release
   if there is one, leaving its notes alone, otherwise creating it with generated notes;
3. **publish** commits the generated `Package.swift` and README to
   [doop-editor-binary](https://github.com/matiaskorhonen/doop-editor-binary) and tags it with
   the same version, pushing the commit and tag atomically
   (`Scripts/publish-binary-package.sh`).

The prebuilt package lives in a separate repository rather than on a branch here, so each
repository has exactly one tag per version. SwiftPM strips a leading `v` when it reads tags, so
a `v0.9.0` and a `0.9.0` in the same repository are two tags for one version -- and it silently
resolves whichever it prefers rather than reporting the ambiguity.

The zips are uploaded before the tag is published because the manifest's download URLs have
to resolve by the time a consumer can see the version. A published version is never rebuilt:
its manifest pins the checksums of zips consumers have already resolved, and rebuilds don't
reproduce them.

If **publish** fails, use "Re-run failed jobs": it republishes the same artifact without
rebuilding, so the checksums still match. A release run's artifact is kept for 30 days for this.
The usual cause is an expired `BINARY_REPO_TOKEN` -- a fine-grained token with **Contents: Read
and write** on `doop-editor-binary` alone, since the workflow's own `GITHUB_TOKEN` can only write
to this repository. Renew it, then re-run.

To rehearse a release locally without pushing anywhere:

```bash
Scripts/build-xcframeworks.sh v0.9.0
Scripts/verify-binary-consumption.sh
Scripts/generate-binary-manifest.py v0.9.0
git init --bare /tmp/doop-editor-binary.git
Scripts/publish-binary-package.sh v0.9.0 /tmp/doop-editor-binary.git
```
