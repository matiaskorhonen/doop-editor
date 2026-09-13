#!/bin/bash
#
# Fail if a shipped framework's public .swiftinterface imports a module that doesn't ship.
#
# Swift's interface printer emits an `import` for every module a source file imports, so a plain
# `import TreeSitterSwift` anywhere in CodeEditLanguages would silently put all the grammar modules
# into the public interface and force consumers of the binaries to resolve every grammar package --
# exactly what the binary distribution exists to avoid. Implementation-detail imports are marked
# `internal import`; this guards that.
#
# The modules that must not appear aren't hand-listed. They are every module the build compiled
# from a SwiftPM package (Xcode writes a module map for each into GeneratedModuleMaps) minus the
# ones that ship. A hand-written list goes stale as soon as a dependency grows a new module:
# swift-collections' DequeModule, for one, pulls in ContainersPreview.
#
# Usage: check-interface-imports.sh <frameworks-dir> <generated-module-maps-dir> <shipped-module>...
set -euo pipefail

if [ "$#" -lt 3 ]; then
    echo "usage: check-interface-imports.sh <frameworks-dir> <generated-module-maps-dir> <shipped-module>..." >&2
    exit 2
fi

FRAMEWORKS="$1"
MODULE_MAPS="$2"
shift 2
SHIPPED=$'\n'"$(printf '%s\n' "$@")"$'\n'

is_shipped() {
    case "$SHIPPED" in *$'\n'"$1"$'\n'*) return 0 ;; *) return 1 ;; esac
}

# Modules compiled from SwiftPM packages that don't ship.
UNSHIPPED=$'\n'
for map in "$MODULE_MAPS"/*.modulemap; do
    [ -f "$map" ] || continue
    name="$(basename "$map" .modulemap)"
    is_shipped "$name" || UNSHIPPED="$UNSHIPPED$name"$'\n'
done
if [ "$UNSHIPPED" = $'\n' ]; then
    # With no package modules there would be nothing to check against, and the check would pass
    # silently. The grammars alone guarantee there are dozens.
    echo "error: no package module maps found in $MODULE_MAPS" >&2
    exit 1
fi

is_unshipped() {
    case "$UNSHIPPED" in *$'\n'"$1"$'\n'*) return 0 ;; *) return 1 ;; esac
}

# The top-level module of every import in an interface. Interfaces don't only print bare
# `import X`: attributes (`@preconcurrency import X`, `@_exported import X`), access modifiers
# (`public import X`) and scoped imports (`import struct X.Y`) all appear too, and a module imported
# any of those ways leaks just the same.
imported_modules() {
    sed -nE 's/^[[:space:]]*(@[A-Za-z_]+(\([^)]*\))?[[:space:]]+)*((public|package|internal|fileprivate|private)[[:space:]]+)?import[[:space:]]+((typealias|struct|class|enum|protocol|let|var|func)[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*).*/\7/p' "$1"
}

status=0
for module in CodeEditTextView CodeEditLanguages CodeEditSourceEditor; do
    framework="$FRAMEWORKS/$module.framework"
    if [ ! -d "$framework" ]; then
        echo "error: $module.framework not found in $FRAMEWORKS" >&2
        status=1
        continue
    fi

    found=0
    while IFS= read -r interface; do
        found=1
        leaked=""
        for imported in $(imported_modules "$interface" | sort -u); do
            if is_unshipped "$imported"; then
                leaked="$leaked  $imported"$'\n'
            fi
        done
        if [ -n "$leaked" ]; then
            echo "error: $module's public interface imports modules that don't ship:" >&2
            printf '%s' "$leaked" >&2
            echo "  (mark the offending import \`internal import\` in the module's sources)" >&2
            status=1
        fi
    done < <(find "$framework" -name '*.swiftinterface' ! -name '*.private.swiftinterface' \
                  ! -name '*.package.swiftinterface')

    if [ "$found" -eq 0 ]; then
        echo "error: $module ships no .swiftinterface -- was BUILD_LIBRARY_FOR_DISTRIBUTION set?" >&2
        status=1
    fi
done

if [ "$status" -eq 0 ]; then
    echo "interface check passed: no public interface imports a module that doesn't ship"
fi
exit $status
