#!/usr/bin/env bash
# Export a patent disclosure to Google Docs using gogcli (gog)
#
# Usage:
#   bash scripts/export-to-gdocs.sh patent-disclosures/<slug>/disclosure.md
#   bash scripts/export-to-gdocs.sh patent-disclosures/<slug>/disclosure.md --folder-id <FOLDER_ID>
#   bash scripts/export-to-gdocs.sh patent-disclosures/<slug>/disclosure.md --account you@company.com
#
# Prerequisites (run `bash scripts/setup.sh` to configure all of these):
#   brew install gogcli         (or see https://github.com/tmc/gogcli)
#   gog login <your-email>      (one-time OAuth; opens browser)

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <disclosure.md> [--folder-id <ID>] [--account <email>]"
    echo ""
    echo "Examples:"
    echo "  $0 patent-disclosures/cascading-color-scoring/disclosure.md"
    echo "  $0 patent-disclosures/cascading-color-scoring/disclosure.md --folder-id 1abc..."
    echo "  $0 patent-disclosures/cascading-color-scoring/disclosure.md --account user@company.com"
    exit 1
fi

DISCLOSURE_FILE="$1"
shift

if [ ! -f "$DISCLOSURE_FILE" ]; then
    echo "Error: File not found: $DISCLOSURE_FILE"
    exit 1
fi

# Check for gog — gogcli is a hard prerequisite
SETUP_SCRIPT="$(dirname "${BASH_SOURCE[0]}")/setup.sh"
if ! command -v gog &> /dev/null; then
    echo "Error: gog (gogcli) is not installed — required for Google Docs publishing."
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

# Extract title from the first H1 heading
TITLE=$(head -5 "$DISCLOSURE_FILE" | grep "^# " | head -1 | sed 's/^# //')
if [ -z "$TITLE" ]; then
    TITLE="Patent Disclosure — $(basename "$(dirname "$DISCLOSURE_FILE")")"
fi

# Build gog command with optional flags
GOG_ARGS=()

# Parse remaining arguments
FOLDER_ID=""
ACCOUNT=""
while [ $# -gt 0 ]; do
    case "$1" in
        --folder-id)
            FOLDER_ID="$2"
            shift 2
            ;;
        --account)
            ACCOUNT="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

if [ -n "$ACCOUNT" ]; then
    GOG_ARGS+=("--account" "$ACCOUNT")
fi

if [ -n "$FOLDER_ID" ]; then
    GOG_ARGS+=("--parent" "$FOLDER_ID")
fi

echo "Creating Google Doc: \"$TITLE\""
echo "Source: $DISCLOSURE_FILE"
echo ""

gog docs create "$TITLE" --file="$DISCLOSURE_FILE" "${GOG_ARGS[@]}" --json

echo ""
echo "Done. The document is now in your Google Drive."
echo ""
echo "To also export the QC report:"
echo "  gog docs create \"QC Report — $(basename "$(dirname "$DISCLOSURE_FILE")")\" --file=\"$(dirname "$DISCLOSURE_FILE")/qc-report.md\""
