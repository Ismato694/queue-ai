# Queue.ai — Phase 17: Commercialization

**Version:** 1.0
**Phase:** 17 (after Industry Expansion)
**Premise (CTO):** the phase technical founders forget. A great product that isn't sold, onboarded, and measured doesn't return anyone's time. Built on the validated pilot ([13b](13b-PILOT-VALIDATION.md)) and the modeled economics ([BUSINESS-OS](BUSINESS-OS.md)).

> Everything here is anchored to the mission metric: **Hours Returned**. It headlines the deck, the dashboard, the case studies, and the analytics.

---

## 1. Sales
- **Sales deck** — problem (invisible abandonment) → Hours Returned → ROI; built from real pilot numbers.
- **Hospital pitch** — the risk-free wedge: *"We measure your queue's cost free for two weeks; no return, no charge"* (baseline mode, R8).
- **ROI calculator** — interactive: visits/day × contribution × recovered loss → ₦/month + Hours Returned (the [BUSINESS-OS](BUSINESS-OS.md) model, made live for a prospect).
- **Pricing** — ₦ tiers (Starter/Growth/Enterprise) + metered messaging; FX headroom (INV-1).
- **Case studies** — the pilot hospital's before/after (wait −X%, Hours Returned, CSAT).

## 2. Customer Success
- **Onboarding guide** — the 1-day playbook ([BUSINESS-OS §9](BUSINESS-OS.md)) productized.
- **Training videos** — per role (receptionist 90s, staff 30s, manager 2m).
- **Documentation** — admin/Flow-Builder docs, FAQ, troubleshooting, offline/paper procedure.
- **Admin manual** — flows, services, staff, policies, notification budgets.
- **Health checks** — periodic review of the customer's Flow Score + Hours Returned trend.

## 3. Marketing
- **Website + landing page** — "Give people their time back." Lead with Hours Returned.
- **Demo video** — the customer↔reception↔manager loop in 90 seconds.
- **FAQ + blog** — queue economics, NDPR, hospital operations, African healthtech.
- Positioning: **the operating system for physical customer flow** (not a queue app).

## 4. Partnerships (distribution leverage)
- **Hospital associations** (Nigeria → Africa) — credibility + reach.
- **Medical software vendors (HMS/EMR)** — integration partners (HL7/FHIR, R10) → embedded distribution.
- **Insurance / HMOs** — wait-time + throughput data aligns with their interests.
- **Government health agencies** — public hospitals (longer cycle; later) and policy alignment.

## 5. Analytics (the metrics we run the business on)
| Metric | Why |
|--------|-----|
| **Hours Returned** (Today / Month / Lifetime) | the mission, the headline |
| Average Wait Saved | core value proof |
| Flow Score (per org) | customer health |
| Customer Retention | do hospitals keep using it |
| Organization Retention / logo churn | durability |
| **NPS** | advocacy |
| Expansion Revenue (more branches/seats) | net-revenue retention |

## 6. The metric, everywhere — **Hours Returned**
A first-class KPI surfaced on every dashboard and asset:
```
Hours Returned
  Today:                41h
  This Month:        1,238h
  Since joining:    28,412h
```
Implemented in-product on the Manager dashboard (`get_hours_returned` RPC). It keeps staff, managers, sales, and the team aligned on the one thing that matters: **time given back to people.**

> Commercialization success = paying hospitals retained + Hours Returned compounding across the customer base.
