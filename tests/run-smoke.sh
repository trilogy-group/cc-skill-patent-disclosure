#!/usr/bin/env bash
# Plugin smoke test — verifies the structural validator behaves correctly on
# a known-good fixture and a known-bad fixture. Run this before every release.
#
# Usage:
#   bash tests/run-smoke.sh
#
# Exit:
#   0 = both fixtures behave as expected
#   1 = at least one fixture produced an unexpected result

set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

VALIDATOR="./scripts/disclosure-validate.sh"
GOOD="./tests/fixtures/good"
BAD="./tests/fixtures/bad"

[ -x "$VALIDATOR" ] || { echo "FAIL: validator not executable: $VALIDATOR"; exit 1; }
[ -d "$GOOD" ]      || { echo "FAIL: good fixture missing"; exit 1; }
[ -d "$BAD" ]       || { echo "FAIL: bad fixture missing"; exit 1; }

PASS=0; FAIL=0

echo "=== Smoke test: good fixture should PASS ==="
if bash "$VALIDATOR" "$GOOD" >/dev/null 2>&1; then
    echo "  PASS: good fixture validated as expected"
    PASS=$((PASS+1))
else
    echo "  FAIL: good fixture FAILED validation (it should have passed). Re-run with verbose:"
    bash "$VALIDATOR" "$GOOD" 2>&1 | sed 's/^/    /'
    FAIL=$((FAIL+1))
fi

echo ""
echo "=== Smoke test: bad fixture should FAIL ==="
if bash "$VALIDATOR" "$BAD" >/dev/null 2>&1; then
    echo "  FAIL: bad fixture PASSED validation (it should have failed). Re-run with verbose:"
    bash "$VALIDATOR" "$BAD" 2>&1 | sed 's/^/    /'
    FAIL=$((FAIL+1))
else
    echo "  PASS: bad fixture failed validation as expected"
    PASS=$((PASS+1))
fi

echo ""
echo "=== Smoke test: helper script syntax ==="
for s in scripts/setup.sh scripts/render-and-export.sh scripts/export-to-gdocs.sh \
         scripts/qc-validate-mermaid.sh scripts/qc-trail.sh scripts/disclosure-validate.sh \
         scripts/log-run.sh scripts/qc-rerun.sh; do
    if bash -n "$s" 2>/dev/null; then
        echo "  PASS: $s parses"; PASS=$((PASS+1))
    else
        echo "  FAIL: $s syntax error"; FAIL=$((FAIL+1))
    fi
done

echo ""
echo "=== Smoke test: JSON config parse ==="
for j in .claude-plugin/plugin.json .claude-plugin/marketplace.json skills/patent-disclosure/ids-schema.json; do
    if python3 -c "import json; json.load(open('$j'))" 2>/dev/null; then
        echo "  PASS: $j parses"; PASS=$((PASS+1))
    else
        echo "  FAIL: $j malformed"; FAIL=$((FAIL+1))
    fi
done

echo ""
echo "=== Result: pass=$PASS fail=$FAIL ==="
[ "$FAIL" -gt 0 ] && exit 1 || exit 0
