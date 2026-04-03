# Patent Disclosure — Claude Code Plugin

A Claude Code plugin that interactively discovers patentable ideas in a codebase and generates high-quality, attorney-ready patent disclosure documents.

## What It Does

1. **Explores your codebase** for potentially novel algorithms, architectures, and techniques
2. **Surfaces patent candidates** with confidence ratings — you don't need to know what's patentable
3. **Interviews you** to extract the tacit knowledge that makes inventions defensible
4. **Generates a complete disclosure** with 11 structured sections, Mermaid diagrams, pseudocode, and case studies
5. **Self-assesses quality** against a patent committee rubric and suggests improvements
6. **Produces attorney-ready output** — markdown and JSON that patent attorneys can turn into formal filings

## Installation

```bash
# Add the marketplace
claude plugin marketplace add trilogy-group/cc-skill-patent-disclosure

# Install the plugin
claude plugin install patent-disclosure@trilogy-patent-tools
```

The plugin automatically installs [beads](https://github.com/gastownhall/beads) for cross-session workflow persistence.

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

### Workflow

The skill guides you through 5 phases:

| Phase | What Happens |
|-------|-------------|
| **1. Explore** | Analyzes the codebase, surfaces candidate inventions, you triage |
| **2. Deep-Dive** | Targeted code analysis + interactive Q&A to capture the inventive insight |
| **3. Generate** | Produces 11 disclosure sections in batches, with your review at each step |
| **4. QC** | Self-assesses against patent committee rubric, iterates on weak sections |
| **5. Output** | Saves polished disclosure.md + ids.json + qc-report.md |

### Incremental Sessions

Work is tracked via beads. You can stop mid-disclosure and resume in a new session — the plugin picks up exactly where you left off.

### No Local Code? No Problem

If you're not in a git repo, the skill asks for a GitHub URL, clones the repo, and analyzes it.

## Output

For each invention, the plugin produces:

```
patent-disclosures/<invention-slug>/
├── disclosure.md     # Full attorney-ready disclosure document
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

### Diagrams

Every disclosure includes Mermaid diagrams:
- System architecture
- Processing pipeline flowcharts (with novel steps highlighted)
- Sequence diagrams for core operations
- Entity-relationship diagrams
- Data flow diagrams
- State diagrams (where applicable)

### Patent Committee Rubric

The self-assessment scores the disclosure on 4 dimensions:

| Dimension | Scale | Meaning |
|-----------|-------|---------|
| Technical Merit | 1-4 | How much does this improve over prior art? |
| Alternatives | 1-4 | How many comparable alternatives exist? |
| Value to Company | 1-4 | Strategic importance |
| Infringement Detection | 1-3 | How easy is it to detect infringement? |

## Export to Google Docs

```bash
# Convert to docx
pandoc patent-disclosures/<slug>/disclosure.md -o disclosure.docx

# Upload (using gdrive CLI)
gdrive upload disclosure.docx
```

## Prerequisites

- [Claude Code](https://claude.ai/code) CLI
- Git (for repo analysis)
- [pandoc](https://pandoc.org/) (optional, for docx export): `brew install pandoc`
- [beads](https://github.com/gastownhall/beads) (auto-installed by the plugin)

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
│   └── sections/            # Per-section generation prompts (11 files)
└── templates/
    └── disclosure-template.md
hooks/                       # Beads session persistence hooks
scripts/
└── setup.sh                 # Post-install setup (installs beads)
docs/                        # Reference documents
```

## License

MIT
