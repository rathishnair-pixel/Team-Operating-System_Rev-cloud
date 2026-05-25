# HIGH-LEVEL.md — Team OS Solution Principles & Architecture Boundaries
> **Semantic Bootloader Layer 2.** Read after SOUL.md, before CLAUDE.md. These are guiding principles, eTOM process boundaries, the RCA pattern library, Pro-Code/Declarative boundaries, and Standard-First data model guidelines. SOUL.md hard rules override anything in this file when they conflict.

---

## eTOM Business Process Framework (GB921 v25)
> Source: TM Forum training knowledge — GB921 suite structure (L0 → L1 → L2). Full normative text requires TM Forum membership at tmforum.org. This taxonomy is accurate to GB921 v22–v25 and sufficient for feature anchoring and cross-impact analysis in Team OS.

Every feature must be anchored to an eTOM process at **L1 minimum** (L2 preferred). [SA] declares the process ID at Step 1 of every PO Interview. A feature without a declared process cannot enter the design gate (SOUL R-13).

---

### L0 — Three Process Areas

| Area | Code | Scope | When to use |
|---|---|---|---|
| **Strategy, Infrastructure & Product** | SIP | Design, plan, build — before live operations | Product launches, catalog changes, service design |
| **Operations** | OPS | Run live services for customers | Quoting, ordering, billing, assurance, support |
| **Enterprise Management** | EM | Run the business itself | Finance, HR, legal, governance |

> For Comms Cloud / RCA work, **OPS** and **SIP** are the primary areas. EM rarely surfaces in feature work.

---

### L1 / L2 — Operations (OPS)

The OPS area is a **4-row × 4-column matrix**. Every cell is a named L2 process.

**Columns (lifecycle phases):**

| Column Code | Name | What it covers |
|---|---|---|
| **OSR** | Operations Support & Readiness | Pre-operational setup — data, tools, staff readiness before live transactions begin |
| **FUL** | Fulfillment | Quoting → ordering → provisioning → activation |
| **ASR** | Assurance | Monitor, detect, diagnose, fix, SLA compliance |
| **BRM** | Billing & Revenue Management | Rate, invoice, collect, recognise revenue |

**Rows (business domains):**

| Row Code | Name | Abbreviation |
|---|---|---|
| CRM | Customer Relationship Management | CRM |
| SMO | Service Management & Operations | SM&O |
| RMO | Resource Management & Operations | RM&O |
| SPRM | Supplier/Partner Relationship Management | S/PRM |

---

#### OPS Matrix — L2 Process Cells

| | OSR | Fulfillment | Assurance | Billing & Revenue Mgmt |
|---|---|---|---|---|
| **CRM** | CRM Support & Readiness `1.1.1` | Order Handling `1.1.2` · Selling `1.1.3` · Marketing Fulfillment Response `1.1.4` | Problem Handling `1.1.5` · Customer QoS/SLA Management `1.1.6` | Billing & Collections Management `1.1.7` · Retention & Loyalty `1.1.8` |
| **SM&O** | SM&O Support & Readiness `1.2.1` | Service Configuration & Activation `1.2.2` | Service Problem Management `1.2.3` · Service Quality Management `1.2.4` | Service & Specific Instance Rating `1.2.5` |
| **RM&O** | RM&O Support & Readiness `1.3.1` | Resource Provisioning `1.3.2` | Resource Trouble Management `1.3.3` · Resource Performance Management `1.3.4` | Resource Data Collection & Processing `1.3.5` |
| **S/PRM** | S/PRM Support & Readiness `1.4.1` | Selling & Order Handling `1.4.2` | Problem Reporting & Management `1.4.3` · Performance Reporting `1.4.4` | Settlement & Payments `1.4.5` |

---

#### OPS L2 → Salesforce Objects Mapping

| eTOM L2 Process | Code | Key Salesforce Objects | RCA / Comms Cloud Component |
|---|---|---|---|
| CRM Support & Readiness | 1.1.1 | Account, Contact, PriceBook2 | Product Catalog, Context Definition setup |
| Order Handling | 1.1.2 | Quote, QuoteLineItem, Order, OrderItem | RCA Quote → Order flow |
| Selling | 1.1.3 | Opportunity, Quote, CPQ/RCA Config | Guided Selling, ProductCatalog |
| Marketing Fulfillment Response | 1.1.4 | Campaign, Lead, ProductOffering | Offer Management |
| Problem Handling | 1.1.5 | Case, CaseComment, Entitlement | Customer Support |
| Customer QoS/SLA Management | 1.1.6 | Entitlement, SLAProcess, WorkOrder | Service Level tracking |
| Billing & Collections Management | 1.1.7 | Invoice, BillingSchedule, Payment | RCA Invoice, Contract |
| Retention & Loyalty | 1.1.8 | ContractLineItem, Asset, RenewalOpportunity | Contract amendment, renewal |
| SM&O Support & Readiness | 1.2.1 | ServiceCatalog, ServiceDefinition | Service Specification setup |
| Service Configuration & Activation | 1.2.2 | ServiceOrder, Asset, WorkOrder | Order activation, provisioning |
| Service Problem Management | 1.2.3 | Case, WorkOrder, KnowledgeArticle | Field Service, escalation |
| Service Quality Management | 1.2.4 | Entitlement, Metric, Report | SLA dashboards |
| Service & Specific Instance Rating | 1.2.5 | UsageRecord, RatingResult | Usage-based pricing, DPE |
| Resource Provisioning | 1.3.2 | Asset, NetworkResource (custom) | Physical/logical resource activation |
| Resource Trouble Management | 1.3.3 | Case, WorkOrder | Network issue management |
| Resource Data Collection & Processing | 1.3.5 | UsageRecord, DataStream | Usage metering, Data Cloud |
| Settlement & Payments | 1.4.5 | Invoice, PaymentGateway, PartnerAccount | Partner billing settlement |

---

### L1 / L2 — Strategy, Infrastructure & Product (SIP)

SIP has **4 horizontal process groups × 3 vertical lifecycle columns**.

**Columns:**

| Column | Name | Scope |
|---|---|---|
| **S&C** | Strategy & Commit | Long-range planning, business cases, investment decisions |
| **ILM** | Infrastructure Lifecycle Management | Build, deploy, maintain infrastructure and platforms |
| **PLM** | Product Lifecycle Management | Design, launch, maintain, retire products and services |

**Rows (process groups):**

| Row | Name | Code |
|---|---|---|
| MOM | Marketing & Offer Management | 2.1.x |
| SDM | Service Development & Management | 2.2.x |
| RDM | Resource Development & Management | 2.3.x |
| SCDM | Supply Chain Development & Management | 2.4.x |

#### SIP L2 → Salesforce Objects Mapping

| eTOM L2 Process | Code | Key Salesforce Objects | RCA / Comms Cloud Component |
|---|---|---|---|
| Product & Offer Portfolio Planning | 2.1.1 | ProductCatalog, ProductCategory | Catalog strategy, bundle design |
| Product & Offer Capability Delivery | 2.1.2 | Product2, AttributeSet, PricingProcedure | Product build, Expression Sets |
| Product & Offer Launch | 2.1.3 | PriceBook2, PriceBookEntry, ProductOffering | Pricebook activation, offer publish |
| Product & Offer Retirement | 2.1.4 | Product2 (IsActive=false), AssetRetirement | End-of-life catalog management |
| Service Development | 2.2.1 | ServiceDefinition, ServiceSpecification | Service spec design |
| Service Deployment | 2.2.2 | ServiceOrder template, Flow | Service activation playbook |
| Resource Development | 2.3.1 | ResourceSpecification (custom) | Network resource spec |
| Supplier/Partner Relationship Dev. | 2.4.1 | PartnerAccount, Contract | Partner onboarding |

---

### L1 / L2 — Enterprise Management (EM)

Rarely touched directly in Comms Cloud features. Included for completeness.

| L1 Process | Code | Salesforce Relevance |
|---|---|---|
| Financial & Asset Management | 3.1.x | Revenue Recognition, ForecastingItem |
| Stakeholder & External Relations | 3.2.x | Community, PartnerPortal |
| Enterprise Architecture | 3.3.x | ADRs, HIGH-LEVEL.md (this file) |
| Knowledge & Research Management | 3.4.x | KnowledgeArticle, KnowledgeCategory |
| Enterprise Risk Management | 3.5.x | ComplianceItem (custom), AuditLog |

---

### 6 E2E Cross-Process Flows (Feature-Level Tags)

These horizontal flows span multiple L1/L2 cells. Use these as the `etom_process` tag in FEATURE_TRACKER.json — they are the right level of granularity for feature tagging. The L2 cells above are for **impact analysis and SID compliance checking**.

| Flow ID | Full Name | L2 Processes Spanned | Primary Salesforce Objects | FEATURE_TRACKER Tag |
|---|---|---|---|---|
| **C2M** | Concept-to-Market | 2.1.1 → 2.1.2 → 2.1.3 | ProductCatalog, Product2, PriceBook2, AttributeSet, PricingProcedure | `"C2M"` |
| **R2A** | Request-to-Answer | 1.1.1 → 1.1.3 → 1.1.2 (pre-order) | Account, Opportunity, Quote, QuoteLineItem, PriceBook2 | `"R2A"` |
| **O2P** | Order-to-Payment | 1.1.2 → 1.2.2 → 1.3.2 → 1.1.7 | Order, OrderItem, Asset, Invoice, Contract, UsageRecord | `"O2P"` |
| **R2C** | Request-to-Change | 1.1.8 → 1.1.2 → 1.2.2 | ContractLineItem, Asset, ChangeOrder, RenewalOrder | `"R2C"` |
| **T2C** | Trouble-to-Change | 1.1.5 → 1.1.6 → 1.2.3 | Case, Entitlement, WorkOrder, SLAProcess | `"T2C"` |
| **P2S** | Problem-to-Solution | 1.2.3 → 1.3.3 → 1.2.4 | Case, WorkOrder, KnowledgeArticle, ResourceRecord | `"P2S"` |

**Cross-feature impact rule:** Two features sharing any L2 process code (e.g., both touching `1.1.2 Order Handling`) have a potential conflict. [TA] must perform blast-radius analysis before both enter the sprint simultaneously.

---

### TM Forum SID — Shared Information/Data Model

SID is the **data model** that pairs with eTOM's process model. WL-2 ("Is the product model SID-compliant?") checks that every Salesforce object used maps to a named SID entity. If it doesn't, an ADR is required.

#### SID Domain Catalogue → Salesforce Object Mapping

| SID Domain | SID Entity | Salesforce Standard Object | Notes |
|---|---|---|---|
| **Product Domain** | ProductSpecification | Product2 | Core catalog item |
| | ProductOffering | Product2 + PriceBookEntry | Offer = Product + Price |
| | ProductOfferingPrice | PriceBookEntry, PricingProcedure | Pricing logic |
| | ProductOfferingTerm | ContractTerm (custom or standard) | Contract duration |
| | BundledProductOffering | ProductRelationship | Bundle parent-child |
| | ProductCharacteristic | ProductAttribute, AttributeSet | Configurable attributes |
| **Customer Domain** | Customer | Account (type=Customer) | Billing account holder |
| | CustomerAccount | Account + BillingAccount | Statement account |
| | CustomerInteraction | Case, EmailMessage, VoiceCall | All touchpoints |
| | CustomerOrder | Order | Confirmed purchase |
| | Agreement | Contract | Legal agreement |
| **Service Domain** | ServiceSpecification | ServiceDefinition (custom) | What is delivered |
| | ServiceOrder | ServiceOrder (custom/standard) | Activation instruction |
| | Service | Asset (service type) | Active delivered service |
| **Resource Domain** | ResourceSpecification | ResourceSpec (custom) | Network resource spec |
| | Resource | Asset (resource type) | Physical/logical resource |
| | LogicalResource | LogicalResource (custom) | IP, VLAN, number |
| | PhysicalResource | PhysicalResource (custom) | Device, port, circuit |
| **Common Business** | PartyRole | Contact, AccountContactRelation | Person in a role |
| | BillingAccount | Account + Invoice | Invoicing record |
| | PaymentMethod | PaymentGateway record | Card/direct debit |
| | UsageRecord | UsageRecord (standard in RCA) | Consumption event |
| | UsageSpecification | UsageType (standard in RCA) | How usage is counted |

#### WL-2 Compliance Check Protocol
[TA] performs this check before approving any product design:
1. List every Salesforce object the feature reads/writes
2. Map each to a SID entity using the table above
3. Any object with no SID mapping → ADR required before design proceeds
4. Custom objects must name the SID entity they represent in the ADR SID Compliance field
5. Standard objects that are being used outside their SID intent (e.g. using `Case` to store pricing data) → flag as SID deviation, ADR required

**Declaration Rule:** The eTOM E2E flow (`etom_process` in FEATURE_TRACKER.json) anchors all downstream design decisions, test scope, cross-feature impact analysis, and integration architecture. A feature without a declared process cannot enter the design gate (SOUL R-13).

---

## 18 Canonical RCA Patterns
Every business model must map to one before design begins. [SA] states the pattern ID in every `/plan`.

| Pattern ID | Name | Use When |
|---|---|---|
| `subscription-basic` | Basic Subscription | Single flat-rate recurring charge |
| `subscription-tiered` | Tiered Subscription | Multiple tier levels, different recurring rates |
| `usage-pure` | Pure Usage | All charges are consumption-based |
| `usage-prepaid-drawdown` | Prepaid Drawdown | Customer prepays a pool; usage draws it down |
| `subscription-usage-hybrid` | Subscription + Usage | Base recurring fee plus variable usage charges |
| `tiered-volume-pricing` | Tiered Volume Pricing | Price per unit changes based on total volume band |
| `volume-pricing` | Volume Pricing | Flat price per unit based on volume bracket |
| `multi-year-ramp` | Multi-Year Ramp | Price changes year-over-year on a scheduled ramp |
| `guided-selling` | Guided Selling | Agent or rules recommend products based on attributes |
| `partner-channel-pricing` | Partner Channel Pricing | Different price books per partner or channel |
| `cost-plus-markup` | Cost Plus Markup | Price derived from cost plus a markup percentage |
| `contract-negotiated` | Contract Negotiated | Price is negotiated and locked per contract |
| `annual-billing-monthly-recognition` | Annual Bill / Monthly Recognize | Invoice annually, recognize revenue monthly |
| `multi-entity-billing` | Multi-Entity Billing | Single order bills across multiple legal entities |
| `cpq-rca-coexistence` | CPQ + RCA Coexistence | Legacy CPQ and RCA running in parallel |
| `cpq-to-rca-migration` | CPQ to RCA Migration | Phased migration from CPQ to RCA |
| `rca-on-off-framework` | RCA On/Off Framework | Feature flags controlling RCA activation per org |

**Unmatched Pattern Rule:** If no pattern matches, [SA] issues a Customisation Challenge (Protocol 11 in CLAUDE.md) before any design work begins.

---

## Pro-Code vs Declarative Boundaries

| Scenario | Mandated Approach | Justification |
|---|---|---|
| Pricing logic | Expression Sets (declarative) | Native DPE — full Pricing Lineage traceability |
| Context preparation | Context Service (declarative) | Standard platform capability |
| Validation (single-object) | Validation Rules (declarative) | No code needed |
| Validation (multi-object) | Apex (code) | Validation Rules cannot span objects |
| UI customization | LWC (code) | Standard Aura/LWC patterns |
| Approval routing (flat threshold) | Flow (declarative) | Simple automation standard |
| Approval routing (complex delta) | Apex (code) | Flow cannot compute multi-step delta |
| Agent actions | Invocable Apex (code) | Required for Agentforce execution context |
| Integration orchestration | MuleSoft (platform) | Decoupled architecture mandate |

**Decision Rule:** Any Apex proposal that maps to a declarative row triggers the Native-First challenge (SOUL R-02). The burden of proof is on the Apex requester.

---

## Standard-First Data Model Guidelines
1. Use standard Revenue Cloud objects before creating custom objects
2. Custom fields on standard objects before custom objects
3. Custom objects only when standard objects provably cannot support the business model — requires ADR (SOUL R-06)
4. Context Definitions reference standard field paths — no custom junction objects for context mapping
5. All custom objects must map to a TM Forum SID entity — document the SID mapping in the ADR

**Core Standard Object Hierarchy:** `Product2` → `ProductCatalog` → `PriceBook2` → `PriceBookEntry` → `Quote` → `QuoteLineItem` → `Order` → `OrderItem` → `Contract` → `Asset`

---

## Agent-Readiness Criteria
A workflow is agent-ready when ALL FOUR conditions are met. [Dev] confirms each before sprint entry.

| # | Criterion | How to Verify |
|---|---|---|
| AR-1 | Every step is an atomic Agentforce Action — single responsibility, no multi-DML | Code review: one DML operation per action invocation |
| AR-2 | Every Action has a 20+ word `description` attribute explaining when and why the agent invokes it | Metadata grep: `description` attribute length check |
| AR-3 | Workflow runs correctly in both headless (API) and interactive (UI) context channels | Test: run via Connect API and via UI, compare results |
| AR-4 | All human decision points are explicit Approval Gates the agent can route to — no implicit human steps | Flow diagram review: every branch terminates in a gate or an action |

---

## Architecture Decision Records (ADRs)
ADRs are the governance backbone. They answer: *"Why did we build it this way?"* The git history of `ADRs/` is the project's architectural audit trail.

**File convention:** `ADRs/ADR-NNN-<slug>.md`  
**Status lifecycle:** `proposed` → `accepted` → `deprecated` → `superseded`  
**Template:** `ADRs/ADR-000-template.md`

### Mandatory ADR Triggers
| Trigger | Owner |
|---|---|
| Standard vs custom object decision | [TA] |
| Declarative vs Apex (when native-first is challenged) | [TA] |
| Deviation from the 18 canonical RCA patterns | [SA] + [TA] |
| MuleSoft integration pattern selection | [TA] |
| Agent Action with cross-system side effects | [Dev] + [TA] |
| New MCP server or skill added to the registry | [TA] |

**The git commit of an ADR is the approval event. No commit = no approval. No verbal approvals.**

---

## White Label 4 Gating Questions
All four must return YES before any feature advances from discovery to design (SOUL R-14).

| # | Gate Question | Owner | Block Action if NO |
|---|---|---|---|
| **WL-1** | Are KPIs mapped to standard eTOM processes? | [PM] + [SA] | [PM] blocks gate — KPI must be defined with eTOM anchor |
| **WL-2** | Is the product model SID-compliant? | [TA] | [TA] issues Customisation Challenge — map to SID entity or ADR required |
| **WL-3** | Is the CRM decoupled from legacy billing? | [TA] + [DevOps] | [DevOps] audits blng__ dependencies — MuleSoft mediation required |
| **WL-4** | Are workflows agent-ready? | [Dev] | [Dev] returns to [SA] for redesign against AR-1 through AR-4 |

---

## Platform Limits (Hard Ceilings)
These are platform constraints, not preferences. [SA] validates all three before any design is approved (SOUL R-08).

| Limit | Value | What Happens if Exceeded | Mitigation |
|---|---|---|---|
| Pricing Procedure Elements | 200 | Procedure fails to activate | Decompose into sub-procedures; establish "pricing budget" per domain at kickoff |
| Invoice Lines | ~2,000 | Billing failures | Validate early for telco/usage-based; architect batching strategy |
| Flows on Quote Object | 3 (audit trigger) | Performance degradation | Full automation audit required before development starts |
| Context Definition Attributes | Platform-governed | Runtime context errors | Audit attribute count before adding new ones |

---

## MCP Skills Registry
Skills and MCP servers are versioned architectural components. Any addition or change requires a [TA] review and ADR entry.

| MCP Server | Purpose | Auth | ADR |
|---|---|---|---|
| `mcp-adaptor` | Google Drive search — approved RLM guides + architecture blueprints | Salesforce SSO | — |
| `user-rca-advisor` | Local search over 4 Gem instruction PDFs (Discovery/Design/Build/Test) | Local | — |

**Registry Rule:** New MCP skills must be documented here and reviewed by [TA] before use. Assessment must cover: token cost per call, security scope, failure mode, and fallback behaviour.
