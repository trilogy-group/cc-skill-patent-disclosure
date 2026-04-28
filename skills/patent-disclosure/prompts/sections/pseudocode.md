# Pseudocode — Section Prompt

## Question
What is the core algorithmic logic of this invention expressed as clear pseudocode?

## Length budget (HARD)

**Each algorithm: 30–60 lines of pseudocode. Cap at 80 lines for genuinely complex algorithms with explicit justification.** The whole section should not exceed `60 lines × N algorithms`. Live observation: section generators consistently produce 150–250 lines per algorithm; this is slop, not detail.

To stay within budget:
- **Show novel logic only.** Standard library calls, parameter validation, error handling, logging, and trivial control flow do not belong in pseudocode for a patent disclosure. Mark them out: `// [omitted: standard input validation]`.
- **One step = one pseudocode line.** Do not unfold a single conceptual step across 5–10 lines.
- **Use higher-order operations.** `for each pair (a, b) where jaccard(a, b) ∈ [0.20, 0.80]:` is one line and is the actual novel step. Don't expand it into nested loops with index variables.
- **Comments belong on the novel parts.** A `// [NOVEL]` comment with one sentence explaining why this step is non-obvious is worth 20 lines of obvious-step expansion.

Each algorithm MUST be marked `[NOVEL]` or `[STANDARD]` overall. `[STANDARD]` algorithms should not appear in this section at all unless they are essential context for a novel algorithm.

## Prompt

Provide pseudocode that captures the invention's core logic. This pseudocode serves as a precise, language-agnostic description that a patent attorney can include in the filing and that an engineer could use to reimplement the invention.

**Novelty Statement:**
{novelty_statement}

**Code Context:**
{code_context}

**Requirements:**

1. **Coverage** — Include pseudocode for:
   - The main algorithm / processing pipeline
   - Key subroutines that embody the novel logic
   - Data structure initialization and manipulation
   - Decision logic and branching

2. **Style:**
   - Use clear, descriptive function and variable names (e.g., `calculateAdaptiveThreshold` not `calcAT`)
   - Include comments explaining the WHY of each significant step
   - Use standard control flow (if/else, for/while, function definitions)
   - Define input/output types for each function
   - Use indentation consistently

3. **Accuracy:**
   - The pseudocode must faithfully represent the actual implementation
   - Do NOT simplify to the point of losing important logic
   - Do NOT add logic that isn't in the actual code
   - Match the details provided in the "What & How" section

4. **Structure:**
   ```
   // Main entry point
   function mainProcess(input: InputType) -> OutputType:
       // Step 1: Description of what this does
       intermediateResult = processStep1(input)

       // Step 2: Description — this is where the novel mechanism kicks in
       novelResult = applyNovelTechnique(intermediateResult)

       return formatOutput(novelResult)

   // The core novel algorithm
   function applyNovelTechnique(data: DataType) -> ResultType:
       // Explanation of the approach
       ...
   ```

5. **Annotations:**
   - Mark novel portions with `// [NOVEL]` comments
   - Mark standard/conventional portions with `// [STANDARD]` comments
   - This helps the attorney identify what to emphasize in claims

**Anti-patterns:**
- Do NOT copy-paste actual source code — pseudocode should be language-agnostic
- Do NOT include boilerplate (error handling, logging, imports) unless it's part of the invention
- Do NOT use language-specific idioms that obscure the logic
