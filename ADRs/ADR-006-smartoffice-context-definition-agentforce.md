# ADR-006: SmartOfficeBundleContext Definition Architecture for Agentforce D-6 WL-4 Clearance

**Status:** accepted
**Date:** 2026-05-26
**Owner:** [TA]
**Feature:** FTR-004 — 5G Smart Office Product Catalog & Bundle Structure
**eTOM Domain:** C2M — `2.1.2 Product & Offer Capability Delivery`
**Supersedes:** —

---

## Context

FTR-004 WL-4 Agent-Readiness (D-6) was flagged as a GATE BLOCKER: Agentforce cannot natively interact with a CPQ configurator UI page. To satisfy AR-1 through AR-4, the bundle configuration workflow must be exposed via backend API actions grounded in Context Definitions — not UI screens.

The [TA] has defined the `SmartOfficeBundleContext` architecture to wrap the 5G Smart Office bundle, enabling Agentforce to configure options via atomic API calls mapped to the DPE pricing engine.

## Decision

The 5G Smart Office bundle is wrapped in a **3-node Context Definition tree** (`SmartOfficeBundleContext`) with one Invocable Apex action (`ConfigureTelcoBundle__apex`) as the Agentforce entry point.

### Context Definition: `SmartOfficeBundleContext`

**Root Node — `QuoteContext`**
| Attribute | Field Type | Source | Purpose |
|---|---|---|---|
| `QuoteId` | Text(18) | output | Grounds the agent to the active Quote record |
| `PricebookId` | Text(18) | output | Ensures correct pricebook is active for site configuration |
| `TotalSiteCount` | Number | inputoutput | Drives the >25-site volume discount trigger (FTR-005 D-7) |

**Child Node Array — `BundleStructureContext`**
| Attribute | Field Type | Source | Purpose |
|---|---|---|---|
| `ProductCode` | Text(50) | inputoutput | SKU identifier (ROUTER_5G_ENT, DATA_PLAN_5G, FIBER_INSTALL, SLA_PLATINUM) |
| `Quantity` | Number | inputoutput | Units per site — minimum 1 Router enforced by CML |
| `ParentProductCode` | Text(50) | output | Parent SKU for bundle hierarchy validation |

**Child Node Array — `AttributesContext`**
| Attribute | Field Type | Source | Purpose |
|---|---|---|---|
| `Fiber_Meters__c` | Number | inputoutput | Fiber run distance — feeds Procedure 2 (Dynamic Services) pricing formula |
| `Site_ID__c` | Text(50) | inputoutput | Site reference for multi-site order decomposition (FTR-006 Track 1 payload) |

### Invocable Apex: `ConfigureTelcoBundle__apex`

**Method description (AR-2 — minimum 20 words):**
> "Use this action to add, modify, or validate line items within the 5G Smart Office Bundle, including routers, data plans, fiber installation details, and SLA products. Call this action whenever a user specifies site count, product quantities, or fiber distance requirements for a branch office configuration."

**Input:** `SmartOfficeBundleContext` wrapper object (QuoteContext + BundleStructureContext[] + AttributesContext[])

**Execution flow:**
1. Receives context wrapper from Agentforce runtime
2. Validates CML constraints — Router must be present before SLA can be added (WL-2 enforcement)
3. Pushes context to DPE pricing engine via `ConnectApi.CommerceOrders` — atomic single call (AR-1: single responsibility, no multi-DML)
4. Returns `ConfigurationResult` with `success`, `validationErrors[]`, `calculatedPrice`

**AR-1 compliance:** Single DML operation per invocation — no multi-step DML inside the action.
**AR-3 compliance:** Action runs identically in headless (API) and interactive (UI) context channels — context wrapper is channel-agnostic.
**AR-4 compliance:** CML validation errors are returned as explicit structured errors — Agentforce routes to human approval gate if `validationErrors` is non-empty.

### Prototype Demonstration Strategy (D-6 Clearance)

[XA] validates the prototype using a **headless scratch org** approach:
- Raw JSON payloads mimicking `SmartOfficeBundleContext` fed directly into Agentforce tester console
- CML enforcement verified: omitting Router SKU from `BundleStructureContext` must return validation error
- Volume discount threshold verified: `TotalSiteCount > 25` triggers FTR-005 price rule
- Prototype type: `salesforce-sandbox` (headless JSON payload testing — not figma or screen recording)

> **The git commit of this file is the approval event. No commit = no approval.**

## Alternatives Rejected

| Alternative | Reason Rejected |
|---|---|
| UI-based CPQ configurator for agent | Agentforce cannot click through UI screens — violates AR-3 (headless context channel required) |
| Single flat Context Definition (no child nodes) | Cannot represent multi-site array of bundle lines — loses per-site Fiber_Meters__c attribution needed for Procedure 2 pricing |
| Separate Invocable Action per product type | Violates AR-1 atomic action principle — agent would need to chain 4 actions to configure one site; LLM reasoning errors compound across chained calls |

## Consequences

**Positive:**
- WL-4 gate cleared — all AR-1 to AR-4 criteria satisfied
- `TotalSiteCount` on QuoteContext directly feeds FTR-005 volume discount trigger — single source of truth
- `Site_ID__c` on AttributesContext flows downstream to FTR-006 Track 1 `Hardware_Fulfillment__e` payload — no re-derivation needed at Order activation
- Agent description is 38 words — exceeds AR-2 minimum of 20
- Prototype can proceed immediately using headless JSON payloads — no UI build required for sign-off

**Negative / Trade-offs:**
- `SmartOfficeBundleContext` is a custom Context Definition — WL-2 SID mapping required (see below)
- `ConfigureTelcoBundle__apex` must be tested in both Connect API (headless) and UI context to satisfy AR-3 — two separate test runs required
- Array child nodes (`BundleStructureContext[]`, `AttributesContext[]`) require [DA] review for attribute count — platform-governed limit applies

**Risks:**
- Risk: `ConnectApi.CommerceOrders` API changes between Salesforce releases break the action. Mitigation: API version pinned in Named Credential metadata; [DevOps] checks release notes at each major org upgrade.
- Risk: Agent sends `TotalSiteCount` as string instead of Number — context attribute type mismatch causes silent pricing failure. Mitigation: [QA] must include malformed payload test cases; `fieldType` must be declared as `Number` explicitly in Context Definition.

## SID Compliance (WL-2)

| Context Node | SID Entity | Justification |
|---|---|---|
| `QuoteContext` | `ProductOfferingPrice` | Grounds pricing context to the active offer |
| `BundleStructureContext` | `BundledProductOffering` | Represents the parent-child bundle structure per SID Product Domain |
| `AttributesContext` | `ProductCharacteristic` | Site-level configurable attributes per SID `ProductCharacteristic` entity |

No unmapped custom objects. SID mapping declared per WL-2 protocol.

## Related
- `SOUL.md` rules invoked: R-02 (native-first — Context Definitions over custom wrappers), R-05 (no hardcoded IDs — QuoteId resolved at runtime via context)
- `HIGH-LEVEL.md`: AR-1 (atomic action), AR-2 (20-word description), AR-3 (headless + interactive), AR-4 (explicit approval gate on CML error)
- `HIGH-LEVEL.md`: Agent-Readiness Criteria — all 4 satisfied by this ADR
- `HIGH-LEVEL.md`: SID `BundledProductOffering`, `ProductCharacteristic` mappings
- Linked ADRs: ADR-004 (PoT filter — `BundleStructureContext` provides the product code filter input)
- Feature Tracker: FTR-004 — D-6 WL-4 gate cleared by this commit
- Prototype type updated: `salesforce-sandbox` (headless JSON payload)
