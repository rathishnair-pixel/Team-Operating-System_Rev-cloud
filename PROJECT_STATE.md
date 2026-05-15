# Project State — Eco-Green Modular Server Smart Swap
**Last Updated:** 2026-05-14

## Active Sprint
Sprint 1 — Complete. All 6 layers shipped and verified.

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
- [ ] Data Cloud grounding (D-02 from REVENUE_SPEC.md) — never verified; current implementation does not use Data Cloud
- [ ] End-to-end live test: Create Quote with HE-RACK-001 → run all 4 actions in sequence → confirm approval routing fires in org

## Org
- **Alias:** rc-dev
- **Username:** revenuecloudrn@gmail.com
- **Instance:** https://dg8000002dc8deau-dev-ed.develop.my.salesforce.com
- **API Version:** 66.0
