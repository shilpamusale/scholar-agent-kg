# Architecture Decision Record (ADR) Log

*ScholarAgent · docs/DECISIONS.md*

An append-only log of architectural decisions. Each ADR follows the **three-move format**:
**(1) Reframe** at the principled level — the general claim the decision rests on;
**(2) Apply** with precision — the specific ScholarAgent choice and its stated tradeoff;
**(3) Falsify** — the condition under which this decision would be shown wrong.

Entries are never edited once committed; they are superseded by later entries that reference them.

---

## ADR-000 — Clean rebuild repo over rebuild-in-place

**Status:** Accepted · Day 1

**Context.** A v1 prototype exists (`scholar-agent`, Gemini/LangChain). The rebuild could either continue in that repo (preserving commit-level history) or start a new repo with clean history (`scholar-agent-kg`).

**(1) Reframe.** An interview portfolio artifact is read as a *finished argument*, not as a development diary. Commit-level archaeology is rarely what a reviewer evaluates; what they evaluate is whether the current artifact is coherent, defensible, and clean. The evolution narrative has value, but it does not have to live in git history to be narratable.

**(2) Apply.** Start a clean repo (`scholar-agent-kg`). **Tradeoff accepted:** the v1→v2 evolution is no longer reconstructable from commits in this repo. **Tradeoff recovered:** v1 is preserved untouched and public as a record of the starting point, the README links back to it, and the evolution is narrated verbally and via this ADR log — so the "why we changed" story is intact without polluting the clean artifact.

**(3) Falsify.** This decision is wrong if a reviewer's evaluation materially depends on commit-level history within one repo — e.g., if the interview explicitly probes incremental development discipline rather than the finished artifact. In that case the verbal walkthrough + v1 backlink would be judged insufficient and rebuild-in-place would have been the better choice.

---

## ADR-001 — Domain reframe: generic documents → payer coverage policy

**Status:** Accepted · Day 2 · see [DOMAIN.md](DOMAIN.md)

**Context.** v1 indexed generic arXiv-style documents. The rebuild pivots the corpus to payer coverage policy (CMS LCDs/NCDs + structurally-faithful synthetic payer documents).

**(1) Reframe.** A system meant to test whether *knowledge representation shape* affects LLM retrieval must run on a corpus that actually exhibits the predicted failure shapes. Documents written to be read (academic papers: abstracts, explicit structure, self-contained argument) do not exhibit conditional-logic severance or cross-payer schema drift, so strong performance on them is uninformative about the thesis.

**(2) Apply.** Reframe the corpus to payer coverage policy, whose two structural properties — conditional/hierarchical coverage logic and cross-payer schema drift — are exactly the mismatch shapes the thesis predicts. The graph encodes five entity types (Payer, Policy, Service, Criterion, Code) and the traversal edges (`REQUIRES`, `EXCEPTION_TO`, `OVERRIDES`, `APPEALABLE_VIA`, …) that human coders follow and LLMs skip. **Tradeoff accepted:** the domain is narrow and requires a structurally-faithful synthetic generator, introducing a synthetic-data fidelity dependency; the contribution is the architecture, not a reusable public dataset. **Why it's worth it:** the domain is a non-replicable R1 RCM moat — the adversarial eval cases come from operational denial-pattern knowledge, not documentation, so the hard cases cannot be closed by an interviewer reading the spec.

**(3) Falsify.** This reframe is wrong if the synthetic documents fail a structural-fidelity audit against real CMS LCD/NCD documents — i.e., if the generated corpus does not actually reproduce the conditional-logic depth and cross-payer drift of real policy. In that case the eval would measure an artifact of the generator rather than the thesis, and the domain advantage would be illusory. (Audit tracked as an open item.)

---

## ADR-002 — Tiered Claude (Haiku + Sonnet) over single-model Gemini

**Status:** Accepted · Day 2

**Context.** v1 used Gemini as a single model for all LLM work. The rebuild adopts a tiered Claude strategy: Claude Haiku 4.5 for routing, Claude Sonnet 4.6 for Cypher generation and final synthesis.

**(1) Reframe.** The sub-tasks inside an agentic retrieval system have different difficulty profiles. Query *routing* is a fast, low-complexity classification; *Cypher generation and synthesis* is a higher-complexity reasoning task. Assigning one model tier to both either overpays for the easy task or underpowers the hard one. Matching model capability to sub-task difficulty is a cost/latency/quality optimization, not a vendor preference.

**(2) Apply.** Use Haiku for the Manager's routing decision (cheap, fast, high-volume) and Sonnet for Cypher translation and answer synthesis (where reasoning quality dominates). **Tradeoff accepted:** a tiered strategy adds orchestration complexity and a routing-quality dependency — a weak router sends queries to the wrong tool regardless of how strong the synthesis model is. Standardizing on Claude also means the four-condition ablation must include a Manager-Gemini arm to isolate whether gains come from the *architecture* or from the *model*. **Why it's worth it:** it makes the routing decision a measurable, swappable component and lets the eval attribute the Manager's contribution explicitly (signed routing-accuracy delta vs. best single-tool baseline).

**(3) Falsify.** This decision is wrong if the ablation shows the Manager-Claude arm provides no significant routing-accuracy gain over Manager-Gemini *and* no cost/latency advantage at equal quality — i.e., if the tiering buys nothing measurable. It is also wrong if router error (Haiku misrouting) dominates the end-to-end failure budget, which would argue for a stronger single model over a tiered split.

---

*Next ADRs (ADR-003+) to be appended as Phase 2+ decisions are made: ingestion idempotency strategy, KG-vs-RAG tool boundary, judge-calibration method.*
