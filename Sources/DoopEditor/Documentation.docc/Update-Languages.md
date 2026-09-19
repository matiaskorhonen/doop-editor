# Update Languages

This article covers updating an existing language's `tree-sitter` grammar to a newer version.

## Overview

Since each grammar is a direct SwiftPM dependency in the root `Package.swift`, bumping a version is usually a one-line edit rather than a rebuild step.

## Update the dependency

1. Find the language's `.package(url:...)` entry in the root `Package.swift` and update its version constraint, matching whatever pinning style it currently uses (`exact:`, or `revision:` with a comment naming the branch).

2. Resolve and build:

    ```bash
    swift package update {package-name}
    swift build
    ```

3. If the grammar's query files changed upstream, re-copy them from the updated checkout into `Sources/CodeEditLanguages/Resources/tree-sitter-{lang}/`. SwiftPM does not do this automatically — the `.scm` files are bundled resources, not generated from the grammar source.

## Check if everything still works

```bash
swift test --filter CodeEditLanguagesTests
```

If a query no longer compiles against the new grammar version, `TreeSitterModel`'s query loader skips the offending `.scm` file and logs a warning rather than failing the build — so a version bump can silently regress highlighting for a language. Check the test output, and cross-reference `CodeEditLanguages/README.md`'s "Grammar Version Upgrade Blockers" section, before assuming a bump is safe.

Once everything passes, commit and open a pull request.
