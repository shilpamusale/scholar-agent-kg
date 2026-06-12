# The Information Architecture Mismatch Thesis

*ScholarAgent · docs/THESIS.md*

---

## The claim, in one sentence

Knowledge bases encode implicit assumptions about who is consuming them; when the consumer changes from a human to an LLM, the affordances that made the KB *legible to humans* become the precise structural seams where retrieval *fails for models* — and payer coverage policy is the sharpest available instance of this mismatch.

---

## Move 1 — Reframe at the principled level

The dominant paradigms for organizing knowledge — documents, sections, tables, cross-references, "see policy X for Y" pointers, version footers — are not neutral containers. They are an **interface** co-designed with a human reader's constraints: bounded working memory, sequential reading, the ability to flip back and forth, and a lifetime of priors about how a document "means." A human resolves an inline reference by holding context and jumping; resolves an ambiguous clause by reading the surrounding paragraph; resolves a version conflict by checking the footer date and applying judgment about what supersedes what.

An LLM consumer inherits none of those affordances for free. It sees a flattened token stream, a fixed context window, and a chunk boundary that some indexer chose for reasons unrelated to the document's logic. The reference it must resolve may sit in a different chunk; the disambiguating context may have been truncated; the superseding version may rank below the stale one by cosine similarity. **The information architecture did not get worse — the consumer changed, and the architecture was never designed for this consumer.** This is the Knowledge Team's stated thesis: many paradigms for how data and knowledge bases are organized assume human consumers and constraints, and that assumption no longer holds.

The corollary that makes this a *research* claim rather than an observation: if human-optimized affordances are the failure seams, then the failures are **predictable from the structure of the affordance**, not random. We should be able to name, in advance, where a given KB will break an LLM — and design architectures that route around exactly those seams.

---

## Move 2 — Apply with precision to payer coverage policy

Payer policy is the canonical instance because it is adversarially complex *by design* — written by payers to be defensible to auditors and regulators, not legible to downstream automated consumers. Two mismatch shapes carry most of the failure mass, and both come directly from operational experience with prior authorization and denials at R1 RCM:

**Mismatch shape A — Conditional logic chains.** A coverage determination is rarely a fact; it is a nested predicate. *Procedure P is covered IF diagnosis ∈ {set} AND a step-therapy precondition was met AND the member is not in exclusion class E, UNLESS an override trigger (e.g., contraindication documented) applies, in which case an alternate pathway governs.* For a human adjudicator this is a readable decision tree. For an LLM over a chunked corpus, the IF, the AND, the UNLESS, and the override pathway frequently live in **different chunks**, sometimes different documents, sometimes a separate "general provisions" bulletin referenced only by pointer. Flat semantic retrieval pulls the chunk that lexically matches the procedure and silently drops the precondition or the exception — producing an answer that is *fluent, confident, and wrong in the direction that gets a claim denied*. The logic is the payload; chunking severs the logic from the entity it governs.

**Mismatch shape B — Cross-payer schema drift.** The same clinical concept — "medical necessity," "step therapy," "site-of-service," "prior auth required" — is expressed under different headings, different document hierarchies, and different controlling-language conventions across Aetna, UnitedHealth, and BCBS lineages, and again differently across CMS LCDs/NCDs. There is no shared schema; each payer's IA is internally coherent and mutually incompatible. A retrieval system tuned to one payer's structure mis-locates the equivalent criterion under another's, and an LLM with no schema-level grounding cannot tell that "Coverage Criteria → Medical Necessity" in one corpus and "Clinical Policy → Indications" in another are the *same slot*. The drift is invisible at the surface text level and only resolvable structurally.

ScholarAgent's architectural bet follows directly from naming these two shapes. A **knowledge graph** (procedure → coverage criteria → medical-necessity conditions → exception pathways → override triggers → appeal grounds) makes the conditional logic chain *traversable as structure* rather than reconstructable from scattered prose — addressing shape A. An explicit, payer-spanning **schema** with typed nodes (Payer, Policy, Service, Criterion, Code) gives a normalization target that survives cross-payer drift — addressing shape B. RAG over the unstructured policy language is retained precisely for the query class where structure is *not* the bottleneck (semantic similarity between a clinical note and policy prose). The KG is not "better than RAG"; it is the right representation for the query class the human-optimized IA most aggressively breaks. That representation × query-class interaction is the effect the eval harness exists to isolate.

---

## Move 3 — Falsifiability and why it matters to the Knowledge Team

**Falsification condition.** The thesis predicts a *representation × query-class interaction*: KG-structured representation should outperform flat RAG **specifically and disproportionately on the structurally-loaded query classes** (conditional-logic and cross-payer-normalization queries), not uniformly across all queries. The thesis is **falsified** if, on the four-condition ablation (KG-only / RAG-only / Manager-RAG / Manager-KG-hybrid) over the 60-query labeled set, the hybrid's advantage is *flat across query types* — i.e., if KG structure helps semantic-similarity queries as much as it helps logic-chain queries. A flat profile would mean the gains come from some confound (more retrieval, better reranking, model size) rather than from structure resolving the named mismatch shapes. A **null result is still publishable**: "human-optimized IA does not measurably disadvantage LLM consumers on this corpus" is a real finding that would redirect the architecture bet.

**Why this matters to Anthropic's Knowledge Team.** The team's mandate is to *redesign how Claude interacts with external data sources* and to *build "hard" knowledge base eval sets that identify failure modes of how language models work with external data*. This thesis is the design hypothesis behind responsibility (1) — it says *where* a new information architecture has to differ from the human-facing one and *why* — and the payer-policy corpus with its conditional-logic and schema-drift query classes is a purpose-built instance of responsibility (3): a hard eval set whose difficulty is not incidental but *traceable to a specific, nameable property of the source IA*. ScholarAgent does not claim to be the team's architecture; it is one architectural bet with a stated falsification condition, instantiated in a domain whose mismatch shapes are non-trivially hard to fabricate without operational exposure to how coverage decisions actually fail.
