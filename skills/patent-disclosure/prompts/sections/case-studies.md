# Case Studies / User Stories — Section Prompt

## Question
How does this invention work in practice? Show it in action with real-world scenarios.

## Prompt

Provide concrete case studies that demonstrate the invention operating in real-world scenarios. These examples make abstract descriptions tangible and help patent attorneys understand the practical significance.

**Novelty Statement:**
{novelty_statement}

**Code Context:**
{code_context}

**Requirements:**

Provide 2-3 case studies. For each:

1. **Scenario** — Describe the real-world situation:
   - Who is involved? (user type, system components)
   - What triggers the invention's use?
   - What is the starting state?

2. **Walkthrough** — Step through the invention's operation in this scenario:
   - Show actual data values at each step (realistic but anonymized)
   - Reference specific functions/modules from the code
   - Highlight where the novel aspects come into play

3. **Outcome** — What is the result?
   - What does the user/system receive?
   - How does this compare to what would happen without the invention?
   - Quantify the improvement where possible

4. **Why This Case Matters** — What does this case demonstrate about the invention that other cases don't?

**Case Study Selection:**
- **Case 1:** The "happy path" — the most common use case, showing the invention working as designed
- **Case 2:** An edge case or challenging scenario that showcases the invention's robustness or adaptability
- **Case 3 (optional):** A use case in a different domain or context that demonstrates broader applicability

**Format:** Use a narrative style with embedded data. Example:

> **Case Study 1: Peak Traffic Adaptation**
>
> A web service receives 50,000 requests per second during normal operation. At 2:00 PM, a marketing campaign launches, causing traffic to spike to 200,000 RPS within 30 seconds...
>
> The system detects the traffic pattern shift by computing... [specific technical details with actual values]
