# Draft Patent Claims — Section Prompt

## Question
What are the specific, defensible patent claims for this invention?

## Prompt

Draft patent claims for the invention. These claims define the legal scope of protection and are the most important part of the patent filing. Write them in standard patent claim format.

**Novelty Statement:**
{novelty_statement}

**Full Disclosure Context:**
{all_previous_sections}

**Requirements:**

### Independent Claims (draft at least 3)

Each independent claim should capture a different aspect or embodiment of the invention:

1. **Method Claim** — A method/process claim describing the steps performed:
   ```
   1. A method for [achieving X], comprising:
      (a) receiving [input data type] from [source];
      (b) performing [first novel step] on the [input data], wherein [specific detail];
      (c) generating [intermediate result] by [specific technique]; and
      (d) producing [output] based on the [intermediate result].
   ```

2. **System/Apparatus Claim** — A system claim describing the components:
   ```
   2. A system for [achieving X], comprising:
      a processor configured to execute instructions; and
      a memory storing instructions that, when executed by the processor, cause the system to:
        [list the key operations]
   ```

3. **Computer-Readable Medium Claim** — A claim covering the software itself:
   ```
   3. A non-transitory computer-readable medium storing instructions that, when executed by a processor, cause the processor to perform operations comprising:
      [list the key operations]
   ```

### Dependent Claims (draft 8-12)

Dependent claims narrow the scope of an independent claim with additional specifics. Each should add exactly ONE additional limitation. Draw from implementation details, specific algorithms, parameters, data structures, and configurations described in the disclosure.

Format:
```
4. The method of claim 1, wherein [step (b)] further comprises [specific sub-step or constraint].
5. The method of claim 1, wherein the [specific element] is [specific implementation detail].
6. The system of claim 2, wherein the processor is further configured to [additional capability].
```

### Claim Drafting Rules

1. **Broadest reasonable scope** — Independent claims should be as broad as defensible. Don't include implementation details that aren't essential to the invention.
2. **One sentence per claim** — Each claim is a single (potentially long) sentence. Use semicolons and "wherein" clauses, not periods.
3. **Antecedent basis** — First mention of an element uses "a" or "an". Subsequent references use "the" or "said". Every element referenced must have been introduced.
4. **Consistent terminology** — Use exactly the same terms as the rest of the disclosure. If the disclosure says "adaptive threshold," the claims must say "adaptive threshold," not "dynamic limit."
5. **No trade names or specific implementations** — Claims should not reference specific programming languages, frameworks, libraries, or product names.
6. **Means-plus-function sparingly** — Avoid "means for [function]" unless absolutely necessary.
7. **Each dependent claim adds value** — Don't write dependent claims that merely restate what's already in the independent claim.

### Claim Strategy

Organize dependent claims to create a "claim tree" that narrows from broad to specific:
- Claims 4-6: Add detail to the core algorithm/method
- Claims 7-8: Specify data structures or formats
- Claims 9-10: Cover specific performance characteristics or thresholds
- Claims 11-12: Cover specific use cases or applications

### Claim-to-Code Mapping

For each claim element, identify where in the code it is implemented:

```
Claim 1(a) "receiving input data" → handleRequest() in src/api/handler.go:42
Claim 1(b) "computing adaptive threshold" → AdaptiveThreshold.compute() in src/algo/threshold.go:112
```

**Anti-patterns:**
- Do NOT write claims that are obvious combinations of known techniques without an inventive step
- Do NOT include unnecessary limitations that narrow scope without adding patentability
- Do NOT use vague language like "optimizing" or "improving" without specifying HOW
- Do NOT write claims that read on the prior art described in the disclosure
- Do NOT include more than one independent invention per claim set (if the disclosure covers multiple inventive concepts, draft separate claim sets)
