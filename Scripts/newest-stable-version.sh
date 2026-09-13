#!/bin/bash
#
# Print the newest stable version among the tag names on stdin, or nothing if there is none.
#
# A stable version is exactly `vX.Y.Z`: prereleases (`v1.0.0-rc.1`) and anything else that merely
# starts with `v` don't count. This is the one definition of "newest stable" for releasing -- the
# release marked "Latest" here and the version doop-editor-binary's `main` points at both use it,
# so the two repositories can't disagree about the current release.
#
# Usage: git tag -l | Scripts/newest-stable-version.sh
set -euo pipefail

stable="$(grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' || true)"
[ -n "$stable" ] || exit 0

# Compare each component numerically, so v0.10.0 sorts after v0.9.1.
printf '%s\n' "$stable" \
    | sed 's/^v//' \
    | sort -t. -k1,1n -k2,2n -k3,3n \
    | tail -n 1 \
    | sed 's/^/v/'
