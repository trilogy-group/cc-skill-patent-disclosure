# What It Does & How It Works — Section Prompt

## Question
What does the invention do end-to-end, and how does it achieve it technically?

## Prompt

This is the most important technical section of the disclosure. Describe the invention's complete operation from input to output with enough detail that a skilled engineer could reimplement it.

**Novelty Statement:**
{novelty_statement}

**Code Context:**
{code_context}

**Requirements:**

1. **Inputs** — What data/signals enter the system?
   - Data sources and formats
   - User inputs or triggers
   - Environmental inputs (sensor data, API calls, events)
   - Include sample input data where helpful

2. **Processing Pipeline** — Describe each step from input to output:
   - For each step: what happens, what module/function performs it, what is the output
   - Use a Mermaid flowchart to visualize the pipeline:
     ```mermaid
     graph TD
       A[Input] --> B[Step 1: Description]
       B --> C[Step 2: Description]
       ...
     ```
   - Identify which steps are novel vs. standard

3. **Core Algorithm(s)** — For each non-trivial algorithm:
   - What is it called? (if it has a name)
   - What are the inputs and outputs?
   - What is the computational approach? (describe the logic, not just the effect)
   - What is the time/space complexity?
   - What parameters or hyperparameters control its behavior?

4. **Data Models** — What data structures flow through the system?
   - Schema or structure of key data objects
   - How data is transformed at each stage

5. **Decision Points** — Where does the system make decisions?
   - What criteria determine the path taken?
   - What thresholds or rules apply?

6. **Outputs** — What does the system produce?
   - Format and structure of outputs
   - How outputs are consumed/used
   - Include sample output data where helpful

7. **Configuration & Tuning** — What parameters control the system's behavior?
   - Key configuration options and their effects
   - Default values and acceptable ranges
   - How the system adapts or is tuned

8. **Error Handling & Edge Cases** — How does the system handle:
   - Invalid or missing input
   - Boundary conditions
   - Failure modes and recovery

9. **AI/ML Components** (if applicable):
   - Model architecture and type
   - Training data requirements and preparation
   - Training procedure and hyperparameters
   - Inference pipeline
   - Performance metrics and evaluation approach

**Anti-patterns:**
- Do NOT describe standard framework features (e.g., "Spring handles dependency injection") — focus on YOUR logic
- Do NOT hand-wave with "uses machine learning to..." — describe the specific technique
- Do NOT omit steps because they seem "obvious" — be exhaustive
