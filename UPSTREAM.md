# Upstream forks

DoopEditor started as three [CodeEdit](https://github.com/CodeEditApp) packages, vendored as git
subtrees from custom forks:

| Former subtree | Source | Branch | Imported at |
|---|---|---|---|
| `CodeEditSourceEditor/` | [`matiaskorhonen/CodeEditSourceEditor`](https://github.com/matiaskorhonen/CodeEditSourceEditor) | `custom` | `5a0923dadeb2b485476db0c7add20df1d796d9a8` |
| `CodeEditTextView/` | [`matiaskorhonen/CodeEditTextView`](https://github.com/matiaskorhonen/CodeEditTextView) | `custom` | `1589ee7d45b5523084b6f611be2efc1c111cd271` |
| `CodeEditLanguages/` | [`matiaskorhonen/CodeEditLanguages`](https://github.com/matiaskorhonen/CodeEditLanguages) | `custom` | `3a8e205fe59262a5e7bce689084a43476bd3acf5` |

`CodeEditLanguages/custom` also carried the `spm-direct-dependencies` changes, which is why the
grammars are direct SwiftPM dependencies instead of an `xcframework`.

## The subtrees are severed

They were imported once, on 2026-05-21, and **never pulled again**. Every change since has been
local work in this repository, and the three packages have since been merged into a single
`DoopEditor` module — so the directory prefixes `git subtree pull` needs no longer exist.

There is no path back. Upstream and this fork have diverged in ways that a merge could not
reconcile anyway:

- one module instead of three, with no `CodeEditTextView`, `CodeEditLanguages` or
  `CodeEditSourceEditor` module to import;
- the tree-sitter grammars as direct SwiftPM dependencies rather than an `xcframework`;
- the third-party dependencies deliberately absent from the public API, so that the binary
  distribution can ship one XCFramework (see [BINARY_DISTRIBUTION.md](BINARY_DISTRIBUTION.md)).

The forks above stay on GitHub as the record of where the code came from. To take a specific
upstream fix, read it there and apply it by hand.

The original MIT licences are preserved in [Licenses/](Licenses/), and the root
[LICENSE](LICENSE) covers all three.
