#!/usr/bin/env bash
# Re-run the multi-agent QC loop on an existing disclosure WITHOUT regenerating
# from scratch. Accepts either:
#   - A local disclosure directory containing disclosure.md (+ ids.json optional)
#   - A Google Doc URL or doc ID — exported via gog and stubbed into a workspace
#
# Usage:
#   bash qc-rerun.sh <local-dir | google-doc-url | doc-id> [--account <email>] [--workspace <dir>]
#
# What this script does:
#   1. Resolves the input to a working directory under <workspace>/<slug>/
#   2. If the input was a Google Doc, exports it to disclosure.md
#   3. If ids.json is missing, synthesizes a stub from the disclosure markdown
#      (extracts title from H1; populates 13 canonical sections with empty answers)
#   4. Sets up qc-rounds/round-0 baseline and prints a JSON manifest the
#      orchestrator (Claude / SKILL.md Phase 4) consumes to launch the QC loop.
#
# After this script runs, the SKILL.md QC-only mode (see "QC-Only Mode" section)
# launches the six critic agents + Writer against the workspace, then re-renders
# diagrams and publishes a [QC v2] Google Doc via render-and-export.sh.

set -euo pipefail

if [ $# -lt 1 ]; then
    cat <<'USAGE' >&2
Usage: qc-rerun.sh <input> [--account <email>] [--workspace <dir>]

Input can be:
  - A local directory containing disclosure.md (e.g. patent-disclosures/foo)
  - A Google Doc URL (https://docs.google.com/document/d/<ID>/edit...)
  - A bare Google Doc ID
USAGE
    exit 1
fi

INPUT="$1"
shift

ACCOUNT=""
WORKSPACE="${PWD}/patent-disclosures"

while [ $# -gt 0 ]; do
    case "$1" in
        --account)   ACCOUNT="$2"; shift 2 ;;
        --workspace) WORKSPACE="$2"; shift 2 ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
    esac
done

mkdir -p "$WORKSPACE"

slugify() {
    # Lowercase, replace non-alnum with -, collapse, trim
    echo "$1" | tr '[:upper:]' '[:lower:]' \
              | tr -c 'a-z0-9' '-' \
              | sed -E 's/-+/-/g; s/^-+//; s/-+$//' \
              | cut -c1-60
}

extract_doc_id() {
    local s="$1"
    # If it's a URL, extract the ID
    if [[ "$s" == http*docs.google.com* ]]; then
        echo "$s" | sed -E 's#.*/document/d/([a-zA-Z0-9_-]+).*#\1#'
    elif [[ "$s" =~ ^[a-zA-Z0-9_-]{20,}$ ]]; then
        # Looks like a bare doc ID
        echo "$s"
    else
        echo ""
    fi
}

# --- Mode A: local directory ---
if [ -d "$INPUT" ] && [ -f "$INPUT/disclosure.md" ]; then
    SOURCE="local"
    SLUG="$(basename "$INPUT")"
    WORK_DIR="$WORKSPACE/${SLUG}-qc-rerun"
    mkdir -p "$WORK_DIR/qc-rounds/round-0"
    cp "$INPUT/disclosure.md" "$WORK_DIR/disclosure.md"
    if [ -f "$INPUT/ids.json" ]; then
        cp "$INPUT/ids.json" "$WORK_DIR/ids.json"
    fi
# --- Mode B: Google Doc URL or ID ---
else
    DOC_ID="$(extract_doc_id "$INPUT")"
    if [ -z "$DOC_ID" ]; then
        echo "Error: input is neither a local disclosure directory nor a recognizable Google Doc URL/ID: $INPUT" >&2
        exit 1
    fi
    SOURCE="gdoc:$DOC_ID"

    if ! command -v gog &> /dev/null; then
        echo "Error: gogcli (gog) not found; required to export Google Doc input." >&2
        echo "       Run: bash $(dirname "${BASH_SOURCE[0]}")/setup.sh" >&2
        exit 1
    fi

    GOG_ACCOUNT_ARGS=()
    [ -n "$ACCOUNT" ] && GOG_ACCOUNT_ARGS=(--account "$ACCOUNT")

    TMP_DIR=$(mktemp -d)
    echo "[qc-rerun] Exporting Google Doc $DOC_ID via gog..."
    gog docs export "$DOC_ID" "${GOG_ACCOUNT_ARGS[@]}" --format md --output "$TMP_DIR/disclosure.md" >/dev/null

    # Title from first H1, fall back to doc ID
    TITLE=$(head -10 "$TMP_DIR/disclosure.md" | grep -m1 '^# ' | sed 's/^# //')
    [ -z "$TITLE" ] && TITLE="Disclosure $DOC_ID"
    SLUG=$(slugify "$TITLE")
    [ -z "$SLUG" ] && SLUG="qc-rerun-${DOC_ID:0:8}"

    WORK_DIR="$WORKSPACE/${SLUG}-qc-rerun"
    mkdir -p "$WORK_DIR/qc-rounds/round-0"
    cp "$TMP_DIR/disclosure.md" "$WORK_DIR/disclosure.md"
    rm -rf "$TMP_DIR"
fi

# --- Synthesize stub IDS if missing ---
if [ ! -f "$WORK_DIR/ids.json" ]; then
    echo "[qc-rerun] No ids.json — synthesizing stub from disclosure.md headers..."
    DISC="$WORK_DIR/disclosure.md" SLUG_VAL="$SLUG" python3 - "$WORK_DIR/ids.json" <<'PY'
import json, re, sys, os
out_path = sys.argv[1]
disc_path = os.environ['DISC']
slug = os.environ['SLUG_VAL']
text = open(disc_path).read()
m = re.search(r'^# (.+)$', text, re.M)
title = m.group(1).strip() if m else "Untitled (re-QC pass)"

canonical = [
    ("executive_summary","Executive Summary","What is this invention in 2 paragraphs that a busy executive can grasp?"),
    ("novelty","Novelty","What is genuinely new about this invention?"),
    ("context","Context and Environment","Where does this run, what depends on it, what assumptions does it make?"),
    ("problems_solved","Problems Solved","What concrete pain points does this invention eliminate?"),
    ("introduction","Introduction","What background does a reader need to follow the rest of the disclosure?"),
    ("what_and_how","What It Does and How It Works","End-to-end technical description of the mechanism with diagrams."),
    ("case_studies","Case Studies","Concrete walkthroughs showing the invention operating end-to-end."),
    ("pseudocode","Pseudocode","Language-agnostic algorithmic description of the novel steps."),
    ("data_structures","Data Structures","What data does the system manipulate and how is it organized?"),
    ("implementation","Implementation Details","Architecture decisions, ML/algorithmic specifics, tradeoffs."),
    ("alternatives","Alternatives & Comparison","Other approaches considered or in the field; why they fall short."),
    ("prior_art","Prior Art","Known related patents/papers/products and why this is distinct."),
    ("claims","Draft Patent Claims","Independent and dependent claims in patent format."),
]

ids = {
    "invention_title": title,
    "invention_slug":  slug or "qc-rerun",
    "inventors": [{"name":"<<INVENTOR TO COMPLETE>>","contribution":"Re-QC pass — original IDS not available; must be supplied before filing per 35 USC 115."}],
    "created_date": "1970-01-01",  # orchestrator overwrites
    "novelty_statement": "(Stub — to be re-derived from the disclosure body during the QC loop.)",
    "metadata": {
        "key_files": [],
        "qc_max_rounds": 3,
        "qc_notes": "Re-QC pass on existing disclosure. Original IDS not available; this stub IDS was synthesized from the disclosure markdown."
    },
    "sections": [{"id":i,"name":n,"question":q,"status":"draft","answer":""} for (i,n,q) in canonical]
}
open(out_path,'w').write(json.dumps(ids, indent=2))
print(f"  Stub IDS written: title='{title}', slug='{ids['invention_slug']}'", file=sys.stderr)
PY
fi

# --- Snapshot baseline + emit manifest ---
cp "$WORK_DIR/ids.json"      "$WORK_DIR/qc-rounds/round-0/ids.json"
cp "$WORK_DIR/disclosure.md" "$WORK_DIR/qc-rounds/round-0/disclosure.md"

cat > "$WORK_DIR/qc-rerun-manifest.json" <<JSON
{
  "mode": "qc_only",
  "source": "${SOURCE}",
  "slug": "${SLUG}",
  "work_dir": "${WORK_DIR}",
  "ids_path": "${WORK_DIR}/ids.json",
  "disclosure_path": "${WORK_DIR}/disclosure.md",
  "account": "${ACCOUNT}",
  "ready_for_phase_4": true
}
JSON

echo ""
echo "[qc-rerun] Workspace ready: $WORK_DIR"
echo "[qc-rerun] Manifest: $WORK_DIR/qc-rerun-manifest.json"
echo "[qc-rerun] Hand off to SKILL.md QC-Only Mode (Phase 4 starting at round 1)."
