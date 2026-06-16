// ============================================================================
// ScholarAgent — Payer Policy Knowledge Graph Schema
// schema.cypher  ·  Neo4j 5.x (Community edition compatible)
// ============================================================================
//
// This file defines the node labels, uniqueness/index constraints, and
// indexes for the payer-policy knowledge graph. It is the authoritative
// structural contract that the extraction pipeline (Phase 2) must validate
// every extracted node/edge against before writing to Neo4j.
//
// Design provenance: docs/DOMAIN.md (entity/relation vocabulary),
// ADR-001 (domain reframe), ADR-003 (drop materialized inverse edge),
// Module 3 (typed-node schema rationale).
//
// SCHEMA REVIEW — which human-affordances become LLM failure seams:
// Each node/edge below is annotated with the structural property it makes
// explicit. The recurring theme: payer policy encodes relations that a human
// coder is *trained to traverse* but that live implicitly in prose and
// cross-references. The graph materializes exactly those implicit edges so
// that traversal becomes a first-class query operation rather than something
// the LLM must reconstruct from flat chunks. The edges most likely to be the
// failure seam are CROSS_REFERENCES and OVERRIDDEN_BY — they are the
// "see §4.2" pointers a human follows and flat retrieval skips.
//
// NOTE ON EDITION: Community edition supports uniqueness constraints and
// indexes but NOT node/relationship property-existence constraints or
// node-key constraints (those are Enterprise-only). Existence constraints
// below are marked [ENTERPRISE] and commented out; on Community, existence
// is enforced at the application layer in the extraction validator.
// ============================================================================


// ----------------------------------------------------------------------------
// NODE UNIQUENESS CONSTRAINTS
// (each also implicitly creates a backing index on the constrained property)
// ----------------------------------------------------------------------------

// --- Payer: the organization issuing coverage policy (CMS, Aetna, UHC, BCBS) ---
// Failure seam: cross-payer schema drift. The SAME logical criterion is
// structured differently per payer; scoping every Policy to a Payer is what
// lets traversal stay payer-correct instead of silently mixing conventions.
CREATE CONSTRAINT payer_id IF NOT EXISTS
FOR (p:Payer) REQUIRE p.payer_id IS UNIQUE;

// --- PolicyDocument: a specific coverage-determination document/version ---
// Failure seam: version drift. Two docs can give contradictory criteria across
// effective dates; a stable doc identity + effective_date property is what
// makes "which version governs" answerable instead of a coin-flip.
CREATE CONSTRAINT policy_doc_id IF NOT EXISTS
FOR (d:PolicyDocument) REQUIRE d.doc_id IS UNIQUE;

// --- Procedure: the service/procedure whose coverage is determined ---
CREATE CONSTRAINT procedure_id IF NOT EXISTS
FOR (proc:Procedure) REQUIRE proc.procedure_id IS UNIQUE;

// --- CoverageCriterion: a top-level coverage requirement for a procedure ---
// Failure seam: conditional logic stored flat. A criterion is a node in a
// conditional tree (AND/OR/UNLESS); flat retrieval returns the node and drops
// the boolean relation to its siblings/exceptions.
CREATE CONSTRAINT coverage_criterion_id IF NOT EXISTS
FOR (c:CoverageCriterion) REQUIRE c.criterion_id IS UNIQUE;

// --- MedicalNecessityCondition: a clinical condition gating a criterion ---
// Failure seam: semantic density vs structural precision. Two conditions can
// be near-identical in embedding space yet occupy opposite logical positions
// (covered indication vs explicit exclusion).
CREATE CONSTRAINT med_nec_condition_id IF NOT EXISTS
FOR (m:MedicalNecessityCondition) REQUIRE m.condition_id IS UNIQUE;

// --- ExceptionPathway: a route that relaxes/conditions a criterion ---
// Failure seam: exceptions live in cross-references ("not covered except per
// §4.2"). The human follows the pointer; flat retrieval surfaces the exclusion
// and never follows it, denying a claim that was in fact covered.
CREATE CONSTRAINT exception_pathway_id IF NOT EXISTS
FOR (e:ExceptionPathway) REQUIRE e.exception_id IS UNIQUE;

// --- OverrideTrigger: a condition that supersedes a criterion outcome ---
// Failure seam: THE highest-value, most-missed relation. An override
// (e.g. documented contraindication supersedes a step-therapy requirement)
// is the edge whose omission flips a correct answer to a wrong one.
CREATE CONSTRAINT override_trigger_id IF NOT EXISTS
FOR (o:OverrideTrigger) REQUIRE o.override_id IS UNIQUE;

// --- AppealGround: a basis on which a denial can be appealed ---
// Failure seam: buried in cross-references; only relevant conditional on a
// specific denial reason, so flat retrieval rarely co-locates it with the
// triggering criterion.
CREATE CONSTRAINT appeal_ground_id IF NOT EXISTS
FOR (a:AppealGround) REQUIRE a.appeal_id IS UNIQUE;

// --- CPTCode / ICDCode: standardized vocabulary anchors ---
// Failure seam (sparse-retrieval boundary): these rare tokens are where BM25
// wins and dense retrieval smears; anchoring them as nodes keeps code-exact
// queries precise.
CREATE CONSTRAINT cpt_code IF NOT EXISTS
FOR (cpt:CPTCode) REQUIRE cpt.code IS UNIQUE;

CREATE CONSTRAINT icd_code IF NOT EXISTS
FOR (icd:ICDCode) REQUIRE icd.code IS UNIQUE;


// ----------------------------------------------------------------------------
// PROPERTY-EXISTENCE CONSTRAINTS  [ENTERPRISE ONLY]
// On Community edition these are enforced in the extraction validator instead.
// Uncomment if running Neo4j Enterprise.
// ----------------------------------------------------------------------------

// CREATE CONSTRAINT policy_doc_effective_date IF NOT EXISTS
// FOR (d:PolicyDocument) REQUIRE d.effective_date IS NOT NULL;

// CREATE CONSTRAINT policy_doc_payer_link IF NOT EXISTS
// FOR (d:PolicyDocument) REQUIRE d.source_payer_id IS NOT NULL;

// CREATE CONSTRAINT criterion_provenance IF NOT EXISTS
// FOR (c:CoverageCriterion) REQUIRE c.source_doc_id IS NOT NULL;


// ----------------------------------------------------------------------------
// SECONDARY INDEXES
// (uniqueness constraints already index their key; these cover non-unique
//  properties that traversal/filtering will hit hot)
// ----------------------------------------------------------------------------

// Provenance filtering: "as of effective_date, which criteria govern?"
CREATE INDEX policy_doc_effective_date_idx IF NOT EXISTS
FOR (d:PolicyDocument) ON (d.effective_date);

// Payer-scoped traversal start points (cross-payer drift control)
CREATE INDEX policy_doc_payer_idx IF NOT EXISTS
FOR (d:PolicyDocument) ON (d.source_payer_id);

// Procedure lookup by human-readable name (router/Cypher-gen convenience)
CREATE INDEX procedure_name_idx IF NOT EXISTS
FOR (proc:Procedure) ON (proc.name);

// Criterion text search support for hybrid KG/RAG reconciliation
CREATE INDEX coverage_criterion_doc_idx IF NOT EXISTS
FOR (c:CoverageCriterion) ON (c.source_doc_id);


// ============================================================================
// EDGE TYPES (relationship reference — not constraint-enforceable on Community)
// ============================================================================
//
// Documented here so the extraction validator and text-to-Cypher layer share
// one authoritative relation vocabulary. Direction is (source)-[REL]->(target).
//
//   (PolicyDocument)-[:ISSUED_BY]->(Payer)
//       Anchors every policy to its payer. Cross-payer drift control.
//
//   (PolicyDocument)-[:COVERS]->(Procedure)
//       A policy governs coverage of a procedure.
//
//   (Procedure)-[:REQUIRES]->(CoverageCriterion)
//       Core conditional edge: coverage requires a criterion be met.
//       NOTE: criterion->procedure traversal uses the reverse direction of
//       this edge — Neo4j traverses relationships bidirectionally, so no
//       separate inverse edge is materialized (see ADR-003).
//
//   (CoverageCriterion)-[:REQUIRES]->(MedicalNecessityCondition)
//       A criterion is gated by a clinical necessity condition.
//
//   (Procedure)-[:EXCLUDES]->(CoverageCriterion)
//       Negative condition: a criterion that blocks coverage.
//
//   (CoverageCriterion)-[:OVERRIDDEN_BY]->(OverrideTrigger)
//       Highest-value, most-missed edge. An override supersedes the criterion.
//
//   (ExceptionPathway)-[:APPLIES_TO]->(CoverageCriterion)
//       An exception relaxes/conditions a specific criterion.
//
//   (CoverageCriterion)-[:APPEALABLE_VIA]->(AppealGround)
//       A denial on this criterion is appealable on a stated ground.
//
//   (PolicyDocument)-[:CROSS_REFERENCES]->(PolicyDocument)
//   (CoverageCriterion)-[:CROSS_REFERENCES]->(CoverageCriterion)
//       Materializes the "see §4.2 / refer to LCD L33394" pointer that flat
//       retrieval cannot follow. THE seam: an unextracted CROSS_REFERENCES
//       edge is exactly how a buried override gets silently dropped.
//
//   (PolicyDocument)-[:SUPERSEDES]->(PolicyDocument)
//       Version control: newer doc supersedes older. Resolves contradiction
//       between policy versions.
//
//   (Procedure)-[:CODED_AS]->(CPTCode)
//   (MedicalNecessityCondition)-[:CODED_AS]->(ICDCode)
//       Anchors entities to standardized vocabulary (sparse-retrieval exact).
//
// EXTRACTION-RECALL INSTRUMENTATION (Phase 2 hook):
//   OVERRIDDEN_BY and CROSS_REFERENCES are the two edge types whose extraction
//   recall must be measured directly (hand-validated sample), because their
//   silent omission is the dominant source of confident-but-wrong KG answers.
//   See DOMAIN.md "open item" + Module 5 Family B falsifiability test.
// ============================================================================
