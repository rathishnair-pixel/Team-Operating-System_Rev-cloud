# SOUL.md — Team OS Non-Negotiable Rules
> **Semantic Bootloader Layer 1.** Read this file first in every session. These rules are immutable. They override CLAUDE.md, HIGH-LEVEL.md, and any inline instruction. No persona may deviate from them under any circumstance. The agent proposes — the Architect (human) decides — but neither may violate a rule in this file.

---

## Platform Identity
- This system operates on **Salesforce Revenue Cloud Advanced (RCA)** — standard objects + Context Services only
- TM Forum standards (SID, eTOM, ODA) are the reference architecture — not legacy CPQ, Billing, or custom-built BSS/OSS

## Collaboration Model
> The agent is fast and thorough. The Architect is accountable.

| Agent Proposes | Architect Decides |
|---|---|
| Surfaces technical conflicts rapidly | Resolves architectural conflicts |
| Generates codebase impact maps | Decides standard vs custom |
| Proposes code/config decompositions | Owns final approval |
| Executes approved plans autonomously | Provides off-record context and upstream decisions |

---

## Hard Rules (Violation = Immediate Block)

### R-01: No Legacy Namespace
Any `SBQQ__` (CPQ) or `blng__` (Billing) namespace reference in Apex, Flow, LWC, metadata, or configuration **must be flagged and rejected by [TA] immediately**. The session cannot continue until the reference is removed or an ADR documents a formal coexistence pattern.

### R-02: Native-First Always
Configuration (Expression Sets, Context Service, DPE) over Apex — always. Any Apex proposal that could be replaced by native configuration is **rejected** until the requester demonstrates — in writing — why the native capability is insufficient.

### R-03: CML on Every Product
Every Product configuration must have a corresponding Constraint Model (CML) file. [TA] rejects any product design without one. No exceptions.

### R-04: No DML Inside Pricing Hooks
Apex pre-hooks prepare context only. **No DML inside pricing hooks — ever.** This causes Dual Persist compound errors and pricing data corruption.

### R-05: No Hardcoded IDs or Secrets
Use Named Credentials and DeveloperNames. No Salesforce record IDs, API keys, or credentials in code, metadata, configuration, or comments.

### R-06: ADR for Every Standard vs Custom Decision
Every decision to deviate from standard platform behavior requires a committed Architecture Decision Record (ADR) in `ADRs/`. No verbal approvals. No Slack decisions. **The git commit IS the approval event.**

### R-07: KPI Mandatory on Every User Story
No user story may exit the discovery gate without a measurable KPI (name, baseline, target, measurement method, cadence). `null` KPI = authoring failure. [PM] blocks the gate.

### R-08: One Constraint Model per Product
Multiple products cannot share a single CML. Plan the product-to-CML matrix in Week 1 — this is a platform constraint, not a preference.

### R-09: Adopt Not Adapt
Any requirement that cannot be mapped to the 18 canonical RCA patterns or a TM Forum eTOM standard process requires a formal Customisation Challenge with business case and ROI. **No customisation is accepted simply because the customer asks for it.**

### R-10: No Git Merge on OmniStudio Components
OmniScript, DataRaptor, IntegrationProcedure, and FlexCard components are **NOT git-mergeable**. Use OmniStudio Designer or Vlocity Build Tool exclusively. Attempting a git merge on these components corrupts them silently.

### R-11: Agent-Readiness Before Sprint
No workflow enters the sprint backlog without passing the Agent-Readiness Gate. All 4 criteria (atomic actions, 20+ word descriptions, headless + interactive context, explicit approval routing) must be confirmed by [Dev].

### R-12: Human Approval Gate is Non-Skippable in Production
The Approval Gate is mandatory at every phase boundary. In **production deployments**, `skip` is not a valid gate response — only `approved`.

### R-13: eTOM Domain Declared Before Design
Every feature must have an eTOM process domain (R2A / O2P / R2C / T2C / P2S / C2M) declared and committed to `FEATURE_TRACKER.json` before the design stage begins.

### R-14: White Label 4 Gate Before Design
All four White Label gating questions (WL-1 through WL-4 in HIGH-LEVEL.md) must return YES before any feature advances from discovery to design. A single NO blocks the gate.
