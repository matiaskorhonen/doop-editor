#!/usr/bin/env sh

# This script updates tree-sitter query files (.scm) from grammar checkouts
# and fills in missing queries from the nvim-treesitter submodule.
#
# Prerequisites:
#   1. Run `swift package resolve` first so .build/checkouts/ is populated
#   2. Ensure the nvim-treesitter submodule is initialized:
#      git submodule update --init
#
# Usage:
#   ./update_queries.sh
#
# Created from build_framework.sh query-copy logic

set -euo pipefail

status () {
    local GREEN='\033[0;32m'
    local NC='\033[0m'
    echo "${GREEN}◆ $1${NC}"
}

CHECKOUTS_PATH="$PWD/.build/checkouts"
RESOURCES_PATH="$PWD/Sources/CodeEditLanguages/Resources"
NVIM_TS_PATH="$PWD/vendor/nvim-treesitter/runtime/queries"

if [ ! -d "$CHECKOUTS_PATH" ]; then
    echo "Error: .build/checkouts not found. Run 'swift package resolve' first."
    exit 1
fi

if [ ! -d "$NVIM_TS_PATH" ]; then
    echo "Error: vendor/nvim-treesitter not found. Run 'git submodule update --init' first."
    exit 1
fi

# Remove previous copied files
status "Copying language queries from grammar checkouts..."
rm -rf "$RESOURCES_PATH"

# Copy .scm files from each grammar checkout
LIST=$( echo $CHECKOUTS_PATH/tree-sitter-* )

for lang in $LIST ; do
    cd "$lang"

    # Get package info as JSON
    manifest=$(swift package dump-package 2>/dev/null || true)
    if [ -z "$manifest" ]; then
        cd "$OLDPWD"
        continue
    fi

    # Get target paths (excluding test targets)
    targets=$(echo "$manifest" | jq -r '.targets[] | select(.type != "test") | .path')
    count=$(echo "$manifest" | jq '[.targets[] | select(.type != "test")] | length')

    # Determine if target paths are all '.'
    same=1
    for target in $targets; do
        if [ "$target" != "." ]; then
            same=0
            break
        fi
    done

    # Loop through targets and copy .scm files
    for target in $targets; do
        name=${lang##*/}

        if [ "$count" -eq 1 ] || [ "$same" -eq 1 ]; then
            mkdir -p "$RESOURCES_PATH/$name"
        else
            mkdir -p "$RESOURCES_PATH/$target"
        fi

        highlights=$( find "$lang/$target" -type f -name "*.scm" 2>/dev/null || true )
        for highlight in $highlights ; do
            highlight_name=${highlight##*/}

            if [ "$count" -eq 1 ] || [ "$same" -eq 1 ]; then
                cp -f "$highlight" "$RESOURCES_PATH/$name/$highlight_name"
            else
                cp -f "$highlight" "$RESOURCES_PATH/$target/$highlight_name"
            fi
        done

        # If target paths are all '.', only process once
        if [ "$same" -eq 1 ]; then
            break
        fi
    done

    cd "$OLDPWD"
done

status "Language queries copied from grammar checkouts!"

# Fill in missing queries from nvim-treesitter submodule
status "Copying missing queries from nvim-treesitter..."

LICENSE_NOTICE='; Copyright 2025 nvim-treesitter
;
; Licensed under the Apache License, Version 2.0 (the "License");
; you may not use this file except in compliance with the License.
; You may obtain a copy of the License at
;
;     http://www.apache.org/licenses/LICENSE-2.0
;
; Unless required by applicable law or agreed to in writing, software
; distributed under the License is distributed on an "AS IS" BASIS,
; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
; See the License for the specific language governing permissions and
; limitations under the License.

'

for lang in $LIST ; do
    # Convert tree-sitter-foo to foo (with hyphens replaced by underscores)
    lang_trim=${lang##*/}
    lang_trim="${lang_trim#tree-sitter-}"
    lang_trim=$(printf '%s' "$lang_trim" | tr '-' '_')

    TARGET_DIR="$RESOURCES_PATH/${lang##*/}"
    SRC_DIR="$NVIM_TS_PATH/$lang_trim"

    if [ ! -d "$SRC_DIR" ]; then
        continue
    fi

    # Copy .scm files that don't already exist
    find "$SRC_DIR" -type f -name "*.scm" | while IFS= read -r src_file; do
        filename=$(basename "$src_file")
        dest_file="$TARGET_DIR/$filename"

        if [ ! -e "$dest_file" ]; then
            echo "  Copying $dest_file"
            echo "$LICENSE_NOTICE" > "$dest_file"
            cat "$src_file" >> "$dest_file"
        fi
    done
done

status "Missing queries added from nvim-treesitter!"

# Patch Swift queries for bundled grammar compatibility
# nvim-treesitter targets a different version of tree-sitter-swift than what's
# bundled via SwiftTreeSitter, so some node types are missing.
SWIFT_RESOURCES="$RESOURCES_PATH/tree-sitter-swift"
if [ -d "$SWIFT_RESOURCES" ]; then
    chmod u+w "$SWIFT_RESOURCES"/*.scm
    for scm_file in "$SWIFT_RESOURCES"/*.scm; do
        [ -f "$scm_file" ] || continue
        python3 -c "
import re, sys

with open(sys.argv[1]) as f:
    text = f.read()

# Node types that exist in nvim-treesitter's queries but not in our bundled grammar
remove = {'init_declaration', 'willset_didset_block', 'willset_clause', 'didset_clause'}

# Remove single-line references inside lists
for node in remove:
    text = re.sub(r'^\s*\(' + node + r'\).*\n', '', text, flags=re.MULTILINE)

# Remove multi-line top-level S-expressions starting with a removed node type
for node in remove:
    pattern = r'^(\(' + node + r'\b)'
    while re.search(pattern, text, re.MULTILINE):
        match = re.search(pattern, text, re.MULTILINE)
        start = match.start()
        depth = 0
        i = start
        while i < len(text):
            if text[i] == '(':
                depth += 1
            elif text[i] == ')':
                depth -= 1
                if depth == 0:
                    break
            i += 1
        end = text.index('\n', i) + 1 if '\n' in text[i:] else len(text)
        line_start = text.rfind('\n', 0, start)
        if line_start == -1:
            line_start = 0
        else:
            line_start += 1
        prev_end = line_start
        prev_start = text.rfind('\n', 0, max(0, prev_end - 1))
        if prev_start == -1:
            prev_start = 0
        else:
            prev_start += 1
        prev_line = text[prev_start:prev_end].rstrip()
        if prev_line.startswith(';') and node.replace('_', ' ') in prev_line.lower():
            start = prev_start
        text = text[:start] + text[end:]

text = re.sub(r'\n{3,}', '\n\n', text)

with open(sys.argv[1], 'w') as f:
    f.write(text)
" "$scm_file"
    done

    echo "  Patched Swift queries for bundled grammar compatibility"
fi

# Patch OCaml highlights for OCaml Interface compatibility
# The (shebang) node exists in the OCaml grammar but not in OCaml Interface,
# and both share the same highlights.scm via tsName "ocaml".
OCAML_HIGHLIGHTS="$RESOURCES_PATH/tree-sitter-ocaml/highlights.scm"
if [ -f "$OCAML_HIGHLIGHTS" ]; then
    sed -i '' 's/(shebang) //' "$OCAML_HIGHLIGHTS"
    echo "  Patched OCaml highlights for OCaml Interface compatibility"
fi

status "Done!"
