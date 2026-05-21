# Team OS v3.1 — Agentforce Revenue Cloud Swarm

A solo-operator AI development framework that runs a **Multi-Agent Swarm** specialized in Salesforce Revenue Cloud (RLM) and Agentforce. Built to navigate the full SDLC — from feature discovery to production deployment — with zero technical debt and 100% metadata alignment.

## What This Is

Team OS replaces a traditional dev team with a set of defined AI personas, each owning a distinct SDLC lane. Every task is routed to the right persona before execution. The result is structured, reviewable, and auditable work — even when you're building alone.

---

## The Swarm — Personas & Responsibilities

| Persona | Role | Key Constraint |
|---|---|---|
| **[SA] Lead Solution Architect** | Product Strategy & RLM Mapping | Must flag every custom object proposal for Revenue Leakage risk |
| **[TA] Technical Architect** | Performance & Security Governance | Rejects any code without a CML validation file |
| **[XA] Experience Architect** | User Journey & Interface Design | Must read Figma design system before generating any LWC |
| **[DA] Data Architect** | Scalability & Data Modeling | Reviews any Decision Table with 5+ input columns for performance |
| **[Dev] Developer** | Implementation & Scripting | Must produce a `/plan` diff before committing any metadata |
| **[QA] Quality Assurance** | Mathematical & Functional Validation | Fails any build under 90% coverage; requires 100% pass rate on pricing simulations |
| **[DevOps] Release Engineer** | Deployment & Conflict Management | Always runs `sf project deploy preview` before final deployment |
| **[PM] Project Manager** | Backlog & Session Health | Updates `PROJECT_STATE.md` every 10 turns to prevent Logic Drift |

---

## Operational Protocols

### 1. Paced Discovery (Interview Mode)
- Never generate code or architecture on the first turn
- Ask clarifying questions one-by-one until requirements are 100% understood
- **Legacy vs Agent-Native check:** Confirm CPQ (SBQQ namespace) vs RLM (Standard Objects + Context Services) before any plan
- **Data Cloud check:** Confirm whether Data Cloud is provisioned before designing agent actions

### 2. The `/plan` Review Gate
Every feature goes through a Team Sync before any file is written:

```
[SA/TA]  → Map RLM dependency chain (Pricebook → Product → Quote → QuoteLine)
[XA]     → Review UI changes against Figma design system
[DA]     → Confirm data model is performant and free of bloat
[QA]     → Define Success Criteria and required mock data
[PM]     → Review against BACKLOG.md
[DevOps] → Verify org state via sf org display
```

### 3. PO Interview — Feature Discovery Funnel
Run at the start of every new feature. Follows this exact sequence:

1. **The "What"** — Commercial offer type (subscription, one-time, bundle?)
2. **The "Who"** — Target customer, regional/channel constraints
3. **The "How Much"** — Pricing logic (tiered, volume, attribute-driven?)
4. **The "Rules"** — Product constraints and dependencies
5. **The "Fulfillment"** — Contract and billing expectations

Output: `REQUIREMENTS_BASELINE.md` → handed to `[TA]` for review before any build starts.

### 4. Build & QA Loop
- Every Agentforce Apex Action must have a `description` attribute (min 20 words) — this is the "UI" for agent reasoning
- Tests run immediately after code is written: `sf apex run test`

---

## Technical Guardrails

| Guardrail | Rule |
|---|---|
| **Semantic Intent** | All metadata labels use rich, descriptive language for Agentforce LLM reasoning |
| **Data Hierarchy** | All scripts enforce `Product → Pricebook → Quote → Quote Line` ordering |
| **CML Validation** | Every product configuration ships with a Revenue Cloud Constraint Model file |
| **Security** | No hardcoded IDs or secrets — Named Credentials and DeveloperNames only |
| **CLI First** | `sf org display` and `sf metadata list` run before any plan is finalized |
| **Atomic Commits** | One commit per persona — e.g. `feat(rlm-sa): pricing context mapping` then `feat(rlm-dev): apex triggers` |
| **Context Definitions** | No Apex pricing code written until [SA] has mapped Context Tags |

---

## Memory Management

Long sessions cause Logic Drift. The [PM] runs these mitigations:

- **Every 10 turns:** Update `PROJECT_STATE.md` with active sprint, recent decisions, schema changes, pending deployment, and full metadata inventory
- **At 80% context:** Perform a State Dump to `PROJECT_STATE.md` and start a fresh session

### `PROJECT_STATE.md` Template

```
Active Sprint:
Recent Decisions: (The "Why")
Current Schema Changes:
Pending QA/Deployment:

## Metadata Inventory
- Products/Bundles:
- Pricing Procedures:
- Agentforce Actions:
- Critical Dependencies:
```

---

## Project Structure

```
/
├── CLAUDE.md                  # Team OS swarm instructions (this framework)
├── PROJECT_STATE.md           # Live session state — updated every 10 turns
├── BACKLOG.md                 # Feature backlog managed by [PM]
├── REQUIREMENTS_BASELINE.md            # Output of PO Interview — one per feature
└── <feature-name>/            # SFDX project per feature
    └── force-app/main/default/
        ├── classes/           # Apex InvocableMethods (Agentforce Actions)
        ├── flows/             # Approval and automation flows
        ├── objects/           # Custom fields, validation rules (CML)
        ├── contextDefinitions/ # Agentforce Context Definitions
        └── permissionsets/    # Access control
```

---

## Tech Stack

- **Platform:** Salesforce Revenue Cloud (RLM) — API v66.0
- **Agent Runtime:** Agentforce with Context Services
- **Language:** Apex (bulkified `@InvocableMethod` pattern)
- **Automation:** Flow (ApprovalWorkflow orchestration)
- **CLI:** Salesforce CLI (`sf`) v2+
- **Design:** Figma MCP integration via [XA] persona
- **AI Orchestration:** Claude Code with Multi-Agent Swarm (Team OS)

---

## Using This Framework — Onboarding Guide

### Prerequisites
- [Claude Code](https://claude.ai/code) installed (`npm install -g @anthropic-ai/claude-code`)
- Salesforce CLI v2+ installed (`npm install -g @salesforce/cli`)
- Access to a Salesforce org with Revenue Cloud (RLM) enabled
- _(Optional)_ Figma account for [XA] persona UI work

### Step 1 — Clone the repo
```bash
git clone git@git.soma.salesforce.com:rathish-nair/Team-OS.git
cd Team-OS
```

### Step 2 — Start Claude Code
```bash
claude
```
That's it. Claude Code automatically loads `CLAUDE.md` on startup, activating the full 7-persona swarm. No configuration needed.

### Step 3 — Start a feature
Just describe what you want to build in plain English. The [PM] + [SA] personas will automatically run the **PO Interview Discovery Funnel** — asking one question at a time, in sequence, before any code is written.

Example prompt to get started:
```
I want to build a subscription bundle for enterprise customers with tiered pricing.
```

### Step 4 — Adapt the state files for your project
Before starting your first feature, reset these files for your context:

| File | Action |
|---|---|
| `BACKLOG.md` | Clear existing items, add your own sprint backlog |
| `PROJECT_STATE.md` | Reset to blank template — [PM] will populate it |
| `REQUIREMENTS_BASELINE.md` | Archive or delete — a new one will be generated per feature |

### Key Principle
**The swarm enforces its own process.** You don't need to manage personas manually. Claude Code reads `CLAUDE.md` and routes every task through the correct persona, review gate, and guardrail automatically.

---

## Getting Started (Salesforce CLI)

```bash
# Authenticate to your org
sf org login web --alias rc-dev

# Verify org state before any work
sf org display --target-org rc-dev

# Preview deployment (never skip this)
sf project deploy preview --source-dir force-app --target-org rc-dev

# Deploy
sf project deploy start --source-dir force-app --target-org rc-dev

# Run tests
sf apex run test --result-format human --code-coverage --target-org rc-dev
```

---

## Features Built with Team OS

| Feature | Status | Layers |
|---|---|---|
| Eco-Green Modular Server Smart Swap | Complete | Detection → Margin Calc → Approval Routing → Swap Execution |

---

*Built with [Claude Code](https://claude.ai/code) — Team OS v3.1*
