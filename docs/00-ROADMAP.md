# Queue.ai — Master Roadmap & Glossary

> **Queue.ai is not a queue app. It is a Customer Flow Operating System.**
> It manages how people move through organizations: arrival → verification → check-in → waiting → serving → transfer → payment → completion → feedback → analytics → prediction.

---

## Phase Roadmap

| # | Phase | Primary Deliverable | Gate |
|---|-------|---------------------|------|
| 0 | Roadmap & Glossary | This document | — |
| 1 | Product Requirements Document | `01-PRD.md` (v1.1) | **Approval** |
| 1.5 | Adversarial Review + Tech-Stack Recommendation | `01b-RED-TEAM.md`, `01c-TECH-STACK.md` | **Approval** |
| 2 | User Flows & State Machines | `02-USER-FLOWS.md` ✅ | Approval |
| 3a | Design Philosophy & System | `03a-DESIGN-PHILOSOPHY.md` | Approval |
| 3b | Wireframes & Information Architecture | `03-WIREFRAMES.md` ✅ | Approval |
| 4 | Database Design | `04-DATABASE.md` ✅ | Approval |
| 5 | API Design | `05-API.md` ✅ | Approval |
| 6 | System Architecture | `06-ARCHITECTURE.md` ✅ | Approval |
| 7 | Flow Intelligence Spec (AI/ML) | `07-FLOW-INTELLIGENCE.md` ✅ | Approval |
| 8 | Security & Compliance | `08-SECURITY.md` ✅ | Approval |
| — | Founder Rules (governs build) | `09-FOUNDER-RULES.md` ✅ | — |
| 9 | MVP Scope Lock (Hospitals) | `09-MVP-SCOPE.md` ✅ | Approval |
| 10 | Customer Flow OS Build — Backend, DB, Auth | code — **S0 ✅** (schema, RLS, seed, skeletons) · **S1 ✅** (auth+bootstrap RPC, onboarding, admin Structure CRUD, **Flow Builder F1**) | Approval |
| 11 | Customer Flow OS Build — Real-time & Queue Engine | code — **S2 ✅** (queue-engine RPCs, Reception board) · **S3 ✅** (Supabase Realtime, customer QR/web join + Live Visit/Journey Timeline + activation, queued notifications + worker dispatcher) | Approval |
| 12 | Customer Flow OS Build — Dashboards & Customer App | code — **S4 ✅** (Trust Engine ETA+confidence+reasons, Staff app, Public display, no-show grace sweep) | Approval |
| 13 | Customer Flow OS Build — **Flow Intelligence v1** | code — **S5 ✅** (Manager dashboard: Flow Score + Digital Twin + Hours Returned + grounded assistant, Claude swap-in ready) · **S6 ✅** (offline cache R5, a11y, PWA manifest, indexes, state-machine tests). **Build feature-complete (S0–S6)** | Approval |
| **13.5** | **Pilot Validation** ⭐ (one real hospital, 2–4 weeks) | `13b-PILOT-VALIDATION.md` | **Approval** |
| 14 | QA & Testing | `14-TEST-PLAN.md` + tests | Approval |
| 15 | DevOps & Deployment | infra + `15-DEVOPS.md` | Approval |
| 16 | Industry Expansion | templates | Approval |
| 16.5 | **Flow Intelligence v2** (post-pilot, data-driven) | Capacity AI (F2) · Predictive Ops (F13) · Simulation (F5) · Org Memory (F14) · auto queue-balancing | Approval |
| 17 | **Commercialization** | `17-COMMERCIALIZATION.md` (sales · success · marketing · partnerships · analytics) | Approval |

**Rule:** Stop after every phase. Wait for explicit approval before starting the next.

> **Sequence change (CTO):** Build (13) → **Pilot Validation (13.5)** → QA (14) → Deploy (15). Real users reshape the product *before* we optimize it. AI is split: **v1** (ETA/Flow Score/Twin/grounded assistant — shipped) and **v2** (16.5, after the pilot generates real data). **Hours Returned** is a first-class KPI shown on every dashboard.

---

## Glossary (shared vocabulary)

| Term | Definition |
|------|------------|
| **Organization** | Top-level tenant (e.g. a hospital group). Owns branches, staff, billing. |
| **Branch** | A physical location of an organization. Has a permanent QR code + geofence. |
| **Department** | A unit within a branch (e.g. Radiology, Cardiology). |
| **Service** | A bookable/queueable offering (e.g. "MRI Scan", "GP Consult") with an avg duration. |
| **Counter** | A serving point (desk/room) where staff serve customers. |
| **Staff** | An employee who serves customers at a counter, or a receptionist/admin. |
| **Customer** | An end user who joins a queue or books an appointment. |
| **Ticket** | A customer's position in a flow. Has a state (see below). |
| **Pre-Queue** | Reserved/booked but NOT yet occupying an active slot. Anti-fraud staging area. |
| **Active Queue** | Tickets actively counted toward wait time, triggered by GPS/QR/check-in. |
| **Geofence** | Configurable radius around a branch that auto-activates a pre-queue ticket. |
| **ETA Engine** | Service that predicts when a customer will be served + when they should leave. |
| **No-show** | A ticket that never activated or never checked in by its window. |
| **Confidence** | Probability band attached to every prediction (never a hard promise). |

---

## Ticket State Machine (canonical)

```
BOOKED ──► PRE_QUEUE ──► ACTIVE ──► CALLED ──► SERVING ──► COMPLETED
   │           │            │          │          │
   │           │            │          │          └──► TRANSFERRED ──► ACTIVE (new dept)
   │           ▼            ▼          ▼
   └────────► CANCELLED / EXPIRED / NO_SHOW
```

Activation triggers (PRE_QUEUE → ACTIVE):
1. GPS within geofence radius, OR
2. Customer taps "I'm on my way", OR
3. Customer scans branch QR, OR
4. Receptionist manual check-in.

---

## Decision Log

Decisions are recorded here as phases are approved, so later phases stay consistent.

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-06-27 | MVP industry = Private Hospitals | Per spec Phase 6 |
| 2026-06-27 | Pilot market = **Nigeria** (Africa/Lagos, English, ₦); Africa→global by design | Large market, severe queue pain, faster private-hospital sales cycle |
| 2026-06-27 | Compliance = **NDPR + HIPAA-aligned architecture**, no full HIPAA cert pre-PMF | Correct security without premature enterprise cost; flexible for HIPAA/GDPR/NDPR/POPIA |
| 2026-06-27 | No confirmed pilot hospital → design for **medium Nigerian private hospital** (15–40 staff, 5–10 rooms, lab/pharmacy/cashier, 150–500 visits/day), configurable | Realistic, generalizable target |
| 2026-06-27 | **10 product refinements (R1–R10)** adopted from adversarial review; R1–R5 are MVP-blocking | Pipeline journeys, triage priority, display privacy, ETA grace, offline/SMS-first |
| 2026-06-27 | Tech-stack **recommended** (TS/Next.js/NestJS/Postgres+PostGIS/Claude/AWS af-south-1) | See `01c-TECH-STACK.md`; **final lock at Phase 9** |
| 2026-06-27 | **10 strategic features (F1–F10)** registered & prioritized; `01d-FEATURE-REGISTER.md` | Flow Builder (F1) repositioned as flagship moat; F1-basic/F3-lite/F4/F8 join MVP; F2/F5/F9 deferred until data exists; F6/F10 = expansion network-effect bets. Schema (P4) designed so all are additions, not rewrites. |
| 2026-06-27 | **Design constitution = "reduce uncertainty, not display queues"**; `03a-DESIGN-PHILOSOPHY.md`. Phase 3 split into 3a (philosophy) + 3b (wireframes) | Every screen must answer the Six Questions instantly; calm/intelligent/predictive/trustworthy; Apple×Stripe×Linear×Uber×Maps. Wireframes judged against it. |
| 2026-06-27 | **F11–F14 added**: Trust Engine, Flow Score, Predictive Operations, Organization Memory. **AI layer renamed → "Flow Intelligence"** (Phase 7) | Trust Engine (ETA+confidence+reasons) = honesty differentiator, MVP; Flow Score consolidates with F8; Predictive Ops = proactive arm of F2; Org Memory learns local patterns. See `01d-FEATURE-REGISTER.md` addendum. |
| 2026-06-27 | **Supreme design principle: "Queue.ai removes decisions, not just displays information."** Design philosophy v1.1; added Decision-Removal Ladder + Three Core Questions | Guided experiences replace passive dashboards; no screen may sit at rung 0 (display-only); every wireframe annotates the rung it reaches. |
| 2026-06-27 | **Law #0 — "Time is the Product" (immutable, above all laws).** North-Star KPI = **Total Time Saved**; mandatory 4-field feature evaluation (problem · decision removed · time saved · how measured) | Queue.ai sells time, not software. Features that don't save measurable time are removed. Hierarchy: Law #0 (why) → Remove decisions (how) → Reduce uncertainty (in service of). See `03a` Law #0 + `01d` scorecard. |
| 2026-06-27 | **Business case modeled** — `BUSINESS-OS.md` (why buy/switch, ROI 30/90/365, pricing, 1-day onboarding, paper migration, full objection-handling) | Modeled ~5–10× monthly ROI on the medium-hospital profile; risk-free "we measure your loss free for 2 weeks" offer enabled by baseline mode (R8). Pricing illustrative; validate at Phase 9 pilot. |
| 2026-06-28 | **Founder Rules adopted** — `09-FOUNDER-RULES.md` (ship>perfection; 3-question feature gate incl. <2-week buildability + willingness-to-pay; no "cool" features; optimize for first paying hospital; demo every sprint; never break "remove decisions"; measure outcomes not code) | Governs Phases 9–16; adds buildability + WTP tests on top of the Law #0 feature eval. Tie-breaker for scope/build decisions. |
| 2026-06-28 | **MVP SCOPE LOCKED + vision frozen** — `09-MVP-SCOPE.md`. **Tech stack LOCKED: Supabase (af-south-1) + Next.js + Node/NestJS worker + Claude** (supersedes 01c recommendation; managed-first for speed). MFA: admin-recommended, pilot-optional, org-enforceable. F2/F5/F13/F14 + WhatsApp/native/HMS/F6/F7/F9/F10 → V2 | Optimize for first paying hospital; ship→learn→validate. Offline full-sync scoped to fast-follow (online+cache+SMS+paper in MVP). 7-sprint backlog (S0–S6), each demoable. Schema/API/arch/security carry over unchanged (Supabase = Postgres+RLS). |
| 2026-06-28 | **CTO roadmap changes**: inserted **13.5 Pilot Validation** before QA; split AI into **v1 (shipped)** / **v2 = 16.5 (post-pilot)**; added **17 Commercialization**; renamed "MVP Build" → "Customer Flow OS Build"; **"Hours Returned" = first-class KPI** on every dashboard (Today / This Month / Since Joining) | Real-world pilot teaches what planning can't (staff adoption, channel preference, what managers value); build v2 AI on real data; keep mission visible via Hours Returned. `13b-PILOT-VALIDATION.md`, `17-COMMERCIALIZATION.md`. |
| 2026-06-28 | **Pilot hosting region = West EU (London, eu-west-2)** — af-south-1 unavailable in the Supabase account at setup | Nearest low-latency region to Lagos; NDPR permits cross-border with safeguards. **af-south-1 remains the production residency target** (Supabase=Postgres → relocatable without rewrite). |
