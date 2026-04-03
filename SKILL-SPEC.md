# Patent Disclosure Skill — Specification

## Overview

A Claude Code skill (`/patent-disclosure`) that interactively guides engineers through discovering potentially patentable ideas in their codebase and producing high-quality patent disclosure documents. The skill is designed so that patent attorneys can consume the output directly and turn it into formal filings with minimal back-and-forth.

The skill uses **beads** (`bd`) for workflow/task management and cross-session memory, enabling incremental work across multiple conversations.

---

## User Persona

- **Primary:** Software engineers who built something and need help articulating what's novel
- **Secondary consumer:** Patent attorneys who will read the output and draft formal filings
- The engineer may or may not know what's patentable — the skill proactively surfaces candidates

---

## Installation

When the skill is installed, it must automatically:

1. Check if `bd` (beads) is installed; if not, install it via `curl -fsSL https://raw.githubusercontent.com/gastownhall/beads/main/scripts/install.sh | bash`
2. Run `bd init --quiet` in the project directory if not already initialized
3. Run `bd setup claude` to install session hooks (so context survives compaction)
4. Add `"Bash(bd:*)"` to the user's Claude Code allowed permissions if not present

---

## Workflow Phases

The skill operates in 5 sequential phases. Each phase is tracked as a beads epic/task so work can resume across sessions.

### Phase 1: Codebase Acquisition & Exploration

**Trigger:** User invokes `/patent-disclosure`

**Steps:**

1. **Determine codebase source:**
   - If invoked inside a git repo with source code, use the current working directory
   - If no code is present, ask the user for a GitHub repository URL
   - Clone the repo if needed: `git clone <url> .patent-disclosure-workspace/<repo-name>`

2. **Deep codebase analysis** (use Explore subagent with "very thorough"):
   - Map the architecture: key modules, data flows, algorithms, ML pipelines
   - Identify areas of technical sophistication: custom algorithms, novel data structures, unique system designs, unusual orchestration patterns, non-obvious optimizations
   - Look for: proprietary scoring/ranking systems, novel data pipelines, unique ML training approaches, creative API designs, inventive caching/indexing strategies, novel UI/UX interaction patterns
   - Catalog external dependencies vs. custom-built components (custom-built = higher patent potential)

3. **Create beads epic** for the overall patent disclosure effort:
   ```
   bd create "Patent Disclosure: <repo-name>" -t epic -p 1
   ```

4. **Present findings to user** as a numbered list of candidate inventions, each with:
   - A working title
   - 2-3 sentence description of what it does and why it might be novel
   - Key files/modules involved
   - Confidence level (High / Medium / Speculative)

5. **Interactive triage:**
   - Ask the user: *"Which of these look promising? Are there others I missed? What do you consider the most innovative part of this system?"*
   - The user selects/adds/refines candidates
   - User picks which invention to work on first
   - Create a beads task for each selected candidate, linked to the epic

### Phase 2: Novelty Deep-Dive (Per Invention)

**Goal:** Build a deep understanding of the specific invention before writing anything.

**Steps:**

1. **Claim the beads task** for the selected invention: `bd update <id> --claim`

2. **Targeted code analysis:**
   - Read all files identified in Phase 1 for this invention
   - Trace data flow end-to-end: inputs → processing → outputs
   - Identify the core algorithmic/architectural innovation
   - Map dependencies and interactions with other system components

3. **Interactive Q&A with the engineer** — ask pointed questions to extract tacit knowledge:
   - *"What problem were you trying to solve when you built this?"*
   - *"What did you try before this approach? Why didn't those work?"*
   - *"What's the key insight that makes this work better than alternatives?"*
   - *"Are there specific edge cases or constraints that shaped this design?"*
   - *"Who are the inventors? (Everyone who contributed to the inventive concept)"*
   - *"Has this been disclosed externally, sold, or offered for sale?"*
   - *"When did you first conceive of this idea? When did you start building it?"*

4. **Synthesize a novelty statement** — a crisp 2-3 paragraph summary of what is inventive and why. Present to user for validation before proceeding.

5. **Save progress to beads:**
   ```
   bd update <id> --note "Novelty statement validated. Core innovation: <summary>"
   ```

### Phase 3: Disclosure Generation

**Goal:** Produce the intermediate disclosure data structure (IDS), then render it as a polished disclosure document.

**Architecture:** Use the IDS intermediate JSON structure as described in the reference document. Generate each section independently, allowing iterative refinement.

#### IDS Sections (generated in order):

Each section is generated by a focused subagent prompt that includes the novelty statement and relevant code context.

| # | Section | Key Requirements |
|---|---------|-----------------|
| 1 | **Executive Summary** | Core invention + value proposition. Non-technical language. Can stand alone. |
| 2 | **Novelty** | What is new. How it differs from known approaches. The inventive step. |
| 3 | **Context / Environment** | Domain, use cases, where the invention operates. |
| 4 | **Problems Solved** | Specific shortcomings in prior approaches. How this improves state of the art. |
| 5 | **Introduction** | Background concepts, key building blocks, sets the stage. |
| 6 | **What It Does & How It Works** | End-to-end processing steps. Data sources, formats, models. Algorithms and modules. Constraints and configuration. Failure modes. |
| 7 | **Case Studies / User Stories** | Real-world usage scenarios that showcase the novelty in action. |
| 8 | **Pseudocode** | Core logic and flow. Clear naming, comments, syntactically correct. |
| 9 | **Data Structures** | All core data structures, fields, types, schema diagrams (Mermaid). |
| 10 | **Implementation Details** | Specifics beyond the high-level how. Config rationale. ML training details. Tradeoffs. |
| 11 | **Alternatives & Comparison** | Known alternative approaches and their disadvantages vs. this invention. |

**Generation approach:**
- Generate sections 1-2 first, present to user for validation (these anchor everything else)
- Generate sections 3-6 in parallel (use multiple subagents)
- Generate sections 7-11 in parallel
- After each batch, present to user for review and refinement
- Store each section's content in the IDS JSON and save to disk as `<invention-slug>/ids.json`

**Standard instructions included in every section prompt:**
- Reference the novelty statement to keep focus
- Use Markdown formatting (headers, bullets, code blocks)
- Generate Mermaid diagrams where visual representation helps
- Be specific — use actual variable names, function names, and data structures from the code
- Write for a patent attorney audience: precise, unambiguous, thorough

### Phase 4: Quality Control & Self-Assessment

**Goal:** Evaluate the disclosure against quality criteria and the patent committee rubric, then iterate.

**Architecture:** Run as a dedicated QC subagent that receives the full IDS JSON.

#### Per-Section QC (Quality Criteria from IDS Reference):

For each of the 11 sections, evaluate:
1. **Coverage** — Are all key points addressed? List gaps.
2. **Clarity & Consistency** — Is it clear, correct, internally consistent?
3. **Level of Detail** — Sufficient for someone skilled in the art to implement?
4. **Cross-Section Consistency** — Any contradictions with other sections?

#### Patent Committee Rubric Self-Assessment:

Score the disclosure on the 4-axis rubric from the Invention Disclosure Form:

| Dimension | Scale | What to Assess |
|-----------|-------|---------------|
| **Technical Merit** | 1 (significant) → 4 (negligible) | How much does this improve over prior art? |
| **Alternatives** | 1 (no known) → 4 (many possible) | How many comparable alternatives exist? |
| **Value to Company** | 1 (key strategic) → 4 (defensive only) | Strategic importance of the invention |
| **Infringement Detection** | 1 (easy in products) → 3 (need source code) | How detectable is infringement? |

**Output:** A QC report with:
- Section-by-section assessment with specific improvement suggestions
- Overall rubric scores with justification
- Prioritized list of improvements (ranked by impact on patentability)

**Interactive loop:**
- Present QC results to user
- Ask: *"Would you like me to strengthen any of these sections? The biggest opportunity is [X]."*
- Iterate until the user is satisfied or all sections score "adequate" or better
- Save QC results to beads: `bd update <id> --note "QC pass 1: <summary of scores>"`

### Phase 5: Final Output

**Goal:** Produce publication-ready artifacts.

#### Output 1: Invention Disclosure Form (Markdown)

A polished markdown document that maps to the Invention Disclosure Form structure:

```markdown
# Invention Disclosure: <Title>

## Submission Information
| Field | Value |
|-------|-------|
| Submitted By | <name> |
| Date | <date> |
| Business Unit | <unit> |
| Product | <product> |

## Inventors
<table of inventors with name, citizenship, contribution>

## Prior Disclosure & Sales
<disclosure status, NDA status>

## Prior Art
<known prior art, related patents/products>

## Invention Details

### 1. Purpose & Problem Solved
<from IDS sections 3-4>

### 2. Previous Approaches
<from IDS section 11 — alternatives>

### 3. Conception & Reduction to Practice
<dates from user Q&A>

### 4. Description of the Invention
<from IDS sections 5-10, comprehensive>

#### 4.1 Executive Summary
#### 4.2 How It Works
#### 4.3 Case Studies
#### 4.4 Pseudocode
#### 4.5 Data Structures
#### 4.6 Implementation Details

## Self-Assessment (Patent Committee Rubric)
| Dimension | Score | Justification |
|-----------|-------|--------------|
| Technical Merit | <1-4> | <why> |
| Alternatives | <1-4> | <why> |
| Value | <1-4> | <why> |
| Infringement Detection | <1-3> | <why> |
```

Save as: `<invention-slug>/disclosure.md`

#### Output 2: IDS JSON

The intermediate data structure with all 11 sections, their prompts, and answers.

Save as: `<invention-slug>/ids.json`

#### Output 3: Google Doc Generation Command

Print a ready-to-run command for the user:

```bash
# Convert to Google Doc (requires gcloud CLI + Google Docs API enabled)
pandoc <invention-slug>/disclosure.md -o <invention-slug>/disclosure.docx
gdocs upload <invention-slug>/disclosure.docx --title "Patent Disclosure: <Title>"
```

Alternatively, if `gdocs` isn't available, provide `gcloud`-based instructions or a simple script using the Google Docs API.

---

## Beads Integration

### Epic/Task Structure

```
bd-XXXX  Epic: "Patent Disclosures for <repo>"
├── bd-XXXX.1  Task: "Codebase Analysis & Candidate Identification"
├── bd-XXXX.2  Task: "Invention: <Title A>"
│   ├── bd-XXXX.2.1  Subtask: "Novelty Deep-Dive"
│   ├── bd-XXXX.2.2  Subtask: "Disclosure Generation"
│   └── bd-XXXX.2.3  Subtask: "QC & Finalization"
├── bd-XXXX.3  Task: "Invention: <Title B>"
│   └── ...
```

### Cross-Session Resumption

When the user returns in a new session:

1. `bd prime` fires automatically (via hooks) and injects workflow context
2. The skill checks `bd list --status in_progress --json` to find active work
3. Greets the user with: *"Welcome back. You were working on the disclosure for '<Title>'. Last progress: <note>. Ready to continue?"*
4. Resumes from the exact phase/section where work left off

### Memory via Beads Notes

Key decisions, user preferences, and validated content are stored as beads notes on the relevant task, not in Claude's memory system. This keeps patent-specific context with the patent workflow.

Examples:
```
bd update <id> --note "User confirmed novelty: the key insight is X"
bd update <id> --note "User wants to emphasize Y over Z in the executive summary"
bd update <id> --note "QC pass 2: all sections adequate. Technical merit: 1, Alternatives: 2"
```

---

## Subagent Architecture

The skill uses multiple subagents for parallelism and context isolation:

| Subagent | Type | Purpose |
|----------|------|---------|
| **Codebase Explorer** | `Explore` (very thorough) | Phase 1 — map architecture, find novel components |
| **Section Writers** (up to 4 parallel) | `general-purpose` | Phase 3 — generate individual IDS sections |
| **QC Reviewer** | `general-purpose` | Phase 4 — evaluate quality and score rubric |
| **Code Analyst** | `Explore` (medium) | Phase 2 — targeted deep-dive into specific invention code |

---

## Skill Trigger & Registration

**Skill name:** `patent-disclosure`

**Trigger phrases:**
- `/patent-disclosure`
- "patent disclosure", "invention disclosure", "what's patentable", "find novel ideas", "generate disclosure"

**Allowed tools:** `Read`, `Write`, `Edit`, `Bash`, `Glob`, `Grep`, `Agent`, `WebFetch`, `AskUserQuestion`, beads CLI (`Bash(bd:*)`)

---

## File Structure on Disk

```
<project-root>/
├── .beads/                          # beads database (auto-created)
├── patent-disclosures/
│   ├── candidates.md                # Phase 1 output: all identified candidates
│   └── <invention-slug>/
│       ├── ids.json                 # Intermediate Data Structure
│       ├── disclosure.md            # Final polished disclosure document
│       ├── qc-report.md            # Quality control assessment
│       └── diagrams/               # Generated Mermaid/Graphviz diagrams
```

---

## Interaction Model (Example Session Flow)

```
User: /patent-disclosure

Skill: I'll analyze this codebase for potentially patentable ideas. Let me explore...
       [launches Explore subagent]

Skill: I found 4 potentially novel aspects of this codebase:

       1. **Adaptive Rate Limiter** (High confidence)
          Custom token bucket algorithm that learns traffic patterns...
          Files: src/ratelimit/adaptive.go, src/ratelimit/learner.go

       2. **Hierarchical Cache Invalidation** (Medium confidence)
          Novel approach to cache coherence across microservices...
          Files: src/cache/hierarchy.go, src/cache/propagation.go

       3. ...

       Which of these look promising? Are there ideas I missed?

User: #1 and #2 are interesting. Let's start with the rate limiter.

Skill: Great. Let me dig deeper into the adaptive rate limiter.
       [creates beads epic + tasks]
       [deep-dives into the rate limiter code]

       I have some questions:
       - What problem were you hitting with standard rate limiters?
       - What's the key insight behind the learning mechanism?
       - Who worked on this?

User: Standard rate limiters couldn't handle our bursty traffic...
      The key insight is that we model traffic as a Markov chain...
      It was me and Alice Chen.

Skill: Here's my novelty statement:
       "A self-adaptive rate limiting system that models API traffic patterns
        as a Markov chain to dynamically adjust token bucket parameters..."

       Does this capture the core innovation?

User: Yes, but also mention that it does this without requiring manual tuning.

Skill: Updated. Now generating the disclosure sections...
       [parallel section generation]

       Here's the executive summary and novelty section for your review:
       [shows content]

User: Looks good. Continue.

Skill: [generates remaining sections, runs QC]

       QC Results:
       - Technical Merit: 1 (Significant improvement)
       - Alternatives: 2 (Very few known)
       - The "What & How" section needs more detail on the Markov chain
         state transition logic. Want me to strengthen it?

User: Yes, beef that up.

Skill: [regenerates section, re-runs QC]

       All sections now pass QC. Final disclosure saved to:
       - patent-disclosures/adaptive-rate-limiter/disclosure.md
       - patent-disclosures/adaptive-rate-limiter/ids.json

       To create a Google Doc:
       pandoc patent-disclosures/adaptive-rate-limiter/disclosure.md -o disclosure.docx

       Ready to work on invention #2 (Hierarchical Cache Invalidation)?
```

---

## Edge Cases & Design Decisions

1. **No code available locally:** Ask for GitHub URL, clone into `.patent-disclosure-workspace/`, analyze from there.

2. **No novel ideas found:** Be honest. Say *"I analyzed the codebase and didn't find obviously novel algorithmic or architectural patterns. However, novelty can be subtle — could you describe what you think is unique about this system?"* Then work from user's description.

3. **User disagrees with QC scores:** User's judgment takes priority. Note the override in beads and proceed.

4. **Very large codebases:** Focus exploration on custom/proprietary code. Skip vendored dependencies, generated code, and standard boilerplate. Ask user to point to the most innovative modules if the codebase is >100K lines.

5. **Multiple sessions spanning days/weeks:** Beads handles this natively. Each session picks up where the last left off via `bd prime` and task notes.

6. **User wants to revise a completed disclosure:** Reopen the beads task, load the existing IDS JSON, modify specific sections, re-run QC.
