# Queue.ai — MVP Scope Lock (Hospitals)

**Version:** 1.0 (for approval — **the last gate before code**)
**Phase:** 9
**Governs:** Phases 10–13 (build). Filtered by [09-FOUNDER-RULES.md](09-FOUNDER-RULES.md) Rule #2 + the **feature-freeze restriction**: *no feature enters MVP unless essential for the first paying hospital.*

> **🔒 PRODUCT VISION FROZEN.** The full vision (F1–F14, multi-industry, network effects) stands as the roadmap — but it is **closed for the MVP**. Anything not on the IN list below is **V2**, no exceptions, until the first hospital is live, paying, and validated. Every decision here optimizes for **ship → learn → validate with a real hospital, fast.**

---

## 1. MVP definition (one sentence)
> One medium Nigerian private hospital runs a **full day of real patients** through Queue.ai — multi-stage journeys, live ETAs with the Trust Engine, reception/staff/manager/customer surfaces — and we **prove measured Total Time Saved vs. its own captured baseline.**

### Success criteria (Rule #7 — outcomes, not code)
| Metric | Target |
|--------|--------|
| **Total Time Saved** (vs baseline) | demonstrably positive, reported daily |
| Patient wait reduction | −20% or better (stretch −30%) |
| ETA accuracy (actual within band) | ≥ 80% |
| Real-time update latency | < 2s p95 |
| Ticket loss | **zero** |
| Reception "add walk-in" | < 15s |
| Hospital says "don't take this away" | the real test |

---

## 2. Feature LOCK — run through Rule #2 (saves time? · will pay? · <2 weeks?) + essential-for-first-hospital

### ✅ IN — MVP (essential to run a day & prove time saved)
| Item | Why essential | Rule #2 |
|------|---------------|---------|
| Multi-tenant core (org/branch/dept/service/counter/staff) + RBAC + RLS | the spine | ✓✓✓ |
| **Flow Builder — BASIC** (hospital template + simple stage editor) F1 | how the hospital is configured; the moat in seed form | ✓✓ (basic only) |
| **Visit/Stage pipeline** R1 | the core product | ✓✓✓ |
| Join: **Receptionist + QR + Web** | covers every patient type day one | ✓✓✓ |
| Pre-Queue/Active + activation (**on-my-way / QR / receptionist**) | anti-fraud, remote join | ✓✓✓ |
| **Acuity/triage + priority override + audit** R2 | clinical safety (non-negotiable) | ✓✓✓ |
| Queue engine verbs (call/serve/complete/transfer/delay/cancel/requeue) | the daily operations | ✓✓✓ |
| **ETA + Trust Engine (heuristic)** F11 | the differentiator + time-saving signal | ✓✓✓ |
| **Journey Timeline** F4 | customer experience, cheap, anxiety↓ | ✓✓✓ |
| Grace window / no-show R4 | fairness + liability | ✓✓✓ |
| **Notifications: Push + SMS + Email** (push-first, R6) | the reach (SMS = universal in NG) | ✓✓✓ |
| **Privacy public display** R3 | required + cheap | ✓✓✓ |
| Dashboards: **Reception · Staff · Manager · Admin** | all four operators | ✓✓✓ |
| **Digital Twin status board** F3-lite | manager <3s value | ✓✓ |
| **Flow Score + daily report** F12/F8 | manager value + ROI proof | ✓✓ |
| **Baseline-capture + Time-Saved** R8 / Law #0 | the sales wedge + success metric | ✓✓✓ |
| **Grounded assistant — v1 (light)** R7 | high-value sell; kept modest | ✓✓ |
| Hybrid walk-in/appointment policy (basic config) R9 | fairness; simple config only | ✓✓ |
| Resilience: **online + cache read + SMS + paper fallback** (scoped, see §3) | Nigeria conditions | ✓✓ |

### ⏸ V2 — deferred (NOT essential for first paying hospital)
Flow Builder drag-drop polish · WhatsApp chatbot · Native mobile · Voice announcements · **Capacity AI (F2)** · **Predictive Operations (F13)** · **Simulation (F5)** · **Organization Memory (F14)** · Multi-Org Identity (F6) · Public Queue (F10) · cross-org Queue Passport (F9) · Family/Group queue (F7) · HMS/EMR integration (R10) · No-show **ML** + demand **ML** (heuristic only in MVP) · GPS geofence activation (optional enhancement) · Payments.

> F2/F5/F13/F14 are deferred *by design* — they need the event-log data the MVP will start generating. They become V2's headline once data exists.

---

## 3. Honest scope cuts (no pretending — Rule #1)
- **Offline (R5):** MVP ships **resilient online + cached reads + SMS + documented paper fallback + reconnect refresh.** The *full* conflict-resolving offline write-queue (`/sync/batch`) is **fast-follow**, prioritized if pilot connectivity demands it. (We don't fake "fully offline" on day one.)
- **Assistant (R7):** v1 answers a fixed set of grounded questions + generates the daily report; open-ended NL breadth grows post-pilot.
- **Flow Builder (F1):** template + form/list stage editor; visual drag-drop canvas is V2.
- These cuts are flagged for the pilot to confirm they're acceptable.

---

## 4. 🔒 TECH STACK — LOCKED (supersedes the [01c](01c-TECH-STACK.md) recommendation; managed-first for speed)

Decision driver: **fastest path to a live, paying hospital** (Rules #1, #4) while keeping NDPR residency.

| Layer | LOCKED choice | Why (over the alternative) |
|-------|--------------|----------------------------|
| Frontend (all surfaces) | **Next.js + TypeScript + Tailwind + shadcn/ui**, PWA | the Stripe/Linear aesthetic; one codebase; offline-capable |
| Backend platform | **Supabase** (managed **Postgres + PostGIS + pgvector**, **Auth**, **Realtime**, **Storage**, **RLS**) in **`af-south-1` (Cape Town)** | eliminates building auth/realtime/storage/RLS infra → weeks saved; **af-south-1 = NDPR residency**; Postgres-authoritative model (Phase 5) still holds. *Chosen over assembled NestJS+Clerk+Socket.IO for MVP speed.* |
| Domain service + workers | **Node/NestJS service** (queue engine, ETA recompute, AI calls, notification orchestration) + **pg_cron / Edge Functions** for sweeps & rollups | keeps complex domain logic + the event-log invariant in our control; managed pieces do the undifferentiated heavy lifting |
| Real-time | **Supabase Realtime** (Postgres change broadcast, per-branch channels) + polling fallback | no custom WS infra to run for MVP |
| AI | **Claude** — `claude-sonnet-4-6` default · `claude-opus-4-8` hardest · `claude-haiku-4-5` cheap; grounded + structured outputs; embeddings via Voyage | per [07](07-FLOW-INTELLIGENCE.md); no PHI sent ([08](08-SECURITY.md) §7) |
| Notifications | **Termii / Africa's Talking** (SMS), **Resend** (email), Web Push | Africa-native deliverability/pricing |
| Maps/geo | Google Maps (travel time) + PostGIS | "leave by" + geofence math |
| Hosting | Frontend on Vercel/Cloudflare; worker container on a managed host; data in Supabase **af-south-1** | managed-first; repatriate to self-managed AWS post-PMF only if enterprise/residency demands (data is already in-region) |
| Observability | Sentry + Supabase logs + lightweight metrics | enough for pilot |
| CI/CD | GitHub Actions; Supabase migrations | standard |

**MFA (resolved):** Supabase Auth MFA **available and recommended for admin/manager**, **optional in the pilot** to reduce onboarding friction (Rule #1), with an **org setting to enforce** it. Strong-password + session policy on by default.

> Migration safety: because Supabase *is* Postgres with RLS, the Phase 4 schema, Phase 5 API model, and Phase 6 event-log invariant all carry over unchanged. If we ever outgrow Supabase, we move Postgres to self-managed AWS af-south-1 — not a rewrite.

---

## 5. Build backlog — sprints (each ends demonstrable to an admin, Rule #5)

Mapped to build phases 10–13. ~1–2 week sprints.

| Sprint | Phase | Deliverable | **Demo to admin** |
|--------|-------|-------------|-------------------|
| **S0 Foundations** | 10 | Repo, CI, Supabase af-south-1, schema migrations, Auth, **RLS + tenant model**, base app shell | "Log in, create org + branch." |
| **S1 Config + Flow Builder** | 10 | Org/branch/dept/service/counter/staff CRUD; **Flow Builder basic + hospital template** | "Build your hospital's flow in minutes." |
| **S2 Queue Engine + Reception** | 11 | State machine, `activity_events`, acuity ordering; **Reception board + <15s add walk-in**; call/serve/complete/transfer | "Run a patient from reception to consult." |
| **S3 Real-time + Customer** | 11/12 | Supabase Realtime; **QR + Web join**; activation; **Customer Live Visit (Journey Timeline)**; called/proceed; **Push + SMS** | "Patient joins by QR, sees live status, gets 'you're next' SMS." |
| **S4 Trust Engine + Staff + Display** | 12/13 | **ETA + confidence + reasons (heuristic)**; grace/no-show; priority+audit; **Staff 1-tap app**; **Public display (numbers only)** | "Live ETA with confidence + reasons; triage; waiting-room screen." |
| **S5 Manager + Flow Intelligence v1** | 13 | **Digital Twin board + Flow Score + Baseline/Time-Saved**; **grounded assistant v1 + daily report** | "See bottlenecks in 3s; today's Flow Score; ask 'why slower?'; time saved." |
| **S6 Resilience + Hardening** | 13/14 | Cache reads + SMS/paper fallback; accessibility; security pass; load test; polish | "Works on a bad network; calm and fast." |

**Definition of Done (every story):** meets the design constitution (answers its Core Questions, ≥ rung 1, never rung 0), tenant-isolated (RLS), emits `activity_events`, has tests, and is demoable.

---

## 6. Pilot plan (the validation loop)

```
Select hospital → sign DPA → remote setup (flow, QR, staff)
   → 1-DAY onboarding (09 playbook)
   → 1–2 wk BASELINE mode (measure the "before")
   → GO LIVE (primary; paper as backup)
   → measure Time-Saved / Flow Score daily
   → weekly learning review → tune → expand
```

- **Risk-free offer (BUSINESS-OS):** "We measure your queue's cost free for two weeks; no return, no charge."
- **Pilot success = §1 criteria met** + hospital converts to paying Growth tier.
- **Learning loop:** instrument everything; weekly review against Rule #7 metrics; feed findings into V2 priority (likely Capacity AI/Predictive Ops once data exists).

---

## 7. Build risks & mitigations
| Risk | Mitigation |
|------|-----------|
| Scope creep mid-build | feature freeze (§this doc) + Rule #2 gate on any new ask → V2 |
| Real-time correctness | Postgres-authoritative + event-log invariant; Supabase Realtime derived from commits |
| ETA looks wrong at cold start | seeds + wide bands + "still learning" label; baseline period tunes it |
| Connectivity at the desk | online+cache+SMS+paper; full offline sync as fast-follow if pilot needs |
| Adoption (reception/doctors) | <15s add-walk-in, 1-tap staff, on-site training day, demo each sprint |
| AI cost/latency | tiered models, prompt caching, budgets, batched reports |

---

## 8. Ready-for-code checklist
- [x] Vision frozen; MVP IN/V2 locked
- [x] Success criteria = outcomes (Rule #7)
- [x] Tech stack locked (Supabase + Next.js + Node worker + Claude, af-south-1)
- [x] MFA decision made
- [x] Sprint backlog with per-sprint demos (Rule #5)
- [x] Pilot plan + risk-free offer
- [x] Schema/API/architecture/security all carry over unchanged to the locked stack

---

## Approval
> ✅ **Approve Phase 9** to begin **Phase 10 — MVP Build (Backend, DB, Auth)** starting at **Sprint S0**.
> This is the transition from planning to code. On approval, the next deliverable is *running software*, demoed sprint by sprint.
> Or adjust the scope/stack/backlog first.
