#!/bin/bash
#
# Print the release notes for a version tag: the body of its annotated tag message.
#
# Tags here are written as `git tag -a v0.9.0 -m "v0.9.0" -m "- What changed"`, so the subject line
# is usually just the version and the notes are the body. If the subject says something more than
# the tag name, it is used as the first line of the notes. Signatures on signed tags are left out.
#
# Notes with Markdown headings need `--cleanup=verbatim`: git's default cleanup deletes every line
# starting with `#` -- `-m` messages included -- so a `## Changes` heading would never reach the
# tag, and nothing here can bring it back. Verbatim messages have to end with a newline, which only
# `-F <file>` gives them; see BINARY_DISTRIBUTION.md.
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

# Git recognises a signature only when it starts on a line of its own. A signed tag whose message
# doesn't end with a newline -- `--cleanup=verbatim` with `-m` -- gets the signature glued onto its
# last line, and git then returns the whole signature as part of the body. Drop everything from the
# signature's first line on, keeping the message text before it on that line.
body="$(printf '%s\n' "$body" | sed -E \
    -e '/-----BEGIN (PGP SIGNATURE|SSH SIGNATURE|SIGNED MESSAGE)-----/{' \
    -e 's/-----BEGIN (PGP SIGNATURE|SSH SIGNATURE|SIGNED MESSAGE)-----.*//' \
    -e 'q' \
    -e '}')"

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
