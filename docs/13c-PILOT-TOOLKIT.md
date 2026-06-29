# Queue.ai — Phase 13.5: Pilot Toolkit (executable instruments)

**Version:** 1.0
**Phase:** 13.5 (companion to [13b-PILOT-VALIDATION](13b-PILOT-VALIDATION.md))
**Purpose:** the concrete instruments to *run* the pilot — interview scripts, the scorecard, baseline procedure, and the pilot report. The pilot itself is executed by the team in the hospital over 2–4 weeks.

> The pilot's job is **learning, not perfection**. Capture numbers (quant) and observations (qual); fix the top 1–3 adoption blockers; feed the rest to v2.

---

## 1. Baseline procedure (week 0–1) — make ROI provable (R8)
1. Install + 1-day onboarding ([BUSINESS-OS §9](BUSINESS-OS.md)); DPA signed.
2. Run in **baseline-capture** mode: staff use it lightly; we record actual waits with minimal intervention.
3. At end of baseline, record the **before** numbers (avg wait, no-show %, abandonment estimate, daily volume) — these anchor every "after" comparison and the **Hours Returned** metric.
4. Set `branches.settings->>'baseline_wait_seconds'` to the measured baseline so Hours Returned/Flow Score compare against reality, not the default.

## 2. The pilot scorecard (track weekly)
| Metric | Baseline | Wk1 | Wk2 | Wk3 | Target |
|--------|---------|-----|-----|-----|--------|
| **Hours Returned** (cumulative) | — | | | | ↑ |
| Avg wait | | | | | −20% |
| No-show rate | | | | | −20% |
| CSAT (1–5) | — | | | | ≥4.2 |
| Reception daily use | — | | | | every shift |
| Staff "complete" rate | — | | | | majority |
| Patients self-joining (QR/web) | — | | | | rising |
| ETA accuracy (within band) | — | | | | ≥80% |

Pull the live numbers from the **Manager dashboard** and `supabase/dev/pilot_report.sql`.

## 3. Interview scripts (run week 1 + week 3)

**Receptionist**
- What's faster than before? What's slower?
- Which screen/button do you skip or avoid? Why?
- When it's busiest, does it help or get in the way?
- What would make adding a walk-in effortless?

**Doctor / Nurse / Tech**
- Do you tap "Complete"? If not, what stops you?
- Does the "what's next" view match how you actually work?
- Anything that adds clicks to your day?

**Patient** (quick, 3 Qs)
- Did you trust the time estimate? Why / why not?
- App, SMS, or would you prefer WhatsApp?
- Did you feel more in control than usual?

**Manager / Owner**
- What decision did the dashboard actually change today?
- Do you care more about queue length or staffing?
- Is the Hours Returned / Flow Score number believable and useful?

> Log every workaround and ignored feature verbatim — those are the product signals.

## 4. Daily standup (5 min, on-site week 1)
- Any blocker that stopped the desk? (offline? confusion? bug?)
- One thing to fix today.
- Numbers trending up or down vs yesterday?

## 5. Fix-prioritization rubric (don't fix everything)
Rank issues by: **(blocks adoption?) × (frequency) × (effort)**. Fix only:
1. Anything that **blocks the desk** (P0, same day).
2. Top adoption friction (P1, within the week).
Everything else → backlog / v2. Resist feature requests mid-pilot (freeze).

## 6. Exit review → decision
Meet the [13b §6](13b-PILOT-VALIDATION.md) exit criteria? →
- **Yes** → convert hospital to paying; proceed to QA hardening + scale + v2 priorities from findings.
- **No** → identify the single biggest reason, fix, re-run a 1-week mini-pilot.

## 7. Pilot report
`supabase/dev/pilot_report.sql` prints the current snapshot (Hours Returned, avg wait, no-show, served, active-now, per-department load) for the branch — paste into the scorecard. Run it daily/weekly.
