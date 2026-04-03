# Pseudocode — Section Prompt

## Question
What is the core algorithmic logic of this invention expressed as clear pseudocode?

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
