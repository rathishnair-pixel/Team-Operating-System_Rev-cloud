# Project State — Team OS v4.0
**Last Updated:** 2026-05-26

## North Star Metric
> **Reduce Quote-to-Activation time from 14 days to 3 days**
> - Baseline: 14 days (current average from quote signature to network activation)
> - Target: 3 days (79% reduction)
> - Measurement: Salesforce report — `Order.ActivatedDate` minus `Quote.SignedDate` per order
> - Review Cadence: Sprint-end + 30/60/90 day post-deploy
> - Owner: [PM] tracks, [TA] owns activation loop SLA

## Active Sprint
**Epic E-001 (5G Smart Office) — COMPLETE ✅**
All 3 features (FTR-004, FTR-005, FTR-006) delivered through Deploy gate.
All ADRs (ADR-002 to ADR-006) committed.
All 5G Smart Office Apex classes, Flows, CML models, test classes, seeding scripts deployed.

**Next up:** Epic E-000 (Team OS Foundation) — FTR-003 (Internet Commercial Offers) is in discovery/blocked on DEP-003 (legal sign-off). FTR-001 build in progress.

## Epic Status

| Epic | Features | Status | Notes |
|---|---|---|---|
| E-001 — 5G Smart Office | FTR-004, FTR-005, FTR-006 | **COMPLETE** ✅ | All gates approved through deploy |
| E-000 — Team OS Foundation | FTR-001, FTR-002, FTR-003 | In Progress | FTR-002 complete; FTR-001 build in progress; FTR-003 blocked DEP-003 |

## [TA] Architecture Blocks — All Resolved for E-001
| Block | Feature | Resolution |
|---|---|---|
| D-6: WL-4 agent-readiness | FTR-004 | CLEARED — ADR-006: SmartOfficeBundleContext + ConfigureTelcoBundle |
| D-7: Price Rule eval order | FTR-005 | ENFORCED — FTR-005 volume discount before FTR-001 tiered matrix |
| D-9: 8pt story smell | FTR-005 | RESOLVED — US-FTR005-002 → 002a (4pts) + 002b (4pts) |
| Flow Orchestration flag | FTR-005 | In devops-preflight-5g.sh (Check 2) |
| FSL license check | FTR-006 | In devops-preflight-5g.sh (Check 4) |
| DEP-005, DEP-008 | FTR-005/006 | RESOLVED — seed-5g-products.sh |

## Pending ADRs
All committed. No pending ADRs.
| ADR | Decision | Status |
|---|---|---|
| ADR-002 | Async Queueable Apex — Telco Network Activation | COMMITTED |
| ADR-003 | Platform Events — ERP Hardware Routing | COMMITTED |
| ADR-004 | Declarative-First PoT Filter | COMMITTED |
| ADR-005 | Flow Orchestrator — 4-Hour Approval SLA | COMMITTED |
| ADR-006 | SmartOfficeBundleContext — Agentforce Context Definition | COMMITTED |

## Pricing Budget — 5G Smart Office
| Procedure | Scope | Element Budget |
|---|---|---|
| Procedure 1 — Core Pricing | Base Hardware + Data Plan | Max 50 elements |
| Procedure 2 — Dynamic Services | Fiber distance pricing matrix | Max 30 elements |
| Procedure 3 — SLA Allocation | Telco Platinum SLA PoT | Max 20 elements |
| **Total** | | **Max 100 / 200 ceiling** |

## Current Metadata Inventory — 5G Smart Office (E-001)

### Apex Classes (6 production + 6 test)
| Class | Purpose | Coverage |
|---|---|---|
| ConfigureTelcoBundle | Agentforce bundle config — CML gate, AR-1 to AR-4 | ConfigureTelcoBundleTest (5 tests) |
| SubmitForTelcoApproval | AR-4 approval gate for >20% discounts | SubmitForTelcoApprovalTest (4 tests) |
| EscalateTelcoApproval | Flow Orchestrator callback — 4hr SLA breach | EscalateTelcoApprovalTest (3 tests) |
| TelcoNetworkActivationQueueable | Track 2 async activation — 3-attempt backoff | TelcoNetworkActivationQueueableTest (4 tests) |
| CreateFieldServiceWorkOrder | Track 3 FSL Work Order — 24hr SLA window | CreateFieldServiceWorkOrderTest (4 tests) |
| EnqueueNetworkActivation | Flow-callable Queueable wrapper (SOUL R-04) | EnqueueNetworkActivationTest (2 tests) |

### Record-Triggered Flows (3)
| Flow | Trigger | Track |
|---|---|---|
| Order_Activation_Hardware_Fulfillment | Order.Status → Activated | Track 1 — publishes Hardware_Fulfillment__e |
| Asset_IMEI_Scan_Network_Activation | Asset.IMEI_Scanned__c → true | Track 2 — enqueues network activation |
| Order_Activation_Fiber_Work_Order | Order.Status → Activated | Track 3 — creates FSL Work Orders |

### CML Models (4)
| CML | Key Rules |
|---|---|
| Edge5GEnterpriseRouterCML | Requires Data Plan; max 1 per site |
| Unlimited5GCoreDataPlanCML | Requires Router; min 1 per site |
| FiberDropSiteInstallationCML | Requires Router; PoT-excluded (ADR-004) |
| TelcoPlatinumSLACML | Requires Router + Data Plan; 15% PoT trigger |

### Custom Fields (9 across 4 objects)
| Object | Field | Purpose |
|---|---|---|
| Asset | Network_Activation_Status__c | Track 2 activation state |
| Asset | IMEI_Scanned__c | Track 2 trigger gate |
| Asset | Activated_DateTime__c | North Star KPI measurement |
| Asset | OrderItemId__c | Links Asset to OrderItem for Queueable |
| OrderItem | Network_Status__c | Mirrors Asset activation state |
| OrderItem | ERP_Confirmed__c | Track 1 idempotency guard |
| OrderItem | Fiber_Meters__c | Drives Track 3 install price + WO prep |
| OrderItem | Site_Id__c | ERP routing key + WO subject |
| Quote | Last_Escalated_DateTime__c | Flow Orchestrator escalation timestamp |

### Platform Event (1)
| Event | Fields | Purpose |
|---|---|---|
| Hardware_Fulfillment__e | 7 fields | ERP hardware routing (ADR-003) |

### Approval Process (1)
| Process | Steps | Trigger |
|---|---|---|
| TelcoDiscount_ApprovalProcess | Finance Director → NetOps VP | Quote.Discount__c > 20% |

### DevOps Scripts (2)
| Script | Purpose |
|---|---|
| scripts/seed-5g-products.sh | Seeds 4 SKUs + PricebookEntries — resolves DEP-005 + DEP-008 |
| scripts/devops-preflight-5g.sh | 10-check pre-deploy validation |

## Pending QA/Deployment
- [ ] Run `sf apex run test --test-level RunLocalTests` in rc-dev to confirm all tests green in org
- [ ] Verify `Asset.Activated_DateTime__c` is being stamped on live activation (North Star KPI measurement field)
- [ ] Confirm Flow Orchestration BusinessHours record exists in org (devops-preflight Check 3)
- [ ] FTR-003 (Internet Commercial Offers) — blocked on DEP-003 (legal/regulatory sign-off on broadband pricing tiers)

## Org
- **Alias:** rc-dev
- **Username:** revenuecloudrn@gmail.com
- **Instance:** https://dg8000002dc8deau-dev-ed.develop.my.salesforce.com
- **API Version:** 66.0

## Knowledge Graph
- Last refreshed: 2026-05-26 (post E-001 deploy)
- `knowledge-graph/org-graph.json` — update after first live activation confirms end-to-end
