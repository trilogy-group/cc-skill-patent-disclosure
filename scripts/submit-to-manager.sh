#!/usr/bin/env bash
# Push a generated disclosure into the Patents Manager web app.
#
#   bash scripts/submit-to-manager.sh patent-disclosures/<slug>/
#
# Required env (or in ~/.config/patents-manager.json):
#   PATENTS_API_URL      e.g. https://patents.alpha.school
#   PATENTS_API_TOKEN    pmt_<token> from <app>/settings/tokens
#
# What it does:
#   1. Resolves the slug + ids.json + final disclosure-export.md from the
#      passed disclosure directory.
#   2. Calls GET /api/v1/disclosures/lookup?plugin_slug=<slug> — if the
#      manager already has a row, we PATCH it. Otherwise we POST a new one.
#   3. Idempotent: re-running the plugin against the same invention is a
#      no-op (just refreshes link/qc fields) — never creates duplicates.
#   4. Prints the manager URL so users / parent agents can open it.
#
# Configuration helpers:
#   - Pass --account/--folder-id-style flags via env if needed; they aren't
#     required because the API authenticates via the bearer token, not gog.
#   - To skip submission for any reason, set PATENTS_SUBMIT_SKIP=1.

set -euo pipefail

if [ "${PATENTS_SUBMIT_SKIP:-0}" = "1" ]; then
    echo "[submit-to-manager] PATENTS_SUBMIT_SKIP=1 — not submitting."
    exit 0
fi

if [ $# -lt 1 ]; then
    cat <<'USAGE' >&2
Usage: submit-to-manager.sh <disclosure-dir> [--gdoc-url <url>] [--qc-trail-url <url>] [--qc-outcome <publish|publish_with_caveats|hold>]

  <disclosure-dir>   patent-disclosures/<slug>/  — directory containing ids.json
                     and (ideally) the published Google Doc URL.

  --gdoc-url URL     The published Google Doc URL. If omitted, the script
                     looks for a single line containing "Google Doc:" or
                     "→ Google Doc" in qc-trail.md / disclosure.md.
  --qc-trail-url URL Optional separate Doc URL for the QC trail.
  --qc-outcome OUT   publish | publish_with_caveats | hold (default: publish).
USAGE
    exit 1
fi

DIR="$1"; shift
GDOC_URL=""; QC_TRAIL_URL=""; QC_OUTCOME="publish"

while [ $# -gt 0 ]; do
    case "$1" in
        --gdoc-url)      GDOC_URL="$2"; shift 2 ;;
        --qc-trail-url)  QC_TRAIL_URL="$2"; shift 2 ;;
        --qc-outcome)    QC_OUTCOME="$2"; shift 2 ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
    esac
done

[ -d "$DIR" ] || { echo "Error: $DIR is not a directory"; exit 1; }
IDS="$DIR/ids.json"
[ -f "$IDS" ] || { echo "Error: $IDS not found"; exit 1; }

# --- Load credentials ---------------------------------------------------------

CONFIG_FILE="${HOME}/.config/patents-manager.json"
if [ -z "${PATENTS_API_URL:-}" ] && [ -f "$CONFIG_FILE" ]; then
    PATENTS_API_URL=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('api_url',''))" "$CONFIG_FILE" 2>/dev/null || echo "")
fi
if [ -z "${PATENTS_API_TOKEN:-}" ] && [ -f "$CONFIG_FILE" ]; then
    PATENTS_API_TOKEN=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('api_token',''))" "$CONFIG_FILE" 2>/dev/null || echo "")
fi

if [ -z "${PATENTS_API_URL:-}" ] || [ -z "${PATENTS_API_TOKEN:-}" ]; then
    cat >&2 <<MSG
[submit-to-manager] Patents Manager credentials not configured. To enable
auto-submission, set these and re-run:

    export PATENTS_API_URL=https://patents.alpha.school
    export PATENTS_API_TOKEN=pmt_<get-from-/settings/tokens>

Or save them once to ${CONFIG_FILE}:

    {"api_url":"https://patents.alpha.school","api_token":"pmt_..."}

This is OPTIONAL — if you skip it, the rest of the plugin still works
(the Google Doc gets published; you just need to add the disclosure to
the manager manually).
MSG
    exit 0
fi

API_BASE="${PATENTS_API_URL%/}/api/v1"
AUTH="Authorization: Bearer ${PATENTS_API_TOKEN}"

# --- Extract metadata from ids.json + disclosure files ------------------------

# Pull title, slug, BU, inventors, and project from ids.json.
read_ids() {
    python3 - "$IDS" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
title  = d.get("invention_title") or "(Untitled)"
slug   = d.get("invention_slug") or ""
# BU isn't typically in ids.json — fall back to PATENTS_DEFAULT_BU env or "CNU".
import os
bu = os.environ.get("PATENTS_DEFAULT_BU", "CNU")
inventors = []
for inv in (d.get("inventors") or []):
    name = inv.get("name") if isinstance(inv, dict) else None
    email = inv.get("email") if isinstance(inv, dict) else None
    inventors.append(email or name or "")
inventors = [i for i in inventors if i]
project = (d.get("metadata", {}) or {}).get("products", [None])[0] if isinstance(d.get("metadata"), dict) else None
print(json.dumps({"title": title, "slug": slug, "bu": bu, "inventors": inventors, "project": project}))
PY
}

META_JSON=$(read_ids)
TITLE=$(echo "$META_JSON" | python3 -c "import json,sys;print(json.load(sys.stdin)['title'])")
SLUG=$(echo "$META_JSON" | python3 -c "import json,sys;print(json.load(sys.stdin)['slug'])")
BU=$(echo "$META_JSON" | python3 -c "import json,sys;print(json.load(sys.stdin)['bu'])")

# If --gdoc-url not provided, try to find one in qc-trail.md (the trail script
# writes "Final Google Doc: <url>" near the top).
if [ -z "$GDOC_URL" ] && [ -f "$DIR/qc-trail.md" ]; then
    GDOC_URL=$(grep -m1 -E '^[[:space:]]*\*\*Final Google Doc:?\*\*' "$DIR/qc-trail.md" | sed -E 's/.*\*\*Final Google Doc:?\*\* *//; s/[[:space:]]*$//')
fi

if [ -z "$SLUG" ]; then
    echo "[submit-to-manager] ids.json is missing invention_slug — cannot key idempotently. Aborting." >&2
    exit 1
fi

# --- Body builder -------------------------------------------------------------

build_create_body() {
    INVENTORS_JSON="$META_JSON" TITLE="$TITLE" SLUG="$SLUG" BU="$BU" \
    GDOC_URL="$GDOC_URL" QC_TRAIL_URL="$QC_TRAIL_URL" QC_OUTCOME="$QC_OUTCOME" \
    IDS_FILE="$IDS" \
    python3 <<'PY'
import json, os
meta = json.loads(os.environ["INVENTORS_JSON"])
ids = json.load(open(os.environ["IDS_FILE"]))
body = {
    "business_unit":    os.environ["BU"],
    "disclosure_title": os.environ["TITLE"],
    "plugin_slug":      os.environ["SLUG"],
    "inventors":        meta.get("inventors") or [],
    "ids_json":         ids,
}
if os.environ.get("GDOC_URL"):     body["disclosure_link"] = os.environ["GDOC_URL"]
if os.environ.get("QC_TRAIL_URL"): body["qc_trail_link"]   = os.environ["QC_TRAIL_URL"]
if os.environ.get("QC_OUTCOME"):   body["qc_outcome"]      = os.environ["QC_OUTCOME"]
if meta.get("project"):            body["project"]         = meta["project"]
print(json.dumps(body))
PY
}

build_patch_body() {
    GDOC_URL="$GDOC_URL" QC_TRAIL_URL="$QC_TRAIL_URL" QC_OUTCOME="$QC_OUTCOME" python3 <<'PY'
import json, os
patch = {}
if os.environ.get("GDOC_URL"):     patch["disclosure_link"] = os.environ["GDOC_URL"]
if os.environ.get("QC_TRAIL_URL"): patch["qc_trail_link"]   = os.environ["QC_TRAIL_URL"]
if os.environ.get("QC_OUTCOME"):   patch["qc_outcome"]      = os.environ["QC_OUTCOME"]
print(json.dumps(patch))
PY
}

# --- Lookup, then POST or PATCH -----------------------------------------------

echo "[submit-to-manager] Looking up plugin_slug=${SLUG}…"
LOOKUP_RES=$(curl -sS -H "$AUTH" "${API_BASE}/disclosures/lookup?plugin_slug=$(python3 -c 'import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))' "$SLUG")")
EXISTING_ID=$(echo "$LOOKUP_RES" | python3 -c "import json,sys; d=json.load(sys.stdin); print((d.get('data') or {}).get('id') or '')")

if [ -n "$EXISTING_ID" ]; then
    echo "[submit-to-manager] Found existing disclosure ${EXISTING_ID} — patching."
    PATCH_BODY=$(build_patch_body)
    if [ "$PATCH_BODY" = "{}" ]; then
        echo "[submit-to-manager] Nothing to patch (no link/qc-outcome args). Done."
        FINAL_ID="$EXISTING_ID"
    else
        RESPONSE=$(curl -sS -w '\n%{http_code}' -X PATCH \
            -H "$AUTH" -H "Content-Type: application/json" \
            -d "$PATCH_BODY" \
            "${API_BASE}/disclosures/${EXISTING_ID}")
        CODE=$(echo "$RESPONSE" | tail -1); BODY=$(echo "$RESPONSE" | sed '$d')
        if [ "$CODE" != "200" ]; then
            echo "[submit-to-manager] PATCH failed (HTTP $CODE): $BODY" >&2
            exit 1
        fi
        FINAL_ID="$EXISTING_ID"
    fi
else
    echo "[submit-to-manager] No existing record — creating."
    CREATE_BODY=$(build_create_body)
    RESPONSE=$(curl -sS -w '\n%{http_code}' -X POST \
        -H "$AUTH" -H "Content-Type: application/json" \
        -d "$CREATE_BODY" \
        "${API_BASE}/disclosures")
    CODE=$(echo "$RESPONSE" | tail -1); BODY=$(echo "$RESPONSE" | sed '$d')
    if [ "$CODE" != "201" ] && [ "$CODE" != "200" ]; then
        echo "[submit-to-manager] POST failed (HTTP $CODE): $BODY" >&2
        exit 1
    fi
    FINAL_ID=$(echo "$BODY" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
fi

MANAGER_URL="${PATENTS_API_URL%/}/disclosures/${FINAL_ID}"
echo ""
echo "→ Patents Manager: ${MANAGER_URL}"
echo ""
