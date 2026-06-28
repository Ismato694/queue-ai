# Queue.ai — Product Requirements Document (PRD)

**Version:** 1.1 (refined after adversarial review — see [01b-RED-TEAM.md](01b-RED-TEAM.md))
**Phase:** 1
**Status:** Awaiting approval
**Owner:** Founder + Queue.ai product team
**Pilot market:** Nigeria · Africa/Lagos · English · Nigerian Naira (₦) · NDPR-aligned

---

## 1. Executive Summary

Queue.ai is an **AI-powered Customer Flow Operating System**. It coordinates people, staff, appointments, capacity, arrivals, and communication so organizations eliminate *unnecessary* waiting — not all waiting.

Unlike legacy queue/ticket systems that only tell a customer "you are number 18," Queue.ai predicts, communicates, and continuously optimizes the entire journey from discovery to feedback, and gives managers real-time operational intelligence.

**One-line positioning:** *Google Maps for the journey inside an organization.*

---

## 2. Goals & Non-Goals

### Goals
- Reduce average customer wait time and perceived wait time.
- Give every customer a dynamic, confidence-scored ETA and "leave-by" recommendation.
- Eliminate fake/early queue occupancy via Pre-Queue + activation triggers.
- Give managers live operational intelligence and AI-driven recommendations.
- Support 5 join methods (Receptionist, QR, WhatsApp, Mobile App, Website).
- Scale to millions of customers and thousands of organizations (multi-tenant).

### Non-Goals (for now)
- We do **not** try to eliminate all waiting.
- We do **not** promise exact service times — always confidence bands.
- We do **not** build a full EMR/CRM; we integrate with them later.
- Payments are modeled but deep payment processing is **post-MVP**.

---

## 3. Success Metrics (KPIs)

> **Law #0 — Time is the Product.** The North-Star metric is **Total Time Saved** (aggregate minutes returned to customers + staff vs. baseline). Every other KPI is supporting evidence. See [03a-DESIGN-PHILOSOPHY.md](03a-DESIGN-PHILOSOPHY.md) Law #0.

| Category | Metric | Target (MVP) |
|----------|--------|--------------|
| ⭐ **North Star** | **Total time saved** (customer + staff minutes vs baseline) | Net positive & growing; reported per branch/day |
| Customer | Avg actual wait reduction | −30% vs baseline |
| Customer | ETA accuracy (within stated band) | ≥ 80% |
| Customer | CSAT (post-service feedback) | ≥ 4.2 / 5 |
| Operations | No-show rate reduction | −20% |
| Operations | Counter utilization | +15% |
| Adoption | % customers self-joining (QR/app/WhatsApp) | ≥ 50% |
| Platform | Real-time update latency | < 2s p95 |
| Platform | Uptime | 99.9% |

---

## 4. Personas

### 4.1 Customer (Patient — MVP)
Wants minimal waiting, clarity on when to leave home, live progress, and not to lose their spot. Ranges from tech-savvy (app) to low-tech (WhatsApp/SMS/walk-in).

### 4.2 Receptionist
Registers walk-ins fast, manages the live queue, checks people in, handles priority overrides. Needs speed and zero ambiguity.

### 4.3 Staff / Server (Doctor, Nurse, Teller)
Calls next customer, completes/transfers/delays service, takes breaks. Needs a frictionless "what's next" view.

### 4.4 Branch Manager
Watches live load, spots bottlenecks, acts on AI recommendations (open a counter, add staff).

### 4.5 Organization Admin
Configures branches, departments, services, counters, staff, hours, holidays, billing, permissions, API keys.

### 4.6 Super Admin (Queue.ai internal)
Platform operations, tenant provisioning, monitoring, support.

---

## 5. Scope — Full Product (Vision)

### 5.1 Join Methods
1. **Receptionist** — register walk-in (name, phone, service, priority).
2. **QR Code** — permanent per-branch QR → choose service → details → instant ticket.
3. **WhatsApp** — chatbot conversation → service → details → ticket + live updates/ETA.
4. **Mobile App** — remote join, live tracking.
5. **Website** — parity with mobile app.

### 5.2 Remote Queue Logic (Pre-Queue / Active)
- Remote joins enter **PRE-QUEUE**, do not occupy active slots.
- Activate on: geofence entry **OR** "I'm on my way" **OR** QR scan **OR** receptionist check-in.
- Prevents fake bookings and home-occupancy of slots.

### 5.3 GPS Smart Arrival
- Geofencing + dynamic "leave-by" recommendations (recalculated on traffic, queue, staff, arrivals).
- Never exact times — always **confidence levels** and **wait bands** (e.g. "2:40 PM · 89% · 18–27 min").

### 5.4 Queue Prediction Engine
Predicts using: current customers, avg service duration, department speed, historical averages, current staff, available counters, cancellations, no-shows, priority/emergency cases, walk-ins, real-time activity.

### 5.5 Queue Types
Walk-in, Appointment, Hybrid, Emergency, VIP, Priority, Department, Multi-Branch, Virtual, Physical.

### 5.6 Notifications
Push, SMS, WhatsApp, Email, Voice announcement, Digital display screen. Event examples: "Almost your turn", "Proceed to Counter 4", "Doctor delayed", "Wait increased 12 min", "Queue moving faster".

### 5.6b Strategic Differentiators (F1–F10 — see [01d-FEATURE-REGISTER.md](01d-FEATURE-REGISTER.md))
Flagship moat = **F1 Organization Flow Builder** ("Shopify for customer flow" — industry-agnostic, no-code flows). Plus: F2 Capacity AI, F3 Digital Twin, F4 Journey Timeline, F5 AI Simulation, F6 Multi-Org Identity, F7 Family/Group Queue, F8 AI Health Score, F9 Queue Passport, F10 Anonymous Public Queue. MVP includes F1(basic)/F3-lite/F4/F8 (+ possibly F7); F2/F5/F9 deferred until data exists; F6/F10 reserved for expansion. The Phase 4 schema is designed so all are additions, not rewrites.

### 5.7 Flow Intelligence (formerly "AI Features")
The AI layer is branded **Flow Intelligence** — six pillars: **Prediction · Optimization · Simulation · Recommendations · Automation · Analytics.** Capabilities: predict wait/arrival/no-shows/busy-days; recommend staffing & counter openings; detect bottlenecks/slow departments; weekly summaries; auto-reports; grounded natural-language assistant over org data. Anchored by four trust/proactivity features:
- **Trust Engine (F11):** every estimate carries a confidence % **and the reasons** ("queue stable, all doctors available"); honesty over false precision.
- **Flow Score (F12):** one daily org score (0–100, ⭐, delta) + best/worst dept + one recommended action.
- **Predictive Operations (F13):** warns *before* a queue degrades and recommends the pre-emptive action ("in ~47 min Lab overloads → move 1 tech").
- **Organization Memory (F14):** learns each org's recurring patterns (day-of-week, weather, season, holidays) and folds them into predictions.

### 5.8 Dashboards & Apps
- **Organization Dashboard** — live waiting, queues, avg wait/service, no-show %, CSAT, busy depts/hours, employee performance, completion rate, live counters, AI insights (all real-time).
- **Customer App** — live queue, ETA, navigation, QR/digital ticket, notifications, feedback, history, dark mode, accessibility, offline support.
- **Receptionist Dashboard** — add/call/transfer/pause/resume/cancel/priority/check-in/search.
- **Staff Dashboard** — call next, complete, transfer, delay, mark unavailable, break, return online.
- **Admin Dashboard** — branches, departments, services, counters, staff, hours, holidays, closures, reports, billing, permissions, API keys.

---

## 6. MVP Cut (Phase 6 — Private Hospitals)

To ship something real and testable, the first build deliberately narrows scope. **Full vision above; MVP below.**

### In MVP
- Multi-tenant core: Organization → Branch → Department → Service → Counter → Staff.
- Join methods: **Receptionist, QR Code, Web app** (Mobile app + WhatsApp = fast-follow).
- Pre-Queue / Active model with all 4 activation triggers (GPS via web geolocation).
- Queue Prediction Engine v1 (heuristic + historical averages; ML refinement later).
- Dynamic ETA + confidence band + "leave-by" recommendation.
- Queue types: Walk-in, Appointment, Hybrid, Priority, Emergency.
- Notifications: Push (web), SMS, Email. (WhatsApp + Voice = fast-follow.)
- Dashboards: Organization, Receptionist, Staff, Admin.
- Customer Web App: live queue, ETA, QR/digital ticket, notifications, feedback, history.
- AI Assistant v1: answer questions over org data + auto daily report.
- Real-time updates (<2s), audit logging, RBAC.

### Deferred to Fast-Follow / Expansion
- Native mobile apps (iOS/Android).
- WhatsApp chatbot + Voice announcements + digital display screens.
- ML-based no-show & demand forecasting models (start heuristic).
- Payments processing.
- Multi-branch routing optimization.
- Banks / Universities / Government templates (Phase 16).

### MVP Success Criteria
- One hospital branch runs a full day on Queue.ai with real patients.
- ETA accuracy ≥ 80%, real-time latency < 2s p95, zero lost tickets.
- **Demonstrable, measured Total Time Saved vs. the captured baseline (Law #0).**

---

## 7. Functional Requirements (high level, by actor)

> Detailed acceptance criteria come in Phase 2 (User Flows). This is the requirement inventory.

**Customer:** join via QR/web/receptionist; receive digital ticket; see live position + ETA + confidence; receive activation prompt; check in; get called; give feedback; view history.

**Receptionist:** register walk-in; check in pre-queue customers; call next; transfer; pause/resume queue; cancel; priority override; search.

**Staff:** see next customer; call; complete; transfer; delay; mark unavailable; break; return.

**Manager:** live dashboard; bottleneck alerts; AI recommendations; reports.

**Admin:** CRUD branches/departments/services/counters/staff; hours/holidays/closures; permissions; API keys; billing; reports.

---

## 8. Non-Functional Requirements

| Attribute | Requirement |
|-----------|-------------|
| Scale | Millions of customers; thousands of tenants; multi-tenant isolation. |
| Performance | Real-time updates < 2s p95; API p95 < 300ms. |
| Availability | 99.9% uptime; graceful degradation if AI/notif services down. |
| Security | RBAC, encryption in transit + at rest, audit logs, tenant isolation. |
| Compliance | Hospital MVP → HIPAA-aligned handling of PHI; GDPR data rights. |
| Accessibility | WCAG 2.1 AA on customer-facing surfaces. |
| Reliability | No ticket loss; idempotent state transitions; offline support on customer app. |
| Observability | Centralized logging, metrics, tracing, alerting. |
| Internationalization | Multi-language + timezone-aware from day one. |

---

## 8b. Refinements from Adversarial Review (v1.1)

The four-lens red team ([01b-RED-TEAM.md](01b-RED-TEAM.md)) surfaced ten changes now part of the product. The 🔴 items are MVP-blocking design decisions.

| # | Refinement | Why it matters |
|---|------------|----------------|
| R1 🔴 | **Multi-stage patient journeys (care pathways).** A ticket carries an ordered sequence of stages (Reception → Consult → Lab → Doctor → Pharmacy → Cashier); each stage has its own queue and ETA; total ETA = sum of remaining stages. | Hospital flow is a pipeline, not one flat queue. |
| R2 🔴 | **Clinical acuity/triage priority** drives ordering (not strict FIFO); emergency + priority overrides are first-class and **audit-logged**. | FIFO is clinically unsafe. |
| R3 🔴 | **Privacy on public displays** — public screens show ticket numbers/initials only; full names on authenticated staff devices only. | NDPR/HIPAA privacy. |
| R4 🔴 | **ETA grace windows + late re-activation.** ETA is never a promise — always confidence bands + "arrive by"; late arrivals can re-activate within a window before no-show. | Liability + fairness. |
| R5 🔴 | **Offline-first reception + SMS-first low-tech path + paper fallback.** Reception PWA caches the queue and syncs on reconnect; SMS works on 2G; a paper procedure exists for full outages. | Nigerian connectivity & power reality. |
| R6 | **Cost-aware notification routing** — push-first; SMS/WhatsApp reserved for high-value events; per-org budgets/metering. | Margin + deliverability. |
| R7 | **Grounded, read-only AI assistant** — answers built from queried metrics + RAG, with sources shown; structured outputs for cited figures. | No hallucinated operations advice. |
| R8 | **Baseline-capture mode** for the first 1–2 weeks to measure current waits and prove ROI. | Adoption + sales proof. |
| R9 | **Configurable overbooking + explicit hybrid (walk-in vs appointment) fairness policy** per branch. | No-shows + perceived fairness. |
| R10 | **HMS/EMR integration roadmap (HL7/FHIR + webhooks)** — standalone first, integrate later. | Hospitals won't replace their record system. |

---

## 9. Key Product Principles

0. **⭐ Law #0 — Time is the Product.** Every feature must save measurable time for at least one actor, or it's redesigned/removed. (Above all other principles.)
0b. **Remove decisions, don't just display.** Guided experiences over passive dashboards (Decision-Removal Ladder).
1. **Predict, don't just count.** Never show a raw number alone.
2. **Honesty over precision.** Always confidence bands, never exact promises (R4).
3. **Anti-fraud by design.** Pre-Queue protects fair ordering.
4. **Real-time everywhere.** State changes propagate instantly — but degrade gracefully offline (R5).
5. **Low-tech inclusive.** Walk-in/SMS/WhatsApp customers are first-class (R5).
6. **Operator intelligence.** Every screen drives an action, not just a number.
7. **Clinically safe.** Acuity over arrival order; every override audited (R2).
8. **Privacy by default.** Minimum PII on shared surfaces (R3).

---

## 10. Open Questions — RESOLVED

1. ~~Geography / first market~~ → **Nigeria** (private hospitals first; Africa→global by design). Africa/Lagos timezone, English, ₦.
2. ~~Compliance bar~~ → **NDPR-aligned + HIPAA-aligned security architecture**, *no* full HIPAA cert for the pilot. Flexible for future HIPAA/GDPR/NDPR/POPIA.
3. ~~Tech stack~~ → **Recommended in [01c-TECH-STACK.md](01c-TECH-STACK.md)**; locked at Phase 9. (TS end-to-end, Next.js, NestJS, Postgres+PostGIS, Claude, AWS af-south-1.)
4. ~~Pilot partner~~ → **None confirmed.** Design around a representative **medium Nigerian private hospital** (see §11 profile); keep configurable for other sizes.
5. **Branding/design** → "Queue.ai" assumed final; visual language = clean minimalist (Stripe/Linear/Notion/Apple). Confirm exact palette at Phase 3 wireframes.

---

## 11. Assumptions & Target-Hospital Profile

**Pilot hospital profile (design target — configurable for other sizes):**
- 15–40 staff; 5–10 consultation rooms.
- Departments: Reception, multiple consult departments, Laboratory, Pharmacy, Cashier.
- ~150–500 patient visits/day.
- Multi-stage patient journeys are the norm (drives R1).

**Platform assumptions:**
- Designed **multi-tenant, multi-country, multi-currency, multi-timezone, multi-language** from day one — expansion is configuration, not redesign.
- Web-first (responsive PWA, **offline-capable**) for all surfaces; native mobile later.
- Cloud-hosted on **AWS af-south-1** (nearest region to Nigeria; NDPR posture).
- English-first UI with i18n scaffolding; ₦ currency with USD COGS modelling.
- Power/connectivity assumed intermittent → offline-first + SMS fallback + UPS at reception.

---

## Approval

> ✅ **Approve Phase 1** to proceed to **Phase 2 — User Flows & State Machines**.
> Or request changes and I'll revise this PRD.
