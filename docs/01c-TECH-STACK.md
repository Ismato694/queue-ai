# Queue.ai — Technology Stack Recommendation

**Version:** 1.0 (recommendation; **locked at Phase 9**)
**Phase:** 1.5
**Context:** Nigeria-first, Africa→global scalable, NDPR/HIPAA-aligned, real-time, AI-powered, fast to PMF.

> This is a *recommendation with rationale and alternatives*, as requested. Nothing here is built yet. Final lock happens at Phase 9 after architecture (Phase 6) is approved. Selection criteria, in priority order for an early-stage product: **developer velocity, real-time fitness, AI integration, scalability runway, hiring pool, operational simplicity, cost.**

---

## 0. TL;DR Stack

| Layer | Choice | One-line why |
|-------|--------|--------------|
| Language (full stack) | **TypeScript** end-to-end | One language, shared types client↔server, huge Nigerian/global hiring pool |
| Frontend (web) | **Next.js (React) + Tailwind + shadcn/ui + Radix** | The Stripe/Linear/Notion aesthetic is literally this stack; SSR + PWA + offline |
| Mobile (fast-follow) | **React Native (Expo)** | Reuse React skills + TS types; one team |
| Backend API | **NestJS (Node/TS)** | Structured, batteries-included, shares types with frontend; fast to build |
| Real-time | **Socket.IO + Redis adapter** (→ Centrifugo/Ably at scale) | Branch-sharded pub/sub, polling fallback for poor networks |
| Primary DB | **PostgreSQL + PostGIS** | Relational integrity for queues, geofencing, RLS multi-tenancy |
| Cache / queues / fan-out | **Redis** | Pub/sub, rate limits, hot queue state, BullMQ jobs |
| Background jobs | **BullMQ** (Redis) | ETA recompute, notifications, no-show sweeps |
| AI assistant + reports | **Claude (Anthropic)** — `claude-sonnet-4-6` default | Grounded RAG, tool use, structured outputs; tiered with Opus/Haiku |
| Embeddings / RAG store | **pgvector** (in Postgres) | No extra infra; semantic search over org data/docs |
| ML predictions (v2) | **Python service** (gradient-boosted models) | Start heuristic in TS; graduate no-show/demand to Python |
| Auth + multi-tenant | **Clerk** (or Supabase Auth) + app-level RBAC | Fast, secure, org/role support out of the box |
| Notifications | **Termii / Africa's Talking** (SMS+WhatsApp), **Resend** (email), Web Push/FCM | Africa-native deliverability & pricing |
| Maps / ETA / traffic | **Google Maps Platform** + PostGIS | Geocoding, traffic-aware travel time, geofence math |
| Hosting | **AWS, `af-south-1` (Cape Town)** region | Closest AWS region to Nigeria; NDPR data-residency posture |
| Compute | **Containers on AWS ECS Fargate** (→ EKS at scale) | Simple now, Kubernetes runway later |
| Observability | **Sentry + OpenTelemetry + Grafana/Prometheus** (or Axiom) | Errors, traces, metrics from day one |
| CI/CD + IaC | **GitHub Actions + Terraform** | Standard, reproducible infra |

---

## 1. Language: TypeScript everywhere

**Why:** One language across web, mobile, and backend means shared domain types (a `Ticket` type defined once), one hiring pool, and maximum velocity for a small team racing to PMF. Nigeria has a deep JS/TS talent pool.

**Alternatives considered:**
- **Go backend** — superior raw performance/concurrency for the real-time layer, but slower to build and a smaller local hiring pool. *Verdict: reserve Go for a dedicated real-time/edge service if/when the Node layer is proven a bottleneck — not for MVP.*
- **Python backend (Django/FastAPI)** — great for AI/ML, but splits the type story and the team. *Verdict: use Python only for the ML prediction service, not the core API.*
- **Elixir/Phoenix** — genuinely excellent for real-time (LiveView, presence, millions of connections), arguably the best technical fit for "live queues." *Verdict: strong runner-up; rejected for MVP on hiring-pool and velocity grounds, but noted as the alternative if real-time scale becomes the dominant constraint.*

---

## 2. Frontend: Next.js + Tailwind + shadcn/ui

**Why:** The requested look — clean, minimalist, Stripe/Linear/Notion/Apple, generous whitespace, soft rounded corners, subtle animation — is most directly achieved with **Tailwind + shadcn/ui (Radix primitives)**, the exact toolchain those reference products' clones use. Next.js gives SSR for fast first paint on slow Nigerian networks, **PWA + offline support** (critical for reception desks per RED-TEAM CTO-2), and excellent accessibility via Radix.

- **State/data:** TanStack Query for server state; minimal client state.
- **Animation:** Framer Motion (subtle micro-interactions only).
- **Accessibility:** Radix is accessible-by-default → WCAG 2.1 AA target.

**Alternatives:** Vue/Nuxt (smaller ecosystem for this aesthetic), SvelteKit (great DX, smaller hiring pool), Angular (heavier, enterprise-y but slower velocity). *Verdict: Next.js wins on ecosystem + talent + the exact design language requested.*

---

## 3. Mobile (fast-follow): React Native / Expo

Reuse React + TypeScript skills and shared domain types; Expo speeds delivery. Web app ships first (PRD MVP), native follows. *Alternative: Flutter — excellent UI but a separate language (Dart) and team; rejected for code/skill reuse.*

---

## 4. Backend: NestJS

**Why:** NestJS gives opinionated structure (modules, DI, guards, pipes) that keeps an ambitious multi-tenant codebase maintainable, while staying in TypeScript for shared types. Strong fit for REST + WebSocket gateways + background workers in one framework.

**Alternatives:**
- **Plain Express/Fastify** — lighter but less structure for a large domain. *Fastify is a fine choice if we want minimalism; NestJS preferred for team scalability.*
- **Django/Rails** — batteries-included and fast, but breaks the TS type story.
*Verdict: NestJS for structure + TS continuity.*

---

## 5. Real-time: Socket.IO + Redis (with polling fallback)

**Why:** Live queues need push. Socket.IO has **automatic fallback to long-polling** on bad networks — a direct fit for Nigerian connectivity (RED-TEAM CTO-3). Redis adapter enables horizontal scaling; clients subscribe per `branch_id` so fan-out shards naturally.

**Scale path:** If connection counts or fan-out outgrow Node, move to **Centrifugo** (self-host) or **Ably/Pusher** (managed). The Elixir/Phoenix option (§1) is the bigger-hammer alternative.

---

## 6. Database: PostgreSQL + PostGIS (+ pgvector)

**Why:** Queues, tickets, journeys, appointments, and billing are **relational and integrity-critical** — Postgres is the right default. **PostGIS** handles geofencing/distance math natively. **Row-Level Security** gives defense-in-depth multi-tenant isolation (RED-TEAM CTO-7). **pgvector** adds embeddings for the AI assistant's RAG without new infra.

- **Time-series analytics:** add **TimescaleDB** extension (or ClickHouse later) for high-volume event/analytics queries.
- **Multi-tenancy:** `tenant_id` on every row + RLS; revisit schema-per-tenant only for large enterprise customers.

**Alternatives:** MongoDB (loses relational integrity for inherently relational data — rejected for the core), DynamoDB (operationally rigid for this access pattern). *Verdict: Postgres, decisively.*

---

## 7. AI Layer: Claude (Anthropic)

The AI assistant ("Why is today slower?", "Predict tomorrow", "Generate today's report") and auto-reporting are built on **Claude**, which is strong at **tool use, grounded RAG, and structured outputs** — exactly what a read-only, must-not-hallucinate operations assistant needs (RED-TEAM CTO-6).

**Model tiering (current model IDs + pricing, per 1M tokens):**

| Use case | Model | ID | Input | Output | Context |
|----------|-------|-----|-------|--------|---------|
| Default assistant, report generation, RAG | **Sonnet 4.6** | `claude-sonnet-4-6` | $3 | $15 | 1M |
| Hardest reasoning / deep "why" analysis | **Opus 4.8** | `claude-opus-4-8` | $5 | $25 | 1M |
| Cheap, high-volume classification (WhatsApp intent, no-show labeling) | **Haiku 4.5** | `claude-haiku-4-5` | $1 | $5 | 200K |

**Recommendation:** **Sonnet 4.6 as the workhorse** — best balance of intelligence, cost, and 1M context for grounded RAG over org data; escalate to Opus 4.8 only for the hardest analytical questions; use Haiku 4.5 for cheap classification. Use **structured outputs** (`output_config.format`) for any number the assistant cites, and ground every answer in queried metrics + pgvector retrieval rather than free generation. SDK: `@anthropic-ai/sdk` (TypeScript), fits the stack natively.

**ML predictions** (no-show, demand forecasting) are a **separate concern from the LLM**: start with **heuristics in TypeScript** (averages, time-of-day, day-of-week), then graduate to a small **Python service** with gradient-boosted models (scikit-learn/XGBoost) once real data accrues (RED-TEAM CTO-4).

---

## 8. Auth & Multi-Tenancy: Clerk (or Supabase Auth) + RBAC

**Why:** Don't hand-roll auth. **Clerk** offers organizations, roles, MFA, and session management out of the box — fast and secure for the multi-org model. Application-level **RBAC** maps to the personas (Super Admin → Admin → Manager → Receptionist → Staff → Customer). NDPR/HIPAA-aligned practices layered on top (Phase 8).

**Alternatives:** Supabase Auth (great if we also want its Postgres/realtime/storage bundle — a viable all-in-one for MVP speed), Auth0 (capable, pricier), self-host with Lucia/NextAuth (more control, more work). *Verdict: managed provider for MVP; Supabase is the strongest "do more with less infra" alternative and worth a serious look at Phase 9.*

---

## 9. Notifications: Africa-native first

| Channel | Provider | Why |
|---------|----------|-----|
| SMS | **Termii** or **Africa's Talking** | Better Nigerian deliverability, sender-ID/DND handling, local pricing vs Twilio |
| WhatsApp | **Termii / 360dialog / Meta Cloud API** | WhatsApp Business; pre-approved templates |
| Email | **Resend** (or Postmark) | Clean DX, good deliverability |
| Push | **Web Push + FCM** | Free; primary channel to control cost |
| Voice / display screens | Fast-follow | Africa's Talking voice; signage as web client |

**Cost-aware routing** (RED-TEAM CTO-5/INV-4): push-first; SMS only for high-value events; per-org budgets and metering.

---

## 10. Geo / Maps: Google Maps Platform + PostGIS

Google Maps for **traffic-aware travel time** (the "leave by" recommendation) and geocoding; **PostGIS** for geofence containment and distance math server-side. *Alternative: Mapbox — strong and often cheaper; viable if Google costs bite.*

---

## 11. Hosting, Infra, Observability

- **Cloud:** **AWS, region `af-south-1` (Cape Town)** — the nearest AWS region to Nigeria, supporting an NDPR-friendly data-residency story and lower latency than EU/US. (NDPR doesn't strictly mandate local hosting but constrains cross-border transfer — keeping data in-region is the safer posture.)
- **Compute:** Containers (Docker) on **ECS Fargate** for MVP simplicity; **EKS (Kubernetes)** runway when scale demands. *Alternative for even faster MVP: Render/Railway, then migrate.*
- **Storage:** S3 (documents, exports, QR assets).
- **CDN:** CloudFront.
- **Observability:** **Sentry** (errors), **OpenTelemetry** traces, **Prometheus/Grafana** metrics (or managed **Axiom/Datadog**). Real-time latency (<2s p95) and uptime (99.9%) from the PRD are tracked here.
- **CI/CD:** GitHub Actions. **IaC:** Terraform.

---

## 12. Compliance-by-architecture (NDPR now; HIPAA/GDPR/POPIA ready)

- Encryption in transit (TLS) and at rest (KMS).
- Tenant isolation via `tenant_id` + Postgres RLS.
- Immutable **audit logs** for all sensitive actions (priority overrides, PHI access).
- **Data residency** via `af-south-1`; data-subject rights (export/delete) wired into the data model.
- PII minimization on public displays (RED-TEAM ADM-3).
- Build correct security from day one **without** premature enterprise-certification cost (no full HIPAA cert for the pilot — aligned practices only). Detailed in **Phase 8**.

---

## 13. Open stack decisions to confirm at Phase 9

1. **Supabase as an all-in-one** (Postgres + Auth + Realtime + Storage) vs. assembled best-of-breed (NestJS + Clerk + Socket.IO)? Supabase could compress MVP time significantly — worth a head-to-head.
2. **ECS Fargate vs. Render/Railway** for the very first deploy (speed vs. control).
3. **Phoenix/Elixir** reconsidered *only if* real-time scale becomes the dominant early constraint.
4. SMS/WhatsApp provider final pick after a deliverability + pricing test in Nigeria.
