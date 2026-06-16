# Payer Policy KG — Entity-Relationship Diagram

*ScholarAgent · docs/er-diagram.md*

This diagram is the visual companion to the schema vocabulary in
[`DOMAIN.md`](DOMAIN.md) and the enforced constraints in
[`schema.cypher`](../schema.cypher). All three must agree.

```mermaid
flowchart LR

    %% =========================
    %% POLICY LAYER
    %% =========================
    Payer[Payer]
    Policy[PolicyDocument]

    Policy -->|ISSUED_BY| Payer
    Policy -->|COVERS| Procedure

    Policy -->|CROSS_REFERENCES| RelatedPolicy[PolicyDocument]
    Policy -->|SUPERSEDES| OldPolicy[Previous Policy]

    %% =========================
    %% COVERAGE LAYER
    %% =========================
    Procedure[Procedure]
    Criterion[CoverageCriterion]

    Procedure -->|REQUIRES| Criterion
    Procedure -->|EXCLUDES| Criterion

    %% =========================
    %% CLINICAL LAYER
    %% =========================
    MedicalNecessity[Medical Necessity Condition]

    Criterion -->|REQUIRES| MedicalNecessity

    %% =========================
    %% EXCEPTION / OVERRIDE LAYER
    %% =========================
    Exception[Exception Pathway]
    Override[Override Trigger]

    Exception -->|APPLIES_TO| Criterion
    Criterion -->|OVERRIDDEN_BY| Override

    %% =========================
    %% APPEALS
    %% =========================
    Appeal[Appeal Ground]

    Criterion -->|APPEALABLE_VIA| Appeal

    %% =========================
    %% VOCABULARY LAYER
    %% =========================
    CPT[CPT Code]
    ICD[ICD Code]

    Procedure -->|CODED_AS| CPT
    MedicalNecessity -->|CODED_AS| ICD

    %% =========================
    %% COLORS
    %% =========================

    classDef policy fill:#D6EAF8,stroke:#2874A6,stroke-width:2px,color:#000;
    classDef coverage fill:#D5F5E3,stroke:#239B56,stroke-width:2px,color:#000;
    classDef clinical fill:#FAD7A0,stroke:#CA6F1E,stroke-width:2px,color:#000;
    classDef exception fill:#E8DAEF,stroke:#7D3C98,stroke-width:2px,color:#000;
    classDef appeal fill:#F5B7B1,stroke:#C0392B,stroke-width:2px,color:#000;
    classDef coding fill:#EAECEE,stroke:#566573,stroke-width:2px,color:#000;

    class Payer,Policy,RelatedPolicy,OldPolicy policy;
    class Procedure,Criterion coverage;
    class MedicalNecessity clinical;
    class Exception,Override exception;
    class Appeal appeal;
    class CPT,ICD coding;
```

## Reading the diagram

The diagram is laid out as the **conditional-traversal spine** the thesis is
built on: Payer → PolicyDocument → Procedure → CoverageCriterion → the four
typed leaf roles (MedicalNecessityCondition, ExceptionPathway, OverrideTrigger,
AppealGround). Color groups the layers — policy (blue), coverage (green),
clinical (orange), exception/override (purple), appeal (red), vocabulary (grey).

**`OVERRIDDEN_BY` and `CROSS_REFERENCES`** are the two edges the thesis predicts
flat RAG will miss — they live in cross-references and separate provisions in the
source documents, not adjacent to the criterion they modify. They are the
failure seams the KG exists to make traversable.

**Criterion → procedure traversal** is not drawn as a separate edge. Neo4j
traverses `(Procedure)-[:REQUIRES]->(CoverageCriterion)` bidirectionally, so the
reverse direction is already navigable without a materialized inverse edge
(see ADR-003).
