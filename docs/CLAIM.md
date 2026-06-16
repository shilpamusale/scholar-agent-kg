# The Research Claim: Null and Alternative Hypotheses

*ScholarAgent · docs/CLAIM.md*

This document operationalizes the falsification condition stated in
[`THESIS.md`](THESIS.md) into a testable claim: a committed primary metric, a
query-class stratification, the four-condition ablation, and the quantitative
bar that distinguishes a real *representation × query-class interaction* from a
flat profile. It is the contract the eval harness (Phase 3) measures against.

---

## What is being claimed (plain statement)

Knowledge-graph representation does not help LLM retrieval *uniformly*. It helps
**specifically and disproportionately on the query classes whose answer requires
traversing structure** the human-optimized information architecture scattered —
multi-hop conditional logic and cross-payer normalization — and roughly **not at
all** on query classes where flat semantic similarity already suffices. The
*shape* of the lift across query classes, not the average lift, is the claim.

This is deliberately a claim about an **interaction effect**, not a main effect.
"KG beats RAG on average" is a weaker and more confoundable assertion; this
document does not claim it and the eval is not designed to support it.

---

## Constructs and how they are measured

**Independent variable 1 — Representation/routing condition** (4 levels, the ablation):

| Condition | Description |
|---|---|
| `RAG-only` | Flat vector retrieval over policy prose (ChromaDB), no graph |
| `KG-only` | Text-to-Cypher over the typed KG (Neo4j), no vector retrieval |
| `Manager-RAG` | Manager agent routes, but only the RAG tool is available |
| `Manager-KG-hybrid` | Manager routes between KG and RAG tools (the full system) |

**Independent variable 2 — Query class** (the stratification; this is the axis the
interaction lives on):

| Query class | Structural load | Why it stresses (or doesn't) the IA |
|---|---|---|
| `semantic-similarity` | Low | Answer is in one chunk; clinical-note-to-policy prose match. RAG should suffice. |
| `multi-hop-conditional` | High | Answer requires chaining procedure → criterion → condition/exception/override across chunks. |
| `cross-payer-normalization` | High | Answer requires recognizing the same logical slot under different payer schemas. |
| `override-exception` | High | Answer hinges on a buried `OVERRIDDEN_BY` / `CROSS_REFERENCES` edge that flat retrieval drops. |

**Dependent variable — Primary metric:** **answer correctness**, scored by an
LLM judge against a gold answer, reported as accuracy per (condition × query
class) cell. Correctness — not retrieval recall — is the primary metric because
the thesis is about end-to-end answer quality; retrieval recall is a secondary
diagnostic (see below).

**Labeled set:** 60 queries, stratified across the four query classes
(target ≈ 15 per class), each with a gold answer and a gold query-class label.
This 60-query set is a **pilot**, powered to detect a *large concentrated
interaction*, not to certify small per-class differences: at ≈15 queries per
class the standard error on a per-cell accuracy is ≈ ±0.12, so the decision
thresholds below are deliberately set to a gap that sits outside that noise
floor. A pre-registered larger set (≈ 40–100 per class) that could resolve
finer differences is recorded as future work.

---

## Hypotheses

### Primary hypothesis (H1) — the interaction effect

> **H1 (alternative).** The accuracy lift of `Manager-KG-hybrid` over the best
> non-graph baseline (`max(RAG-only, Manager-RAG)`) is **concentrated in the
> high-structural-load query classes** (multi-hop-conditional,
> cross-payer-normalization, override-exception) and **near-zero in the
> low-structural-load class** (semantic-similarity).

> **H1₀ (null).** The accuracy lift of `Manager-KG-hybrid` over the best
> non-graph baseline is **uniform across query classes** — the lift on
> semantic-similarity queries is not meaningfully smaller than the lift on the
> high-structural-load classes.

**Decision rule (the quantitative bar).** Let *lift(class)* =
accuracy(`Manager-KG-hybrid`, class) − accuracy(best-non-graph, class).

H1 is **supported** if ALL three hold:
1. **Concentrated lift:** mean *lift* on the three high-load classes ≥ **0.25**
   (25 percentage points), AND
2. **Flat-where-flat-should-be:** *lift* on `semantic-similarity` ≤ **0.10**, AND
3. **Resolvable separation:** the gap (high-load mean lift − semantic-similarity
   lift) ≥ **0.15**.

These thresholds are set wider than statistical instinct might suggest *on
purpose*: at n ≈ 15 per class a 5-point distinction is inside sampling noise, so
the rule is written to fire only on a separation (≥ 0.15) the pilot can actually
resolve. Certifying a smaller gap requires the larger set noted above.

H1 is **falsified** (H1₀ retained) if the separation in condition (3) is below
**0.15** — i.e., the lift is roughly flat across query classes. A flat profile
means the gains come from a confound (more retrieval, model size, reranking)
rather than from structure resolving the named mismatch shapes.

> **The near-zero bar does as much work as the large-lift bar.** A reviewer
> should read condition (2) as the load-bearing one: if the KG also lifts
> semantic-similarity queries, the thesis is *wrong even if average accuracy
> rose*, because the mechanism claim (structure resolves structural failure) is
> not what produced the gain.

### Secondary hypothesis (H2) — the routing contribution

> **H2 (alternative).** The Manager's routing adds accuracy over a fixed
> single-tool policy: `Manager-KG-hybrid` > `max(KG-only, RAG-only)` on the full
> set, and the Manager routes high-load queries to the KG tool at a rate
> meaningfully above chance.

> **H2₀ (null).** The Manager provides no accuracy gain over always picking the
> single best tool, and/or routes no better than a fixed/random policy.

**Decision rule.** H2 supported if hybrid accuracy exceeds the best single-tool
condition by ≥ **0.10** on the full set AND routing accuracy (router's tool
choice vs. the tool that actually answers the query class correctly) ≥ **0.80**.
A failure here localizes blame: a strong KG with a weak router underperforms,
and H2 separates "the KG doesn't help" from "the router doesn't reach it."

---

## Secondary diagnostics (not the primary claim, but instrumented)

These do not decide H1/H2 but are recorded to attribute *why* a cell scored as
it did, so a failure is a controlled disconfirmation rather than an unexplained
number:

- **Retrieval recall by edge type**, specifically `OVERRIDDEN_BY` and
  `CROSS_REFERENCES` (the thesis's named failure-seam edges). Low correctness on
  override-exception queries *with* high edge recall implicates traversal/synthesis;
  low correctness *with* low edge recall implicates extraction. (Open item in
  [`DOMAIN.md`](DOMAIN.md).)
- **Router confusion matrix** (query class → tool chosen), feeding H2.
- **Judge agreement** against a human-scored subsample, to bound judge bias as a
  confound in the primary metric.

---

## Confounds this design controls for

| Confound | Control |
|---|---|
| "KG wins because it retrieves more" | `Manager-RAG` baseline holds routing constant; lift must be representation-specific, not retrieval-volume |
| "Gains are just a bigger/better model" | All conditions use the same tiered-Claude config; representation is the only thing varied |
| "Gains are reranking, not structure" | RAG-only and KG-only isolate representation with retrieval pipeline held fixed |
| "The labels encode the answer" | Query-class labels are assigned independently of which condition answers correctly; gold answers are condition-agnostic |

> **Acknowledged open confound (volunteered, not hidden).** The gold answers and
> query-class labels encode a *human* notion of the correct traversal path. If
> the KG's gold labels systematically encode the traversal a human coder would
> take, they may under-credit a *different* but valid LLM-native retrieval path —
> the very behavior the Knowledge Team thesis exists to discover. This is logged
> as a measurement-instrument limitation, not silently assumed away; the
> human-judge agreement subsample is the partial check on it.

---

## What a result means (all three outcomes are informative)

- **H1 supported (concentrated lift):** evidence for the information-architecture
  mismatch thesis — structure resolves *structural* failure specifically.
- **H1₀ retained (flat lift):** the thesis is wrong *for this corpus* — a real,
  publishable finding ("human-optimized IA does not measurably disadvantage LLM
  consumers here") that would redirect the architecture bet rather than be buried.
- **H1 supported but H2₀ retained:** the representation matters but the routing
  doesn't — argues for KG-only or a stronger router, and localizes the next
  experiment precisely.

The eval is a **measurement instrument**, not a validation step engineered to
pass. The null is stated first, in numbers, before any data is collected.

---

## Forward dependencies

- The metric, query-class strata, and decision-rule thresholds committed here are
  the contract the **eval harness (Phase 3)** implements. Changing a threshold
  after seeing data is a recorded ADR, not a silent edit.
- The 60-query labeled set's structural fidelity depends on the synthetic-document
  generator reproducing real hop depth and exception branching — the open audit
  item in [`DOMAIN.md`](DOMAIN.md). If synthetic queries don't carry the
  structural load their class label claims, H1 is testing the generator, not the
  thesis.
