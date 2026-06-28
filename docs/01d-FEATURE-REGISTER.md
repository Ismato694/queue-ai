# Queue.ai — Strategic Feature Register

**Version:** 1.0
**Phase:** cross-cutting (feeds PRD scope, Phase 3 wireframes, Phase 4 DB, Phase 6 architecture, Phase 7 AI)
**Source:** Founder feature set (F1–F10), evaluated as CTO/CPO/advisor.

> **Guiding tension:** these features are the *moat* — but the investor red-team (INV-3) warns scope creep kills the pilot. So the rule here is: **keep the MVP lean, but design the data model and architecture *now* so every one of these is a later addition, not a rewrite.** Each feature below has a **"design hook"** — the thing we must bake in early.

---

## Prioritization at a glance (MoSCoW × phase)

| # | Feature | Founder ⭐ | Value | Build cost | Tier | First appears |
|---|---------|-----------|-------|-----------|------|---------------|
| **F1** | **Organization Flow Builder** ("Shopify for customer flow") | ⭐⭐⭐⭐⭐ | 🟢 Very high (the moat) | 🟠 Med | **MVP (basic) → fast-follow (drag-drop polish)** | P3/P4 |
| **F4** | **Customer Journey Timeline** | — | 🟢 High (anxiety↓) | 🟢 Low | **MVP** | P3 |
| **F8** | **AI Health Score (daily org report)** | — | 🟢 High | 🟢 Low (heuristic) | **MVP v1** | P7 |
| **F3** | **Organization Digital Twin** (live status board → map) | ⭐⭐⭐⭐⭐ | 🟢 High | 🟠 Med | **MVP-lite (status board) → fast-follow (map)** | P3/P7 |
| **F7** | **Smart Family/Group Queue** | — | 🟡 Med (Africa-relevant) | 🟢 Low | **MVP-stretch** | P4 |
| **F2** | **Capacity AI** (staffing/room recommendations) | ⭐⭐⭐⭐⭐ | 🟢 Very high (willingness-to-pay) | 🔴 High | **Fast-follow (heuristic v1)** | P7 |
| **F5** | **AI Simulation** ("what if I close Counter 4?") | ⭐⭐⭐⭐⭐ | 🟢 High (exec decision support) | 🔴 High | **Fast-follow / P7+** | P7 |
| **F9** | **Queue Passport** (scan → everything appears) | — | 🟡 Med | 🟠 Med | **Single-org returning-patient: late MVP. Cross-org: needs F6** | P4 |
| **F6** | **Multi-Organization Identity** (one profile everywhere) | — | 🟢 High (platform network effect) | 🔴 High (privacy/consent) | **Vision / P16+** | P16 |
| **F10** | **Anonymous Public Queue** (compare branch waits) | — | 🟢 High (network effect) | 🔴 High (opt-in, competitive) | **Vision / expansion** | P16 |

---

## Why this ordering (the advisor's case)

1. **F1 is the franchise.** It's literally the pathway model from [02-USER-FLOWS.md](02-USER-FLOWS.md) (R1) elevated to no-code. Hospital/Bank/Passport-office flows are just different flow definitions — **we must not hardcode any one industry's flow.** This is also the single biggest barrier to competitors. → It graduates from "Admin pathway template" (Phase 2) to a **first-class Flow Builder**. MVP ships a usable builder (form/list-based or simple canvas); the polished drag-and-drop is fast-follow.
2. **F4 + F8 + F3-lite are cheap wins on data we already have.** The Journey Timeline is the customer-facing view of F1. The Health Score is the PRD's auto daily report. The Digital Twin "lite" is a live status board over existing stage data. High perceived value, low marginal cost → include in MVP.
3. **F2 and F5 are *earned*, not free.** Capacity AI and Simulation need **clean per-staff/per-room throughput data** that only exists once the basic system has run for weeks (cold start, CTO-4). Shipping them on day one would mean shipping confident garbage. So: capture the data from day one, ship heuristic recommendations as fast-follow, graduate to real models in Phase 7.
4. **F6 and F10 are network-effect platform bets** — they only pay off at multi-org scale and carry the heaviest privacy/consent and competitive-sensitivity load (NDPR consent for shared identity; banks may refuse to publish wait times). They belong in **expansion (Phase 16)**, but the data model must leave the door open.

---

## Per-feature: design hooks we must bake in NOW (so later = addition, not rewrite)

| # | Feature | **Design hook (decided now, built later)** | Key risk → mitigation |
|---|---------|--------------------------------------------|------------------------|
| F1 | Flow Builder | **Flows are data, not code** — a Flow = ordered/branching set of Stages with per-stage config (department, service, est. duration, rules). Versioned per org. Industry-agnostic. | Over-flexible builder confuses users → ship **templates per industry** + simple editor first. |
| F2 | Capacity AI | **Capture per-staff & per-room throughput** (served count, avg duration, idle time) as first-class metrics from day one. | Recommends nonsense on thin data → gate behind a data-volume threshold; label confidence; human-in-the-loop ("suggested"). |
| F3 | Digital Twin | **Every stage/counter emits a live status** (waiting count, busy/free/delayed). Twin = a view over this; start as a **status board**, evolve to a spatial map (optional branch floor-plan coords). | Building a literal map too early = wasted effort → status board first; map is opt-in. |
| F4 | Journey Timeline | Visit→Stages model (already R1) carries `done / current / upcoming` + per-stage ETA. | — (already in model) |
| F5 | AI Simulation | **Event-sourced activity log** (every state transition timestamped) so we can replay/model "what-if." | Sim accuracy doubted → present as scenario ranges, validate against historical replays. |
| F6 | Multi-Org Identity | **Customer is a global entity** with per-org links + **explicit consent records**; PII shared across orgs only with opt-in. | NDPR/privacy + chicken-and-egg network effect → consent-first; launches only once many orgs live. |
| F7 | Family/Group Queue | **Ticket can belong to a Group**; group members move together, share/independently track. | Group fairness/counting edge cases → define counting rule in Phase 4. |
| F8 | AI Health Score | Daily aggregate metrics (efficiency, deltas, best/worst dept) — heuristic v1, grounded (R7). | Vanity metric → tie each score to a concrete recommendation. |
| F9 | Queue Passport | **Returning-customer fast lookup within an org** (scan QR → prior visits/preferences) works at MVP from our own data; cross-org needs F6 + HMS/EMR integration (R10). | Scope blur → split: single-org passport (cheap) vs cross-org passport (F6-gated). |
| F10 | Anonymous Public Queue | **Branch-level wait metrics are aggregatable & opt-in publishable** (a per-branch "publish public wait" flag, anonymized). | Banks won't publish; gaming; competitive risk → strictly opt-in, anonymized, org-controlled. |

---

## Impact on the phase plan

- **Phase 3 (Wireframes):** add screens for **Flow Builder (F1)**, **Journey Timeline (F4)**, **Digital Twin status board (F3-lite)**, **Health Score (F8)**. Note family-group and returning-patient passport interactions.
- **Phase 4 (Database):** model **Flows-as-data (F1)**, **per-staff/room throughput metrics (F2)**, **event-sourced activity log (F5)**, **global Customer identity + consent (F6)**, **Group tickets (F7)**, **branch publishable-metrics flag (F10)**. These are *schema-shaping* — getting them right now is the whole point of this register.
- **Phase 6 (Architecture):** analytics/event pipeline that feeds Twin/Simulation/Capacity AI; ensure the real-time layer can drive the Twin.
- **Phase 7 (AI/ML Spec):** Capacity AI, Simulation, Health Score, and grounded assistant all specced here, with the heuristic-first → model-later path.
- **Phase 9 (MVP Scope Lock):** confirm exactly which of F1/F3/F4/F7/F8 land in MVP vs fast-follow.
- **Phase 16 (Expansion):** F6 Multi-Org Identity, F10 Public Queue, full cross-org Queue Passport — the network-effect layer.

---

---

## Addendum — Trust, Scoring & Predictive Operations (F11–F14 + rename)

A second founder set, focused on **trust and proactivity**. These are highly aligned with the design constitution ([03a-DESIGN-PHILOSOPHY.md](03a-DESIGN-PHILOSOPHY.md)) and the "Flow Intelligence" identity.

| # | Feature | Value | Cost | Tier | Notes |
|---|---------|-------|------|------|-------|
| **F11** | **Trust Engine** — ETA + confidence % + *the reasons* | 🟢 Very high (the honesty differentiator) | 🟢 Low–Med | **MVP** | "Can I trust this estimate?" answered explicitly |
| **F12** | **Flow Score** — single daily org score (0–100, ⭐, delta) | 🟢 High | 🟢 Low | **MVP** | The headline number of F8 Health Score — consolidate, don't duplicate |
| **F13** | **Predictive Operations** — warn *before* it goes bad + recommend action | 🟢 Very high (the unique edge) | 🔴 High | **Fast-follow (heuristic early-warnings possible sooner)** | Proactive arm of F2 Capacity AI |
| **F14** | **Organization Memory** — learns recurring local patterns | 🟢 High | 🟠 Med (needs history) | **Fast-follow → P7** | Monday late-doctor, rainy-day −30%, December traffic |
| **—** | **Rename: "AI Features" → "Flow Intelligence"** | identity | — | **Adopted now** | Umbrella for Prediction · Optimization · Simulation · Recommendations · Automation · Analytics |

### F11 Trust Engine — the standout
Instead of a bare "ETA 22 min", show **ETA + Confidence + Reasons**:
```
ETA          22 min
Confidence   92%   ▰▰▰▰▰▰▰▰▰▱
Why          • Queue stable  • All doctors available  • Historical accuracy high
```
When confidence drops, the band widens and the reasons explain *why* — honesty, not false precision (R4):
```
ETA          22–35 min
Confidence   62%   ▰▰▰▰▰▰▱▱▱▱
Why          • Emergency patient admitted  • Doctor temporarily unavailable
```
- **Design hook:** every prediction carries `{value_range, confidence, reasons[]}`. The ETA Pill (03a §6) becomes the **Trust Engine** component. Reasons are generated from the same signals that drive the ETA (queue stability, staff availability, historical accuracy) — grounded, not invented (R7). **MVP-eligible** with heuristic confidence + rule-based reasons; learned confidence later.

### F12 Flow Score — consolidated with F8
Flow Score **is** the headline of the AI Health Score: one number (e.g. `94 ⭐⭐⭐⭐⭐, +8 vs yesterday`) + the best/worst department + one recommended action. Managers improve a number over time. MVP v1 = heuristic composite (wait vs baseline, no-show %, utilization, CSAT).

### F13 Predictive Operations — the unique edge
The dashboard stops *reporting* and starts *warning*:
```
⚠ In ~47 min, Laboratory will be overloaded.
   Recommended: move 1 technician before 11:30. [Apply] [Dismiss]
```
This is F2 Capacity AI run **forward in time**. **Design hook:** the event-sourced log (F5 hook) + per-resource throughput (F2 hook) already give us the inputs. Ship rule-based early-warnings as fast-follow, learned forecasting in Phase 7.

### F14 Organization Memory — local pattern learning
The system learns each org's recurring rhythms (day-of-week, weather, season, holidays) and folds them into predictions and warnings. **Design hook:** capture **calendar/seasonality/weather features + per-entity behavior history** from day one so the model has signal later. Fast-follow → Phase 7; needs accumulated history (cold start).

### Rename adopted: **Flow Intelligence**
PRD §5.7, Phase 7, and dashboards now use **"Flow Intelligence"** instead of "AI Features." Sub-pillars: **Prediction · Optimization · Simulation · Recommendations · Automation · Analytics.** Stronger, flow-centric identity than generic "AI."

---

---

## Law #0 Compliance — Time-Saved Scorecard

Per [03a-DESIGN-PHILOSOPHY.md](03a-DESIGN-PHILOSOPHY.md) **Law #0 (Time is the Product)**, every feature must justify itself by time saved. New features from here on **must** include all four fields (problem · decision removed · time saved · how measured). Scorecard for the headline features:

| Feature | Decision removed | Time saved (whose · est.) | How measured |
|---------|------------------|---------------------------|--------------|
| F1 Flow Builder | "How do we model our workflow?" (admin) | Admin: hours of setup/change; Org: fewer mis-routes | Setup time; mis-route rate |
| F4 Journey Timeline | "Where am I / should I keep waiting?" (customer) | Customer: anxiety-waiting + wasted trips | Abandonment ↓; CSAT |
| F11 Trust Engine | "Do I believe this ETA / leave now?" (customer) | Customer: minutes saved leaving at optimal time | Arrival-accuracy; wait reduction |
| F12 Flow Score | "Is today good or bad / where to focus?" (manager) | Manager: triage time to the right problem | Time-to-decision; flow-score trend |
| F13 Predictive Operations | "Is a bottleneck coming / act now?" (manager) | Org: waiting **prevented** before it forms | Predicted-vs-actual; pre-empted delays |
| F2 Capacity AI | "How do I staff/allocate right now?" (manager) | Org: throughput ↑, idle staff ↓ | Utilization; throughput/hr |
| F8 Health Score | "How are we doing overall?" (manager) | Manager: reporting time | Report-gen time saved |
| F3 Digital Twin | "Where's the problem on the floor?" (manager) | Manager: seconds to locate bottleneck | Time-to-spot bottleneck |

Each row maps a removed decision (Decision-Removal Ladder) to a time outcome (Law #0). Features that can't fill a row don't ship.

---

## Bottom line
All ten are kept. **F1 is repositioned as the flagship differentiator.** The MVP gains F1(basic)/F3-lite/F4/F8 (and possibly F7) because they're cheap and ride data we already capture. F2/F5/F9 are deliberately deferred until the system has generated the data that makes them *correct*, not just impressive. F6/F10 are the platform/network-effect bets reserved for expansion — but the Phase 4 schema will be built so they're switch-ons, not rebuilds.

> ✅ This register updates PRD scope and the roadmap decision log. **Phase 3 (Wireframes)** will now include the Flow Builder, Journey Timeline, Digital Twin board, and Health Score.
