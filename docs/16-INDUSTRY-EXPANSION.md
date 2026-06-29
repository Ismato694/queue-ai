# Queue.ai — Phase 16: Industry Expansion

**Version:** 1.0
**Phase:** 16 (post-pilot expansion)
**Thesis:** the Flow Builder (F1) is industry-agnostic by construction — flows are *data*, not code. Expanding to a new industry is **a new template + config**, not a new build. This is the moat made visible ("Shopify for customer flow").

> Sequencing note: real expansion happens **after** the hospital pilot validates the core (13.5). This phase proves the claim now (templates) and defines how new verticals onboard.

---

## 1. Proof: same engine, different rows
Every vertical is the same `Visit → Stages` pipeline, the same queue engine, the same Trust Engine, the same dashboards. Only the **flow definition** (stage names + departments) differs.

| Industry | Flow (stages) |
|----------|---------------|
| **Hospital** | Reception → Vitals → Consultation → Lab → Review → Pharmacy → Cashier |
| **Bank** | Reception → Customer Service → Cashier → Manager Approval |
| **Passport / Govt** | Security → Biometrics → Document Verification → Interview → Collection |
| **University** | Reception → Registration → Bursary/Fees → ID Card |

Shipped as a **template library** in the Flow Builder ([apps/web/src/lib/flow-templates.ts](../apps/web/src/lib/flow-templates.ts)): pick an industry → stages pre-fill → admin maps each to a department → publish. No code change, no schema change.

## 2. What carries over unchanged (zero rework)
Multi-tenancy + RLS · Pre-Queue/activation · acuity/priority (becomes VIP/priority in banks) · ETA + Trust Engine · notifications · Digital Twin · Flow Score · **Hours Returned** · public display · offline. The vocabulary changes (patient→customer, doctor→teller, room→counter) but the model doesn't.

## 3. Per-vertical nuances (config, not rebuild)
| Vertical | Nuance | Handled by |
|----------|--------|-----------|
| Bank | priority/VIP tiers; KYC steps | acuity + flow stages |
| Passport/Govt | strict sequential steps, appointments | flow ordering + appointments (R9) |
| University | seasonal surge (enrolment week) | Org Memory (F14, v2) + overbooking |
| Airport/Telecom | high volume, many counters | same queue engine; scale path (06) |

## 4. Go-to-market sequence (focus, INV-3)
1. **Win private hospitals** (pilot → references) before opening a second vertical.
2. **Banks next** — shorter flows, high volume, clear ROI, fast sales cycle.
3. **Universities** — seasonal, high-visibility wins.
4. **Government/airports** — longest cycle; pursue with references + partnerships ([17](17-COMMERCIALIZATION.md)).

Each new vertical = a template (done for 4) + a reference customer + light vocabulary tuning. **Not** a new product.

## 5. What's intentionally NOT in this phase
- No new core features for verticals (that's scope creep). Verticals reuse the MVP.
- Cross-industry network features (Multi-Org Identity F6, Public Queue F10) remain expansion bets, gated on scale + consent.

---

> Output: a working multi-industry template library proving F1, plus the expansion playbook. Real vertical launches follow the hospital pilot and reference customers.
