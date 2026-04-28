# Patent Disclosure — Claude Code Plugin

A Claude Code plugin that interactively discovers patentable ideas in a codebase and generates high-quality, attorney-ready patent disclosure documents with draft claims.

## What It Does

1. **Explores your codebase** for potentially novel algorithms, architectures, and techniques
2. **Surfaces patent candidates** with confidence ratings — you don't need to know what's patentable
3. **Interviews you** conversationally to extract the tacit knowledge that makes inventions defensible
4. **Generates a complete disclosure** with 12 structured sections, Mermaid diagrams, pseudocode, and case studies
5. **Drafts patent claims** — independent and dependent claims in proper patent format with claim-to-code traceability
6. **Self-assesses quality** against a patent committee rubric and suggests improvements
7. **Produces attorney-ready output** — markdown and JSON that patent attorneys can turn into formal filings

## Installation

```bash
# Add the marketplace
claude plugin marketplace add trilogy-group/cc-skill-patent-disclosure

# Install the plugin
claude plugin install patent-disclosure@trilogy-patent-tools
```

### Required one-time setup

Every disclosure is published to **Google Docs** — there is no local-only mode. You must install and authorize [`gogcli`](https://github.com/tmc/gogcli) before running the skill. Use the setup script, which walks you through install + OAuth sign-in end-to-end:

```bash
bash scripts/setup.sh
```

The script will:

1. Verify Homebrew is available (or error out with instructions).
2. `brew install gogcli` if missing.
3. Probe `gog auth list --json` for an authorized account.
4. If none, prompt you for the Google account email and run `gog login <email>` — a browser window opens for OAuth consent.
5. Install `mermaid-cli` (diagrams → PNGs, recommended) and flag optional extras (pandoc, beads).

If you prefer to do it by hand:

```bash
brew install gogcli
gog login you@company.com                 # opens browser for OAuth
# Workspace admin requires explicit scopes?
gog login you@company.com --scopes drive,docs
npm install -g @mermaid-js/mermaid-cli   # recommended
```

Optionally install [beads](https://github.com/gastownhall/beads) for richer cross-session tracking. Without it the plugin falls back to file-based state.

### For Development / Testing

```bash
git clone https://github.com/trilogy-group/cc-skill-patent-disclosure.git
claude --plugin-dir ./cc-skill-patent-disclosure
```

## Usage

Navigate to any project directory and run:

```
/patent-disclosure
```

Or describe what you want naturally:

```
> What's patentable in this codebase?
> Help me write a patent disclosure for our ranking algorithm
> Find novel ideas in https://github.com/org/repo
```

### Four Modes

| Mode | When to Use | What It Does |
|------|-------------|-------------|
| **Full Discovery** | You don't know what's patentable | Explores entire codebase, surfaces candidates, generates full disclosures |
| **Targeted Analysis** | You know which code to patent | Point to specific files/functions, skip exploration |
| **Quick Triage** | You want a fast assessment | 1-page brief per candidate — pursue/skip/needs-more-info |
| **QC-Only** | You have an existing disclosure that needs cleanup | Re-runs the QC team on an existing local disclosure or Google Doc URL — skips Phase 1–3, republishes as `[QC v…]` |

### Workflow (Full Discovery)

The skill guides you through 5 phases with explicit checkpoints at each transition:

| Phase | What Happens |
|-------|-------------|
| **1. Explore** | Analyzes codebase, auto-detects inventors from git, surfaces candidates, you triage |
| **2. Deep-Dive** | Targeted code analysis + 3-round conversational Q&A to capture the inventive insight |
| **3. Generate** | Produces 12 disclosure sections in batches with your review at each checkpoint |
| **4. QC** | Six-agent QC team (lead attorney, claims, technical reviewer, slop detector, diagram auditor, examiner) critiques in parallel; a Writer rewrites; loop until all six approve or `qc_max_rounds` (default 3) — Lead Attorney arbitrates if budget hits |
| **5. Output** | Publishes a Google Doc; saves intermediate artifacts (disclosure.md, ids.json, qc-trail.md, qc-rounds/) for reproducibility |

### Incremental Sessions

Work is saved after every phase. You can stop mid-disclosure and resume in a new session — the plugin reads your IDS JSON and picks up exactly where you left off.

### No Local Code? No Problem

If you're not in a git repo, the skill asks for a GitHub URL, clones the repo, and analyzes it.

## Output

Every invention is delivered as a **Google Doc** in the authorized account's Drive. The local files are intermediate artifacts kept for reproducibility and editing:

```
Google Doc (deliverable) — URL printed at the end of the session.

patent-disclosures/<invention-slug>/   (intermediate artifacts)
├── disclosure.md          # Mermaid-source markdown used to build the doc
├── disclosure-export.md   # Version with rendered PNG references
├── diagrams/              # Rendered diagram PNGs
├── ids.json               # Intermediate Data Structure (structured JSON)
├── qc-trail.md            # Multi-agent QC summary
└── qc-rounds/             # Per-round raw findings + writer outputs (auditable trail)
```

### Disclosure Sections

| # | Section | Purpose |
|---|---------|---------|
| 1 | Executive Summary | Non-technical overview for executives |
| 2 | Novelty | What is genuinely new — the inventive step |
| 3 | Context / Environment | Domain, system environment, constraints |
| 4 | Problems Solved | Pain points and prior approach failures |
| 5 | Introduction | Background concepts and terminology |
| 6 | What It Does & How | End-to-end technical description with diagrams |
| 7 | Case Studies | Real-world scenarios demonstrating the invention |
| 8 | Pseudocode | Language-agnostic algorithmic description |
| 9 | Data Structures | Schemas, ERDs, and data flow |
| 10 | Implementation Details | Architecture decisions, ML specifics, tradeoffs |
| 11 | Alternatives | Comparison with known approaches |
| 12 | Prior Art | Known related patents, papers, products (from inventor awareness) |
| -- | **Draft Claims** | Independent + dependent claims with claim-to-code mapping |

### Diagrams

Diagrams are included where they add value (not forced into every section):

- **What It Does & How:** System architecture, processing pipeline flowchart (novel steps highlighted), sequence diagram
- **Data Structures:** Entity-relationship diagram
- **Implementation Details:** Component interaction diagram
- **Case Studies:** Walkthrough diagrams (recommended)

All diagrams use patent-style reference numerals (e.g., "Processor 102", "Step 302") where practical.

### Draft Patent Claims

The plugin generates:
- **3+ independent claims** (method, system, computer-readable medium)
- **8-12 dependent claims** narrowing scope with specific implementation details
- **Claim-to-code mapping** — traceability from each claim element to source file and line numbers

### Patent Committee Rubric

Self-assessment scores on 4 dimensions (1 = strongest, higher = weaker):

| Dimension | Scale | Meaning |
|-----------|-------|---------|
| Technical Merit | 1-4 | 1=Significant improvement ... 4=Negligible distinction |
| Alternatives | 1-4 | 1=No known alternatives ... 4=Many viable |
| Value to Company | 1-4 | 1=Key strategic ... 4=Defensive only |
| Infringement Detection | 1-3 | 1=Easy to detect ... 3=Needs source code |

## Publishing

The skill publishes automatically at the end of each disclosure — you shouldn't normally need to run these scripts by hand. They're here for re-publishing an edited disclosure or for troubleshooting:

```bash
# Publish with rendered diagrams (this is what the skill runs)
bash scripts/render-and-export.sh patent-disclosures/<slug>/disclosure.md

# Pin to a specific Drive folder / account:
bash scripts/render-and-export.sh patent-disclosures/<slug>/disclosure.md \
  --folder-id <DRIVE_FOLDER_ID> --account you@company.com
```

If `mmdc` isn't installed, diagrams fall back to code blocks — a Google Doc is still produced:
```bash
bash scripts/export-to-gdocs.sh patent-disclosures/<slug>/disclosure.md
```

## Prerequisites

**Required:**
- [Claude Code](https://claude.ai/code) CLI
- Git (for repo analysis)
- [gogcli](https://github.com/tmc/gogcli) — installed AND authorized against a Google account. Use `bash scripts/setup.sh` to set this up end-to-end.

**Recommended:**
- [mermaid-cli](https://github.com/mermaid-js/mermaid-cli) — renders diagrams as images inside the Google Doc: `npm install -g @mermaid-js/mermaid-cli`

**Optional:**
- [pandoc](https://pandoc.org/) — `.docx` fallback: `brew install pandoc`
- [beads](https://github.com/gastownhall/beads) — cross-session tracking

## Plugin Structure

```
.claude-plugin/
├── plugin.json              # Plugin manifest
└── marketplace.json         # Marketplace manifest
skills/patent-disclosure/
├── SKILL.md                 # Main skill definition (5-phase workflow)
├── ids-schema.json          # IDS JSON schema
├── prompts/
│   ├── codebase-exploration.md
│   ├── diagram-guidelines.md
│   ├── qc-reviewer.md           # Legacy single-reviewer prompt (deprecated, kept for back-compat)
│   ├── qc/                      # Multi-agent QC team (v1.3+)
│   │   ├── findings-schema.md
│   │   ├── lead-attorney.md
│   │   ├── claims-specialist.md
│   │   ├── technical-reviewer.md
│   │   ├── slop-detector.md
│   │   ├── diagram-auditor.md
│   │   ├── skeptical-examiner.md
│   │   └── writer.md
│   └── sections/                # Per-section generation prompts (13 files)
│       ├── executive-summary.md
│       ├── novelty.md
│       ├── context.md
│       ├── problems-solved.md
│       ├── introduction.md
│       ├── what-and-how.md
│       ├── case-studies.md
│       ├── pseudocode.md
│       ├── data-structures.md
│       ├── implementation.md
│       ├── alternatives.md
│       ├── prior-art.md
│       └── claims.md
└── templates/
    └── disclosure-template.md
hooks/                       # Session persistence hooks
scripts/
├── setup.sh                       # Required setup (gogcli + OAuth + mermaid-cli)
├── render-and-export.sh           # Render Mermaid → PNG + publish via gogcli
├── export-to-gdocs.sh             # Fallback publish (no rendering)
├── disclosure-validate.sh         # Structural validator (Phase 3 fail-fast + smoke test)
├── qc-validate-mermaid.sh         # Extract + validate Mermaid blocks under mmdc
├── qc-trail.sh                    # Build qc-trail.md from qc-rounds/
├── qc-rerun.sh                    # QC-Only entry point (local dir OR Google Doc URL)
├── apply-section-patches.py       # Merge per-section Writer patches into IDS
└── log-run.sh                     # Telemetry → ~/.cache/patent-disclosure/runs.jsonl
tests/
├── fixtures/{good,bad}/           # Smoke-test fixtures
└── run-smoke.sh                   # Regression test before each release
docs/                              # Reference documents
```

### Telemetry

Each phase boundary writes a JSONL entry to `~/.cache/patent-disclosure/runs.jsonl`. Each line has `ts`, `version`, `slug`, `phase`, `event`, plus optional `tokens`, `duration_ms`, and a free-form `data` object. Inspect with:

```bash
jq -c '.' ~/.cache/patent-disclosure/runs.jsonl | tail
```

## License

MIT
