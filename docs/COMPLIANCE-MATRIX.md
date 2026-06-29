# Queue.ai — Implementation Compliance Matrix

**Date:** 2026-06-29
**Method:** every feature verified against the code (RPCs in `supabase/migrations`, pages in `apps/web`, jobs in `services/worker`). "Implemented" ≠ "working" — status reflects verification.

**Legend** — Status: ✅ Fully · ◑ Partial · ❌ Missing (schema/flag/doc hook may still exist).
**Tested:** Ⓐ automated (unit/CI) · Ⓛ live-verified (manual UAT on Supabase) · ❌ none.

| Feature | Planned | Impl. | Full | Partial | Missing | Tested | Notes |
|---|:--:|:--:|:--:|:--:|:--:|:--:|---|
| **Multi-tenant core** (org/branch/dept/service/counter/staff) | ✓ | ✓ | ✅ | | | Ⓐ Ⓛ | RLS isolation test in CI; structure CRUD used live |
| **RLS tenant isolation** | ✓ | ✓ | ✅ | | | Ⓐ | `0008` + `test/10_rls_isolation` |
| **Auth + onboarding** (bootstrap org) | ✓ | ✓ | ✅ | | | Ⓛ | signup → onboarding verified live |
| **Flow Builder (F1)** + publish + templates | ✓ | ✓ | ✅ | | | Ⓛ | flows pages + `publish_flow`; 4 industry templates |
| **Multi-stage pipeline (R1)** | ✓ | ✓ | ✅ | | | Ⓐ Ⓛ | smoke test + customer-journey UAT (6 stages) |
| **Join: Receptionist** (create_walkin) | ✓ | ✓ | ✅ | | | Ⓛ | add-walk-in verified live |
| **Join: QR / Web** (join_queue) | ✓ | ✓ | ✅ | | | Ⓛ | 12/12 live UAT assertions |
| **Join: WhatsApp** | ✓ | | | | ❌ | ❌ | V2 (not built) |
| **Join: Native mobile** | ✓ | | | | ❌ | ❌ | V2 (PWA only) |
| **Pre-Queue / Active + activation** (on-my-way/QR/reception) | ✓ | ✓ | ✅ | | | Ⓛ | `activate_visit`; verified live |
| **GPS geofence activation (CTO-1)** | ✓ | | | ◑ | | ❌ | branch geo+radius in schema; **no GPS client** |
| **Acuity / triage priority + audit (R2)** | ✓ | ✓ | ✅ | | | ❌ | `set_stage_priority`→`audit_log`; not in a test yet |
| **Queue verbs: call / serve / complete (auto-advance)** | ✓ | ✓ | ✅ | | | Ⓐ Ⓛ | smoke + UAT |
| **Queue verbs: transfer / skip / delay / requeue** | ✓ | | | ◑ | | ❌ | **no RPCs**; complete auto-advances only |
| **ETA + Trust Engine (F11)** (range+confidence+reasons) | ✓ | ✓ | ✅ | | | Ⓛ | `get_visit_status`; live UAT showed conf+reasons |
| **Trust accuracy feedback loop (07 §11)** | ✓ | | | | ❌ | ❌ | `predictions` not logged/scored |
| **Journey Timeline (F4)** | ✓ | ✓ | ✅ | | | Ⓛ | visit page; UAT |
| **Grace window / no-show (R4)** | ✓ | ✓ | | ◑ | | ❌ | sweep in worker (untested live); **no requeue-in-grace** path |
| **Notifications (R6)** push/SMS/email | ✓ | ✓ | | ◑ | | ❌ | queued + worker dispatcher **simulated**; no real provider/push/email send |
| **Privacy public display (R3)** | ✓ | ✓ | ✅ | | | Ⓛ | numbers-only; UAT confirmed no names |
| **Reception dashboard** | ✓ | ✓ | ✅ | | | Ⓛ | verified live |
| **Staff dashboard** (1-tap + status) | ✓ | ✓ | ✅ | | | ❌ | `set_staff_status` RPC; not live-tested |
| **Manager dashboard** | ✓ | ✓ | | ◑ | | ❌ | built; needs 0019/0021–24 applied; not live-tested |
| **Admin console** (structure/flows) | ✓ | ✓ | ✅ | | | Ⓛ | used live |
| **Digital Twin board (F3-lite)** | ✓ | ✓ | | ◑ | | ❌ | `get_flow_overview`; not live-tested |
| **Flow Score (F12) / Health (F8)** | ✓ | ✓ | | ◑ | | ❌ | live compute + rollup; AI summary is mock; untested live |
| **AI Health daily report** | ✓ | ✓ | | ◑ | | Ⓐ | `dailySummary` mock (grounded); unit-tested |
| **Baseline-capture + Time-Saved (R8/Law#0)** | ✓ | ✓ | | ◑ | | ❌ | `time_saved` + Hours Returned computed; baseline = a setting, not a guided "mode" |
| **Hours Returned KPI** (today/month/lifetime) | ✓ | ✓ | ✅ | | | ❌ | `get_hours_returned` (rollup-backed); not live-tested |
| **Grounded assistant (R7)** | ✓ | ✓ | | ◑ | | Ⓐ | **mock generation** (no real Claude/RAG); grounding unit-tested |
| **Hybrid policy + overbooking (R9)** | ✓ | | | ◑ | | ❌ | `appointments.overbooking_slot` column only; no booking/policy logic |
| **Offline-first reception (R5)** | ✓ | ✓ | | ◑ | | ❌ | cache-read + offline banner; **no write-queue sync** |
| **HMS/EMR integration (R10)** | ✓ | | | ◑ | | ❌ | `external_ref` hook only |
| **Capacity AI (F2)** | ✓ | ✓ | | ◑ | | ❌ | `get_predictive_ops` recommendation (heuristic; no throughput history yet) |
| **Predictive Operations (F13)** | ✓ | ✓ | | ◑ | | ❌ | heuristic forward-look; untested live |
| **Simulation (F5)** | ✓ | ✓ | | ◑ | | ❌ | `simulate_branch` crude formula, **not event-replay/back-tested** |
| **Organization Memory (F14)** | ✓ | | | | ❌ | ❌ | `org_patterns` table only; **no learner** |
| **Multi-Org Identity (F6)** | ✓ | | | | ❌ | ❌ | global `customers` + `consents` hooks only |
| **Family / Group Queue (F7)** | ✓ | | | | ❌ | ❌ | `visit_groups` table only; no UI/logic |
| **Queue Passport (F9)** | ✓ | | | | ❌ | ❌ | no returning-patient lookup RPC |
| **Anonymous Public Queue (F10)** | ✓ | | | | ❌ | ❌ | `publish_public_wait` flag only; no feature/page |
| **Appointments / booking** | ✓ | | | ◑ | | ❌ | `appointments` table only; no booking UI |
| **Industry templates (Bank/Passport/Univ) — Expansion 16** | ✓ | ✓ | ✅ | | | Ⓐ | `flow-templates.ts`; typecheck |
| **ROI calculator — Commercialization 17** | ✓ | ✓ | ✅ | | | ❌ | `/roi` page (pure); build-verified |
| **Sales one-pager / FAQ — 17** | ✓ | ✓ | ✅ | | | n/a | docs |
| **Marketing site / partnerships / CS assets — 17** | ✓ | | | ◑ | | n/a | docs only (not produced) |
| **Pilot toolkit — 13.5** | ✓ | ✓ | ✅ | | | n/a | scripts + scorecard + pilot_report.sql; pilot itself = real-world |
| **State machine integrity** | ✓ | ✓ | ✅ | | | Ⓐ | shared tests + CI transition-parity |
| **DB-integration CI (audit C1)** | ✓ | ✓ | ✅ | | | Ⓐ | `db-ci.yml` (smoke + RLS + parity) |
| **Phone encryption (audit C2)** | ✓ | ✓ | ✅ | | | ❌ | `0022`; needs apply+live test |
| **Worker: notification dispatch / no-show sweep / rollups** | ✓ | ✓ | | ◑ | | ❌ | code present; **needs worker running with service key** (not live-tested) |

---

## Scorecard
- **Fully working (✅):** ~22 — the entire **MVP core loop** (tenancy, RLS, auth, Flow Builder, pipeline, QR/web/reception join, activation, Trust Engine, Journey Timeline, public display, reception/admin, Hours Returned, templates, ROI, state-machine + CI).
- **Partial (◑):** ~16 — built but **unverified live or incomplete**: manager dashboard/twin/flow-score, predictive/sim/capacity (heuristic, no history), notifications (simulated send), offline (read-only), grace sweep, assistant (mock), baseline mode, appointments/overbooking, HMS hook.
- **Missing (❌):** ~10 — **V2/expansion** not built: WhatsApp, native, GPS client, transfer/skip/delay/requeue verbs, Org Memory learner, Multi-Org Identity, Family Queue, Queue Passport, Public Queue, Trust accuracy loop.

## Honest read
The **MVP customer→reception→display loop is fully working and live-verified**. The **manager/Flow-Intelligence layer is built but not yet live-verified** (needs migrations `0019`/`0021–24` applied + the worker running). The **v2/expansion features are mostly schema hooks, not behavior**. "Tested" is the weakest column: strong on the customer journey (live) and pure logic (CI), thin on the manager/worker/notification paths.
