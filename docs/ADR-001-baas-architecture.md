# ADR-001 — The MVP is a Supabase-direct (BaaS) architecture

**Status:** Accepted (documents what was built; audit finding H2)
**Date:** 2026-06-29
**Context:** Phases 5 (API) and 6 (Architecture) specced a **NestJS modular-monolith + REST `/v1` contract + Socket.IO/Redis real-time**. Phase 9 then **locked Supabase** for speed to the first paying hospital. The build followed Phase 9 — so 05/06 describe a system that wasn't built.

## Decision
The MVP architecture is **Supabase-direct**:
- **Data/API:** the Next.js client calls **Supabase PostgREST** (table reads) and **Postgres RPCs** (all mutations/business logic) directly, gated by **RLS**. There is no separate NestJS API service.
- **Business logic / queue engine:** PostgreSQL `SECURITY DEFINER` functions (atomic, un-bypassable), not a Node domain layer.
- **Real-time:** **Supabase Realtime** (`postgres_changes`), not Socket.IO/Redis. No `seq`/reconcile layer.
- **Worker:** a small Node process for notifications, the no-show sweep, and metric rollups.

## Consequences
- ✅ Far less infrastructure; shipped a working, RLS-isolated MVP fast (Founder Rule #1).
- ✅ The Phase 4 schema, security model, and event-log invariant carry over unchanged (Supabase *is* Postgres).
- ⚠️ Tight client↔schema coupling (table/RPC names in components; rows typed `any`) — audit M3.
- ⚠️ Business logic in SQL is harder to unit-test → mitigated by the DB-integration CI (audit C1).
- ⚠️ Docs 05/06 are now **target/reference designs** for if a dedicated API layer is reintroduced (e.g. heavy server-side orchestration, non-Supabase scale). They are flagged as partly superseded.

## Revisit when
We outgrow Supabase (multi-region residency, custom real-time scale, or a need for server-side orchestration the DB can't host) — at which point 05/06 become the migration target (Postgres moves to self-managed; a thin API/edge layer is added). The schema does not change.
