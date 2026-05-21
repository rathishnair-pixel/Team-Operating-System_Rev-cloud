# REVENUE_SPEC.md
**Feature:** Eco-Green Modular Server Smart Swap Agent
**Spec Version:** 1.0
**Date:** 2026-05-14
**Status:** Awaiting [TA] Review

---

## 1. Commercial Offer (The "What")

| Attribute | Value |
|---|---|
| Offer Type | Nested Bundle (mixed-billing) |
| Legacy SKU | High-Energy Server Rack (to be Superseded — NOT deleted) |
| New SKU | Eco-Green Modular Server (Nested Bundle) |

### Bundle Structure — Eco-Green Modular Server

| Child Product | Type | Billing | Price | Notes |
|---|---|---|---|---|
| Eco-Core Chassis | Component | One-time | TBD | Physical hardware frame |
| High-Efficiency PSU | Component | One-time | TBD | Modular power supply |
| Smart-Cooling AI | Component | Recurring (monthly/annual) | TBD | Software cooling optimizer |
| Carbon Offset Credit | Optional Add-on | One-time | $500 list / $0 net | Auto-added on swap acceptance; 100% discount applied |

---

## 2. Target Customer & Channel (The "Who")

| Attribute | Value |
|---|---|
| Segment | Internal Enterprise Sales Reps |
| Platform | Salesforce Lightning Experience |
| Agent Surface | Agentforce Side Panel |
| Interaction Mode | **Dual:** Rep-Led (Quote Line Editor) + System-Prompted (Data Cloud Proactive Action) |
| Data Cloud | **CONFIRMED IN SCOPE** — detects legacy SKU on active Quote and fires Proactive Action |
| Regional Constraints | None defined; Carbon Offset availability to be confirmed per territory |

### Agent Trigger Logic
- **Rep-Led:** Rep opens Quote Line Editor → invokes agent to "optimize this deal"
- **System-Prompted:** Data Cloud segment detects `Product2.ProductCode = 'HIGH-ENERGY-RACK'` on an open Quote → fires Proactive Action in Side Panel

---

## 3. Pricing Logic (The "How Much")

### Pricing Model: Margin-Preservation Solve

**Formula:**
```
Target Margin% = (Legacy Bundle Price - Legacy Aggregate Standard Cost) / Legacy Bundle Price

Required Swap Price = New Aggregate Standard Cost / (1 - Target Margin%)
```

### Cost Source
- **Object:** Standard Cost (related to Product2) — NOT PricebookEntry
- **Version Strategy:** Always fetch the record with the latest active `EffectiveDate ≤ QuoteDate`
- **Aggregation:** Total Bundle Level (all child components summed, including Carbon Offset acquisition cost)

### Carbon Offset Margin Impact
- List Price: $500 | Net Revenue: $0 (100% discount)
- Acquisition Cost: TBD — must be included in aggregate cost denominator
- **Impact:** Suppresses aggregate margin%; solve must account for this cost burden before calculating required swap price

### Identical Net Total Goal
- The agent targets `New Bundle Net Total = Legacy Quote Line Net Total`
- Margin% must be equal to or greater than legacy margin% after Carbon Offset cost burden is applied

---

## 4. Business Rules & Constraints (The "Rules")

### Rule 1 — Legacy Line Supersession (Audit Trail)
- Do NOT delete the High-Energy Server Rack Quote Line
- Set `Status = 'Superseded'` on the legacy line
- Add a lookup field on the new Eco-Green Quote Line pointing to the legacy Quote Line ID
- Purpose: preserves Commercial Intent for renewal cycles and swap history audit

### Rule 2 — Carbon Offset Auto-Add
- On Rep acceptance of swap: automatically add Carbon Offset Credit as a child product to the bundle
- Apply 100% discount to Carbon Offset line
- Carbon Offset Cost must be included in aggregate margin calculation

### Rule 3 — Dynamic Approval Chain (Advanced Approvals)
| Condition | Approval Route |
|---|---|
| New bundle total < legacy total AND discount delta ≤ 30% | Route to Direct Manager |
| New bundle total < legacy total AND discount delta > 30% | Escalate to Deal Desk |
| New bundle total ≥ legacy total | No approval required |

> **[TA] BLOCKER:** Advanced Approvals (SBQQ namespace) must be verified on rc-dev before this rule can be implemented. Fallback: native Approval Process + Flow-based escalation router.

### Rule 4 — Margin Floor
- Agent must not accept a swap configuration where resulting Margin% < Legacy Margin%
- If Carbon Offset cost burden makes this mathematically impossible at $0 net, surface a warning to the Rep

---

## 5. Fulfillment & Contract (The "Fulfillment")

### Order → Contract Sequence
```
Quote Accepted
      ↓
Quote Status → 'Ordered'
      ↓
Order Activated (standard fulfillment — hardware shipping gate)
      ↓
Contract created + Billing Schedules generated
      (Smart-Cooling AI recurring schedule starts post-Order activation)
```

### Billing Treatment
| Component | Billing Trigger |
|---|---|
| Eco-Core Chassis | On Order activation |
| High-Efficiency PSU | On Order activation |
| Smart-Cooling AI | Recurring schedule generated on Contract activation |
| Carbon Offset Credit | On Order activation ($0 — no invoice line) |

### Key Design Constraint
- Billing schedules MUST NOT generate on Quote acceptance — only on Order activation
- This protects against billing triggering during hardware shipping delays

---

## 6. Critical Dependencies (Pre-Build Gates)

| # | Dependency | Owner | Status |
|---|---|---|---|
| D-01 | Verify Advanced Approvals installed on rc-dev | [DevOps] | ⏳ Pending |
| D-02 | Verify Data Cloud provisioned & connected to rc-dev | [DevOps] | ⏳ Pending |
| D-03 | Confirm Standard Cost object exists & is queryable | [DA] | ⏳ Pending |
| D-04 | Add `Status` (Superseded) field to QuoteLine if not present | [SA] | ⏳ Pending |
| D-05 | Add lookup field on QuoteLine → legacy QuoteLine ID | [SA] | ⏳ Pending |
| D-06 | Confirm Carbon Offset Credit product exists in rc-dev catalog | [SA] | ⏳ Pending |
| D-07 | Context Definition audit for Quote + QuoteLine data passing | [SA] | ⏳ Pending |
| D-08 | Check Figma AI Testing project for RC design files | [XA] | ⏳ Pending |

---

## 7. Agentforce Actions Required (Draft)

| Action Class | Purpose | Trigger |
|---|---|---|
| `DetectLegacySkuAction` | Detects HIGH-ENERGY-RACK on open Quote; surfaces swap recommendation | Data Cloud Proactive / Rep invocation |
| `CalculateMarginPreservationAction` | Solves for required swap bundle price preserving legacy margin% | Pre-swap price calculation |
| `ExecuteSwapAction` | Supersedes legacy line, adds Eco-Green bundle + Carbon Offset, applies discount | Rep acceptance |
| `EvaluateApprovalAction` | Calculates discount delta; routes to Manager or Deal Desk via Advanced Approvals | Post-swap, pre-commit |

---

## 8. [QA] Success Criteria (Draft)

- [ ] Margin% post-swap ≥ Margin% pre-swap (including Carbon Offset cost burden)
- [ ] Net Total post-swap = Net Total pre-swap (within $0.01 rounding tolerance)
- [ ] Legacy Quote Line status = 'Superseded'; lookup field populated
- [ ] Carbon Offset Credit child line present with 100% discount
- [ ] Approval triggered when discount delta > 0%; escalated to Deal Desk when delta > 30%
- [ ] No approval triggered when new bundle total ≥ legacy total
- [ ] Billing schedule NOT generated until Order activation
- [ ] Smart-Cooling AI recurring schedule generated on Contract activation only
- [ ] All Agentforce Action descriptions ≥ 20 words
- [ ] Test coverage ≥ 90% on all logic

---

*Ready for [TA] Technical Architect review. Pending: D-01 through D-08 verification.*
