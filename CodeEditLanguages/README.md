# CodeEditLanguages

A collection of `tree-sitter` languages for syntax highlighting.

This package uses **direct SPM grammar dependencies** (no xcframework). It heavily depends on [SwiftTreeSitter](https://github.com/ChimeHQ/SwiftTreeSitter) by [Matt Massicotte](https://bsky.app/profile/massicotte.org).

## Documentation

The documentation including a guide on how to add support for new languages can be found **[here](https://codeeditapp.github.io/CodeEditLanguages/documentation/codeeditlanguages)**!

## Supported Languages

| Grammar | Implemented | Syntax Highlighting |
| ------- | :---------: | :-----------------: |
| [Bash](https://github.com/tree-sitter/tree-sitter-bash) | ✅ | ✅ |
| [C](https://github.com/tree-sitter/tree-sitter-c) | ✅ | ✅ |
| [C++](https://github.com/tree-sitter/tree-sitter-cpp) | ✅ | ✅ |
| [C#](https://github.com/tree-sitter/tree-sitter-c-sharp) | ✅ | ✅ |
| [CSS](https://github.com/tree-sitter/tree-sitter-css.git) | ✅ | ✅ |
| [Dockerfile](https://github.com/camdencheek/tree-sitter-dockerfile) | ✅ | ✅ |
| [Elixir](https://github.com/elixir-lang/tree-sitter-elixir) | ✅ | ✅ |
| [Go](https://github.com/tree-sitter/tree-sitter-go) | ✅ | ✅ |
| [HTML](https://github.com/tree-sitter/tree-sitter-html) | ✅ | ✅ |
| [Java](https://github.com/tree-sitter/tree-sitter-java) | ✅ | ✅ |
| [JavaScript/JSX](https://github.com/tree-sitter/tree-sitter-javascript) | ✅ | ✅ |
| [JSDoc](https://github.com/tree-sitter/tree-sitter-jsdoc) | ✅ | ✅ |
| [JSON](https://github.com/tree-sitter/tree-sitter-json) | ✅ | ✅ |
| [Julia](https://github.com/tree-sitter/tree-sitter-julia) | ✅ | _not available_ |
| [Kotlin](https://github.com/fwcd/tree-sitter-kotlin) | ✅ | ✅ |
| [Lua](https://github.com/tree-sitter-grammars/tree-sitter-lua) | ✅ | ✅ |
| [Markdown](https://github.com/tree-sitter-grammars/tree-sitter-markdown) | ✅ | ✅ |
| [Objective C](https://github.com/tree-sitter-grammars/tree-sitter-objc) | ✅ | ✅ |
| [OCaml](https://github.com/tree-sitter/tree-sitter-ocaml) | ✅ | ✅ |
| Plain Text | ✅ | _not available_ |
| [Perl](https://github.com/ganezdragon/tree-sitter-perl) | ✅ | _not available_ |
| [PHP](https://github.com/tree-sitter/tree-sitter-php) | ✅ | ✅ |
| [Python](https://github.com/tree-sitter/tree-sitter-python) | ✅ | ✅ |
| [Regex](https://github.com/tree-sitter/tree-sitter-regex) | ✅ | ✅ |
| [Ruby](https://github.com/mattmassicotte/tree-sitter-ruby) | ✅ | ✅ |
| [Rust](https://github.com/tree-sitter/tree-sitter-rust) | ✅ | ✅ |
| [Scala](https://github.com/tree-sitter/tree-sitter-scala) | ✅ | ✅ |
| [SQL](https://github.com/DerekStride/tree-sitter-sql) | ✅ | ✅ |
| [Swift](https://github.com/alex-pinkus/tree-sitter-swift/tree/with-generated-files) | ✅ | ✅ |
| [TOML](https://github.com/cengelbart39/tree-sitter-toml/tree/feature/spm) | ✅ | ✅ |
| [TypeScript/TSX](https://github.com/tree-sitter/tree-sitter-typescript) | ✅ | ✅ |
| [YAML](https://github.com/tree-sitter-grammars/tree-sitter-yaml.git) | ✅ | ✅ |
| [Zig](https://github.com/tree-sitter-grammars/tree-sitter-zig.git) | ✅ | ✅ |

## Grammar Version Upgrade Blockers

Several grammar packages are pinned to older versions due to upstream issues.

### Blocked by FileManager scanner detection bug

Newer versions (≥ 0.25.0 for most) use `FileManager.default.fileExists(atPath: "src/scanner.c")` to dynamically include the external scanner source. This path is resolved relative to the _consumer's_ working directory rather than the package checkout, so the file is never found when the grammar is consumed as an SPM dependency. Needs an upstream fix to hardcode `scanner.c` in the `sources` list.

| Package | Current | Target |
| ------- | :-----: | :----: |
| [tree-sitter-css](https://github.com/tree-sitter/tree-sitter-css) | 0.23.2 | 0.25.0 |
| [tree-sitter-javascript](https://github.com/tree-sitter/tree-sitter-javascript) | 0.23.1 | 0.25.0 |
| [tree-sitter-jsdoc](https://github.com/tree-sitter/tree-sitter-jsdoc) | 0.23.2 | 0.25.0 |
| [tree-sitter-julia](https://github.com/tree-sitter/tree-sitter-julia) | 0.23.1 | 0.25.0 |
| [tree-sitter-lua](https://github.com/tree-sitter-grammars/tree-sitter-lua) | 0.3.0 | 0.5.0 |
| [tree-sitter-python](https://github.com/tree-sitter/tree-sitter-python) | 0.23.6 | 0.25.0 |
| [tree-sitter-yaml](https://github.com/tree-sitter-grammars/tree-sitter-yaml) | 0.7.0 | 0.7.2 |

### Other blockers

- **[tree-sitter-bash](https://github.com/tree-sitter/tree-sitter-bash) (0.23.3):** `master` declares a dependency on `SwiftTreeSitter` with `from: "0.25.0"`, incompatible with this package's `exact: "0.10.0"` pin of `tree-sitter/swift-tree-sitter`.
- **[tree-sitter-json](https://github.com/tree-sitter/tree-sitter-json) (0.24.8):** `master` still references the old `ChimeHQ/SwiftTreeSitter` URL instead of `tree-sitter/swift-tree-sitter`.
