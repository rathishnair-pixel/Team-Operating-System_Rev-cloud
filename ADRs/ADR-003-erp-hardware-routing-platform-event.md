# ADR-003: Platform Events over Outbound Messages for ERP Hardware Fulfillment Routing

**Status:** accepted
**Date:** 2026-05-26
**Owner:** [TA]
**Feature:** FTR-006 — Order Decomposition Track 1 (Physical Supply Chain)
**eTOM Domain:** O2P — `1.3.2 Resource Provisioning`
**Supersedes:** —

---

## Context

FTR-006 Track 1 requires that when an Order is activated, the `Edge_5G_Enterprise_Router` line item is routed to the warehouse ERP inventory system to trigger physical asset picking and shipping.

Two candidate patterns exist in Salesforce for outbound event-driven integration: **Outbound Messages** (SOAP-based, legacy Workflow Rules) and **Platform Events** (pub/sub, scalable, Flow/Apex publishable). A third option — direct Apex HTTP callout to the ERP REST API — was also evaluated.

The chosen mechanism must handle multi-site orders (25+ routers), survive ERP downtime without data loss, and provide a dead-letter audit trail when delivery fails. It is on the critical path of the North Star Metric: **Quote-to-Activation ≤ 3 days** — a dropped hardware event means the router never ships and Day 3 is structurally unreachable.

## Decision

Track 1 ERP routing uses **Platform Events** (`Hardware_Fulfillment__e`) published via bulk `EventBus.publish(List<Hardware_Fulfillment__e>)` from a Record-Triggered Flow on Order activation.

- On `Order.Status = Activated`, a Record-Triggered Flow collects all `OrderItem` records where `ProductCode = 'ROUTER'`
- Flow publishes a `Hardware_Fulfillment__e` event per site in a single bulk `EventBus.publish()` call
- ERP subscriber (MuleSoft or ERP-side webhook) consumes events via `ReplayId`-based durable subscription
- On successful ERP acknowledgement: `OrderItem.ERP_Confirmed__c = TRUE`, `OrderItem.ERP_Confirmed_DateTime__c` stamped
- On no acknowledgement within 2 hours: a Scheduled Flow creates a `Hardware_Fulfillment_Error__c` Case assigned to the Supply Chain Ops queue
- Dead-letter recovery: ERP can replay missed events using `ReplayId = -2` (replay all retained events) — Platform Events retain for 72 hours by default

> **The git commit of this file is the approval event. No commit = no approval.**

## Alternatives Rejected

| Alternative | Reason Rejected |
|---|---|
| Outbound Messages (Workflow Rules) | Legacy SOAP pattern; Workflow Rules deprecated in new orgs; no bulk publish; no ReplayId-based redelivery; cannot be triggered from Flow or Apex directly |
| Direct Apex HTTP callout to ERP REST API | Synchronous callout inside Order activation transaction violates same pattern rejected in ADR-002; no durability — if ERP is down, event is lost with no replay capability |
| Change Data Capture (CDC) on OrderItem | CDC fires on any field change — too broad; no way to filter to hardware-only lines declaratively; subscriber receives noise from unrelated updates |

## Consequences

**Positive:**
- Bulk publish handles 25+ site orders in a single `EventBus.publish()` call — no governor limit risk
- 72-hour event retention means ERP downtime of up to 3 days does not cause data loss — events replay on reconnect
- `ReplayId` gives ERP subscriber idempotent delivery — no duplicate picks if subscriber reconnects
- `Hardware_Fulfillment_Error__c` Case creation provides actionable dead-letter audit trail for Supply Chain Ops
- Decoupled from Order transaction — ERP latency never affects Salesforce activation performance

**Negative / Trade-offs:**
- Platform Event schema (`Hardware_Fulfillment__e`) must be deployed before FTR-006 build starts — DevOps dependency
- ERP subscriber must implement `ReplayId` tracking — this is an ERP-side implementation requirement, not purely Salesforce
- 2-hour acknowledgement window is an assumption — must be validated with ERP team before go-live

**Risks:**
- Risk: ERP subscriber goes down for >72 hours — events expire from retention window. Mitigation: [DevOps] monitors Platform Event subscription lag; alert at 48-hour mark.
- Risk: Duplicate `Hardware_Fulfillment__e` events published if Flow re-runs (e.g. Order Status toggled). Mitigation: Flow entry condition checks `OrderItem.ERP_Confirmed__c = FALSE` before publishing — idempotency guard.
- Risk: `Hardware_Fulfillment__e` payload schema changes break ERP subscriber silently. Mitigation: Platform Event fields are additive-only; breaking changes require a new event version and a parallel publish period.

## Platform Event Schema — `Hardware_Fulfillment__e`

| Field | Type | Description |
|---|---|---|
| `Order_Id__c` | Text(18) | Salesforce Order record ID |
| `Order_Item_Id__c` | Text(18) | Salesforce OrderItem record ID |
| `Site_Address__c` | Text(255) | Delivery address for this site |
| `Router_SKU__c` | Text(50) | Product SKU — always `ROUTER_5G_ENT` |
| `Quantity__c` | Number | Units to pick for this site |
| `IMEI_Slot_Reference__c` | Text(50) | IMEI registration slot for Track 2 handoff |
| `Required_Ship_Date__c` | Date | Order activated date + 1 day (Day 1 target) |

## SID Compliance
- `Order`, `OrderItem` — SID `CustomerOrder`
- `Hardware_Fulfillment__e` Platform Event — SID `ResourceSpecification` event trigger (resource provisioning initiation)
- `Asset` (created post-delivery) — SID `PhysicalResource`

No custom objects introduced beyond the Platform Event definition. Platform Event SID mapping documented here per WL-2 compliance requirement.

## Related
- `SOUL.md` rules invoked: R-05 (no hardcoded IDs — Order/OrderItem IDs passed via event payload, not hardcoded)
- `HIGH-LEVEL.md`: eTOM `1.3.2 Resource Provisioning`; Pro-Code boundary — integration orchestration uses platform-native pub/sub
- Linked ADRs: ADR-002 (async network activation — companion Track 2 decision)
- Feature Tracker: FTR-006
- North Star KPI: Quote-to-Activation ≤ 3 days — Track 1 must complete by Day 1 (router shipped) to keep Day 3 target viable
