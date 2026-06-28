# Queue.ai

**An AI-powered Customer Flow Operating System** — not a queue app. It removes decisions and gives people their time back (Law #0). MVP target: Nigerian private hospitals.

📚 **Full spec lives in [`/docs`](docs/)** — start with [`docs/00-ROADMAP.md`](docs/00-ROADMAP.md). The product/design/data/API/architecture/security/business are all specified there (Phases 0–9).

---

## Monorepo layout
```
apps/web/          Next.js PWA — customer, reception, staff, manager, admin, public display
services/worker/   Node worker — ETA recompute, no-show sweep, notifications, AI jobs
packages/shared/   Shared TS types + the ticket state machine (single source of truth)
supabase/          Migrations (the DB schema = the spine) + seed (a demo hospital + care pathway)
docs/              The complete specification (Phases 0–9)
```

## Tech stack (locked — see `docs/09-MVP-SCOPE.md`)
**Supabase** (Postgres + PostGIS + pgvector + Auth + Realtime + Storage + RLS, `af-south-1`) · **Next.js** · **Node/NestJS worker** · **Claude** (Sonnet 4.6 default) · Termii/Africa's Talking · Google Maps.

---

## Getting started (Sprint S0)

### 1. Install
```bash
npm install
```

### 2. Create a Supabase project
- Region: **af-south-1 (Cape Town)** for NDPR residency.
- Install the Supabase CLI (`brew install supabase/tap/supabase`), then link:
```bash
supabase link --project-ref YOUR_REF
supabase db push          # applies supabase/migrations/*
psql "$DATABASE_URL" -f supabase/seed.sql   # loads the demo hospital + care pathway
```
> Or run a local stack with Docker: `supabase start` (applies migrations automatically), then `supabase db reset` to include the seed.

### 3. Configure env
```bash
cp .env.example apps/web/.env.local   # add NEXT_PUBLIC_SUPABASE_* (+ others as features land)
cp .env.example services/worker/.env  # add SUPABASE_SERVICE_ROLE_KEY (worker only)
```

### 4. Run
```bash
npm run dev:web      # http://localhost:3000  (status page shows env wiring)
npm run dev:worker   # http://localhost:4000/health
```

---

## What's in S0 (this sprint)
- ✅ Complete database schema as migrations (`supabase/migrations/`) — tenancy, Flow Builder, identity/consent, the **Visit/Stage pipeline**, Flow Intelligence tables, events/notifications/audit.
- ✅ **Row-Level Security** tenant isolation + privacy-safe `public_queue_view` (R3).
- ✅ Seed: a **demo medium hospital** with the canonical care pathway (F1 template).
- ✅ Shared types + the **ticket state machine** with validated transitions.
- ✅ Web + worker skeletons, env templates, CI.

**Demo (Rule #5):** with a Supabase project connected, the schema + seed give you a working tenant, branch, departments, services, staff, and a published Outpatient flow — the foundation S1 builds CRUD + Flow Builder on.

## Roadmap of build sprints
S0 Foundations → S1 Config + Flow Builder → S2 Queue Engine + Reception → S3 Real-time + Customer →
S4 Trust Engine + Staff + Display → S5 Manager + Flow Intelligence → S6 Resilience + Hardening.
(See `docs/09-MVP-SCOPE.md` §5.)

## Principles that govern every change
- **Law #0** — Time is the Product. Measure minutes saved, not lines of code.
- **Remove decisions**, don't just display (Decision-Removal Ladder; no screen at rung 0).
- **Founder Rules** (`docs/09-FOUNDER-RULES.md`) break ties: ship > perfection; optimize for the first paying hospital.
