#!/usr/bin/env bash
# Render Mermaid diagrams to images, then export to Google Docs via gogcli
#
# Usage:
#   bash scripts/render-and-export.sh patent-disclosures/<slug>/disclosure.md
#   bash scripts/render-and-export.sh patent-disclosures/<slug>/disclosure.md --account you@company.com
#   bash scripts/render-and-export.sh patent-disclosures/<slug>/disclosure.md --folder-id <ID>
#
# Prerequisites (run `bash scripts/setup.sh` to configure all of these):
#   npm install -g @mermaid-js/mermaid-cli   (provides mmdc)
#   brew install gogcli                       (provides gog)
#   gog login <your-email>                    (one-time OAuth; opens browser)

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <disclosure.md> [--folder-id <ID>] [--account <email>]"
    exit 1
fi

DISCLOSURE_FILE="$1"
shift

if [ ! -f "$DISCLOSURE_FILE" ]; then
    echo "Error: File not found: $DISCLOSURE_FILE"
    exit 1
fi

# Check dependencies
if ! command -v mmdc &> /dev/null; then
    echo "Error: mmdc (mermaid-cli) not found. Install with: npm install -g @mermaid-js/mermaid-cli"
    exit 1
fi
SETUP_SCRIPT="$(dirname "${BASH_SOURCE[0]}")/setup.sh"
if ! command -v gog &> /dev/null; then
    echo "Error: gog (gogcli) not found — required for publishing to Google Docs."
    echo "       Run: bash ${SETUP_SCRIPT}"
    echo "       or:  brew install gogcli"
    exit 1
fi
if ! gog auth list --json 2>/dev/null | grep -q '"email"'; then
    echo "Error: gogcli has no authorized Google account."
    echo "       Run: gog login <your-email>"
    echo "       or:  bash ${SETUP_SCRIPT}   (walks through sign-in)"
    exit 1
fi

# Parse optional flags
FOLDER_ID=""
ACCOUNT=""
while [ $# -gt 0 ]; do
    case "$1" in
        --folder-id) FOLDER_ID="$2"; shift 2 ;;
        --account)   ACCOUNT="$2"; shift 2 ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
done

# Create temp working directory
WORK_DIR=$(mktemp -d)
DISCLOSURE_DIR=$(dirname "$DISCLOSURE_FILE")
DIAGRAMS_DIR="$WORK_DIR/diagrams"
mkdir -p "$DIAGRAMS_DIR"

echo "=== Rendering Mermaid diagrams ==="

# Extract and render each mermaid block
DIAGRAM_INDEX=0
IN_MERMAID=false
MERMAID_CONTENT=""

while IFS= read -r line; do
    if [[ "$line" == '```mermaid' ]]; then
        IN_MERMAID=true
        MERMAID_CONTENT=""
        continue
    fi

    if $IN_MERMAID; then
        if [[ "$line" == '```' ]]; then
            IN_MERMAID=false
            DIAGRAM_INDEX=$((DIAGRAM_INDEX + 1))
            MERMAID_FILE="$DIAGRAMS_DIR/diagram_${DIAGRAM_INDEX}.mmd"
            PNG_FILE="$DIAGRAMS_DIR/diagram_${DIAGRAM_INDEX}.png"

            echo "$MERMAID_CONTENT" > "$MERMAID_FILE"

            echo "  Rendering diagram ${DIAGRAM_INDEX}..."
            if mmdc -i "$MERMAID_FILE" -o "$PNG_FILE" -w 1200 -b transparent --quiet 2>/dev/null; then
                echo "    OK: diagram_${DIAGRAM_INDEX}.png"
            else
                echo "    WARN: diagram_${DIAGRAM_INDEX} failed to render, will keep as code block"
                rm -f "$PNG_FILE"
            fi
        else
            MERMAID_CONTENT="${MERMAID_CONTENT}${line}
"
        fi
    fi
done < "$DISCLOSURE_FILE"

echo "  Rendered ${DIAGRAM_INDEX} diagrams"

# Now build the output markdown with images replacing mermaid blocks
echo "=== Building export markdown ==="
OUTPUT_FILE="$WORK_DIR/disclosure-export.md"

IN_MERMAID=false
CURRENT_DIAGRAM=0

while IFS= read -r line; do
    if [[ "$line" == '```mermaid' ]]; then
        IN_MERMAID=true
        CURRENT_DIAGRAM=$((CURRENT_DIAGRAM + 1))
        PNG_FILE="$DIAGRAMS_DIR/diagram_${CURRENT_DIAGRAM}.png"

        if [ -f "$PNG_FILE" ]; then
            # Replace mermaid block with image reference
            echo "![Diagram ${CURRENT_DIAGRAM}](diagrams/diagram_${CURRENT_DIAGRAM}.png)" >> "$OUTPUT_FILE"
        else
            # Keep the code block if rendering failed
            echo '```mermaid' >> "$OUTPUT_FILE"
        fi
        continue
    fi

    if $IN_MERMAID; then
        if [[ "$line" == '```' ]]; then
            IN_MERMAID=false
            PNG_FILE="$DIAGRAMS_DIR/diagram_${CURRENT_DIAGRAM}.png"
            if [ ! -f "$PNG_FILE" ]; then
                echo '```' >> "$OUTPUT_FILE"
            fi
        else
            PNG_FILE="$DIAGRAMS_DIR/diagram_${CURRENT_DIAGRAM}.png"
            if [ ! -f "$PNG_FILE" ]; then
                echo "$line" >> "$OUTPUT_FILE"
            fi
        fi
    else
        echo "$line" >> "$OUTPUT_FILE"
    fi
done < "$DISCLOSURE_FILE"

echo "  Output: $OUTPUT_FILE"

# Extract title
TITLE=$(head -5 "$OUTPUT_FILE" | grep "^# " | head -1 | sed 's/^# //')
if [ -z "$TITLE" ]; then
    TITLE="Patent Disclosure — $(basename "$DISCLOSURE_DIR")"
fi

# Build gog args
GOG_ARGS=()
if [ -n "$ACCOUNT" ]; then
    GOG_ARGS+=("--account" "$ACCOUNT")
fi
if [ -n "$FOLDER_ID" ]; then
    GOG_ARGS+=("--parent" "$FOLDER_ID")
fi

echo ""
echo "=== Creating Google Doc ==="
echo "Title: $TITLE"
echo ""

gog docs create "$TITLE" --file="$OUTPUT_FILE" "${GOG_ARGS[@]}" --json

echo ""
echo "Done. Diagrams rendered as images in the Google Doc."

# Cleanup
rm -rf "$WORK_DIR"
