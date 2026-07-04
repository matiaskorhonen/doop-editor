# Add Languages

This article explains how to add support for a new language to ``CodeLanguage``.

## Overview

This fork depends directly on a SwiftPM grammar package per `tree-sitter` language — there is no `xcframework` build step.

> Note: If you want to update an existing language's grammar version instead, see <doc:Update-Languages>.

## Find or create a grammar package

You need a SwiftPM-compatible `tree-sitter` grammar package: one with a `Package.swift` exposing a `TreeSitter{Lang}` library product built from `src/parser.c` (and `src/scanner.c`/`.cc` if the grammar has an external scanner). Many `tree-sitter-{lang}` repositories already have one; check for a `Package.swift` at the root or on a branch such as `spm` before writing your own.

## Add the dependency

1. Add the grammar package to the `dependencies` array in the root `Package.swift`:

    ```swift
    .package(url: "https://github.com/tree-sitter/tree-sitter-{lang}.git", exact: "X.Y.Z"),
    ```

    Prefer an `exact` version pin; fall back to `revision:` (with a trailing comment naming the branch) only if no tagged release works for this package. Check `CodeEditLanguages/README.md`'s "Grammar Version Upgrade Blockers" section for known issues (e.g. some grammars' `FileManager`-based scanner detection breaks when consumed as an SPM dependency) before picking a version.

2. Add the product dependency and a resource copy to the `CodeEditLanguages` target, keeping both lists alphabetical:

    ```swift
    .product(name: "TreeSitter{Lang}", package: "tree-sitter-{lang}"),
    ```

    ```swift
    .copy("Resources/tree-sitter-{lang}"),
    ```

3. Copy the grammar's query files into `Sources/CodeEditLanguages/Resources/tree-sitter-{lang}/` — `highlights.scm` at minimum, plus any of `folds.scm`, `indents.scm`, `injections.scm`, `locals.scm`, or `tags.scm` it provides.

## Add it to CodeEditLanguages

Four files in `Sources/CodeEditLanguages` need updating.

### TreeSitterLanguage.swift

Add a case, keeping it alphabetical:

```swift
public enum TreeSitterLanguage: String {
    // other cases
    case {lang}
}
```

### CodeLanguage.swift

Import the grammar module and add a case to the `tsLanguage` computed property:

```swift
import TreeSitter{Lang}
```

```swift
private var tsLanguage: OpaquePointer? {
    switch id {
    // other cases
    case .{lang}:
        return tree_sitter_{lang}()
    }
}
```

### CodeLanguage+Definitions.swift

Add the language to ``CodeLanguage/allLanguages`` and define its static constant, both alphabetically:

```swift
static let allLanguages: [CodeLanguage] = [
    // other languages
    .{lang},
    // other languages
]

/// A language structure for `{Lang}`
static let {lang}: CodeLanguage = .init(
    id: .{lang},
    tsName: "{lang}",
    extensions: ["ext"],
    lineCommentString: "//",
    rangeCommentStrings: ("/*", "*/"),
    highlights: ["folds", "injections", "locals"] // whichever additional query files you bundled
)
```

> Important: `highlights` should list only the *additional* query files beyond `highlights.scm`, which is always loaded.

### TreeSitterModel.swift

Add a lazily-computed query property and a case in ``TreeSitterModel/query(for:)``:

```swift
public private(set) lazy var {lang}Query: Query? = {
    return queryFor(.{lang})
}()
```

```swift
public func query(for language: TreeSitterLanguage) -> Query? {
    switch language {
    // other cases
    case .{lang}:
        return {lang}Query
    }
}
```

## Add tests

Add cases to `Tests/CodeEditLanguagesTests/CodeEditLanguagesTests.swift`, following the existing per-language `// MARK:` sections — one `test_CodeLanguage{Lang}` per file extension, and a `test_FetchQuery{Lang}` confirming the query compiles:

```swift
func test_CodeLanguage{Lang}() throws {
    let url = URL(fileURLWithPath: "~/path/to/file.{ext}")
    let language = CodeLanguage.detectLanguageFrom(url: url)

    XCTAssertEqual(language.id, .{lang})
}

func test_FetchQuery{Lang}() throws {
    var language = CodeLanguage.{lang}
    language.resourceURL = bundleURL

    let data = try Data(contentsOf: language.queryURL!)
    let query = try? Query(language: language.language!, data: data)
    XCTAssertNotNil(query)
    XCTAssertNotEqual(query?.patternCount, 0)
}
```

`LanguageResourcesTests` also runs automatically and will fail the build if `highlights` references a file that isn't bundled, or log a warning if a bundled file isn't referenced by `highlights` — check its output.

Run the suite locally:

```bash
swift test --filter CodeEditLanguagesTests
```
![unit test results](tests-results)

## Documentation

Add the language to the "Supported Languages" list and "Type Properties" topic in <doc:CodeLanguage>, and its query property to <doc:TreeSitterModel>. Update the table in `CodeEditLanguages/README.md` too.
![docs location](docs-location)
