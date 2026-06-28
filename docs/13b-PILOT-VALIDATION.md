# Queue.ai — Phase 13.5: Pilot Validation ⭐

**Version:** 1.0
**Phase:** 13.5 (after build feature-complete, **before** QA/optimization)
**Premise (CTO):** the first hospital teaches what no planning or internal testing can. Validate with real users, then optimize. Build → **Pilot** → QA → Deploy.

> The point of the pilot is **learning, not perfection.** We expect to be surprised — receptionists ignoring a screen, doctors refusing to tap "Complete," patients preferring WhatsApp, managers caring about staffing over queue length. Those surprises reshape the product before we scale it.

---

## 1. Setup
- **Install** Queue.ai in **one** medium Nigerian private hospital (the [BUSINESS-OS](BUSINESS-OS.md) profile).
- Sign the **DPA** (NDPR; [08-SECURITY](08-SECURITY.md)); 1-day onboarding ([BUSINESS-OS §9](BUSINESS-OS.md)).
- Run **baseline-capture mode** (R8) for the first 1–2 weeks to record the "before."
- Then go live; observe **2–4 weeks**.

## 2. What we measure (the pilot scorecard)
| Metric | Source | Target |
|--------|--------|--------|
| **Hours Returned** (Law #0) | dashboard | positive & growing vs baseline |
| Average wait reduction | baseline vs live | −20% (stretch −30%) |
| Patient satisfaction (CSAT) | feedback | ≥ 4.2 / 5 |
| **Staff adoption** | per-role usage logs | receptionist daily use; staff "complete" rate |
| Daily active users (each role) | auth/events | trending up |
| ETA accuracy (within band) | predictions vs actuals | ≥ 80% |
| No-show reduction | vs baseline | −20% |

## 3. Observation & interviews (the qualitative half)
- **Observe in use** on-site across shifts (morning peak especially).
- **Interview every user type** at week 1 and week 3:
  - *Receptionist:* what's faster/slower than before? which screens do you skip?
  - *Doctor/Nurse:* do you tap "Complete"? what would make it effortless?
  - *Patient:* did you trust the ETA? app vs SMS vs WhatsApp preference?
  - *Manager:* what decision did the dashboard actually change? staffing vs queue?
- Log every workaround and ignored feature — those are signals, not noise.

## 4. The learning loop
- Weekly review against §2 + §3.
- **Fix the biggest usability issues before wider rollout** (not all issues — the top few that block adoption or value).
- Feed findings into **Flow Intelligence v2 (16.5)** priority — Capacity AI / Predictive Ops earn their place once the pilot proves the basics and generates data.

## 5. Hypotheses to test (write the answer, don't assume)
| Hypothesis | If false → action |
|-----------|-------------------|
| Receptionists adopt the <15s add-walk-in | simplify further / integrate with existing intake |
| Doctors will mark "Complete" | shift completion to nurse/auto-advance; infer from next call |
| Patients prefer the web/app tracker | prioritize **WhatsApp** (currently V2) sooner |
| Managers value bottleneck-spotting | if they want staffing → fast-track Capacity AI (F2) |
| The ETA is trusted | tune confidence/reasons; widen bands |

## 6. Exit criteria (proceed to QA + scale)
- Hours Returned demonstrably positive on the hospital's own numbers.
- Reception + at least one clinical department in daily real use.
- No critical data/safety/privacy incident.
- The hospital says **"don't take this away"** (and converts to paying).

## 7. Anti-goals during the pilot
- Don't add features mid-pilot (freeze; log requests for v2).
- Don't optimize prematurely — observe first.
- Don't expand to a second site until exit criteria met (INV-3 focus).

> Output of this phase: a **pilot report** (metrics + interview findings + prioritized fix list) that drives QA scope (14) and Flow Intelligence v2 (16.5).
