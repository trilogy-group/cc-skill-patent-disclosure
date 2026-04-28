# QC Findings Schema

Every critic agent in the multi-agent QC loop MUST return a single JSON object that conforms to the schema below. The orchestrator parses these to drive rewrites and termination.

## Section IDs (use these verbatim)

```
executive_summary, novelty, context, problems_solved, introduction,
what_and_how, case_studies, pseudocode, data_structures, implementation,
alternatives, prior_art, claims
```

If a section is `not_applicable` per the IDS, omit it from `section_findings`.

## JSON shape

```json
{
  "agent": "<one of: lead_attorney | claims_specialist | technical_reviewer | slop_detector | diagram_auditor | skeptical_examiner>",
  "round": 1,
  "overall_verdict": "approve | revise",
  "round_summary": "Two-sentence summary of the most important findings this round.",
  "section_findings": [
    {
      "section_id": "novelty",
      "verdict": "approve | revise",
      "issues": [
        {
          "id": "novelty-001",
          "severity": "critical | high | medium | low",
          "category": "<agent-specific category, e.g. 'verbosity' | 'missing_diagram' | 'claim_scope' | 'inaccurate_code_description'>",
          "location": "<paragraph reference, line range in disclosure.md, or 'whole section'>",
          "description": "<concrete statement of what is wrong>",
          "evidence": "<short quote (≤200 chars) or filename:line reference that proves the problem>",
          "suggested_action": "<a directive the Writer can act on, not a vague suggestion>"
        }
      ]
    }
  ],
  "cross_section_issues": [
    {
      "id": "xs-001",
      "severity": "critical | high | medium | low",
      "affected_sections": ["novelty", "what_and_how"],
      "description": "<e.g. 'novelty statement claims mechanism X but §6 describes mechanism Y'>",
      "suggested_action": "<directive>"
    }
  ]
}
```

## Verdict semantics

- `approve` — this section / overall is publication-ready from your perspective. Minor / low-severity issues may exist but do not block.
- `revise` — there is at least one issue of severity `medium` or higher that must be addressed.

A section's `verdict` should be `revise` if it contains ANY issue with severity `medium`, `high`, or `critical`. `low` issues alone → `approve`.

`overall_verdict` is `revise` if any section verdict is `revise` OR any `cross_section_issues` has severity ≥ `medium`.

## Severity calibration

- **critical** — blocks publication. Patent attorney would refuse to draft from this. Examples: claims unsupported by spec, novelty statement contradicts the technical description, the disclosure describes a system the code does not implement.
- **high** — would cause significant attorney back-and-forth or weakened patent. Examples: missing required diagram, ≥30% of section is filler/repetition, dependent claim is just a rephrasing of the independent.
- **medium** — degrades quality but the disclosure is still drafting-usable. Examples: redundant transitional paragraphs, mildly verbose passages, one diagram has unlabeled edges.
- **low** — nit. Style preference, minor wording. Should not by itself trigger a rewrite.

## Hard rules

1. **No vague findings.** "Could be clearer" is not actionable. Write a `suggested_action` the Writer can follow without further interpretation.
2. **Cite evidence.** Every issue must include either a quoted snippet or a precise location. The Writer should be able to find what you flagged in <30 seconds.
3. **Stay in your lane.** Only flag things in your role's scope. If you spot an issue outside your scope, mention it once in `round_summary` but do NOT add it as an issue another agent owns. (E.g., the Slop Detector should not file claim-scope issues.)
4. **Output ONLY the JSON.** No prose preamble, no markdown fences around the JSON, no closing remarks. The orchestrator parses your output directly with `json.loads`.
5. **Idempotence across rounds.** If the prior round addressed an issue and the current artifact no longer has the problem, do NOT re-raise it.
