# ADR-005: Flow Orchestrator over Schedulable Apex for 4-Hour Approval SLA Escalation

**Status:** accepted
**Date:** 2026-05-26
**Owner:** [TA]
**Feature:** FTR-005 — 5G Smart Office Pricing Rules & Advanced Approvals
**eTOM Domain:** R2A — `1.1.2 Order Handling`
**Supersedes:** —

---

## Context

FTR-005 requires that when a Sales Rep applies a manual discount greater than 20% on the `Unlimited_5G_Core_Data_Plan`, the quote is locked and routed sequentially: first to the Regional Telco Finance Director, then to the Network Operations VP. If either approver does not respond within 4 business hours, the approval must automatically escalate to their manager.

Advanced Approvals natively handles sequential routing but has no sub-day asynchronous cron scheduler. A 4-hour OOO escalation is a "complex delta" that requires a programmatic timing mechanism. Two candidates were evaluated: **Schedulable Apex** (a dedicated scheduler class polling approval timestamps) and **Flow Orchestrator** (platform-native async orchestration with built-in step timers).

SOUL R-02 mandates native-first. Flow Orchestrator is a platform-native declarative capability and takes precedence over Schedulable Apex.

## Decision

The 4-hour approval SLA escalation is implemented via **Flow Orchestrator** with a scheduled stage:

- Advanced Approvals submits the quote → sets `Quote.Approval_Submitted_DateTime__c`
- Flow Orchestrator (`TelcoApprovalEscalationOrchestration`) launched on quote record update
- **Stage 1:** Wait step — pauses for 4 business hours (Flow Orchestrator native `$GlobalConstant` time-based resume condition)
- **Stage 2:** Evaluation step — checks `Quote.Approval_Status__c` still = `Pending`
- **Stage 3 (conditional):** If still pending → Invocable Apex `EscalateTelcoApproval` executes:
  - Reassigns the open approval step to `$Record.Owner:User.Manager` (Finance Director's manager or NetOps VP's manager respectively)
  - Posts a Chatter notification to the escalated approver
  - Stamps `Quote.Last_Escalated_DateTime__c`
- Orchestration terminates when `Quote.Approval_Status__c` = `Approved` or `Rejected`

Agent-readiness (AR-4): Agentforce can call `SubmitForTelcoApproval` Invocable Apex to programmatically submit the quote. Approval status is readable via SOQL on `ProcessInstance` — agent can surface status without a UI screen.

> **The git commit of this file is the approval event. No commit = no approval.**

## Alternatives Rejected

| Alternative | Reason Rejected |
|---|---|
| Schedulable Apex polling loop | Violates SOUL R-02 — Flow Orchestrator is the platform-native equivalent; Schedulable Apex minimum resolution is 1 minute (acceptable) but introduces a governor-limit-exposed polling class that must be re-scheduled after each org deploy |
| Advanced Approvals native escalation rules | AA escalation rules are time-based on calendar days — no sub-day (4-hour) precision supported natively |
| Platform Event + subscriber Apex | Adds unnecessary indirection — Flow Orchestrator handles async wait natively without event infrastructure |
| Parallel approval (simultaneous Finance + NetOps) | Rejected by business requirement — sequential sign-off is a compliance mandate, not a preference |

## Consequences

**Positive:**
- Flow Orchestrator is fully declarative — visible in Setup, no Apex deploy cycle for routing logic changes
- 4-hour business-hour precision supported via Orchestrator scheduled resume conditions
- `EscalateTelcoApproval` Invocable Apex is narrow-scoped — reassigns approval step only, no pricing logic, no DML on Quote pricing fields
- AR-4 satisfied: `SubmitForTelcoApproval` Invocable Apex provides deterministic API entry point for Agentforce
- Orchestration audit trail is native — every stage transition logged in Flow Interview logs

**Negative / Trade-offs:**
- Flow Orchestrator requires `Flow Orchestration` feature to be enabled in org — [DevOps] must verify before build starts (`sf org display` check)
- Business-hours escalation requires a `BusinessHours` record configured in org — [DevOps] pre-flight check required
- `EscalateTelcoApproval` Invocable Apex must have 90%+ test coverage; mock must simulate ProcessInstance reassignment

**Risks:**
- Risk: Flow Orchestrator not enabled in target org — escalation flow cannot be deployed. Mitigation: [DevOps] pre-flight check mandatory; this is a feature flag, not a license change.
- Risk: `$Record.Owner:User.Manager` is null for a Finance Director with no manager set in org. Mitigation: Invocable Apex must null-check manager field; fallback escalates to a named `Telco_Approval_Fallback_Queue` (Custom Metadata record).
- Risk: Orchestration instance not terminated if approval resolved outside the normal flow (e.g. admin override). Mitigation: Orchestration evaluates `Approval_Status__c` at Stage 2 — if already resolved, terminates without escalating.

## Story Decomposition (D-9 Resolution)

Per [TA] D-9 ruling, US-FTR005-002 (8pts) is decomposed into:

| New Story | Title | Points | Scope |
|---|---|---|---|
| US-FTR005-002a | Sequential approval routing — Finance Director then NetOps VP | 4 pts | Advanced Approvals configuration; quote lock on >20% discount; `SubmitForTelcoApproval` Invocable Apex |
| US-FTR005-002b | 4-hour SLA escalation via Flow Orchestrator | 4 pts | Flow Orchestrator build; `EscalateTelcoApproval` Invocable Apex; Business Hours config; manager null-check fallback |

## SID Compliance
Standard objects only — no SID deviation:
- `Quote` — SID `Agreement`
- `ProcessInstance`, `ProcessInstanceStep` — SID `CustomerInteraction` (approval workflow)

## Related
- `SOUL.md` rules invoked: R-02 (native-first — Flow Orchestrator over Schedulable Apex), R-05 (no hardcoded approver IDs — manager resolved via User relationship, fallback via Custom Metadata)
- `HIGH-LEVEL.md`: Pro-Code boundary — `Approval routing (complex delta) → Apex` — `EscalateTelcoApproval` is the scoped Apex; routing logic remains in Flow Orchestrator
- `HIGH-LEVEL.md`: AR-4 Agent-Readiness — `SubmitForTelcoApproval` satisfies explicit approval gate requirement
- Linked ADRs: ADR-002 (async pattern precedent — same Invocable Apex pattern for agent actions)
- Feature Tracker: FTR-005
- D-9 story decomposition: US-FTR005-002a (4pts) + US-FTR005-002b (4pts)
