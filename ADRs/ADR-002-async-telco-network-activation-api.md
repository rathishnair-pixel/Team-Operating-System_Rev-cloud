# ADR-002: Async Queueable Apex over Synchronous Flow Callout for Telco Network Activation

**Status:** accepted
**Date:** 2026-05-26
**Owner:** [TA]
**Feature:** FTR-006 — Order Decomposition Track 2 (Network Provisioning)
**eTOM Domain:** O2P — `1.2.2 Service Configuration & Activation`
**Supersedes:** —

---

## Context

FTR-006 Track 2 requires an HTTP callout to the Telco Network Activation Controller when an Order is activated. The initial design proposed a Record-Triggered Flow on `Order.Status = Activated` making a synchronous HTTP callout to the Named Credential `Telco_Network_Controller`.

Salesforce Flow HTTP callouts execute inside the originating transaction. If the external controller API responds slowly (>10s) or is unavailable, the Flow times out, the Order activation transaction rolls back or hangs, and no retry mechanism exists. On a 25-site enterprise order, 25 simultaneous synchronous callouts would immediately breach governor limits.

This is on the critical path of the North Star Metric: **Quote-to-Activation ≤ 3 days**. A synchronous failure on Day 0 resets the clock to Day 14.

## Decision

Track 2 network activation is implemented as a **Queueable Apex chain** with 3-attempt exponential backoff, decoupled entirely from the Order activation transaction.

- Order activation sets `Order_Item.Network_Status__c = 'Pending_Activation'` — no callout in transaction
- A Record-Triggered Flow on `OrderItem.Network_Status__c = 'Pending_Activation'` enqueues `TelcoNetworkActivationQueueable`
- Queueable performs the HTTP callout via Named Credential `Telco_Network_Controller`
- On success: sets `Asset.Network_Activation_Status__c = 'Active'`, stamps `Asset.Activated_DateTime__c`
- On failure: retries after 30s → 60s → 120s (exponential backoff via `System.scheduleBatch`)
- After 3 failures: creates a `Case` assigned to Network Ops queue with `Subject = 'Activation Failed — [Order Number]'` and sets `Asset.Network_Activation_Status__c = 'Failed'`
- For 25+ site orders: Queueable chains are batched — max 5 concurrent activation jobs, chained via `System.enqueueJob` inside each Queueable's `execute()`

> **The git commit of this file is the approval event. No commit = no approval.**

## Alternatives Rejected

| Alternative | Reason Rejected |
|---|---|
| Synchronous Flow HTTP callout | Blocks Order activation transaction; no retry; times out on slow API; governor limit breach on multi-site orders |
| Platform Event subscriber with callout | Platform Events cannot make HTTP callouts directly — requires Apex subscriber anyway; adds indirection without benefit |
| External service (MuleSoft mediation) | Valid long-term pattern but introduces MuleSoft dependency not yet provisioned for this feature; ADR required separately if adopted |
| Scheduled Apex batch | 15-minute minimum schedule interval is too coarse for a 3-day activation SLA target |

## Consequences

**Positive:**
- Order activation never blocked by external API state
- 3-attempt retry with exponential backoff handles transient controller outages without manual intervention
- `Asset.Network_Activation_Status__c` field gives real-time visibility for Operations dashboard
- Batched Queueable chain safely handles 25+ site orders within governor limits
- Failed activations auto-create Cases — Operations team has actionable work items, not silent failures

**Negative / Trade-offs:**
- Activation is no longer instantaneous on Order save — there is a short async gap (seconds to minutes)
- Queueable depth must be monitored — Salesforce limits 50 queued jobs per transaction; batch-of-5 pattern stays well within this
- `TelcoNetworkActivationQueueable` requires 90%+ test coverage including mock HTTP callout scenarios (success, timeout, 500 error)

**Risks:**
- Risk: Queueable job silently dropped if org hits Async Apex queue limit under load. Mitigation: [DevOps] monitors Apex Jobs queue in org dashboard; alert threshold set at 80% queue occupancy.
- Risk: Named Credential `Telco_Network_Controller` endpoint changes break all activations. Mitigation: endpoint URL stored in Custom Metadata `Telco_API_Config__mdt` — no hardcoded values (SOUL R-05).

## SID Compliance
Uses standard RCA objects only:
- `Order`, `OrderItem` — SID `CustomerOrder`
- `Asset` — SID `Service` (active delivered service)
- `Case` — SID `CustomerInteraction` (failure escalation)

No custom objects introduced. No SID deviation.

## Related
- `SOUL.md` rules invoked: R-04 (no DML in pricing hooks — callout kept out of pricing transaction), R-05 (no hardcoded IDs/endpoints)
- `HIGH-LEVEL.md`: Pro-Code boundary — `Validation (multi-object)` → Apex; `Integration orchestration` → Named Credentials
- Linked ADRs: ADR-003 (ERP hardware routing — companion Track 1 decision)
- Feature Tracker: FTR-006
- North Star KPI: Quote-to-Activation ≤ 3 days — this ADR is on the critical path
