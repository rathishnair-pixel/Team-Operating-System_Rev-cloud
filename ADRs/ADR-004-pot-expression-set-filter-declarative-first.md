# ADR-004: Declarative-First PoT Filter with Apex Pre-Hook Fallback for FIBER_INSTALL Exclusion

**Status:** accepted
**Date:** 2026-05-26
**Owner:** [TA]
**Feature:** FTR-004 — 5G Smart Office Product Catalog & Bundle Structure
**eTOM Domain:** C2M — `2.1.2 Product & Offer Capability Delivery`
**Supersedes:** —

---

## Context

The `Telco_Platinum_SLA` product is priced at exactly 15% of the combined Net Price of `Edge_5G_Enterprise_Router` and `Unlimited_5G_Core_Data_Plan`, explicitly excluding `Fiber_Drop_&_Site_Installation`. This requires the Expression Set to aggregate only two of the four bundle lines — filtering out `FIBER_INSTALL` from the collection array before the PoT calculation executes.

SOUL R-02 (Native-First Always) requires a declarative attempt before any Apex is introduced. However, [TA] has flagged that complex conditional exclusions on parent-child collection arrays in Expression Sets can cause silent calculation failures or hit loop iteration limits at runtime. A two-stage approach is mandated: declarative first, Apex pre-hook as a controlled fallback.

## Decision

**Stage 1 (Build):** Implement the FIBER_INSTALL exclusion as a native Expression Set filter using a Context Attribute condition:
- Context Definition includes a `bundle_line_product_code` attribute per line
- Expression Set filter condition: `bundle_line_product_code != 'FIBER_INSTALL'`
- Aggregated sum of filtered lines feeds `sla_base_amount` variable
- `sla_price = sla_base_amount × 0.15` computed in Procedure 3 (SLA Allocation, max 20 elements)

**Stage 2 (Fallback — only if Stage 1 fails runtime validation):** Implement an Apex Pricing Pre-Hook (`TelcoSlaContextPreHook.cls`) that:
- Executes before Procedure 3 only (not before the full pricing run)
- Reads the Quote Line collection, sums `NetPrice` for Router + Data Plan lines only
- Sets a single Context Attribute `sla_base_amount` on the context object
- Contains zero DML operations (SOUL R-04)
- Passes the pre-computed value directly to the PoT Expression Set, bypassing the native filter

Fallback activation requires a new ADR amendment — this ADR must be updated with `Status: superseded` and a new ADR filed documenting the Apex approach before any pre-hook code is committed.

> **The git commit of this file is the approval event. No commit = no approval.**

## Alternatives Rejected

| Alternative | Reason Rejected |
|---|---|
| Apex pre-hook as first approach | Violates SOUL R-02 native-first mandate; declarative filter must be attempted and documented as failed before Apex is justified |
| Separate standalone PoT Procedure with hardcoded product codes | Hardcoded product codes violate SOUL R-05; brittle if SKUs change; no metadata-driven flexibility |
| Separate Quote Line Group for excluded products | Changes bundle UX — installation and core products must remain in same group for Sales Rep visibility |

## Consequences

**Positive:**
- Full Pricing Lineage traceability maintained: `QuoteLineItem.NetPrice → Context Attribute → Expression Set filter → PoT formula → SLA line price`
- Declarative approach keeps pricing within DPE — visible in Pricing Lineage Report and BRE Connect API debug
- Fallback path is pre-approved and scoped — no surprise Apex sprawl
- Procedure 3 budget: 20 elements — PoT calculation with filter fits comfortably within budget

**Negative / Trade-offs:**
- Stage 1 must be fully tested in sandbox before Stage 2 is even considered — adds one test cycle
- If fallback is triggered, a new ADR amendment is mandatory — no silent Apex introductions

**Risks:**
- Risk: Expression Set collection filter silently returns empty array if `bundle_line_product_code` context attribute is null for any line. Mitigation: [QA] must test with missing context values as a mandatory edge case — this is a pricing failure point per Pricing Diagnostics (CLAUDE.md).
- Risk: Procedure 3 (SLA Allocation) runs before Procedure 1 (Core Pricing) completes, meaning `sla_base_amount` is calculated on stale Net Prices. Mitigation: [TA] must enforce Procedure Plan sequence — Procedure 3 sequenceNumber must be greater than Procedure 1 and 2.

## Pricing Lineage

```
QuoteLineItem.NetPrice (Router + Data Plan only)
→ Context Attribute: bundle_line_product_code (filter condition)
→ Context Attribute: sla_base_amount (aggregated filtered sum)
→ Context Mapping: QuoteLineItem → EcoSwapLineItem node (filter applied here)
→ Expression Set: TelcoSLA_PoT_Calculator
→ Pricing Element: sla_price = sla_base_amount × 0.15
→ Procedure Plan: Procedure 3 (SLA Allocation) — sequenceNumber AFTER Procedure 1 + 2
→ Persistence: QuoteLineItem.UnitPrice on SLA line
Failure Points:
- bundle_line_product_code null → filter returns empty → sla_base_amount = 0 → SLA priced at $0
- Procedure 3 runs before Procedure 1 → sla_base_amount based on pre-discount prices
```

## SID Compliance
Standard objects only — no SID deviation:
- `QuoteLineItem` — SID `ProductOfferingPrice`
- Context Definition — SID `PricingLogicAlgorithm`

## Related
- `SOUL.md` rules invoked: R-02 (native-first), R-04 (no DML in pricing hooks), R-05 (no hardcoded product codes)
- `HIGH-LEVEL.md`: Pro-Code boundary — `Pricing logic → Expression Sets (declarative)` first; `Validation (multi-object) → Apex` only as fallback
- Pricing Budget: Procedure 3 (SLA Allocation) — 20 element max (D-4)
- Linked ADRs: ADR-001 (native Expression Sets precedent)
- Feature Tracker: FTR-004
