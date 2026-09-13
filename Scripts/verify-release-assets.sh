#!/bin/bash
#
# Check that a GitHub release's assets are exactly the XCFramework zips from this build.
#
# The binary package pins each zip's SHA-256 (SwiftPM's checksum), and GitHub reports each asset's
# SHA-256 as its `digest`. Publishing a manifest over assets that don't match would give every
# consumer a checksum failure, and with immutable releases the assets can't be replaced afterwards.
#
# Reads `gh release view <tag> --json assets` on stdin; compares against
# build/xcframeworks/binary-targets.txt (module, checksum, dependencies per line).
#
# Usage: gh release view v0.9.0 --json assets | Scripts/verify-release-assets.sh
set -euo pipefail

cd "$(dirname "$0")/.."
TARGETS="build/xcframeworks/binary-targets.txt"

if [ ! -f "$TARGETS" ]; then
    echo "error: $TARGETS not found -- download the build artifact first" >&2
    exit 1
fi

# name<TAB>sha256 for every asset the release has. An asset still uploading has no digest yet.
actual="$(jq -r '.assets[] | "\(.name)\t\(.digest // "" | ltrimstr("sha256:"))"' | sort)"
expected="$(awk '{ printf "%s.xcframework.zip\t%s\n", $1, $2 }' "$TARGETS" | sort)"

if [ "$actual" = "$expected" ]; then
    echo "release assets match the build: $(printf '%s\n' "$expected" | wc -l | tr -d ' ') zips"
    exit 0
fi

echo "error: the release's assets don't match this build's XCFrameworks" >&2
diff <(printf '%s\n' "$expected" | sed '/^$/d') <(printf '%s\n' "$actual" | sed '/^$/d') \
    | sed -n 's/^< /  expected: /p; s/^> /  on release: /p' >&2 || true
exit 1
