# Patent Disclosure: Synthetic Smoke-Test Invention

## 1. Executive Summary

A two-stage thresholded classifier with a deterministic auto-decide band and a model-decide ambiguous band.

## 2. Novelty

The inventive contribution is the band boundary at 0.20 — pairs below 0.20 are auto-rejected, eliminating model invocations for the trivial-mismatch tail.

## 3. Context

Operates inside an LLM-backed pipeline where each model call is a billable tool invocation.

## 4. Problems Solved

Single-stage classifiers either incur full LLM cost on every pair or use an arbitrary cutoff that loses recall.

## 5. Introduction

Defines the terms `auto_merge_threshold`, `auto_reject_threshold`, and `model_decide_band`.

## 6. What It Does and How It Works

The system architecture is shown in Figure 1; the processing pipeline is shown in Figure 2; the end-to-end interaction is in Figure 3.

```mermaid
graph TB
    Input[Input Pair 100] --> Jaccard[Jaccard Module 110]
    Jaccard --> Decide{Band Decider 120}
    Decide -->|>0.80| Auto[Auto-Merge 130]
    Decide -->|<0.20| Reject[Auto-Reject 140]
    Decide -->|else| LLM[LLM Judge 150]
    style Decide fill:#ff9,stroke:#333,stroke-width:2px
```

```mermaid
flowchart TD
    Start([Step 302: Pair Arrives]) --> Compute[Step 304: Compute Jaccard]
    Compute --> Test{Step 306: Band Test}
    Test -->|>0.80| Merge[Step 308: Auto-Merge]
    Test -->|<0.20| Drop[Step 310: Auto-Reject]
    Test -->|0.20-0.80| Ask[Step 312: LLM Decide]
    style Test fill:#ff9,stroke:#333,stroke-width:2px
```

```mermaid
sequenceDiagram
    participant Caller
    participant Jaccard
    participant LLM
    Caller->>Jaccard: pair(A,B)
    Jaccard-->>Caller: score
    alt score in band
        Caller->>LLM: judge(A,B)
        LLM-->>Caller: equivalent/distinct
    end
    Note over Caller,LLM: LLM only invoked for ambiguous-band pairs
```

## 7. Case Studies

```mermaid
flowchart LR
    A[Pair: 'send report' / 'send the report'] --> J[Jaccard 0.86]
    J --> M[Auto-Merge — no LLM call]
```

## 8. Pseudocode

```
function classify(pair):
    s = jaccard(pair.a, pair.b)         // [STANDARD]
    if s > 0.80: return MERGE            // [NOVEL] auto-decide tail
    if s < 0.20: return REJECT           // [NOVEL] auto-reject tail
    return llm_decide(pair)              // ambiguous band only
```

## 9. Data Structures

```mermaid
erDiagram
    PAIR ||--o{ DECISION : produces
    PAIR {
      string a
      string b
      float jaccard
    }
    DECISION {
      string verdict
      string source
    }
```

## 10. Implementation Details

The runtime topology is shown in the component-interaction diagram below. The Jaccard module runs inline in the request path; the LLM judge is called via an async queue.

```mermaid
graph LR
    Caller -->|sync REST| JaccardSvc[Jaccard Service]
    JaccardSvc -->|enqueue| Queue[(LLM Job Queue)]
    Queue --> LLMSvc[LLM Judge Service]
    LLMSvc -->|callback| Caller
```

## 11. Alternatives & Comparison

Single-stage classifiers (LLM-only or threshold-only) are discussed in §11.

## 12. Prior Art

Record-linkage literature (Fellegi-Sunter, Christen) covers calibrated probabilistic gray-zones; the band-boundary inventive contribution is distinct.

## 13. Draft Patent Claims

1. A method comprising: receiving a pair; computing a Jaccard score; auto-merging when the score exceeds a first threshold; auto-rejecting when the score is below a second threshold; and invoking a model judge for scores between the thresholds.
