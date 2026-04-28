#!/usr/bin/env bash
# Structural validator for a patent-disclosure artifact pair (ids.json + disclosure.md).
# Used by Phase 3 fail-fast checks AND the smoke-test fixture.
#
# Usage:
#   bash disclosure-validate.sh <disclosure-dir>
#
# Checks:
#   - ids.json validates against ids-schema.json (best-effort: shape + required fields)
#   - disclosure.md exists and is non-empty
#   - All 13 canonical sections are present in IDS or marked not_applicable
#   - Mandated diagrams are present in §6 (3), §9 (1), §10 (1)
#   - No duplicate H2 headers in disclosure.md
#   - No `DIAGRAM_BLOCKED:` sentinel left over (means generator gave up)
#   - Mermaid blocks all parse under mmdc (delegates to qc-validate-mermaid.sh)
#   - Section line counts: warn if any section > 800 lines
#
# Exit codes:
#   0 = pass
#   1 = usage / IO error
#   2 = validation failure (one or more checks failed)

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <disclosure-dir>" >&2
    exit 1
fi

DIR="$1"
IDS="$DIR/ids.json"
DISC="$DIR/disclosure.md"

[ -f "$IDS" ]  || { echo "FAIL: ids.json missing"; exit 2; }
[ -f "$DISC" ] || { echo "FAIL: disclosure.md missing"; exit 2; }
[ -s "$DISC" ] || { echo "FAIL: disclosure.md empty"; exit 2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA="${SCRIPT_DIR}/../skills/patent-disclosure/ids-schema.json"

PASS=0; FAIL=0; WARN=0
report_pass() { echo "  PASS: $1"; PASS=$((PASS+1)); }
report_fail() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }
report_warn() { echo "  WARN: $1"; WARN=$((WARN+1)); }

echo "=== Validating $DIR ==="

# 1. IDS structural validity
python3 - "$IDS" "$SCHEMA" <<'PY' && report_pass "ids.json shape" || report_fail "ids.json shape"
import json, sys
ids_path, schema_path = sys.argv[1], sys.argv[2]
ids    = json.load(open(ids_path))
schema = json.load(open(schema_path))
required = schema.get('required', [])
missing  = [f for f in required if f not in ids]
if missing:
    print(f"    missing required top-level fields: {missing}", file=sys.stderr); sys.exit(1)
sys.exit(0)
PY

# 2. All 13 canonical sections present (or not_applicable)
CANONICAL=(executive_summary novelty context problems_solved introduction what_and_how case_studies pseudocode data_structures implementation alternatives prior_art claims)
python3 - "$IDS" "${CANONICAL[@]}" <<'PY' && report_pass "all 13 canonical sections present" || report_fail "canonical section coverage"
import json, sys
ids_path = sys.argv[1]
canonical = sys.argv[2:]
ids = json.load(open(ids_path))
present = {s.get('id') for s in ids.get('sections', [])}
missing = [c for c in canonical if c not in present]
if missing:
    print(f"    missing sections: {missing}", file=sys.stderr); sys.exit(1)
PY

# 3. Mandated diagrams (counts in disclosure.md per section)
python3 - "$DISC" <<'PY' && report_pass "mandated diagram counts (§6 ≥3, §9 ≥1, §10 ≥1)" || report_fail "mandated diagrams"
import re, sys
text = open(sys.argv[1]).read()
# Split on h2 headers; keep header → body mapping
parts = re.split(r'(?m)^## (.+)$', text)
# parts = [pre, h2_1, body_1, h2_2, body_2, ...]
sections = {}
for i in range(1, len(parts), 2):
    sections.setdefault(parts[i].strip(), '')
    sections[parts[i].strip()] += parts[i+1] if i+1 < len(parts) else ''
def count_mermaid(name_substring_matchers):
    for name in sections:
        if any(m.lower() in name.lower() for m in name_substring_matchers):
            return sections[name].count('```mermaid')
    return 0
what_how = count_mermaid(['what it does', 'how it works', 'what & how', 'what and how'])
data_struct = count_mermaid(['data structures'])
impl = count_mermaid(['implementation'])
fail = []
if what_how < 3: fail.append(f"§6 What It Does has {what_how} diagrams (need ≥3)")
if data_struct < 1: fail.append(f"§9 Data Structures has {data_struct} diagrams (need ≥1)")
if impl < 1: fail.append(f"§10 Implementation has {impl} diagrams (need ≥1)")
if fail:
    for f in fail: print(f"    {f}", file=sys.stderr)
    sys.exit(1)
PY

# 4. No duplicate H2 headers
DUPS=$(grep -E '^## ' "$DISC" | sort | uniq -d || true)
if [ -z "$DUPS" ]; then report_pass "no duplicate H2 headers"; else
    echo "    duplicate H2 headers found:"
    echo "$DUPS" | sed 's/^/      /'
    report_fail "duplicate H2 headers"
fi

# 5. No DIAGRAM_BLOCKED sentinels left over
if grep -q 'DIAGRAM_BLOCKED:' "$DISC"; then
    report_fail "DIAGRAM_BLOCKED sentinel still present (generator gave up on a required diagram)"
else
    report_pass "no DIAGRAM_BLOCKED sentinels"
fi

# 6. Mermaid blocks parse
if command -v mmdc &> /dev/null; then
    TMP=$(mktemp -d)
    if bash "${SCRIPT_DIR}/qc-validate-mermaid.sh" "$DISC" "$TMP" >/dev/null 2>&1; then
        TOTAL=$(python3 -c "import json; print(json.load(open('$TMP/summary.json'))['total'])")
        report_pass "all $TOTAL mermaid blocks render"
    else
        FAILS=$(cat "$TMP/failures.txt" 2>/dev/null | tr '\n' ' ')
        report_fail "mermaid blocks fail to render: $FAILS"
    fi
    rm -rf "$TMP"
else
    report_warn "mmdc not found; skipping mermaid render check"
fi

# 7. Section line-length warnings (>800 lines)
python3 - "$DISC" <<'PY'
import re, sys
text = open(sys.argv[1]).read()
parts = re.split(r'(?m)^(## .+)$', text)
for i in range(1, len(parts), 2):
    name = parts[i].strip()
    body = parts[i+1] if i+1 < len(parts) else ''
    lines = body.count('\n')
    if lines > 800:
        print(f"  WARN: section '{name}' is {lines} lines (>800; consider compression)")
PY

echo ""
echo "=== Result: pass=$PASS fail=$FAIL warn=$WARN ==="
[ "$FAIL" -gt 0 ] && exit 2 || exit 0
