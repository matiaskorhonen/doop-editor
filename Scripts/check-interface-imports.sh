#!/bin/bash
#
# Fail if a built framework's public .swiftinterface references a module that isn't shipped.
#
# Swift's interface printer emits an `import` for every module a source file imports, so a
# plain `import TreeSitterSwift` anywhere in CodeEditLanguages would silently put all 40
# grammar modules into the public interface and force consumers of the binaries to resolve
# every grammar package -- exactly what the binary distribution exists to avoid. The
# implementation-detail imports are marked `internal import`; this guards that.
set -euo pipefail

if [ "$#" -eq 0 ]; then
    echo "usage: check-interface-imports.sh <dir-containing-frameworks>..." >&2
    exit 2
fi

# Modules absorbed as static libraries into the frameworks that use them. None of these ship,
# so none may appear in a public interface.
ABSORBED='^(TreeSitter[A-Z]|Collections$|DequeModule$|_RopeModule$|InternalCollectionsUtilities$)'

status=0
for module in CodeEditTextView CodeEditLanguages CodeEditSourceEditor; do
    # Each framework is archived separately, so look through every directory given.
    framework=""
    for dir in "$@"; do
        if [ -d "$dir/$module.framework" ]; then
            framework="$dir/$module.framework"
            break
        fi
    done
    if [ -z "$framework" ]; then
        echo "error: $module.framework not found in: $*" >&2
        status=1
        continue
    fi

    found=0
    while IFS= read -r interface; do
        found=1
        leaked=$(grep -E '^import ' "$interface" | sed 's/^import //' \
                 | grep -E "$ABSORBED" || true)
        if [ -n "$leaked" ]; then
            echo "error: $module's public interface leaks absorbed modules:" >&2
            echo "$leaked" | sed 's/^/  /' >&2
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
    echo "interface check passed: no absorbed module leaks into a public interface"
fi
exit $status
