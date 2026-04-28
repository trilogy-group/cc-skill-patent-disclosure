#!/usr/bin/env bash
# Append a structured telemetry entry to ~/.cache/patent-disclosure/runs.jsonl.
# The skill calls this at phase boundaries to capture timing, token counts, and
# outcome metadata so users can see where their budget went and tune the loop.
#
# Usage:
#   bash log-run.sh \
#     --slug <invention-slug> \
#     --phase <phase_1|phase_2|phase_3|phase_4|phase_5|qc_round> \
#     --event <start|end|note> \
#     [--tokens <N>] \
#     [--duration-ms <N>] \
#     [--data <json-string>]   # arbitrary additional JSON, merged into the entry
#
# The log file is JSONL: one JSON object per line, one entry per call.
#
# Examples:
#   log-run.sh --slug foo --phase phase_4 --event start
#   log-run.sh --slug foo --phase qc_round --event end --tokens 423000 --duration-ms 87000 --data '{"round":1,"agents":6}'

set -euo pipefail

LOG_DIR="${HOME}/.cache/patent-disclosure"
LOG_FILE="${LOG_DIR}/runs.jsonl"
mkdir -p "$LOG_DIR"

SLUG=""
PHASE=""
EVENT=""
TOKENS=""
DURATION=""
DATA=""

while [ $# -gt 0 ]; do
    case "$1" in
        --slug)        SLUG="$2"; shift 2 ;;
        --phase)       PHASE="$2"; shift 2 ;;
        --event)       EVENT="$2"; shift 2 ;;
        --tokens)      TOKENS="$2"; shift 2 ;;
        --duration-ms) DURATION="$2"; shift 2 ;;
        --data)        DATA="$2"; shift 2 ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
    esac
done

[ -n "$SLUG" ]  || { echo "Error: --slug required" >&2; exit 1; }
[ -n "$PHASE" ] || { echo "Error: --phase required" >&2; exit 1; }
[ -n "$EVENT" ] || { echo "Error: --event required" >&2; exit 1; }

# Build the JSON entry.
TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
PLUGIN_VERSION="$(python3 -c "import json,sys; print(json.load(open('$(dirname "${BASH_SOURCE[0]}")/../.claude-plugin/plugin.json'))['version'])" 2>/dev/null || echo "unknown")"

python3 - <<PY >> "$LOG_FILE"
import json, os
entry = {
    "ts":       "${TS}",
    "version":  "${PLUGIN_VERSION}",
    "slug":     "${SLUG}",
    "phase":    "${PHASE}",
    "event":    "${EVENT}",
    "cwd":      os.getcwd(),
}
tokens   = "${TOKENS}".strip()
duration = "${DURATION}".strip()
data_str = """${DATA}""".strip()
if tokens:   entry["tokens"]      = int(tokens)
if duration: entry["duration_ms"] = int(duration)
if data_str:
    try:
        extra = json.loads(data_str)
        if isinstance(extra, dict):
            entry.update(extra)
        else:
            entry["data"] = extra
    except json.JSONDecodeError:
        entry["data_raw"] = data_str
print(json.dumps(entry))
PY
