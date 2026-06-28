# Queue.ai — Design Philosophy & System

**Version:** 1.1 (for approval)
**Phase:** 3a (precedes 3b Wireframes)
**Mandate:** Design as if **Apple, Stripe, Linear, Uber, and Google Maps** built a Customer-Flow OS together. **Do not design around queues. Design around removing decisions.**

> This document is the constitution every wireframe and UI decision is judged against. If a screen doesn't answer the Three Core Questions *immediately* — and remove or guide the decision — it fails review.

---

## Law #0 — Time is the Product (immutable; above all other laws)

> # Queue.ai is not selling software. It is selling time.
> ## Its true product is giving people their time back.

Every feature, screen, notification, recommendation, automation, and workflow must answer, **before it is built**:

> **"Whose time does this save, and by how much?"**

If a feature does not save measurable time for at least one actor (customer · receptionist · staff · manager · admin), it is **redesigned or removed.** **Time saved is a first-class, measured metric** across the platform — not a marketing line.

### The hierarchy of laws
```
Law #0   Time is the Product            ← WHY we exist (save time)
   └─ Supreme Principle: Remove decisions ← HOW we save it (don't make people decide)
        └─ North Star: Reduce uncertainty  ← IN SERVICE OF removing the decision
             └─ Six Questions · Decision-Removal Ladder · 10 Principles · tokens
```

### Time-saved as a first-class metric (examples per actor)
| Actor | Time-saved metric |
|-------|-------------------|
| Customer | Unnecessary waiting avoided; minutes saved by leaving at the optimal time |
| Receptionist | Customers checked in per hour; minutes saved via QR/WhatsApp self-check-in |
| Staff | Reduced idle time; reduced admin overhead |
| Manager | Bottlenecks resolved *before* they occur; faster operational decisions |
| Organization | ↑ daily throughput; ↓ abandonment; higher CSAT with fewer staff-hours |

### Mandatory Feature Evaluation (every new feature must state)
1. **The user problem** it solves.
2. **The decision it removes** (which rung on the Decision-Removal Ladder).
3. **Estimated time saved** (whose, how much).
4. **How the time saving will be measured** after deployment.

> A feature proposal without all four is incomplete and not approved. This is enforced from now on (see [01d-FEATURE-REGISTER.md](01d-FEATURE-REGISTER.md) scorecard).

---

## 0. Supreme Principle (how we obey Law #0)

> # Queue.ai removes decisions — it does not just display information.

A queue app shows you data and leaves you to figure out what it means and what to do. Queue.ai does the thinking: it interprets the situation, decides the best next move, and either **does it** or **hands the user a single obvious action**. Information is the raw material; **a removed (or guided) decision is the product.**

This subsumes "reduce uncertainty" — uncertainty is removed *in service of* removing the decision the uncertainty was blocking.

### The Decision-Removal Ladder (climb every screen up it)
Every surface should be pushed as high up this ladder as is safe:

| Rung | Behavior | Example |
|------|----------|---------|
| ❌ 0 — **Display** (avoid) | Show raw data, user decides | "Lab: 14 waiting, avg 9 min" |
| 1 — **Interpret** | Turn data into meaning | "Lab is becoming a bottleneck" |
| 2 — **Recommend** | Propose the one best action | "Move 1 technician before 11:30" |
| 3 — **One-tap act** | Make the action a single confirm | "[Apply] / [Dismiss]" |
| 4 — **Automate** (where safe + permitted) | Do it, tell the user | "Auto-opened Counter 6 · undo?" |

**Rule:** no screen may sit at rung 0. If we're only displaying, we've failed.

---

## 1. North Star: Reduce Uncertainty (in service of removing decisions)

Waiting is tolerable. **Not knowing** is not. **Deciding under uncertainty** is worst of all. Every screen collapses uncertainty into clarity *so it can remove or guide the decision.* The product makes a person — patient or manager — feel **oriented, guided, and in control**, never left wondering what to do next.

### The Three Core Questions (the distilled essence — every screen answers all three)

1. **What is happening?** (interpreted, not raw)
2. **What should I do next?** (one obvious action — the decision, removed or guided)
3. **Can I trust this recommendation?** (the Trust Engine — confidence + reasons)

The Six Questions below are the **operational expansion** of these three.

### The Six Questions (every screen answers ≥1, instantly)

| # | Question | Whose anxiety it kills | Lead pattern |
|---|----------|------------------------|--------------|
| Q1 | **Where am I in my journey?** | Customer | Journey timeline (current step lit) |
| Q2 | **What happens next?** | Customer | "Up next" preview |
| Q3 | **How long will it take?** | Customer + Manager | ETA with confidence band |
| Q3b | **Can I trust this estimate?** | Customer + Manager | **Trust Engine** — confidence % + reasons (F11) |
| Q4 | **What should I do now?** | Everyone | Single primary action ("Next Best Action") |
| Q5 | **Is there a faster option?** | Customer | Alternatives surfaced proactively |
| Q6 | **What changed since I last looked?** | Everyone | Live diff / "what's new" highlight |

**Design test (two parts):**
1. Cover everything but the top third — the user must already know *what is happening* and *what to do next*.
2. Ask: "what decision does this screen remove or guide?" If the honest answer is "none — it just shows data," it's at rung 0 and must be redesigned.

---

## 2. Brand Personality (from the five influences)

| Influence | What we take |
|-----------|--------------|
| **Apple** | Calm, generous whitespace, typographic hierarchy, restraint, one obvious action |
| **Stripe** | Trustworthy precision, enterprise polish, dense data made legible, beautiful empty states |
| **Linear** | Speed, keyboard-first, crisp motion, opinionated minimalism, zero chrome |
| **Uber** | Real-time status, "your thing is happening now," map-anchored confidence, ETA as hero |
| **Google Maps** | Dynamic re-routing, confidence over false precision, "leave by," alternatives |

**Resulting voice:** *Calm. Intelligent. Predictive. Trustworthy.* Never cluttered. Never ticket-centric. Never alarmist.

---

## 3. The Ten Design Principles

1. **Remove the decision, don't just inform it.** Climb every screen up the Decision-Removal Ladder (§0). Lead with the answer and the action, not the raw number. **Guided experiences replace passive dashboards** wherever possible.
2. **One primary action per screen.** Everything else is secondary/tertiary. The system *recommends the next move* (Next Best Action), it doesn't just display state. **Never leave the user wondering what to do next.**
3. **Proactive, not reactive.** The UI tells you before you ask — pushes the change, surfaces the faster option, warns of the delay.
4. **Honest about confidence.** Always ranges + confidence, never false precision (R4). A wide band shown calmly beats a fake exact time.
5. **Calm by default, loud only when it matters.** Color and motion are reserved for state changes that require attention. Steady state is quiet.
6. **Glanceable for operators.** A manager spots the bottleneck, the overloaded staffer, the idle resource in **<3 seconds** — color + position do the work, not reading.
7. **Show the delta (Q6).** Anything that changed since last look is gently highlighted; nothing forces a re-read of the whole screen.
8. **Progressive disclosure.** Surface the essential; reveal depth on demand. No wall of metrics.
9. **Accessible & inclusive (WCAG 2.1 AA).** Works one-handed, in sunlight, on a cheap Android, for low-literacy and low-vision users. Never rely on color alone.
10. **Trust through restraint.** Premium = what we leave out. Hospitals, banks, airports must feel they can trust it.

---

## 4. Anti-Patterns (explicitly banned)

- ❌ "You are number 18" as the hero (number-centric).
- ❌ Dashboards that are a grid of equal-weight metrics with no narrative.
- ❌ Exact promised times ("Served at 2:40 PM").
- ❌ Playful, colorful, gamified UI; emoji-as-decoration; gradients-for-flair.
- ❌ Red everywhere / constant alerts (alarm fatigue).
- ❌ Forcing the user to hunt for "what do I do now."
- ❌ **Passive dashboards** that display metrics without interpreting them or recommending an action (rung 0).
- ❌ High cognitive load — making the user synthesize multiple numbers to reach a conclusion the system could have reached for them.
- ❌ Patient names on public screens (R3).

---

## 5. Visual Language (tokens — to be finalized as code in build)

### 5.1 Typography
- **Type family:** a clean grotesque/geometric sans (e.g. Inter / Geist / SF-like). One family, three weights (Regular / Medium / Semibold).
- **Scale (rem):** Display 2.5 · H1 2.0 · H2 1.5 · H3 1.25 · Body 1.0 · Caption 0.875 · Micro 0.75. Generous line-height (1.5 body).
- **Numbers:** tabular figures for all metrics/ETAs so they don't jitter as they update.
- **Hierarchy rule:** the answer is the biggest thing on screen; labels are quiet.

### 5.2 Color (semantic, restrained)
Calm neutral foundation; color = meaning, not decoration. Single brand accent for primary actions.

| Token | Use | Note |
|-------|-----|------|
| `neutral-0..900` | Backgrounds, text, surfaces | Near-white canvas, soft elevation |
| `accent` | Primary action, "you" indicator | One brand color, used sparingly |
| `status-calm` (green) | Free / on-track / healthy | Q-status |
| `status-busy` (amber) | Busy / watch / approaching | Q-status |
| `status-delayed` (red) | Delayed / bottleneck / action-needed | Used rarely → stays meaningful |
| `status-info` (blue) | Neutral information / changed | Q6 "what changed" |

- **Contrast:** all text ≥ AA. **Never color-only** — pair with icon/label/shape (color-blind + sunlight).
- **Dark mode** first-class (customer app, wards, night shifts).

### 5.3 Space & Shape
- **8px spacing grid**; generous whitespace (Apple-calm).
- **Soft rounded corners** (cards ~12–16px, controls ~8px).
- **Elevation** via subtle shadow/borders, not heavy drop-shadows. Flat-calm, not skeuomorphic.

### 5.4 Motion
- **Purposeful, fast, subtle.** 150–250ms ease-out for transitions.
- Motion communicates **change and continuity** (a ticket advancing, an ETA updating) — never decorative.
- Live numbers **count/transition** rather than snap, so updates feel trustworthy not jumpy.
- **Respect `prefers-reduced-motion`.**

### 5.5 Iconography
- Single line-icon set, consistent stroke. Functional only. Status always icon **+** color **+** label.

---

## 6. Signature Components (the building blocks of every screen)

| Component | Answers | Description |
|-----------|---------|-------------|
| **Journey Timeline** | Q1, Q2 | Horizontal/vertical stepper: ✔ done · ⏳ current (lit) · ○ upcoming. Always shows where you are + what's next (F4). |
| **Trust Engine** (was ETA Pill) | Q3, Q3b | ETA range + confidence % + **the reasons** (F11). "~22 min · 92% · queue stable, all doctors available." Band widens + reasons explain when confidence drops. The honesty differentiator. |
| **Next Best Action card** | Q4 | The single recommended move, big and obvious ("Proceed to Room 3", "Open Counter 6"). |
| **Faster-Option banner** | Q5 | Appears only when a better choice exists ("UBA Ikeja: 5 min vs here 48 min"). |
| **Live Change chip** | Q6 | Gentle highlight on anything new since last view ("+12 min", "moved up 3"). |
| **Status Tile / Digital Twin cell** | operator Q's | Department/room cell: name + waiting count + calm/busy/delayed. Glanceable grid (F3). |
| **Confidence Band** | Q3 | Visual range, widening for distant predictions. |
| **Quiet Metric** | manager | Label small, value large, delta vs prior shown subtly. |

---

## 7. Surface-by-Surface Application

### 7.1 Customer App — *"Your visit, like a flight tracker"*
Hero = **Journey Timeline + Trust Engine + Next Best Action**, the way Uber/Maps make the trip the hero. Below the fold: details on demand. The faster-option banner and live-change chips do the proactive work. Calm, single-column, one-handed, dark-mode, offline-aware.

### 7.2 Receptionist — *"Fast, forgiving, never blocks the desk"*
Add-walk-in in <3 taps; the live queue reads as a calm list ordered by acuity then arrival; offline state is explicit and trusted; Next Best Action = "Call next" is always one tap. Search is instant.

### 7.3 Staff — *"What's next, nothing else"*
Almost zero chrome (Linear-minimal). One card: the current/next patient + one primary action (Call / Done / Transfer). Status changes animate so completion feels real.

### 7.4 Manager / Org Dashboard — *"Bottlenecks in 3 seconds"*
**Digital Twin status board** is the hero (F3): a glanceable grid where color + position reveal the overloaded staffer, the idle room, the delayed department instantly. Top-left: the **Flow Score** (one number + delta, F12). Persistent: **Predictive Operations** warnings — "in ~47 min Lab overloads → move 1 tech [Apply]" (F13). Below: quiet metrics with deltas, then **grounded Flow Intelligence insights with a Next Best Action** (sources shown — R7/F8). No equal-weight metric soup.

### 7.5 Admin / Flow Builder — *"Calm, powerful, no-code"* (F1)
Stripe-grade configuration: clean forms + a simple flow canvas (stages as nodes). Powerful but never intimidating; templates first, blank canvas second.

### 7.6 Public Display Screen — *"Airport board, privacy-safe"*
Big, legible, ticket-numbers-only (R3), calm color states, "now serving / coming up." Readable across a room.

---

## 8. Accessibility & Context-of-Use (Nigeria-grounded)
- One-handed reach; large tap targets (≥44px).
- Sunlight-legible contrast; works on low-end Android + slow networks (skeletons, not spinners-of-doom).
- Low-literacy support: icons + plain language + (future) local-language strings.
- Offline states are designed, not error screens (R5).
- `prefers-reduced-motion`, screen-reader labels, focus-visible, keyboard nav (Linear-style power for operators).

---

## 9. How wireframes (3b) will be judged
Each wireframe must annotate: (a) **which of the Three Core / Six Questions it answers and how**, (b) its **single primary action**, (c) the **rung on the Decision-Removal Ladder** it reaches (and why not higher), and (d) its **calm vs. attention** states. Anything sitting at rung 0, or failing the "cover the bottom two-thirds" test, gets sent back.

---

## Approval
> ✅ **Approve 3a** to proceed to **3b — Wireframes** (built against this constitution; default format: rich markdown low-fi with ASCII layouts).
> Or refine the philosophy/tokens first.
