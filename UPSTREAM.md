# Upstream forks

DoopEditor vendors three [CodeEdit](https://github.com/CodeEditApp) packages as git subtrees, each pulled from a custom fork rather than directly from CodeEditApp:

| Subtree | Source | Branch |
|---|---|---|
| `CodeEditSourceEditor/` | [`matiaskorhonen/CodeEditSourceEditor`](https://github.com/matiaskorhonen/CodeEditSourceEditor) | `custom` |
| `CodeEditTextView/` | [`matiaskorhonen/CodeEditTextView`](https://github.com/matiaskorhonen/CodeEditTextView) | `custom` |
| `CodeEditLanguages/` | [`matiaskorhonen/CodeEditLanguages`](https://github.com/matiaskorhonen/CodeEditLanguages) | `custom` |

The `custom` branch on each fork is the canonical source for that package. `CodeEditLanguages/custom` also has the `spm-direct-dependencies` changes merged in, which is why `CodeEditLanguages` depends directly on SwiftPM grammar packages instead of an xcframework.

Each subdirectory contains the full imported history from its upstream fork, but only the root `Package.swift` is used to build — changes made inside a subtree directory are regular commits in this repo, no special workflow needed for day-to-day edits.

This monorepo exists for fast cross-package iteration on Doop and is not intended for upstreaming changes back to CodeEdit.

## Bootstrapping

### Import the subtrees

```bash
git subtree add --prefix=CodeEditSourceEditor \
  https://github.com/matiaskorhonen/CodeEditSourceEditor.git custom

git subtree add --prefix=CodeEditTextView \
  https://github.com/matiaskorhonen/CodeEditTextView.git custom

git subtree add --prefix=CodeEditLanguages \
  https://github.com/matiaskorhonen/CodeEditLanguages.git custom
```

### Pull upstream changes

```bash
git subtree pull --prefix=CodeEditSourceEditor \
  https://github.com/matiaskorhonen/CodeEditSourceEditor.git custom

git subtree pull --prefix=CodeEditTextView \
  https://github.com/matiaskorhonen/CodeEditTextView.git custom

git subtree pull --prefix=CodeEditLanguages \
  https://github.com/matiaskorhonen/CodeEditLanguages.git custom
```
