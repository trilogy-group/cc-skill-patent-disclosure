#!/usr/bin/env bash
# Extract every Mermaid block from a markdown file and validate each with mmdc.
# Used by Phase 3 (post-generation diagram presence check) and Phase 4 (per-round
# mechanized validation) of the patent-disclosure skill.
#
# Usage:
#   bash qc-validate-mermaid.sh <disclosure.md> [<output-dir>]
#
# Output:
#   - <output-dir>/block_NN.mmd  : extracted Mermaid sources
#   - <output-dir>/block_NN.svg  : rendered SVGs (when validation passes)
#   - <output-dir>/failures.txt  : newline-separated list of blocks that failed
#   - <output-dir>/summary.json  : { "total": N, "passed": M, "failed": K }
#
# Exit code:
#   0 = all blocks parse (or no blocks found)
#   2 = at least one block failed to render
#   1 = usage / IO error

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <disclosure.md> [<output-dir>]" >&2
    exit 1
fi

DISCLOSURE="$1"
OUT_DIR="${2:-$(dirname "$DISCLOSURE")/mermaid-check}"

if [ ! -f "$DISCLOSURE" ]; then
    echo "Error: file not found: $DISCLOSURE" >&2
    exit 1
fi

if ! command -v mmdc &> /dev/null; then
    echo "Error: mmdc (mermaid-cli) not found. Run: bash scripts/setup.sh" >&2
    exit 1
fi

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

# Extract every ```mermaid ... ``` block into a separate .mmd file
awk -v out_dir="$OUT_DIR" '
    /^```mermaid$/ { in_block=1; idx++; out=sprintf("%s/block_%02d.mmd", out_dir, idx); next }
    /^```$/        { if (in_block) in_block=0; next }
    in_block       { print > out }
' "$DISCLOSURE"

TOTAL=0
PASSED=0
FAILED=0
> "$OUT_DIR/failures.txt"

for f in "$OUT_DIR"/block_*.mmd; do
    [ -f "$f" ] || continue
    TOTAL=$((TOTAL + 1))
    if mmdc -i "$f" -o "${f%.mmd}.svg" --quiet 2>/dev/null; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
        basename "$f" >> "$OUT_DIR/failures.txt"
    fi
done

cat > "$OUT_DIR/summary.json" <<JSON
{"total": ${TOTAL}, "passed": ${PASSED}, "failed": ${FAILED}}
JSON

echo "[mermaid-validate] total=${TOTAL} passed=${PASSED} failed=${FAILED}"
[ "$FAILED" -gt 0 ] && exit 2 || exit 0
