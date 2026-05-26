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
Team OS v4.0 — Epic E-001 (5G Smart Office). All 4 ADRs committed (ADR-002 to ADR-005).
Sprint HOLD: [TA] D-9 ruling — US-FTR005-002 (8pts) decomposed into 002a (4pts) + 002b (4pts).
[DevOps] pre-flight required: Flow Orchestration feature flag + BusinessHours record in org before FTR-005 build.
[Dev] blocked on application code until D-6 resolved: Context Definitions must wrap bundle before WL-4 gate clears.

## [TA] Architecture Blocks — Active
| Block | Feature | Resolution |
|---|---|---|
| D-6: WL-4 agent-readiness | FTR-004 | **CLEARED** — ADR-006 committed: SmartOfficeBundleContext + ConfigureTelcoBundle__apex. WL-4 = true |
| D-7: Price Rule eval order | FTR-005 | Enforced: FTR-005 volume discount (Step 1) → FTR-001 tiered matrix (Step 2) |
| D-9: 8pt story smell | FTR-005 | RESOLVED — US-FTR005-002 split into 002a + 002b (4pts each) |
| Flow Orchestration flag | FTR-005 | [DevOps] must verify org has Flow Orchestration enabled before US-FTR005-002b build |
| BusinessHours record | FTR-005 | [DevOps] must verify BusinessHours configured in org |
| FSL license check | FTR-006 | [DevOps] must verify Field Service Lightning enabled in org |
| DEP-008: FTR-004 products in org | FTR-006 | Prototype blocked until FTR-004 product records seeded |

## Prototype Stage — Current Status (2026-05-26)
| Feature | Prototype Status | Type | Customer Approved |
|---|---|---|---|
| FTR-004 | In Progress | salesforce-sandbox (headless JSON payload) | Awaiting |
| FTR-005 | In Progress | process-walkthrough | Awaiting |
| FTR-006 | Pending | process-walkthrough | Blocked — DEP-008 open |

## Pricing Budget — 5G Smart Office (D-4 Domain Budget)
| Procedure | Scope | Element Budget |
|---|---|---|
| Procedure 1 — Core Pricing | Base Hardware + Data Plan pricing | Max 50 elements |
| Procedure 2 — Dynamic Services | Fiber distance pricing matrix | Max 30 elements |
| Procedure 3 — SLA Allocation | Telco Platinum SLA PoT calculation | Max 20 elements |
| **Total** | | **Max 100 / 200 ceiling** |

## Team OS Protocol Status
| # | Protocol | Status | Notes |
|---|---|---|---|
| 1 | Paced Discovery (Interview Mode) | Active | |
| 2 | /plan Review Gate (Pre-Build) | Active | |
| 3 | PO Interview — Feature Discovery | Active | |
| 4 | Build & QA Loop | Active | |
| 5 | **Technical Decomposition Protocol** | **Active — 2026-05-22** | 8-13pt stories must be sliced to ≤3pt vertical slices via INVEST criteria |
| 6 | Feature Journey Dashboard | Active | FEATURE_TRACKER.json → generate-journey.js |
| 7 | Approval Gate — Human-in-the-Loop | Active | approved / skip / revise vocabulary |
| 8 | Delta Rule | Active | |
| 9 | Source Citation Appendix (MCP) | Active | |

## Pending ADRs (decisions made this session that need a commit)
| ADR | Decision | Owner | Status |
|---|---|---|---|
| ADR-002 | Async Queueable Apex for Telco Network Activation | [TA] | COMMITTED |
| ADR-003 | Platform Events for ERP Hardware Routing | [TA] | COMMITTED |
| ADR-004 | Declarative-First PoT Filter with Apex Pre-Hook Fallback | [TA] | COMMITTED |
| ADR-005 | Flow Orchestrator for 4-Hour Approval SLA Escalation | [TA] | COMMITTED |

## Recent Decisions (The "Why")
- **Standalone ContextDefinition**: Platform-managed `RLM_SalesTransactionContext` cannot be extended via metadata (all attributes are `inheritedFrom`). Created self-contained `EcoGreenSwapContext` with `EcoSwapLineItem` node (`transposable=true`) instead.
- **Flow-based Approval (not Classic ApprovalProcess)**: Classic approval process XML references FieldUpdate actions that don't exist in this org. Switched to `processType=ApprovalWorkflow` orchestration flow (`EcoGreenSwapApprovalRouter`) — matches the existing `MultiLevel_Quote_Apporval` pattern in org.
- **EvaluateApprovalAction stamps Quote directly**: Rather than a separate flow-launch call, `EvaluateApprovalAction` sets `Quote.EcoSwapApproverTier__c` + `Status='Needs Review'` via `Database.update` — RecordAfterSave trigger fires `EcoGreenSwapApprovalRouter` automatically.
- **VP-level Deal Desk assignee**: No Deal Desk queue exists in org (only `DRO Fulfilment Queue`). Used `$Record.Owner:User.Manager.Manager.Username` as VP-level escalation path.
- **Dynamic DML for ProductCost__c**: Used `Schema.getGlobalDescribe().get('ProductCost__c')` pattern to bypass Apex compile-time schema cache on recently deployed object.

## Current Schema Changes

### Custom Fields
| Object | Field | Type | Status |
|---|---|---|---|
| QuoteLineItem | LineStatus__c | Picklist (Active/Superseded) | ✅ Deployed |
| QuoteLineItem | SupersededById__c | Lookup(QuoteLineItem) | ✅ Deployed |
| Quote | EcoSwapApproverTier__c | Picklist (Manager/DealDesk) | ✅ Deployed |

### Custom Objects
| Object | Purpose | Status |
|---|---|---|
| ProductCost__c | Standard cost by Product2 + bundle component | ✅ Deployed |

### Products / Pricebook
| SKU | Name | Type | Status |
|---|---|---|---|
| HE-RACK-001 | Legacy HE Server Rack | One-time | ✅ Seeded |
| ECO-BUNDLE-001 | Eco-Green Modular Server Bundle | Mixed | ✅ Seeded |
| ECO-CHASSIS-001 | Eco Modular Chassis | One-time component | ✅ Seeded |
| ECO-PSU-001 | Eco Power Supply Unit | One-time component | ✅ Seeded |
| ECO-COOLING-001 | Eco Liquid Cooling Module | One-time component | ✅ Seeded |
| ECO-CARBON-001 | Carbon Offset Subscription | Evergreen monthly | ✅ Seeded |

## 📦 Current Metadata Inventory

### Agentforce Actions (InvocableMethods)
| Class | Label | Category | Coverage |
|---|---|---|---|
| DetectLegacySkuAction | Detect Legacy HE-RACK-001 Lines | EcoGreen Swap | 100% |
| CalculateMarginPreservationAction | Calculate Margin-Preservation Swap Price | EcoGreen Swap | 100% |
| EvaluateApprovalAction | Evaluate Eco-Green Swap Approval Requirements | EcoGreen Swap | 100% |
| ExecuteSwapAction | Execute Eco-Green Product Swap | EcoGreen Swap | 100% |

### Flows
| Flow | Type | Trigger | Status |
|---|---|---|---|
| EcoGreenSwapApprovalRouter | ApprovalWorkflow | Quote.Status = Needs Review (RecordAfterSave) | ✅ Deployed |

### Validation Rules (CML Layer)
| Rule | Object | Purpose | Status |
|---|---|---|---|
| EcoSwap_PreventDoubleSwap | QuoteLineItem | Blocks re-superseding already-superseded line | ✅ Deployed |
| EcoSwap_NoReactivateSuperseded | QuoteLineItem | Blocks reverting Superseded → Active | ✅ Deployed |
| EcoSwap_RequireAuditLinkWhenSuperseded | QuoteLineItem | Requires SupersededById__c when Superseded | ✅ Deployed |

### Context Definitions
| Context | Node | Attributes | Status |
|---|---|---|---|
| EcoGreenSwapContext | EcoSwapLineItem | 5 (QuoteLineItemId, QuoteId, LineStatus, SupersededById, StandardCost) | ✅ Deployed |

### Test Coverage
- `EcoGreenSwapActionsTest`: 15 tests, all passing
- `EcoGreenSwapTestUtils`: Full fixture factory (Account → Opp → PB → Products → PBEs → ProductCost__c → Quote → QLL)
- All 4 Apex action classes: **100% code coverage**

## Critical Dependencies
- `Standard Price Book` must exist before any seeding runs
- `ProductCost__c` records required by `CalculateMarginPreservationAction` — missing costs return `calculationError`
- `EcoSwapApproverTier__c` field on Quote must be deployed before `EcoGreenSwapApprovalRouter` flow (flow references `$Record.EcoSwapApproverTier__c`)
- Approval chain names `Swap_Manager_Review` and `Swap_DealDesk_Review` referenced in flow — must exist in org before live approval routing works end-to-end

## Pending QA/Deployment
- [ ] Classic approval process XML files (`Quote.EcoGreenSwap_ManagerApproval.approvalProcess-meta.xml`, `Quote.EcoGreenSwap_DealDeskApproval.approvalProcess-meta.xml`) — on disk but not deployed; superseded by flow approach; candidates for cleanup
- [ ] Data Cloud grounding (D-02 from REQUIREMENTS_BASELINE.md) — never verified; current implementation does not use Data Cloud
- [ ] End-to-end live test: Create Quote with HE-RACK-001 → run all 4 actions in sequence → confirm approval routing fires in org

## Org
- **Alias:** rc-dev
- **Username:** revenuecloudrn@gmail.com
- **Instance:** https://dg8000002dc8deau-dev-ed.develop.my.salesforce.com
- **API Version:** 66.0
