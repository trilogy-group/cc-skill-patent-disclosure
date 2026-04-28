#!/usr/bin/env bash
# Generate a qc-trail.md from a disclosure's qc-rounds/ directory.
# Used by Phase 4 Step 4.7 of the patent-disclosure skill.
#
# Usage:
#   bash qc-trail.sh <disclosure-dir> [--gdoc-url <url>] [--original-url <url>] [--outcome <publish|publish_with_caveats|hold>]
#
# Reads:   <disclosure-dir>/qc-rounds/round-N/{<agent>.json, writer-output/changelog.json}
# Writes:  <disclosure-dir>/qc-trail.md

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <disclosure-dir> [--gdoc-url <url>] [--original-url <url>] [--outcome <outcome>]" >&2
    exit 1
fi

DISC_DIR="$1"
shift
GDOC_URL=""
ORIG_URL=""
OUTCOME="publish"

while [ $# -gt 0 ]; do
    case "$1" in
        --gdoc-url)     GDOC_URL="$2"; shift 2 ;;
        --original-url) ORIG_URL="$2"; shift 2 ;;
        --outcome)      OUTCOME="$2"; shift 2 ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
    esac
done

if [ ! -d "${DISC_DIR}/qc-rounds" ]; then
    echo "Error: ${DISC_DIR}/qc-rounds not found" >&2
    exit 1
fi

OUT_FILE="${DISC_DIR}/qc-trail.md"

DISC_DIR="$DISC_DIR" GDOC_URL="$GDOC_URL" ORIG_URL="$ORIG_URL" OUTCOME="$OUTCOME" OUT_FILE="$OUT_FILE" \
python3 <<'PY'
import json, os, sys
from collections import Counter

doc_dir   = os.environ["DISC_DIR"]
gdoc_url  = os.environ.get("GDOC_URL", "")
orig_url  = os.environ.get("ORIG_URL", "")
outcome   = os.environ.get("OUTCOME", "publish")
out_file  = os.environ["OUT_FILE"]
agents = ['lead_attorney','claims_specialist','technical_reviewer','slop_detector','diagram_auditor','skeptical_examiner']

ids_path = os.path.join(doc_dir, 'ids.json')
title = ""
if os.path.exists(ids_path):
    try: title = json.load(open(ids_path)).get('invention_title','')
    except: pass

def safe_load(p):
    try: return json.load(open(p))
    except: return None

rounds_dir = os.path.join(doc_dir, 'qc-rounds')
round_dirs = sorted(d for d in os.listdir(rounds_dir) if d.startswith('round-') and d != 'round-0')

addressed = 0
deferred  = 0
diagrams_added = 0
round_rows = []
final_verdicts = {a: 'n/a' for a in agents}

for r in round_dirs:
    rd = os.path.join(rounds_dir, r)
    sev = Counter()
    sec_revise = set()
    av = {}
    for a in agents:
        d = safe_load(os.path.join(rd, f"{a}.json"))
        if not d: continue
        av[a] = d.get('overall_verdict','?')
        for s in d.get('section_findings', []):
            if s.get('verdict') == 'revise':
                sec_revise.add(s['section_id'])
            for i in s.get('issues', []):
                sev[i.get('severity','?')] += 1
        for x in d.get('cross_section_issues', []):
            sev[x.get('severity','?')] += 1
    wc = safe_load(os.path.join(rd, 'writer-output', 'changelog.json'))
    if wc:
        for sc in wc.get('section_changes', []):
            addressed += len(sc.get('addressed_findings', []))
            deferred  += len(sc.get('deferred_findings', []))
        diagrams_added += len(wc.get('diagrams_added', []))
    round_rows.append((r, sev, len(sec_revise), av, wc is not None))
    if av:
        final_verdicts.update(av)

lines = []
lines.append(f"# QC Trail — {title or doc_dir}\n")
if gdoc_url: lines.append(f"**Final Google Doc:** {gdoc_url}")
if orig_url: lines.append(f"**Original (pre-QC) Google Doc:** {orig_url}")
lines.append(f"**Rounds run:** {len(round_rows)}")
lines.append(f"**Findings addressed:** {addressed}")
lines.append(f"**Findings deferred:** {deferred}")
lines.append(f"**Diagrams added by Writer:** {diagrams_added}")
lines.append(f"**Final outcome:** {outcome}\n")

lines.append("## Per-round summary\n")
lines.append("| Round | Critical | High | Medium | Low | Sections needing revision | Writer ran |")
lines.append("|---|---|---|---|---|---|---|")
for r, sev, secs, _, wr in round_rows:
    lines.append(f"| {r} | {sev.get('critical',0)} | {sev.get('high',0)} | {sev.get('medium',0)} | {sev.get('low',0)} | {secs} | {'yes' if wr else 'no'} |")

lines.append("\n## Final per-agent verdicts\n")
lines.append("| Agent | Verdict |")
lines.append("|---|---|")
for a in agents:
    lines.append(f"| {a} | {final_verdicts.get(a, 'n/a')} |")

lines.append("\n## Reproducibility\n")
lines.append(f"Raw findings, writer outputs, and intermediate artifacts: `{doc_dir}/qc-rounds/round-N/`.")

open(out_file, 'w').write("\n".join(lines) + "\n")
print(f"[qc-trail] wrote {out_file}")
PY
