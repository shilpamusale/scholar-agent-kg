# Domain Reframe: Payer Coverage Policy

*ScholarAgent · docs/DOMAIN.md*

---

## The reframe, in one sentence

ScholarAgent's corpus is **payer coverage policy** — CMS Local and National Coverage Determinations (LCDs/NCDs) plus synthetic payer policy documents that mirror real payer structure — chosen not for convenience but because this domain is the sharpest available instance of the [Information Architecture Mismatch Thesis](THESIS.md), and because its adversarial structure is non-trivially hard to fabricate without operational exposure.

---

## Why this corpus, and why not generic papers

The v1 prototype indexed generic arXiv-style documents. That corpus is a poor test of the thesis: academic papers are *written to be read*, with abstracts, explicit section structure, and self-contained argument. They do not exhibit the failure shapes the thesis predicts, so a system that does well on them proves nothing about whether knowledge representation shape matters for LLM retrieval.

Payer coverage policy is the opposite. These documents are **adversarially complex by design** — written by payers to be defensible to auditors and regulators and navigable by trained human coders, *not* by automated consumers. Two structural properties make them the right stress test:

**Conditional, hierarchical coverage logic.** A coverage determination is not a fact; it is a nested predicate (procedure → coverage criteria → medical-necessity conditions → exception pathways → override triggers → appeal grounds). You cannot retrieve the right answer without traversing that hierarchy. Flat vector similarity retrieves the chunk that lexically matches the procedure and silently drops the precondition, the exclusion, or the override — producing a fluent, confident, structurally wrong answer.

**Cross-payer schema drift.** The same clinical concept — "medical necessity," "step therapy," "site of service" — is expressed under different headings and document hierarchies across Aetna, UnitedHealth, BCBS, and CMS lineages. There is no shared schema. The drift is invisible at the surface-text level and resolvable only structurally.

These are the two mismatch shapes named in the thesis. The corpus exists to make them measurable.

---

## The R1 RCM moat (why this reframe is non-replicable)

The decisive reason to choose this domain is defensive: it is a moat an interviewer cannot probe and find a documentation-shaped gap behind.

The adversarial eval cases — the queries that expose architecture-driven failure — come from **operational experience with prior authorization and claim denials at R1 RCM**, not from reading payer documentation. The relevant operational facts are not in any public spec: that exception pathways and appeal grounds live in cross-references human coders are trained to follow and LLMs skip; that override triggers (e.g., documented contraindication superseding a step-therapy requirement) are the highest-value and most-missed edges; that **denial patterns cluster by knowledge-base structural-failure type, not by clinical content** — i.e., the architecture is the bottleneck, not the reasoning.

A candidate who has only read the documentation can describe what an LCD contains. A candidate who worked the denials knows *which structural seams actually produce wrong outcomes and why*. That gap is the moat: the hard eval cases are grounded in operational pattern recognition that documentation cannot supply.

---

## Data sources

| Source | Description | Licensing |
|---|---|---|
| CMS LCDs / NCDs | Publicly available coverage determinations from cms.gov | Public, no licensing issue |
| Synthetic payer policy | Generated to mirror real payer structure (Aetna / UnitedHealth / BCBS patterns) without reproducing proprietary content | Structural research contribution, not a proprietary dataset |

The research artifact is the **KG schema and routing architecture**, not the underlying policy content. The synthetic documents reproduce *structure* (the conditional-logic and schema-drift shapes), not proprietary text — a deliberate choice so the contribution is the information architecture, not the data.

> **Open dependency (forward reference):** the synthetic-document generator must reproduce the *structural fidelity* of real payer policy — the conditional-logic depth and cross-payer drift — or the eval measures an artifact of the generator rather than the thesis. A structural-fidelity audit of synthetic policies against real CMS LCD/NCD documents is tracked as an open item.

---

## Entity types (node labels)

The graph encodes the coverage-determination hierarchy. Five core node labels:

| Entity | Definition | Example |
|---|---|---|
| **Payer** | The organization issuing the coverage policy | CMS, Aetna, UnitedHealth, BCBS |
| **Policy** | A specific coverage-determination document or section, with provenance (source, effective date) | LCD L34567, "Continuous Glucose Monitoring" |
| **Service** | The procedure, drug, device, or item whose coverage is being determined | CGM device, CPT 95250, a specified drug |
| **Criterion** | A medical-necessity condition, coverage requirement, exclusion, exception pathway, override trigger, or appeal ground — the conditional logic nodes | "documented diabetes diagnosis," "step-therapy precondition met," "contraindication override" |
| **Code** | A billing or clinical code that anchors a Service or Criterion to a standardized vocabulary | CPT, HCPCS, ICD-10 |

`Criterion` is deliberately the richest node type: it carries the conditional logic (the IF/AND/UNLESS/override structure) that flat retrieval severs from the entity it governs. Sub-typing within `Criterion` (necessity-condition vs. exception vs. override-trigger vs. appeal-ground) is a schema-design decision deferred to Day 3 (`schema.cypher`).

---

## Relation types (edge labels)

Edges encode the traversal a human coder performs and an LLM skips. Core relation set:

| Relation | Direction | Meaning |
|---|---|---|
| `ISSUED_BY` | Policy → Payer | A policy is issued by a payer (anchors cross-payer normalization) |
| `COVERS` | Policy → Service | A policy governs coverage of a service |
| `REQUIRES` | Service → Criterion | Coverage of a service requires a criterion be met (the core conditional edge) |
| `EXCLUDED_BY` | Service → Criterion | A criterion excludes coverage (negative condition) |
| `EXCEPTION_TO` | Criterion → Criterion | An exception pathway that conditions or relaxes another criterion |
| `OVERRIDES` | Criterion → Criterion | An override trigger that supersedes another criterion (highest-value, most-missed edge) |
| `APPEALABLE_VIA` | Criterion → Criterion | An appeal ground available when a criterion produces a denial |
| `CODED_AS` | Service / Criterion → Code | Anchors an entity to a standardized vocabulary |

The `OVERRIDES` and `EXCEPTION_TO` edges are the ones the thesis predicts flat RAG will miss, because in the source documents they live in cross-references and separate provisions rather than adjacent to the criterion they modify. Edge-level extraction recall on exactly these relation types is the instrumentation that lets us attribute downstream failure to extraction vs. traversal — tracked as an open item for Phase 2.

---

## What this doc locks (and what it defers)

**Locked:** the corpus (payer coverage policy), the source mix (CMS public + structurally-faithful synthetic), the moat framing (operational R1 RCM grounding), and the entity/relation vocabulary above.

**Deferred to `schema.cypher` (Day 3):** node properties, uniqueness/index constraints, `Criterion` sub-typing, and the formal Cypher constraint definitions.

**Deferred to `DECISIONS.md` (Day 2):** this reframe is recorded as ADR-001 with its stated tradeoff and falsification condition.
