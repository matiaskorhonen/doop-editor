# Follow-up Steps

## Re-enable disabled grammars

### Dart
`UserNobody14/tree-sitter-dart` has a git submodule using an SSH URL (`git@github.com:tree-sitter/tree-sitter`), which causes SPM to fail during checkout. Options:
- Configure git to rewrite SSH to HTTPS: `git config url."https://github.com/".insteadOf "git@github.com:"`
- Find or create a fork without the SSH submodule
- Use a different dart grammar repo (e.g. `nielsenko/tree-sitter-dart`, though it also has a submodule)

### ~~Perl~~ ✅
Switched to `tree-sitter-perl/tree-sitter-perl` on `release` branch (has pre-built parser.c and Swift bindings).

## ~~Regenerate query files~~ ✅
Regenerated via `update_queries.sh`. Patched OCaml highlights to remove `(shebang)` node (not in OCaml Interface grammar). Verilog disabled (no query files available at pinned version).

### Verilog
`tree-sitter-verilog` at v1.0.3 has no `.scm` query files and nvim-treesitter has no verilog queries either. Grammar disabled like Dart. Options:
- Find or create query files for verilog
- Upgrade to a newer version that includes queries

## Upgrade to latest grammar versions
Many grammars are pinned to older tags to avoid a Swift 6.x SPM identity mismatch (test targets in newer grammar releases reference `"SwiftTreeSitter"` by product name, but the package identity derived from the `tree-sitter/swift-tree-sitter` URL is `swift-tree-sitter`). Once upstream grammar packages fix their test target dependency declarations (using `.product(name:package:)` instead of string shorthand), the pins can be updated to latest.

Affected packages pinned to older versions:
- tree-sitter-bash (0.23.3), tree-sitter-c (0.23.6), tree-sitter-cpp (0.23.4)
- tree-sitter-css (0.23.2), tree-sitter-go (0.23.4), tree-sitter-javascript (0.23.1)
- tree-sitter-jsdoc (0.23.2), tree-sitter-json (0.24.8), tree-sitter-julia (0.23.1)
- tree-sitter-lua (0.3.0), tree-sitter-markdown (0.5.1), tree-sitter-ocaml (0.24.0)
- tree-sitter-php (0.23.12), tree-sitter-python (0.23.6), tree-sitter-regex (0.24.3)
- tree-sitter-verilog (1.0.3), tree-sitter-yaml (0.7.0), tree-sitter-zig (1.1.2)

## Pin branch-based dependencies to revisions
Several grammars use `branch:` instead of version tags. For reproducibility, consider switching to `revision:` pins using the commits from `Package.resolved`:
- tree-sitter-agda, tree-sitter-c-sharp, tree-sitter-dockerfile, tree-sitter-elixir
- tree-sitter-generic, tree-sitter-go-mod, tree-sitter-haskell, tree-sitter-html
- tree-sitter-java, tree-sitter-kotlin, tree-sitter-objc, tree-sitter-ruby
- tree-sitter-rust, tree-sitter-scala, tree-sitter-sql, tree-sitter-swift
- tree-sitter-toml, tree-sitter-typescript
