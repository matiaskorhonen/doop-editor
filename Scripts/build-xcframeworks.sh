#!/bin/bash
#
# Build DoopEditor's distributable XCFrameworks.
#
# Produces one universal (arm64 + x86_64) macOS XCFramework per shipped module under
# `build/xcframeworks`, plus a zip and SwiftPM checksum for each, and the dependency graph
# that Scripts/generate-binary-manifest.py turns into the doop-editor-binary Package.swift.
#
# Usage: Scripts/build-xcframeworks.sh [version]
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
VERSION="${1:-dev}"

PROJECT="BinaryDistribution/DoopEditorBinary.xcodeproj"
BUILD="$ROOT/build"
ARCHIVE="$BUILD/DoopEditor.xcarchive"
OUTPUT="$BUILD/xcframeworks"
DERIVED="$BUILD/DerivedData"

# CodeEditSourceEditor sits at the top of the graph, so archiving it builds and installs every
# framework in one pass. Archiving each scheme separately would be both slower and *wrong*: a
# module that two of our frameworks share (InternalCollectionsUtilities, via DequeModule and
# _RopeModule) gets absorbed statically when only one target needs it and promoted to a shared
# dynamic framework when both do -- so per-scheme archives disagree about their own link graph.
TOP_SCHEME="CodeEditSourceEditor"

# Sanity check only; the shipped set is discovered from the link graph below.
EXPECTED=(CodeEditTextView CodeEditLanguages CodeEditSourceEditor)

echo "==> Resolving package dependencies"
# The third-party framework targets build straight out of .build/checkouts, and the grammar
# packages are pinned to the revisions in Package.resolved, so resolve before generating.
swift package resolve

echo "==> Generating $PROJECT"
python3 Scripts/generate-binary-project.py
(cd BinaryDistribution && xcodegen generate --spec project.yml)

rm -rf "$ARCHIVE" "$OUTPUT"
mkdir -p "$OUTPUT"

echo "==> Archiving $TOP_SCHEME"
# SKIP_INSTALL and BUILD_LIBRARY_FOR_DISTRIBUTION are deliberately not passed here: on the
# command line they would also apply to the SwiftPM dependencies, and swift-collections does
# not compile with library evolution enabled. They are set per target in the generated spec.
xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$TOP_SCHEME" \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -archivePath "$ARCHIVE" \
    -derivedDataPath "$DERIVED" \
    > "$BUILD/archive.log" 2>&1 || {
        echo "error: archiving failed; errors from $BUILD/archive.log:" >&2
        grep -E "error:" "$BUILD/archive.log" | sort -u | head -20 >&2
        exit 1
    }

INSTALLED="$ARCHIVE/Products/Library/Frameworks"
DSYMS="$ARCHIVE/dSYMs"

for module in "${EXPECTED[@]}"; do
    if [ ! -d "$INSTALLED/$module.framework" ]; then
        echo "error: $module.framework was not installed into the archive" >&2
        exit 1
    fi
done

# One shipped module's interface referencing an absorbed module would force consumers to
# resolve the grammar packages again, so this is a hard gate rather than a warning.
echo "==> Checking interface hygiene"
Scripts/check-interface-imports.sh "$INSTALLED"

echo "==> Resolving the framework closure"
# The shipped set is discovered from the link graph, not hand-written -- see
# Scripts/framework-closure.py for why that matters.
CLOSURE="$BUILD/closure.tsv"
python3 Scripts/framework-closure.py "$INSTALLED" "$DERIVED/Build" "${EXPECTED[@]}" > "$CLOSURE"
printf '    %d frameworks: %s\n' \
    "$(wc -l < "$CLOSURE" | tr -d ' ')" \
    "$(cut -f1 "$CLOSURE" | tr '\n' ' ')"

STAGED="$BUILD/staged"
rm -rf "$STAGED"

while IFS=$'\t' read -r module path deps; do
    echo "==> Packaging $module.xcframework"

    # A framework promoted from a SwiftPM package target is built without library evolution,
    # so it carries a .swiftmodule with no .swiftinterface -- which -create-xcframework
    # refuses. Consumers never import these (they are `internal import`ed by code already
    # absorbed into our frameworks); only the dylib has to be present at load time, so ship
    # it binary-only. Obj-C and C frameworks have no .swiftmodule and must be left alone --
    # stripping their module map would make them unusable.
    if [ -n "$(find "$path/Versions/A/Modules" -name '*.swiftmodule' -print -quit 2>/dev/null)" ] \
       && [ -z "$(find "$path/Versions/A/Modules" -name '*.swiftinterface' -print -quit)" ]; then
        echo "    (binary-only: no .swiftinterface, stripping the unusable module)"
        mkdir -p "$STAGED"
        cp -Rc "$path" "$STAGED/" 2>/dev/null || cp -R "$path" "$STAGED/"
        path="$STAGED/$module.framework"
        rm -rf "$path/Versions/A/Modules" "$path/Modules"
    fi

    args=(-framework "$path")
    # Ship dSYMs so crash reports from the consuming app symbolize into these binaries.
    [ -d "$DSYMS/$module.framework.dSYM" ] && args+=(-debug-symbols "$DSYMS/$module.framework.dSYM")

    xcodebuild -create-xcframework "${args[@]}" \
        -output "$OUTPUT/$module.xcframework" > /dev/null

    (cd "$OUTPUT" && ditto -c -k --sequesterRsrc --keepParent \
        "$module.xcframework" "$module.xcframework.zip")
done < "$CLOSURE"

echo "==> Checksums"
TARGETS="$OUTPUT/binary-targets.txt"
: > "$TARGETS"
while IFS=$'\t' read -r module path deps; do
    checksum=$(swift package compute-checksum "$OUTPUT/$module.xcframework.zip")
    # module <checksum> <comma-separated direct dependencies>
    printf '%s %s %s\n' "$module" "$checksum" "$deps" >> "$TARGETS"
    printf '  %-30s %s\n' "$module" "$checksum"
done < "$CLOSURE"

echo
echo "XCFrameworks:  $OUTPUT"
echo "Checksums:     $TARGETS"
echo "Next:          Scripts/generate-binary-manifest.py $VERSION"
