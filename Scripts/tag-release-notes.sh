#!/bin/bash
#
# Print the release notes for a version tag: the body of its annotated tag message.
#
# Tags here are written as `git tag -a v0.9.0 -m "v0.9.0" -m "- What changed"`, so the subject line
# is usually just the version and the notes are the body. If the subject says something more than
# the tag name, it is used as the first line of the notes. Signatures on signed tags are left out.
#
# Prints nothing -- and exits 0 -- when there are no notes to take from the tag: a lightweight tag,
# or an annotated one whose message is only the version. The caller decides on a fallback.
#
# Usage: tag-release-notes.sh <tag>
set -euo pipefail

TAG="${1:?usage: tag-release-notes.sh <tag>}"
REF="refs/tags/$TAG"

if ! git rev-parse --verify --quiet "$REF" > /dev/null; then
    echo "error: tag $TAG not found locally -- fetch it first" >&2
    exit 1
fi

# A lightweight tag has no message of its own; its `contents` would be the commit's message.
if [ "$(git for-each-ref "$REF" --format='%(objecttype)')" != "tag" ]; then
    exit 0
fi

subject="$(git for-each-ref "$REF" --format='%(contents:subject)')"
body="$(git for-each-ref "$REF" --format='%(contents:body)')"

notes=""
if [ -n "$subject" ] && [ "$subject" != "$TAG" ]; then
    notes="$subject"
fi
if [ -n "$body" ]; then
    notes="${notes:+$notes$'\n\n'}$body"
fi

if [ -n "$notes" ]; then
    printf '%s\n' "$notes"
fi
