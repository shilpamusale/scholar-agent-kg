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

The graph encodes the coverage-determination hierarchy with **typed nodes per role in the policy logic**. The authoritative definitions (constraints, properties, indexes) live in [`schema.cypher`](../schema.cypher); this table is the conceptual vocabulary. The diagram is in [`er-diagram.md`](er-diagram.md).

| Entity | Definition | Example |
|---|---|---|
| **Payer** | The organization issuing the coverage policy | CMS, Aetna, UnitedHealth, BCBS |
| **PolicyDocument** | A specific coverage-determination document/version, with provenance (source payer, effective date) | LCD L34567, "Continuous Glucose Monitoring" |
| **Procedure** | The procedure, drug, device, or item whose coverage is being determined | CGM device, spinal cord stimulator trial |
| **CoverageCriterion** | A top-level coverage requirement for a procedure — the conditional-logic node (IF/AND/UNLESS) | "documented diabetes diagnosis," "step-therapy precondition met" |
| **MedicalNecessityCondition** | A clinical condition that gates a coverage criterion | "failure of conservative therapy ≥ 6 weeks" |
| **ExceptionPathway** | A route that relaxes or conditions a criterion | "covered except as provided in §4.2" |
| **OverrideTrigger** | A condition that supersedes a criterion outcome — highest-value, most-missed | "documented contraindication overrides step therapy" |
| **AppealGround** | A basis on which a denial can be appealed | "appeal on grounds of documented prior failure" |
| **CPTCode / ICDCode** | Standardized billing/clinical codes anchoring a Procedure or condition | CPT 95250, ICD-10 G43.711 |

> **Schema refinement note.** An earlier draft of this vocabulary used a single rich `Criterion` node with a `kind` property to cover necessity-conditions, exceptions, overrides, and appeal-grounds. The schema was refined to **distinct typed node labels per sub-role** (`CoverageCriterion`, `MedicalNecessityCondition`, `ExceptionPathway`, `OverrideTrigger`, `AppealGround`). Rationale: the override and exception roles are the architecture's load-bearing moat, and giving them first-class labels (a) lets the text-to-Cypher layer target them by label rather than by property filter, (b) lets extraction-recall be instrumented *per role* — critical for the `OVERRIDDEN_BY` / `CROSS_REFERENCES` blind spot — and (c) makes the conditional structure legible in the graph itself rather than hidden in a property. The tradeoff (more labels, more extraction targets) is accepted for that measurability. Recorded against ADR-001.

---

## Relation types (edge labels)

Edges encode the traversal a human coder performs and an LLM skips. Direction is `(source)-[REL]->(target)`. Full reference in [`schema.cypher`](../schema.cypher).

| Relation | Direction | Meaning |
|---|---|---|
| `ISSUED_BY` | PolicyDocument → Payer | Anchors every policy to its payer (cross-payer drift control) |
| `COVERS` | PolicyDocument → Procedure | A policy governs coverage of a procedure |
| `REQUIRES` | Procedure → CoverageCriterion · CoverageCriterion → MedicalNecessityCondition | The core conditional edge: coverage requires a criterion/condition be met |
| `EXCLUDES` | Procedure → CoverageCriterion | Negative condition: a criterion that blocks coverage |
| `OVERRIDDEN_BY` | CoverageCriterion → OverrideTrigger | An override trigger supersedes the criterion (highest-value, most-missed) |
| `APPLIES_TO` | ExceptionPathway → CoverageCriterion | An exception relaxes/conditions a specific criterion |
| `APPEALABLE_VIA` | CoverageCriterion → AppealGround | A denial on this criterion is appealable on a stated ground |
| `CROSS_REFERENCES` | PolicyDocument → PolicyDocument · CoverageCriterion → CoverageCriterion | Materializes the "see §4.2 / refer to LCD L33394" pointer flat retrieval can't follow |
| `SUPERSEDES` | PolicyDocument → PolicyDocument | Version control: newer doc supersedes older (resolves contradictions) |
| `CODED_AS` | Procedure → CPTCode · MedicalNecessityCondition → ICDCode | Anchors entities to standardized vocabulary |

> **Note on criterion → procedure traversal.** An earlier draft included a materialized inverse edge `APPLIES_TO_PROCEDURE` (CoverageCriterion → Procedure) for criterion-anchored queries. It was removed: Neo4j traverses relationships bidirectionally, so `(Procedure)-[:REQUIRES]->(CoverageCriterion)` is already navigable criterion→procedure via the reverse direction. The materialized inverse added an extra extraction target and a consistency burden for no traversal benefit. Recorded as ADR-003.

The `OVERRIDDEN_BY` and `CROSS_REFERENCES` edges are the ones the thesis predicts flat RAG will miss, because in the source documents they live in cross-references and separate provisions rather than adjacent to the criterion they modify. Edge-level extraction recall on exactly these two relation types is the instrumentation that lets us attribute downstream failure to extraction vs. traversal — tracked as an open item for Phase 2.

---

## What this doc locks (and what it defers)

**Locked:** the corpus (payer coverage policy), the source mix (CMS public + structurally-faithful synthetic), the moat framing (operational R1 RCM grounding), and the typed entity/relation vocabulary above.

**Defined in `schema.cypher` (Day 3):** node properties, uniqueness/index constraints, and the formal Cypher constraint definitions. `DOMAIN.md` is the conceptual contract; `schema.cypher` is the enforced one — they must agree.

**Recorded in `DECISIONS.md`:** ADR-001 (domain reframe) carries the typed-node refinement; ADR-003 records the removal of the `APPLIES_TO_PROCEDURE` inverse edge.
