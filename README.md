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

Optionally install [beads](https://github.com/gastownhall/beads) for richer cross-session tracking:
```bash
bash scripts/setup.sh
```
The plugin works without beads using file-based state.

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

### Three Modes

| Mode | When to Use | What It Does |
|------|-------------|-------------|
| **Full Discovery** | You don't know what's patentable | Explores entire codebase, surfaces candidates, generates full disclosures |
| **Targeted Analysis** | You know which code to patent | Point to specific files/functions, skip exploration |
| **Quick Triage** | You want a fast assessment | 1-page brief per candidate — pursue/skip/needs-more-info |

### Workflow (Full Discovery)

The skill guides you through 5 phases with explicit checkpoints at each transition:

| Phase | What Happens |
|-------|-------------|
| **1. Explore** | Analyzes codebase, auto-detects inventors from git, surfaces candidates, you triage |
| **2. Deep-Dive** | Targeted code analysis + 3-round conversational Q&A to capture the inventive insight |
| **3. Generate** | Produces 12 disclosure sections in batches with your review at each checkpoint |
| **4. QC** | Self-assesses against patent committee rubric, validates diagrams, iterates on weak sections |
| **5. Output** | Saves disclosure.md + ids.json + qc-report.md with claim-to-code mapping |

### Incremental Sessions

Work is saved after every phase. You can stop mid-disclosure and resume in a new session — the plugin reads your IDS JSON and picks up exactly where you left off.

### No Local Code? No Problem

If you're not in a git repo, the skill asks for a GitHub URL, clones the repo, and analyzes it.

## Output

For each invention, the plugin produces:

```
patent-disclosures/<invention-slug>/
├── disclosure.md     # Full attorney-ready disclosure with draft claims
├── ids.json          # Intermediate Data Structure (structured JSON)
└── qc-report.md     # Quality assessment with rubric scores
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

## Export to Google Docs

```bash
# Convert to docx (requires pandoc: brew install pandoc)
pandoc patent-disclosures/<slug>/disclosure.md -o disclosure.docx

# Upload (using gdrive CLI)
gdrive upload disclosure.docx
```

## Prerequisites

- [Claude Code](https://claude.ai/code) CLI
- Git (for repo analysis)
- [pandoc](https://pandoc.org/) (optional, for docx export): `brew install pandoc`
- [beads](https://github.com/gastownhall/beads) (optional, for richer session tracking)

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
│   ├── qc-reviewer.md
│   └── sections/            # Per-section generation prompts (13 files)
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
└── setup.sh                 # Optional setup (installs beads)
docs/                        # Reference documents
```

## License

MIT
