# Queue.ai — Founder Rules

**Version:** 1.0
**Status:** Governing operating rules for the build (Phases 9–16). Sits beneath **Law #0** ([03a](03a-DESIGN-PHILOSOPHY.md)) and applies to every sprint, backlog decision, and scope call.

> These are the founder's non-negotiable operating rules. When a decision is unclear, these break the tie. Each rule below is stated as given, with one line on how it's enforced in practice.

---

## Founder Rule #1 — Shipping beats perfection.
*In practice:* prefer a working, demonstrable slice over a polished unfinished one. Done-and-validated > elegant-and-theoretical. Ties to the demonstrable-every-sprint rule (#5).

---

## Founder Rule #2 — Every feature must answer three questions.

1. **Does this save measurable time?**
2. **Will the hospital pay for this?**
3. **Can we build it in under two weeks?**

**If not → move it to Version 2.**

*In practice:* this is the gate on the build backlog. It extends the mandatory 4-field feature evaluation ([01d](01d-FEATURE-REGISTER.md): problem · decision removed · time saved · how measured) with a **2-week buildability** and **willingness-to-pay** test. Anything failing any of the three is tagged `V2`.

---

## Founder Rule #3 — No feature enters the MVP because it is "cool."
**Only because it solves a validated problem.**

*In practice:* every MVP feature must trace to a real problem in the flows ([02](02-USER-FLOWS.md)), red-team findings ([01b](01b-RED-TEAM.md): R1–R10), or the business case ([BUSINESS-OS](BUSINESS-OS.md)). "Cool but unvalidated" → backlog, not MVP.

---

## Founder Rule #4 — Optimize for the first paying hospital. Not one million hospitals.
*In practice:* build for the one medium Nigerian hospital pilot. Scalability hooks already exist in the schema/architecture (so we don't paint ourselves in), but we **do not** build for scale we don't have. Counters INV-3 (scope creep). One branch, live, paying, delighted — then expand.

---

## Founder Rule #5 — Every sprint ends with something demonstrable to a hospital administrator.
*In practice:* each sprint produces a clickable/usable slice an admin would recognize and react to — not internal plumbing only. Demo-ability is the definition of done at the sprint level.

---

## Founder Rule #6 — Never break the product philosophy: **Remove decisions.**
*In practice:* every screen and feature must climb the Decision-Removal Ladder ([03a](03a-DESIGN-PHILOSOPHY.md)) — interpret → recommend → one-tap → automate. Nothing ships at rung 0 (display-only). This rule protects the moat.

---

## Founder Rule #7 — Measure success by outcomes, not output.

- **Minutes saved.**
- **Waiting reduced.**
- **Throughput increased.**
- **Satisfaction improved.**

**Not by lines of code.**

*In practice:* the North-Star metric is **Total Time Saved** (Law #0); the pilot is judged on the baseline-vs-actual numbers ([BUSINESS-OS](BUSINESS-OS.md), R8), surfaced live via Flow Score / Time-Saved dashboards. Velocity and code volume are never success metrics.

---

## How these rules are applied
- **Phase 9 (MVP Scope Lock):** every candidate feature is run through Rule #2's three questions; failures → V2 list.
- **Phases 10–13 (Build):** Rule #5 gates each sprint; Rule #6 gates each screen; Rule #1 guides tradeoffs.
- **Phase 14+ (Test/Pilot):** Rule #7 defines success.

> Hierarchy reminder: **Law #0 (Time is the Product)** → **Supreme Principle (Remove decisions)** → **Founder Rules (how we operate to honor both)**.
