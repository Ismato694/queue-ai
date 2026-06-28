# Queue.ai — Adversarial Review (Red Team)

**Version:** 1.0
**Phase:** 1.5 (challenge before build)
**Method:** Four hostile lenses — Skeptical CTO, Hospital Administrator, Operations Manager, Investor. Each finding has one or more practical solutions. Findings that change the product are folded into PRD v1.1.

> The goal here is to break the idea *on paper* so we don't break it in a hospital. Severity: 🔴 must-fix-before-MVP · 🟠 design-around · 🟡 watch.

---

## 1. Skeptical CTO — "Will this actually work technically, in Nigeria, at scale?"

### CTO-1 🔴 GPS geofencing is unreliable as a *primary* activation trigger
Background location on low-end Android is throttled, battery-hungry, and permission-gated. Most users won't grant always-on location, and web geolocation only fires when the page is open.
- **Solution:** GPS is an *enhancement*, never a dependency. The Pre-Queue→Active model already has 4 triggers — make **"I'm on my way" + QR scan + receptionist check-in** the load-bearing ones; treat geofence as a bonus when permission is granted and the app/PWA is foregrounded. Never let a missed geofence cost someone their slot.

### CTO-2 🔴 Nigerian connectivity & power reality (intermittent data, NEPA outages)
Reception desks lose internet and power regularly. A cloud-only, online-only system fails exactly when the queue is busiest.
- **Solution:** **Offline-first reception app** (PWA with local queue cache + write queue that syncs on reconnect). UPS/inverter assumption documented for pilot. **SMS as the universal fallback channel** (works on 2G feature phones). Paper-ticket fallback procedure so the branch never fully stops.

### CTO-3 🟠 Real-time fan-out cost at scale
Millions of concurrent WebSocket connections is expensive and ops-heavy.
- **Solution:** Start with a managed/Redis-pub-sub WebSocket layer; **degrade gracefully to polling** on poor networks (Nigeria-friendly anyway). Only one branch's worth of clients subscribe to that branch's channel — natural sharding by `branch_id`. Revisit a dedicated real-time service (Centrifugo/Ably) at scale.

### CTO-4 🔴 ETA cold-start problem
The prediction engine needs history that doesn't exist on day one. A wrong ETA on day one destroys trust.
- **Solution:** **Bootstrap with heuristics** (admin-entered average service durations per service type) + **wide confidence bands** that narrow as real data accrues. Always show a range, never a point. Label low-confidence predictions explicitly ("still learning this branch").

### CTO-5 🟠 SMS/WhatsApp deliverability & cost in Nigeria
Twilio is expensive and has poorer local deliverability; Nigerian sender-ID registration (NCC) and DND rules apply; WhatsApp Business API has template approval + per-message fees that can dwarf SaaS margin.
- **Solution:** Use **Africa-focused providers (Termii / Africa's Talking)** for SMS + WhatsApp; pre-register sender IDs and templates. **Cost-aware notification routing**: push (free) → SMS (paid) only for high-value events ("you're next"), not every queue movement. Per-org notification budgets/caps.

### CTO-6 🟡 AI assistant hallucination over org data
"Why is today slower?" answered with a confident wrong number erodes manager trust and could mislead operations.
- **Solution:** Assistant is **read-only and grounded** — answers built from queried metrics (RAG over the org's own data + structured tool calls), not free generation. Show the numbers/source behind each answer. Structured outputs for any figure it cites.

### CTO-7 🟡 Multi-tenant data isolation
A leak across hospitals is fatal for trust and NDPR/HIPAA posture.
- **Solution:** `tenant_id` on every row + Postgres **Row-Level Security**; tenant scoping enforced at the data-access layer and tested. (Detailed in Phase 8 Security.)

---

## 2. Hospital Administrator — "Will my staff and patients actually use this?"

### ADM-1 🔴 The hospital flow is a *pipeline*, not a single queue
A patient does Reception → Consult → Lab → back to Doctor → Pharmacy → Cashier. A flat "you are number 18" model doesn't fit. This is the single biggest domain gap in v1.0.
- **Solution:** Model **multi-stage patient journeys** ("care pathways"): a ticket carries a sequence of stages, each with its own queue and ETA. The Transfer action already hints at this — promote it to a first-class **journey/pathway** concept. ETA = sum of remaining stages. **Folded into PRD v1.1.**

### ADM-2 🔴 Clinical priority ≠ FIFO
Emergencies and acuity jump the queue; a strict first-come system is clinically wrong and unsafe.
- **Solution:** **Clinical acuity/triage priority** as a core ticket attribute, with Emergency queue + receptionist/nurse priority override (already in spec) — make acuity drive ordering, and **log every override** for audit. **Folded into PRD v1.1.**

### ADM-3 🔴 Patient privacy on public displays & screens
Showing patient names on a waiting-room screen violates privacy (NDPR/HIPAA principles).
- **Solution:** Display **ticket numbers or initials only** on public screens; full names only on authenticated staff devices. **Folded into PRD v1.1.**

### ADM-4 🟠 Staff (especially doctors) won't tap buttons
If "Complete service" depends on a busy doctor remembering to tap, data rots and ETAs break.
- **Solution:** Make the **receptionist/nurse the primary operator** of state changes; give staff the absolute minimum (one-tap "call next / done"). Design for **auto-advance** where safe and reconciliation later. Long-term: integrate with existing HMS so completion is inferred.

### ADM-5 🟠 Existing HMS/EMR already in place
Hospitals won't rip out their record system; a parallel data-entry tool gets abandoned.
- **Solution:** Position Queue.ai as a **standalone flow layer first** (no integration needed to start), with an **integration roadmap (HL7/FHIR + webhooks)** so it can later sync patients/appointments rather than duplicate them. **Added to PRD v1.1 roadmap.**

### ADM-6 🔴 Liability when the ETA is wrong
If a patient trusts "be there at 2:40" and misses their turn, who's at fault?
- **Solution:** **Grace windows** (configurable) before a no-show is declared; never present ETA as a promise — confidence bands + "arrive by" guidance + a re-activation path if they're late. Clear in-product disclaimer language. **Folded into PRD v1.1.**

### ADM-7 🟡 Large share of patients have no smartphone
- **Solution:** Already covered — walk-in + receptionist + SMS are first-class. Reaffirm as a **design principle**, not an afterthought.

---

## 3. Operations Manager — "Will this make my day better or worse?"

### OPS-1 🔴 No-shows and queue-gaming persist
Even with Pre-Queue, people book and don't come, or activate early.
- **Solution:** **Configurable overbooking** for appointment slots based on predicted no-show rate; activation requires a real signal (QR/geofence/check-in); no-show history feeds the prediction. Start heuristic, graduate to ML.

### OPS-2 🟠 Walk-in vs appointment fairness
Walk-ins resent appointment-holders skipping ahead, and vice versa.
- **Solution:** **Hybrid queue policy** is explicit and configurable per branch (e.g. reserve N% capacity for walk-ins, interleave rules). Make the policy visible to staff so they can explain it.

### OPS-3 🟠 Mid-queue disruption (staff break, doctor unavailable)
A doctor going offline mid-session silently wrecks every downstream ETA.
- **Solution:** Staff "mark unavailable / break" (already in spec) must **immediately recompute ETAs** and notify affected waiting customers ("doctor delayed, +X min"). Surface the cause to the manager dashboard.

### OPS-4 🟠 Change management & training
A new system at a busy reception desk fails if it's not faster than the whiteboard.
- **Solution:** Reception flow optimized for **<3 taps to add a walk-in**; printed quick-start; in-app onboarding; pilot includes on-site training days. Measure time-to-add-customer as a UX KPI.

### OPS-5 🟡 Proving ROI needs a baseline
Without "before" numbers, the hospital won't believe the improvement.
- **Solution:** **Baseline-capture mode** for the first 1–2 weeks (measure current waits) so improvement is provable. Becomes a sales asset too. **Added to PRD v1.1.**

---

## 4. Investor — "Is this a business, and is it defensible?"

### INV-1 🟠 Willingness to pay in Naira + FX exposure
SaaS priced in ₦ against USD-denominated infra (cloud, AI, SMS) compresses margin as the Naira moves.
- **Solution:** Price in ₦ for customers but **model COGS in USD**; build FX headroom into pricing; **notification costs are the main variable cost** — cap and meter them (CTO-5). Consider usage-based add-ons for SMS/WhatsApp.

### INV-2 🟠 Competition / "just use WhatsApp"
Incumbents (Qmatic, Qminder) and the "we already have a WhatsApp line" objection.
- **Solution:** Wedge is **prediction + multi-stage flow intelligence + Africa-native channels**, not ticketing. The moat is **operational data network effects** (better predictions per branch over time) + integrations once embedded.

### INV-3 🟠 Scope creep — "operating system for everything"
The vision spans every industry; an unfocused MVP dies.
- **Solution:** Ruthless MVP focus on **one industry (private hospitals), one city, one workflow** — exactly as the phase plan dictates. The "OS" is the long-term narrative, not the v1 build.

### INV-4 🟡 Unit economics dominated by per-message cost
- **Solution:** Push-first, SMS-for-critical-only; per-org notification budgets; transparent metering. Revisit at scale.

### INV-5 🟡 Single-market concentration risk
- **Solution:** Architecture is **multi-country/currency/timezone from day one** (already required) so expansion is config, not rebuild — de-risks the concentration narrative for investors.

---

## 5. Summary — what changes the product (folded into PRD v1.1)

| # | Change | Driver |
|---|--------|--------|
| R1 | **Multi-stage patient journeys (care pathways)** as a core concept | ADM-1 |
| R2 | **Clinical acuity/triage priority** drives ordering; overrides audited | ADM-2 |
| R3 | **Privacy on public displays** — ticket numbers/initials only | ADM-3 |
| R4 | **ETA grace windows + late re-activation**; ETA never a promise | ADM-6 |
| R5 | **Offline-first reception + SMS-first low-tech path + paper fallback** | CTO-2, ADM-7 |
| R6 | **Cost-aware notification routing** (push-first, SMS for critical) | CTO-5, INV-4 |
| R7 | **Grounded, read-only AI assistant** with shown sources | CTO-6 |
| R8 | **Baseline-capture mode** for ROI proof | OPS-5 |
| R9 | **Configurable overbooking + hybrid fairness policy** | OPS-1, OPS-2 |
| R10 | **HMS/EMR integration roadmap (HL7/FHIR)** — standalone first | ADM-5 |

Severity-🔴 items R1–R5 are MVP-blocking design decisions, not nice-to-haves.
