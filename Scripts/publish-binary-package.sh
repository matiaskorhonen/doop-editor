#!/bin/bash
#
# Publish the generated binary package to the doop-editor-binary repository.
#
# Commits build/binary-package/{Package.swift,README.md} on top of that repository's main branch
# and tags the commit with the release version. `main` itself only moves to the newest stable
# version: publishing an older patch release or a prerelease pushes just its tag, so `main` -- and
# the README on the repository's front page -- keep describing the latest release. When `main`
# does move, the branch and the tag are pushed atomically.
#
# Usage: Scripts/publish-binary-package.sh <vX.Y.Z> <remote-url>
#
# The remote is taken as an argument rather than derived here so CI can pass an authenticated
# URL; the workflow's own GITHUB_TOKEN can only write to the repository it runs in.
set -euo pipefail

VERSION="${1:?usage: publish-binary-package.sh <vX.Y.Z> <remote-url>}"
REMOTE="${2:?usage: publish-binary-package.sh <vX.Y.Z> <remote-url>}"

cd "$(dirname "$0")/.."
PACKAGE="$PWD/build/binary-package"

for file in Package.swift README.md; do
    if [ ! -f "$PACKAGE/$file" ]; then
        echo "error: $PACKAGE/$file not found -- run Scripts/generate-binary-manifest.swift" >&2
        exit 1
    fi
done
if ! grep -q "Prebuilt DoopEditor $VERSION\.$" "$PACKAGE/Package.swift"; then
    echo "error: $PACKAGE/Package.swift was not generated for $VERSION" >&2
    exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

git clone --quiet "$REMOTE" "$WORK" 2>/dev/null || {
    # Don't echo the remote: in CI it carries a token.
    echo "error: could not clone the binary package repository" >&2
    exit 1
}
cd "$WORK"

# Refuse to move an existing release. Its manifest pins checksums of zips that consumers have
# already resolved, and the builds aren't reproducible, so a rebuild can never match them.
if git rev-parse --verify --quiet "refs/tags/$VERSION" > /dev/null; then
    echo "error: $VERSION is already published to the binary package repository" >&2
    exit 1
fi

if git rev-parse --verify --quiet HEAD > /dev/null; then
    git checkout --quiet -B main
else
    # A brand-new repository has no commits, so start its history.
    git checkout --quiet --orphan main
fi

cp "$PACKAGE/Package.swift" "$PACKAGE/README.md" .
git add Package.swift README.md

if [ -z "$(git config user.name || true)" ]; then
    git config user.name "github-actions[bot]"
    git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
fi

git commit --quiet -m "DoopEditor $VERSION"
# Annotated, like the tags in the source repository.
git tag -a "$VERSION" -m "DoopEditor $VERSION"

# The newest stable version, now that this one is tagged locally. Prereleases never move `main`.
newest_stable="$(git tag -l 'v*' --sort=-v:refname | grep -v -- '-' | head -n 1 || true)"

if [ "$VERSION" = "$newest_stable" ]; then
    git push --quiet --atomic origin main "refs/tags/$VERSION"
    echo "Published $VERSION ($(git rev-parse --short HEAD)); main updated"
else
    # The commit still sits on top of main's history, but main stays where it is.
    git push --quiet origin "refs/tags/$VERSION"
    echo "Published $VERSION ($(git rev-parse --short HEAD)); main left at ${newest_stable:-<none>}"
fi
