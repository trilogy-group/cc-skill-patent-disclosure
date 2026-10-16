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

# mmdc drives headless Chrome through Puppeteer. On Linux CI containers, Docker images running as
# root, and VMs without user namespaces, Chrome cannot start its sandbox and mmdc dies inside
# @puppeteer/browsers. The disclosure then fails this gate for a reason that has nothing to do with
# the diagram, and because the per-block error used to be sent to /dev/null, the only symptom was
# "blocks fail to render". Every mermaid block of the repo's own good fixture failed this way.
#
# So: probe once with a trivial diagram. If plain mmdc works, change nothing - a machine that CAN
# sandbox keeps sandboxing. Only if the probe fails do we retry with the sandbox off, and only then
# is the flag used for the real blocks.
PUPPETEER_CFG=""
probe_mmdc () {
    local probe_dir probe_rc
    probe_dir=$(mktemp -d)
    printf 'graph TD\n  A[a] --> B[b]\n' > "$probe_dir/probe.mmd"
    if mmdc -i "$probe_dir/probe.mmd" -o "$probe_dir/probe.svg" --quiet >/dev/null 2>&1; then
        rm -rf "$probe_dir"; return 0
    fi
    printf '{"args":["--no-sandbox","--disable-setuid-sandbox"]}\n' > "$probe_dir/puppeteer.json"
    if mmdc -i "$probe_dir/probe.mmd" -o "$probe_dir/probe.svg" -p "$probe_dir/puppeteer.json" \
            --quiet >/dev/null 2>&1; then
        PUPPETEER_CFG="$probe_dir/puppeteer.json"
        echo "[mermaid-validate] Chrome cannot sandbox here; rendering with --no-sandbox." >&2
        return 0
    fi
    rm -rf "$probe_dir"
    echo "[mermaid-validate] mmdc cannot render even a trivial diagram, with or without the" >&2
    echo "[mermaid-validate] sandbox. This is an environment problem, not a problem with your" >&2
    echo "[mermaid-validate] diagrams. The error from the attempt follows:" >&2
    mmdc -i /dev/null -o /dev/null 2>&1 | tail -5 >&2
    return 1
}
probe_mmdc || true

run_mmdc () {
    if [ -n "$PUPPETEER_CFG" ]; then
        mmdc -i "$1" -o "$2" -p "$PUPPETEER_CFG" --quiet
    else
        mmdc -i "$1" -o "$2" --quiet
    fi
}

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
    # The error is KEPT, next to the block it came from. Sending it to /dev/null is why a pure
    # environment failure looked like six bad diagrams for months.
    if run_mmdc "$f" "${f%.mmd}.svg" 2>"${f%.mmd}.err"; then
        PASSED=$((PASSED + 1))
        rm -f "${f%.mmd}.err"
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
