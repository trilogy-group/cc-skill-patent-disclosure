#!/usr/bin/env python3
"""Apply per-section Writer patches to an IDS file.

Used by Phase 4 Step 4.5c of the patent-disclosure skill. Each parallel
section-patch Writer emits a JSON object describing the updated content for ONE
section. This script merges those patches into the master IDS.

Patch schema (from writer.md `MODE=section_patch`):
  {
    "section_id": "novelty",
    "updated_answer": "...",
    "updated_diagrams": [ {type, caption, mermaid, ...}, ... ],
    "addressed_findings": [...],
    "deferred_findings":  [...],
    "summary": "...",
    "before_length_lines": int,
    "after_length_lines":  int
  }

Usage:
  apply-section-patches.py --ids <in.json> --patches-dir <dir> --output-ids <out.json> [--changelog <out.json>]
"""
import argparse
import json
import os
import sys
from pathlib import Path


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--ids", required=True, help="path to current ids.json")
    ap.add_argument("--patches-dir", required=True, help="dir containing <section_id>.json patches")
    ap.add_argument("--output-ids", required=True, help="path to write updated ids.json")
    ap.add_argument("--changelog", default=None, help="optional path to write a section_changes-style changelog")
    args = ap.parse_args()

    ids = json.loads(Path(args.ids).read_text())
    sections = {s["id"]: s for s in ids.get("sections", [])}

    section_changes = []
    diagrams_added = []
    applied = 0
    for patch_file in sorted(Path(args.patches_dir).glob("*.json")):
        try:
            patch = json.loads(patch_file.read_text())
        except json.JSONDecodeError as e:
            print(f"[apply-patches] WARN: {patch_file.name} not valid JSON: {e}", file=sys.stderr)
            continue
        sid = patch.get("section_id")
        if not sid or sid not in sections:
            print(f"[apply-patches] WARN: {patch_file.name} has unknown section_id={sid!r}; skipping", file=sys.stderr)
            continue

        before_diagrams = sections[sid].get("diagrams", []) or []

        sections[sid]["answer"] = patch.get("updated_answer", sections[sid].get("answer", ""))
        if "updated_diagrams" in patch:
            sections[sid]["diagrams"] = patch["updated_diagrams"]
        sections[sid]["status"] = "draft"

        # Track diagram diff for changelog
        after_diagrams = sections[sid].get("diagrams", []) or []
        if len(after_diagrams) > len(before_diagrams):
            for d in after_diagrams[len(before_diagrams):]:
                diagrams_added.append({"section_id": sid, "type": d.get("type"), "caption": d.get("caption", "")})

        section_changes.append({
            "section_id": sid,
            "addressed_findings": patch.get("addressed_findings", []),
            "deferred_findings":  patch.get("deferred_findings", []),
            "summary":            patch.get("summary", ""),
            "before_length_lines": patch.get("before_length_lines"),
            "after_length_lines":  patch.get("after_length_lines"),
        })
        applied += 1

    # Reassemble IDS sections array (preserving original order)
    ids["sections"] = [sections[s["id"]] for s in ids["sections"] if s["id"] in sections] + \
                      [s for s in ids["sections"] if s["id"] not in sections]

    Path(args.output_ids).write_text(json.dumps(ids, indent=2))
    print(f"[apply-patches] applied {applied} section patches → {args.output_ids}")

    if args.changelog:
        changelog = {
            "section_changes": section_changes,
            "diagrams_added":  diagrams_added,
            "diagrams_modified": [],
            "diagrams_removed":  [],
            "global_changes": "",
        }
        Path(args.changelog).write_text(json.dumps(changelog, indent=2))
        print(f"[apply-patches] changelog → {args.changelog}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
