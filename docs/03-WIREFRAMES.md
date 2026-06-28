# Queue.ai — Wireframes & Information Architecture

**Version:** 1.0 (for approval)
**Phase:** 3b
**Built against:** [03a-DESIGN-PHILOSOPHY.md](03a-DESIGN-PHILOSOPHY.md) (Law #0, Decision-Removal Ladder, Six Questions), [02-USER-FLOWS.md](02-USER-FLOWS.md), [01d-FEATURE-REGISTER.md](01d-FEATURE-REGISTER.md).
**Format:** low-fi ASCII layouts. Every screen carries an **annotation block**:

> 🎭 **Actor** · ✂️ **Decision removed** · ⏱ **Time saved** · ▶ **Primary action** · 🪜 **Ladder rung** · 📊 **Success metric** · ❓ **Q's answered**

Fidelity is intentionally low (layout + hierarchy + behavior), not pixel-perfect — colors/type come from 03a tokens at build.

---

## Information Architecture (surfaces map)

```
Queue.ai
├── Customer (PWA / QR / WhatsApp / SMS)
│   ├── C1 Join (QR landing / web)
│   ├── C2 Live Visit  ← the hero
│   ├── C3 Activation ("I'm on my way")
│   ├── C4 Called ("Proceed to…")
│   └── C5 Feedback
├── Receptionist (offline-capable PWA)
│   ├── R1 Reception board
│   └── R2 Add walk-in (<3 taps)
├── Staff (1-tap)
│   └── S1 What's next
├── Manager (Org dashboard)
│   └── M1 Flow Overview (Digital Twin + Flow Score + Predictive Ops)
├── Admin
│   └── A1 Flow Builder (F1)
└── Public
    └── P1 Display screen (privacy-safe)
```

---

# CUSTOMER

## C1 — Join (QR landing / web)
> 🎭 Customer · ✂️ "Which line do I stand in / which form do I fill?" · ⏱ Customer: eliminates physical queueing just to register · ▶ **Get my ticket** · 🪜 Rung 2 (recommends nearest branch + likely service) · 📊 % self-joins (target ≥50%); time-to-ticket · ❓ Q4, Q5

```
┌─────────────────────────────────────┐
│  Queue.ai            Lagoon Hospital │
│                                      │
│  Get seen faster. Skip the line.     │
│                                      │
│  Service                             │
│  ┌─────────────────────────────────┐│
│  │ General Consultation         ▾  ││  ← pre-selected if known from QR
│  └─────────────────────────────────┘│
│  Name        [___________________]   │
│  Phone       [___________________]   │
│  ☐ I'm here now   ◉ I'll arrive later│  ← decides ACTIVE vs PRE_QUEUE
│                                      │
│  ⓘ You'll get live updates by SMS    │
│                                      │
│  ┌─────────────────────────────────┐│
│  │        ▶  Get my ticket         ││  ← single primary action
│  └─────────────────────────────────┘│
└─────────────────────────────────────┘
```
Notes: minimal fields (Law #0 — even sign-up saves time). "Arrive later" → PRE_QUEUE. Calm; no queue numbers shown yet.

---

## C2 — Live Visit  ★ THE HERO SCREEN
> 🎭 Customer · ✂️ "Should I keep waiting? When do I leave? Is it worth it?" · ⏱ Customer: avoids unnecessary waiting + wasted trips; leave-at-optimal-time · ▶ **(context: "I'm on my way" / "Navigate" / none)** · 🪜 Rung 2–3 (tells you the next move, offers faster option) · 📊 Wait reduction −30%; abandonment ↓; CSAT · ❓ Q1 Q2 Q3 Q3b Q5 Q6

```
┌─────────────────────────────────────┐
│ Lagoon Hospital · Cardiology   ⟳ live│
│                                      │
│   ⏱  You'll be seen in               │
│      ~22 min            (89% sure)   │  ← Trust Engine: range + confidence
│      ▰▰▰▰▰▰▰▰▱▱                       │
│      Why: queue stable · all doctors │  ← reasons (F11)
│           available                  │
│ ─────────────────────────────────── │
│  Your journey                        │  ← Journey Timeline (F4)
│   ✔ Reception                        │
│   ⏳ Consultation  ← you are here     │
│   ○ Laboratory                       │
│   ○ Review                           │
│   ○ Pharmacy                         │
│   ○ Cashier                          │
│   Total visit est. ~1h 10m           │
│ ─────────────────────────────────── │
│  ▸ What changed: moved up 2 places   │  ← Live-Change chip (Q6)
│ ─────────────────────────────────── │
│  ┌─────────────────────────────────┐│
│  │   ▶  I'm on my way (leave by 1:55)││ ← Next Best Action (context-aware)
│  └─────────────────────────────────┘│
│  ⚡ Faster nearby: Lekki branch ~8min││  ← Faster-Option (F5/Q5), only if true
└─────────────────────────────────────┘
```
States: **calm** (steady ETA), **attention** (confidence drops → band widens, reason appears, ✉ sent): "Now ~22–35 min · doctor delayed." Never a hard promise (R4). Numbers transition, don't snap.

---

## C3 — Activation ("I'm on my way")
> 🎭 Customer · ✂️ "Do I lose my place if I'm not there yet?" · ⏱ Customer: avoids arriving-too-early dead time · ▶ **Confirm I'm leaving** · 🪜 Rung 3 (one tap converts PRE_QUEUE→ACTIVE) · 📊 activation→arrival accuracy; early-arrival idle time ↓ · ❓ Q2 Q3

```
┌─────────────────────────────────────┐
│  Leave at the right time             │
│                                      │
│   Recommended departure              │
│        1:55 PM         (in 12 min)   │
│   Drive ~18 min · traffic moderate   │  ← Maps-style, dynamic
│                                      │
│   We'll hold your place once you     │
│   confirm. If plans change, tap      │
│   "Pause" anytime.                   │
│                                      │
│  ┌─────────────────────────────────┐│
│  │     ▶  Confirm I'm leaving       ││
│  └─────────────────────────────────┘│
│        Navigate            Pause     │
└─────────────────────────────────────┘
```

---

## C4 — Called ("Proceed to…")
> 🎭 Customer · ✂️ "Where do I go now?" · ⏱ Customer + Staff: removes wandering/lookups · ▶ **I'm here** · 🪜 Rung 3 · 📊 call→present time; no-show ↓ · ❓ Q2 Q4

```
┌─────────────────────────────────────┐
│  ●  It's your turn                   │  ← attention state (loud, but calm)
│                                      │
│      Proceed to                      │
│        Room 3                        │
│      Dr. Okafor · Cardiology         │
│                                      │
│   Please arrive within  ⏳ 4:32       │  ← grace window (R4)
│                                      │
│  ┌─────────────────────────────────┐│
│  │          ▶  I'm here             ││
│  └─────────────────────────────────┘│
│        Need more time?               │  ← within grace → requeue, not no-show
└─────────────────────────────────────┘
```

---

## C5 — Feedback
> 🎭 Customer · ✂️ "Was that good? (and skip a survey)" · ⏱ Customer: one-tap, no form · ▶ **Submit** · 🪜 Rung 3 · 📊 CSAT capture rate; CSAT score · ❓ Q1(done)

```
┌─────────────────────────────────────┐
│  ✔ Visit complete · 58 min total     │
│     ⏱ You saved ~35 min vs usual     │  ← Law #0 made visible to the user
│                                      │
│  How was it?                         │
│     😞    😐    🙂    😀    🤩         │
│  ┌─────────────────────────────────┐│
│  │             ▶  Submit            ││
│  └─────────────────────────────────┘│
│     Add a comment (optional)         │
└─────────────────────────────────────┘
```

---

# RECEPTIONIST

## R1 — Reception Board (offline-capable)
> 🎭 Receptionist · ✂️ "Who do I call next? Who's overdue?" · ⏱ Receptionist: removes manual queue tracking; Customer: faster calls · ▶ **Call next** · 🪜 Rung 2–3 (orders by acuity then arrival, recommends next) · 📊 customers/hour; time-to-add; call latency · ❓ Q1 Q4 Q6

```
┌──────────────────────────────────────────────────────────┐
│ Reception · Lagoon Hospital      ⚠ Offline — syncing 3 ⟳  │ ← offline state (R5)
│ ┌──────────────┐                          [ + Add walk-in ]│
│ │ ▶ CALL NEXT  │  Next: #A24 Mrs Bello (priority)         │ ← primary action
│ └──────────────┘                                          │
│ ── Waiting (ordered: acuity ▸ arrival) ───────────────────│
│  #A24  Mrs Bello      Cardiology   🔴 Priority   12m       │
│  #A25  J. Eze         General      ⚪ Normal      08m       │
│  #A26  Family (3) 👪  General      ⚪ Normal      05m       │ ← group (F7)
│  #A22  K. Musa        Lab          🟠 waiting>SLA 31m  ⚠   │ ← attention
│ ───────────────────────────────────────────────────────── │
│  Call  ·  Transfer  ·  Priority  ·  Cancel  ·  🔍 Search   │
└──────────────────────────────────────────────────────────┘
```
Offline: actions queue locally, badge shows pending sync; conflicts flagged (E1). Calm list; only the SLA-breach row is amber.

---

## R2 — Add Walk-in (<3 taps)
> 🎭 Receptionist · ✂️ "How do I register this person fast?" · ⏱ Receptionist: <3 taps vs paper/whiteboard · ▶ **Add to queue** · 🪜 Rung 3 · 📊 time-to-add (<15s target) · ❓ Q4

```
┌─────────────────────────────────────┐
│  Add walk-in                    ✕    │
│  Service  [ General Consultation ▾ ] │  tap 1
│  Name     [____________]  Phone [__] │
│  Acuity   ( Normal )( Priority )( 🚨 )│  tap 2 (default Normal)
│  ┌─────────────────────────────────┐│
│  │        ▶  Add to queue           ││  tap 3 → SMS ticket auto-sent
│  └─────────────────────────────────┘│
└─────────────────────────────────────┘
```

---

# STAFF

## S1 — What's Next (1-tap)
> 🎭 Staff (Doctor/Tech/etc.) · ✂️ "Who's next / what do I do?" · ⏱ Staff: removes admin overhead, reduces idle gaps · ▶ **Call next → Complete** · 🪜 Rung 3 · 📊 idle time ↓; throughput/hr ↑ · ❓ Q1 Q2 Q4

```
┌─────────────────────────────────────┐
│ Dr. Okafor · Room 3        ● Online  │
│                                      │
│  NOW SERVING                         │
│   #A24  Mrs Bello · 54                │
│   Cardiology · arrived 1:42          │
│   Stage 2 of 6 · next: Laboratory    │  ← shows downstream (pathway)
│                                      │
│  ┌──────────────┐ ┌────────────────┐│
│  │  ✔ Complete  │ │  → Transfer    ││  ← one tap; Complete auto-advances
│  └──────────────┘ └────────────────┘│
│   Delay        Break / Unavailable   │  ← Break ✉ notifies waiting (OPS-3)
│ ─────────────────────────────────── │
│  Up next: #A27 (8 waiting · ~1h)     │  ← glance only, no clutter
└─────────────────────────────────────┘
```
Almost no chrome (Linear-minimal). Complete animates the advance so it feels real.

---

# MANAGER

## M1 — Flow Overview (Digital Twin + Flow Score + Predictive Ops)
> 🎭 Manager · ✂️ "Is today OK? Where's the problem? What do I do about it?" · ⏱ Manager: spot bottleneck in <3s + act before it forms · ▶ **Apply recommendation** · 🪜 Rung 3–4 (recommends, one-tap apply; auto where permitted) · 📊 time-to-spot-bottleneck; pre-empted delays; Flow Score trend · ❓ all six

```
┌────────────────────────────────────────────────────────────┐
│ Lagoon Hospital · Today          Flow Score  94 ▲+8 ⭐⭐⭐⭐⭐ │ ← F12, hero number
│                                                              │
│ ⚠ PREDICTED: Laboratory overloaded in ~47 min               │ ← Predictive Ops (F13)
│    Recommended: move 1 technician before 11:30               │
│    [ ▶ Apply ]   [ Dismiss ]   why? ▾                        │ ← rung 3 action
│ ── Digital Twin (live) ─────────────────────────────────────│ ← F3 status board
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐        │
│  │Reception │ │Consult 1 │ │Consult 2 │ │   Lab    │        │
│  │ 🟢 12 wait│ │ 🟡 busy  │ │ 🔴 delay │ │ 🟠 4·SLA │        │ ← color+label, glance
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘        │
│  ┌──────────┐ ┌──────────┐                                  │
│  │ Pharmacy │ │ Cashier  │                                  │
│  │ 🟢 free  │ │ 🟡 4 wait│                                  │
│  └──────────┘ └──────────┘                                  │
│ ── Quiet metrics ───────────────────────────────────────────│
│  Avg wait 14m ▼-3   No-show 6% ▼-2   Time saved today 41h ▲ │ ← Law #0 metric
│ ── 🧠 Flow Intelligence ─────────────────────────────────────│
│  "Reception is excellent today. Lab is the constraint —      │ ← grounded (R7)
│   opening a 2nd counter 10–12 cuts avg wait ~22%."  sources ▾│
│  Ask Flow Intelligence:  [ Why is today slower?_________ ]   │
└────────────────────────────────────────────────────────────┘
```
The screen never sits at rung 0: the twin is interpreted (colors), the warning is predictive, the insight carries an action. Red used only where action is needed.

---

# ADMIN

## A1 — Flow Builder (F1, the moat)
> 🎭 Admin · ✂️ "How do we encode our workflow without engineers?" · ⏱ Admin: hours→minutes of setup; Org: fewer mis-routes · ▶ **Save & publish** · 🪜 Rung 2 (templates recommend a starting flow) · 📊 setup time; mis-route rate · ❓ Q1 Q2

```
┌────────────────────────────────────────────────────────────┐
│ Flow Builder · "Outpatient Visit"      Template: Hospital ▾ │
│                                              [ Save & publish]│
│  Stages (drag to reorder)                                    │
│   ┌───────────┐   ┌───────────┐   ┌───────────┐             │
│   │1 Reception│ → │2 Consult  │ → │3 Lab      │ → …          │
│   └───────────┘   └───────────┘   └───────────┘             │
│        ＋ add stage        ⑂ add branch (e.g. skip Lab)      │
│ ── Selected: "2 Consult" ───────────────────────────────────│
│   Department  [ Cardiology ▾ ]                               │
│   Avg duration (seed) [ 12 ] min   ← cold-start (CTO-4)      │
│   Rules: ☑ requires triage  ☐ appointment-only              │
│ ── Preview ────────────────────────────────────────────────│
│   Patient journey: Reception→Consult→Lab→Review→Pharmacy→Pay │
└────────────────────────────────────────────────────────────┘
```
Templates per industry first (Hospital/Bank/Passport), blank canvas second. Stripe-grade calm; powerful but not intimidating.

---

# PUBLIC

## P1 — Display Screen (privacy-safe)
> 🎭 Customer (ambient) · ✂️ "Is it my turn? where do I look?" · ⏱ Customer: removes anxious desk-checking · ▶ none (ambient) · 🪜 Rung 1 (interprets status) · 📊 desk interruptions ↓ · ❓ Q1 Q2 Q6

```
┌────────────────────────────────────────────────────────────┐
│  LAGOON HOSPITAL                              1:48 PM        │
│                                                              │
│   NOW SERVING            COMING UP                           │
│     A24  → Room 3          A25  A26  A27                     │
│     B11  → Lab             B12  B13                          │
│     C07  → Cashier         C08                               │
│                                                              │
│   Cardiology  ~20 min   ·   Lab  ~15 min   ·   Pharmacy free │
└────────────────────────────────────────────────────────────┘
```
**Numbers only, never names (R3).** Big, room-legible, calm color states.

---

## Cross-screen patterns (consistent everywhere)
- **Trust Engine** wherever a time is shown (range + confidence + reason).
- **Live-Change chips** for anything new since last view (Q6).
- **One primary action** per screen, visually dominant.
- **Offline + skeleton states** designed, not error pages (R5).
- **Color = meaning + always paired with icon/label** (accessibility, sunlight).
- **Tabular figures** so live numbers don't jitter.

## Screen → Decision-Removal Ladder summary
| Screen | Rung | Why not higher |
|--------|------|----------------|
| C2 Live Visit | 2–3 | Customer must physically move; we guide, can't act for them |
| M1 Flow Overview | 3–4 | Staffing moves can auto-apply *only* where org permits (rung 4) |
| R1 Reception | 2–3 | Calling a patient is a human judgment we recommend |
| S1 Staff | 3 | Completion is a physical act, made one tap |
| A1 Flow Builder | 2 | Config is inherently a human authoring task; templates assist |
| P1 Public | 1 | Ambient display; no actor action |

---

## Approval
> ✅ **Approve Phase 3b** to proceed to **Phase 4 — Database Design** (where the Visit/Stage/Flow/throughput/identity/consent models from these screens get schematized — the schema-shaping phase for F1–F14).
> Or request screen changes / additional screens (e.g. WhatsApp chat, appointment booking, Capacity AI detail).
