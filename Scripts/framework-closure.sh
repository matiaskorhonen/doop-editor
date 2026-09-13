#!/bin/bash
#
# Resolve the set of frameworks that have to ship, by walking the actual link graph.
#
# Anything a shipped framework loads at runtime has to ship too, and Xcode decides on its own
# whether a SwiftPM dependency ends up absorbed into the framework that uses it or promoted to a
# shared dynamic framework -- `InternalCollectionsUtilities` is absorbed when only
# `CodeEditTextView` needs it and promoted once `CodeEditSourceEditor` needs it as well.
# Discovering the set here means such a change breaks the build rather than the consumer.
#
# Usage: framework-closure.sh <installed-dir> <derived-build-dir> <root-module>...
# Prints one tab-separated `name<TAB>path<TAB>comma,separated,deps` line per framework, with
# `-` for no dependencies.
#
# Written for macOS's bash 3.2: no associative arrays.
set -euo pipefail

if [ "$#" -lt 3 ]; then
    echo "usage: framework-closure.sh <installed-dir> <derived-build-dir> <root-module>..." >&2
    exit 2
fi

INSTALLED="$1"
DERIVED="$2"
shift 2

# Resolve symlinks throughout: Xcode's build products directory is full of symlinks into
# UninstalledProducts, and a relative symlink breaks as soon as it is copied elsewhere.
realpath_dir() {
    (cd "$1" && pwd -P)
}

locate() {
    local name="$1"
    if [ -d "$INSTALLED/$name.framework" ]; then
        realpath_dir "$INSTALLED/$name.framework"
        return
    fi
    # SwiftPM package products keep SKIP_INSTALL=YES, so a promoted one never reaches the
    # archive and has to be picked out of the build products instead.
    local candidate
    candidate="$(find "$DERIVED" -path "*/BuildProductsPath/Release/$name.framework" -print -quit 2>/dev/null)"
    if [ -n "$candidate" ] && [ -d "$candidate" ]; then
        realpath_dir "$candidate"
    fi
}

dependencies() {
    local framework="$1" name="$2" binary
    binary="$framework/Versions/A/$name"
    [ -f "$binary" ] || binary="$framework/$name"
    if ! otool -L "$binary" > /dev/null 2>&1; then
        echo "error: could not read the link graph of $framework" >&2
        return 1
    fi
    otool -L "$binary" \
        | sed -n 's|.*@rpath/\([A-Za-z_][A-Za-z0-9_]*\)\.framework/.*|\1|p' \
        | grep -vx "$name" \
        | sort -u \
        || true
}

queue=("$@")
seen=$'\n'

while [ "${#queue[@]}" -gt 0 ]; do
    name="${queue[0]}"
    queue=("${queue[@]:1}")

    case "$seen" in *$'\n'"$name"$'\n'*) continue ;; esac
    seen="$seen$name"$'\n'

    path="$(locate "$name")"
    if [ -z "$path" ]; then
        echo "error: $name.framework is loaded at runtime but was not built anywhere." >&2
        echo "       Add it to the generated project, or stop the public API from needing it." >&2
        exit 1
    fi

    deps="$(dependencies "$path" "$name")"
    for dep in $deps; do
        queue+=("$dep")
    done

    printf '%s\t%s\t%s\n' "$name" "$path" "$(echo $deps | tr ' ' ',' | sed 's/^$/-/')"
done
