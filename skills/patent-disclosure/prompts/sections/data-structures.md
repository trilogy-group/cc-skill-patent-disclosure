# Data Structures — Section Prompt

## Question
What are the core data structures used in this invention?

## Required diagrams (HARD REQUIREMENT — section is invalid without this)

This section MUST contain at least one **Entity-Relationship diagram** (`erDiagram`) showing the relationships between the core data structures. Every entity referenced in the section's prose must appear in the ER diagram, and every cardinality (1:1, 1:N, N:M) must be labeled. Sections delivered without an ER diagram are rejected by the Phase 3 diagram-presence check.

If the data model genuinely does not have meaningful relationships (e.g., a single flat record), produce a `classDiagram` instead showing the field structure with types — but the diagram is still required.

If you cannot construct an ER or class diagram from the available code/spec, do NOT silently omit it. Return your content followed by: `DIAGRAM_BLOCKED: er — <why>`.

## Prompt

Document all significant data structures that the invention uses, creates, or transforms. Data structures are often at the heart of what makes an invention work — they determine what information is available and how efficiently it can be processed.

**Novelty Statement:**
{novelty_statement}

**Code Context:**
{code_context}

**Requirements:**

1. **For each core data structure, provide:**

   - **Name** and purpose (one sentence)
   - **Schema/Fields** — list every field with:
     - Field name
     - Data type
     - Description of what it represents
     - Whether it's required or optional
     - Default value (if any)
     - Valid range or constraints
   - **Relationships** to other data structures (foreign keys, references, embeddings)
   - **Lifecycle** — when is it created, updated, and destroyed?
   - **Access patterns** — how is it queried or traversed?

2. **Visual Representations:**
   - Include a Mermaid entity-relationship diagram showing how data structures relate:
     ```mermaid
     erDiagram
       EntityA ||--o{ EntityB : contains
       EntityA {
         string id
         int score
       }
       EntityB {
         string id
         float weight
       }
     ```
   - Include a Mermaid class diagram if the structures have methods/behaviors

3. **Novel Data Structures:**
   - If any data structures are themselves part of the invention (not just containers), describe:
     - What makes the structure novel
     - Why a standard structure (array, hash map, tree) was insufficient
     - What performance or capability advantage the novel structure provides

4. **Data Flow:**
   - Show how data structures are populated and transformed through the processing pipeline
   - Identify which fields are inputs, which are computed, and which are outputs

**Anti-patterns:**
- Do NOT include generic framework models (ORM base classes, HTTP request objects)
- Do NOT include trivial structures (simple key-value configs, log entries) unless they're part of the invention
- DO include database schemas if the schema design is part of the invention
