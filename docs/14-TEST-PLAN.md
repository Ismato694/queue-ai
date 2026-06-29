# Queue.ai — Test Plan

**Version:** 1.0
**Phase:** 14 (QA & Testing)
**Goal:** enough automated + scripted coverage to trust the pilot, without over-testing pre-PMF (Founder Rule #1). Success = the **pilot UAT script passes** and the safety-critical invariants hold.

---

## 1. Test pyramid (what we test, where)

| Level | Scope | Tooling | Status |
|-------|-------|---------|--------|
| **Unit** | Pure logic: state machine, grounded assistant, notification routing | `node:test` (`npm test`) | ✅ 12 tests, in CI |
| **DB / RPC integration** | Queue-engine transitions + the activity-event invariant | `supabase/dev/smoke_test.sql` | ✅ runnable in SQL editor |
| **RLS / tenant isolation** | Cross-org data cannot leak | SQL isolation checks (§4) | ✅ scripted |
| **Build / typecheck** | Whole monorepo compiles | `npm run typecheck` + `next build` | ✅ in CI |
| **E2E / manual UAT** | The real user journeys on a live env | Pilot UAT script (§5) | ▶ run at deploy/pilot |
| **Performance** | Queue read latency, realtime <2s | manual + indexes (§6) | ▶ at pilot scale |

---

## 2. Automated unit tests (in CI, `npm test`)
- **`packages/shared`** — ticket **state-machine** transitions (valid/invalid/terminal), grace re-queue (R4), channel naming. *Protects the safety-critical transition rules.*
- **`apps/web`** — **grounded assistant**: daily summary + Q&A trace to real numbers, citations present, and the **anti-hallucination** test (never names a department not in the data, R7).
- **`services/worker`** — notification **copy** (no medical detail, R3-adjacent) and **cost-aware channel routing** (SMS only for "your turn", R6).

CI (`.github/workflows/ci.yml`): `npm install → typecheck → test → build` on every push/PR. Keep green as the merge gate.

## 3. Queue-engine smoke test (DB)
`supabase/dev/smoke_test.sql` runs the full pipeline as the org and **asserts** each transition:
create walk-in → `active` → `call_next` → `called` → `serve` → `serving` → `complete` → `completed` **+ auto-advance** next stage → `active`, and verifies an **`activity_event` was written** (the zero-ticket-loss invariant). Raises on any mismatch; prints `SMOKE TEST PASSED ✓`.

## 4. RLS / tenant-isolation checks
The highest-risk failure is cross-tenant leakage. Verify on the live DB:
```sql
-- As org A's context, you must NOT see org B's rows.
select set_config('app.current_org', '<ORG_A>', true);
select count(*) from visits;          -- only org A's visits
select count(*) from visit_stages;    -- only org A's stages
-- customers are global but gated: only those linked to org A are visible
select count(*) from customers;
```
Plus the design guarantees: `public_queue_view` exposes **ticket numbers only** (no names, R3); priority overrides write `audit_log` (R2). Add a second org + user during QA and confirm neither sees the other's data via the app.

## 5. Pilot UAT script (manual E2E — the gate that matters)
Run on the deployed env before/at pilot. Each step = pass/fail.

| # | Actor | Action | Expected |
|---|-------|--------|----------|
| 1 | Admin | Sign up → onboard org + branch | Lands in `/admin`, not a loop |
| 2 | Admin | Structure: add dept/service/staff | Persist + visible |
| 3 | Admin | Flow Builder: build + **publish** a flow | Published; preview shows stages |
| 4 | Reception | Add walk-in (<15s) | Appears in queue, `active` |
| 5 | Reception | Call next | Patient → `called`, grace set |
| 6 | Reception/Staff | Serve → Complete | Auto-advances to next stage |
| 7 | Customer | Scan QR `/join/<token>` → join | Gets ticket + live Journey Timeline |
| 8 | Customer | View `/visit/<id>` | **Trust Engine**: ETA range + confidence + reasons |
| 9 | Customer | (remote) "I'm on my way" | Pre-queue → active |
| 10 | Staff | `/staff` one-tap call/complete; break/online | Status reflects; ETA reacts |
| 11 | Public | `/display/<token>` | Numbers only, no names (R3) |
| 12 | Manager | `/manager` | Flow Score, Digital Twin, **Hours Returned** |
| 13 | System | Don't show within grace | Auto **no_show** (worker sweep, R4) |
| 14 | Reception | Priority override | Reorders; `audit_log` row written (R2) |
| 15 | Reception | Kill network briefly | "Offline" banner, last queue shown (R5) |
| 16 | Security | Second org can't see first's data | Isolation holds |

## 6. Performance / load (pilot-grade)
- Targets (PRD): realtime < 2s p95, API p95 < 300ms, zero ticket loss.
- Indexes for the hot paths are in place (`0005`, `0015`); the queue read is `(org, dept, state, acuity, position)`.
- At pilot volume (~300 visits/day) this is comfortably within Postgres/Supabase limits. Revisit load testing only when a branch approaches the high end or multi-branch scale.

## 7. Regression checklist (before each deploy)
- [ ] `npm test` green · `npm run typecheck` green · `next build` green
- [ ] `smoke_test.sql` passes on staging
- [ ] RLS isolation check passes with two orgs
- [ ] UAT steps 1–8 (core loop) pass on the deployed preview

## 8. Known gaps (tracked, acceptable for pilot)
- No automated browser E2E yet (Playwright) — UAT script is manual for now; add Playwright post-pilot if churn warrants.
- RPC integration tests are SQL-script form, not yet in CI (needs a CI Postgres + seed); wire up when the team grows.
- Load testing deferred until scale demands (Founder Rule #4).

---

> Output: a green automated suite + a runnable smoke test + a manual UAT script. Sufficient confidence to enter **Phase 13.5 Pilot Validation**.
