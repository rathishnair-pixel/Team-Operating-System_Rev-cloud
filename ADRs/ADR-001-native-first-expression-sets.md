# ADR-001: Native Expression Sets over Apex for Tiered Pricing Logic

**Status:** accepted  
**Date:** 2026-05-22  
**Owner:** [TA]  
**Feature:** FTR-001 — Tiered Pricing Expression Sets  
**eTOM Domain:** R2A  
**Supersedes:** —

---

## Context
FTR-001 requires tiered volume pricing calculations on Quote lines. The initial implementation proposal included an Apex trigger to compute tiered rates. SOUL R-02 (Native-First Always) and R-06 (ADR for every standard vs custom decision) require this to be formally reviewed.

## Decision
Tiered pricing logic is implemented entirely via Decision Tables and Expression Sets within the DPE (Decision Procedure Engine). No Apex is used for price calculation. Apex is permitted only for context preparation (pre-hook) with zero DML.

> **The git commit of this file is the approval event. No commit = no approval.**

## Alternatives Rejected
| Alternative | Reason Rejected |
|---|---|
| Apex trigger on QuoteLineItem | Violates SOUL R-02 native-first mandate; breaks Pricing Lineage traceability; no DPE visibility in debug |
| Flow-based calculation | Flow cannot handle multi-row Decision Table lookups with variable input keys at scale |

## Consequences
**Positive:**
- Full Pricing Lineage Report traceability (sObject → Context → Expression Set → Procedure)
- Runtime debugging via BRE Connect API
- No Apex governor limit exposure on pricing path

**Negative / Trade-offs:**
- 200-element Pricing Procedure limit applies — pricing budget must be established at kickoff
- Expression Set versioning requires disciplined release management

**Risks:**
- Risk: Procedure element count approaches 200 as tiers grow. Mitigation: sub-procedures per tier band.

## SID Compliance
N/A — uses standard RCA objects only (no custom objects).

## Related
- `SOUL.md` rules: R-02, R-03, R-04, R-06
- Feature Tracker: FTR-001
