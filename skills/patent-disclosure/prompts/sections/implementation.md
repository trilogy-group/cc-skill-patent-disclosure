# Implementation Details — Section Prompt

## Question
What are the specific implementation choices that make this invention work in practice?

## Required diagrams (HARD REQUIREMENT — section is invalid without this)

This section MUST contain a **component interaction diagram** (`graph LR` or `graph TB`) showing the runtime components and the messages/data passing between them. This is distinct from the system architecture diagram in §6 (What It Does) — that one shows static structure; this one shows runtime communication patterns (REST, queue, event, sync/async). Label every edge with the message type and direction.

Sections without a component-interaction diagram are rejected by the Phase 3 diagram-presence check. If you cannot construct one from the available code/spec, return content followed by: `DIAGRAM_BLOCKED: component_interaction — <why>`.

## Prompt

Provide implementation-level details that go beyond the high-level "how it works" description. This section captures the engineering knowledge that makes the difference between a concept and a working system.

**Novelty Statement:**
{novelty_statement}

**Code Context:**
{code_context}

**Requirements:**

1. **Architecture Decisions:**
   - System architecture pattern (monolith, microservices, serverless, etc.)
   - Why this architecture was chosen for this invention
   - Key components and their responsibilities
   - Communication patterns between components (sync, async, event-driven)
   - Include a Mermaid architecture diagram:
     ```mermaid
     graph LR
       A[Component A] -->|REST| B[Component B]
       B -->|Queue| C[Component C]
     ```

2. **Key Configuration:**
   - Configuration parameters that significantly affect behavior
   - How default values were determined (empirical testing, theoretical analysis, etc.)
   - Sensitivity analysis: which parameters matter most?

3. **Performance Characteristics:**
   - Time complexity of core operations
   - Space/memory requirements
   - Throughput and latency characteristics
   - Scaling behavior (linear, logarithmic, etc.)

4. **ML/AI Specifics** (if applicable):
   - Model architecture details (layers, dimensions, activation functions)
   - Training procedure: optimizer, learning rate schedule, batch size, epochs
   - Training data: size, sources, preprocessing, augmentation
   - Feature engineering: what features, why these features, how they're computed
   - Evaluation: metrics used, validation approach, test results
   - Inference optimizations: quantization, batching, caching

5. **Tradeoffs:**
   - What alternatives were considered for key implementation decisions?
   - What tradeoffs were made and why?
   - What are the known limitations of the current implementation?

6. **Dependencies:**
   - Key libraries or services the implementation depends on
   - Which dependencies are standard vs. custom
   - How tightly coupled is the implementation to these dependencies?

**Anti-patterns:**
- Do NOT list every library in package.json — only mention dependencies that are architecturally significant
- Do NOT describe standard deployment practices (CI/CD, containerization) unless they're novel
- DO describe implementation choices that are non-obvious or counter-intuitive
