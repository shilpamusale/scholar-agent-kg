# scholar-agent-kg

A hybrid knowledge-graph + RAG system for relational reasoning over payer
coverage policy, built as a research artifact for evaluating how knowledge
representation shape affects LLM retrieval.

**Why this rebuild exists:** [The Information Architecture Mismatch Thesis](docs/THESIS.md)
— why human-optimized knowledge bases fail LLM consumers, instantiated in payer
coverage policy.

## Lineage

This is a ground-up rebuild (v2) of an earlier prototype. The original
Gemini/LangChain implementation is preserved untouched as a public record of
the evolution: [scholar-agent v1](https://github.com/shilpamusale/scholar-agent).

The rebuild narrative — what changed, what was wrong with v1, and why — is
defensible decision-by-decision via the ADR log in
[docs/DECISIONS.md](docs/DECISIONS.md) (populated from Day 2 onward).

## Status

Phase 1 — Foundation & Domain Reframe (in progress). Full 27-day rebuild plan
tracked separately.
