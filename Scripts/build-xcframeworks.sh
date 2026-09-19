#!/bin/bash
#
# Build DoopEditor's distributable XCFramework.
#
# Produces the universal (arm64 + x86_64) macOS XCFramework under `build/xcframeworks`, with a zip,
# a SwiftPM checksum, and the dependency graph that Scripts/generate-binary-manifest.swift turns
# into the doop-editor-binary Package.swift.
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

# The one framework. Everything else in the generated project is a static library absorbed
# into it, so archiving this scheme builds and installs the whole release.
TOP_SCHEME="DoopEditor"

# Sanity check only; the shipped set is still discovered from the link graph below, which is
# what catches a dependency that stopped being absorbed and became a second framework.
EXPECTED=(DoopEditor)

echo "==> Resolving package dependencies"
# The third-party framework targets build straight out of .build/checkouts, and the grammar
# packages are pinned to the revisions in Package.resolved, so resolve before generating.
# --force-resolved-versions builds exactly what Package.resolved pins, and fails rather than
# silently picking newer versions when it's out of date with Package.swift -- run
# `swift package update` (or `resolve`) and commit the result.
swift package --force-resolved-versions resolve

# The framework absorbs every one of those dependencies, so their licences have to ship with it.
# This only checks that the committed notices list what Package.resolved pins; the texts themselves
# are regenerated from the checkouts by Scripts/generate-binary-manifest.swift.
echo "==> Checking third-party licences"
Scripts/generate-licenses.swift --check

echo "==> Generating $PROJECT"
Scripts/generate-binary-project.swift
(cd BinaryDistribution && xcodegen generate --spec project.json)

# DerivedData's Build directory goes too, so every build -- local rehearsals included -- compiles from
# scratch and can't pick up products left behind by an earlier one. Its SourcePackages, Xcode's
# checkouts of the grammar packages, are the slow part to recreate and are only ever read, so they stay.
rm -rf "$ARCHIVE" "$OUTPUT" "$DERIVED/Build"
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
        echo "error: archiving failed; the full log is $BUILD/archive.log" >&2
        errors="$(grep -E "error:" "$BUILD/archive.log" | sort -u | head -20 || true)"
        if [ -n "$errors" ]; then
            printf '%s\n' "$errors" >&2
        else
            # Not every failure prints an `error:` line (resolution, signing, a crashed tool).
            tail -n 40 "$BUILD/archive.log" >&2
        fi
        exit 1
    }

INSTALLED="$ARCHIVE/Products/Library/Frameworks"
DSYMS="$ARCHIVE/dSYMs"
# This scheme's own intermediates. Everything below looks only in here, never across all of
# DerivedData, so nothing from a different scheme's archive can be mistaken for part of this one.
INTERMEDIATES="$DERIVED/Build/Intermediates.noindex/ArchiveIntermediates/$TOP_SCHEME"
if [ ! -d "$INTERMEDIATES" ]; then
    echo "error: $INTERMEDIATES not found -- has Xcode's DerivedData layout changed?" >&2
    exit 1
fi

for module in "${EXPECTED[@]}"; do
    if [ ! -d "$INSTALLED/$module.framework" ]; then
        echo "error: $module.framework was not installed into the archive" >&2
        exit 1
    fi
done

echo "==> Resolving the framework closure"
# The shipped set is discovered from the link graph, not hand-written -- see
# Scripts/framework-closure.sh for why that matters.
CLOSURE="$BUILD/closure.tsv"
Scripts/framework-closure.sh "$INSTALLED" "$INTERMEDIATES/BuildProductsPath/Release" "${EXPECTED[@]}" \
    > "$CLOSURE"
printf '    %d frameworks: %s\n' \
    "$(wc -l < "$CLOSURE" | tr -d ' ')" \
    "$(cut -f1 "$CLOSURE" | tr '\n' ' ')"

# A framework promoted from a SwiftPM package target is built without library evolution, so it
# carries a .swiftmodule with no .swiftinterface -- which -create-xcframework refuses. Consumers
# never import these (they are `internal import`ed by code already absorbed into our frameworks);
# only the dylib has to be present at load time, so they ship binary-only. Obj-C and C frameworks
# have no .swiftmodule and must be left alone -- stripping their module map would make them
# unusable.
is_binary_only() {
    [ -n "$(find "$1/Versions/A/Modules" -name '*.swiftmodule' -print -quit 2>/dev/null)" ] \
        && [ -z "$(find "$1/Versions/A/Modules" -name '*.swiftinterface' -print -quit)" ]
}

# A shipped module's interface importing a module consumers can't import would force them to
# resolve the grammar packages again, so this is a hard gate rather than a warning. Binary-only
# frameworks ship, but without a module, so an interface may not import them either.
#
# The loops over $CLOSURE read it on fd 3 rather than stdin: xcodebuild, ditto and swift run inside
# them, and any tool that reads stdin would swallow the remaining lines and silently ship fewer
# frameworks.
IMPORTABLE=()
while IFS=$'\t' read -r module path deps <&3; do
    is_binary_only "$path" || IMPORTABLE+=("$module")
done 3< "$CLOSURE"

echo "==> Checking interface hygiene"
Scripts/check-interface-imports.sh "$INSTALLED" \
    "$INTERMEDIATES/IntermediateBuildFilesPath/GeneratedModuleMaps" "${IMPORTABLE[@]}"

# A framework with no Info.plist links fine but cannot be embedded in an app bundle: Xcode
# fails the consuming build with "did not contain an Info.plist". Nothing else here notices,
# because the consumer check builds a SwiftPM executable, which links the framework without
# embedding it. v0.9.0 and earlier shipped without one.
echo "==> Checking bundle structure"
while IFS=$'\t' read -r module path deps <&3; do
    if [ ! -f "$path/Versions/A/Resources/Info.plist" ] && [ ! -f "$path/Resources/Info.plist" ]; then
        echo "error: $module.framework has no Info.plist -- it cannot be embedded in an app bundle." >&2
        echo "       Set GENERATE_INFOPLIST_FILE=YES on its target in the generated project." >&2
        exit 1
    fi
done 3< "$CLOSURE"

STAGED="$BUILD/staged"
rm -rf "$STAGED"

while IFS=$'\t' read -r module path deps <&3; do
    echo "==> Packaging $module.xcframework"

    if is_binary_only "$path"; then
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
done 3< "$CLOSURE"

echo "==> Checksums"
TARGETS="$OUTPUT/binary-targets.txt"
: > "$TARGETS"
while IFS=$'\t' read -r module path deps <&3; do
    checksum=$(swift package compute-checksum "$OUTPUT/$module.xcframework.zip")
    # module <checksum> <comma-separated direct dependencies>
    printf '%s %s %s\n' "$module" "$checksum" "$deps" >> "$TARGETS"
    printf '  %-30s %s\n' "$module" "$checksum"
done 3< "$CLOSURE"

echo
echo "XCFrameworks:  $OUTPUT"
echo "Checksums:     $TARGETS"
echo "Next:          Scripts/generate-binary-manifest.swift $VERSION && Scripts/verify-binary-consumption.sh"
