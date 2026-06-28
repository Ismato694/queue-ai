# Queue.ai — API Design

**Version:** 1.0 (for approval)
**Phase:** 5
**Over:** [04-DATABASE.md](04-DATABASE.md) schema · serves [02 flows](02-USER-FLOWS.md) & [03 screens](03-WIREFRAMES.md).
**Style:** REST (JSON) for request/response + **WebSocket** for live state + **outbound webhooks** for integrations. Versioned under `/v1`.

> **Resolved open questions from Phase 4:**
> - **Live-queue consistency → Postgres-authoritative, Redis as cache + pub/sub transport.** Writes commit to Postgres (source of truth) inside a transaction that also emits an `activity_event`; a post-commit publish pushes the delta to Redis → WebSocket fan-out. Reads hit the Redis hot-cache; on miss, Postgres. This keeps correctness simple (no split-brain) while staying real-time (<2s p95).
> - **Flow branching (MVP) → linear + simple conditional** (`flow_stages.branch_rules`); full DAG deferred.

---

## 1. API principles

| Concern | Decision |
|---------|----------|
| Base | `https://api.queue.ai/v1` |
| Format | JSON; `snake_case` fields; `timestamptz` ISO-8601 UTC |
| Auth | Bearer JWT (staff/admin via Clerk session) · scoped **API keys** (server-to-server) · short-lived **ticket tokens** (customer, no account) |
| Tenancy | `organization_id` from token claims → sets `app.current_org` for RLS; never client-supplied |
| Idempotency | `Idempotency-Key` header on all POSTs that mutate queue state (offline-safe, R5) |
| Pagination | cursor-based: `?limit=&cursor=` → `{data, next_cursor}` |
| Errors | RFC-9457 problem+json: `{type, title, status, detail, code, request_id}` |
| Rate limits | per-key token bucket; `429` + `Retry-After`; standard headers |
| Versioning | URL `/v1`; additive changes only; breaking → `/v2` |
| Real-time | WebSocket `/v1/realtime` (per-branch channels) — §5 |
| Concurrency | `ETag`/`If-Match` on stage mutations → reject stale offline writes (E1) |

---

## 2. Auth & roles

| Caller | Credential | Scope |
|--------|-----------|-------|
| Admin/Manager/Receptionist/Staff | Clerk JWT → role claim | RBAC by `staff.role` |
| Customer (no account) | **ticket token** (signed, ties to one `visit`) | read own visit, activate, feedback |
| Server/integration | API key (`scopes[]`) | per-scope |
| Public display | display token (branch-scoped, read-only) | `public_queue_view` only (R3) |

`POST /v1/auth/ticket-token` issues a customer token at join time (returned with the ticket). Role gates enforced server-side **and** by RLS (defense-in-depth).

---

## 3. Configuration & Admin endpoints

| Method · Path | Purpose | Role |
|---------------|---------|------|
| `GET/POST /organizations`, `GET/PATCH /organizations/{id}` | tenant CRUD | super/org_admin |
| `GET/POST /branches` · `PATCH /branches/{id}` | branches (geo, geofence, hours, `publish_public_wait`) | org_admin |
| `GET/POST /departments` · `/counters` | structure | org_admin |
| `GET/POST /services` · `PATCH` | services (avg_duration seed) | org_admin |
| `GET/POST /staff` · `PATCH /staff/{id}` | staff & roles | org_admin |
| `GET/POST /api-keys` · `DELETE` | integration keys | org_admin |

### Flow Builder (F1)
| Method · Path | Purpose |
|---------------|---------|
| `GET /flows` · `POST /flows` | list/create flows (optionally from `industry_template`) |
| `GET /flows/{id}` · `PATCH /flows/{id}` | flow meta |
| `POST /flows/{id}/versions` | **create immutable version** (stages in body) |
| `GET /flows/{id}/versions/{v}` | fetch a version + stages |
| `POST /flows/{id}/publish` | set `current_version_id`, `is_published=true` |
| `POST /flows/{id}/simulate` | dry-run a flow against sample load (preview) |

---

## 4. Core Queue endpoints (the verbs from the flows)

> These are the heart. Every mutation: Postgres txn → `activity_event` → post-commit Redis publish → WS broadcast. All POSTs accept `Idempotency-Key`.

### Identity & join
| Method · Path | Purpose | Actor |
|---------------|---------|-------|
| `POST /visits` | **Join / create visit** (channel: receptionist/qr/web). Resolves/creates `customer` + `customer_org_link`, instantiates `flow_version` → `visit_stages`. Returns visit + ticket token. | reception / customer(QR/web) |
| `GET /visits/{id}` | Full visit: stages, current stage, ETAs, journey timeline (F4) | owner/staff |
| `GET /branches/{id}/qr` | branch QR payload | public |
| `POST /customers/lookup` | returning-patient quick lookup (F9 single-org) | reception |
| `POST /consents` · `DELETE /consents/{id}` | grant/revoke (NDPR) | customer/admin |

### Activation (PRE_QUEUE → ACTIVE)
| Method · Path | Purpose |
|---------------|---------|
| `POST /visits/{id}/activate` | body `{trigger: on_my_way\|qr\|receptionist\|gps}` → moves current stage to ACTIVE |
| `POST /visits/{id}/location` | customer GPS ping → server checks geofence (CTO-1: enhancement, idempotent) |

### Stage operations (staff/reception verbs)
| Method · Path | Purpose | Maps to |
|---------------|---------|---------|
| `POST /branches/{id}/call-next?department_id=` | **Call next** (acuity-first) → next stage CALLED, sets `grace_deadline` | R1/S1 |
| `POST /stages/{id}/call` | call a specific stage | reception override |
| `POST /stages/{id}/serve` | CALLED → SERVING (patient present) | S1/C4 |
| `POST /stages/{id}/complete` | SERVING → COMPLETED → **auto-advance** next stage to ACTIVE | S1 |
| `POST /stages/{id}/transfer` | body `{to_department_id\|to_flow_stage_id}` → route to next stage (runtime branch, E4) | S1 |
| `POST /stages/{id}/skip` | mark stage skipped (E5) | staff |
| `POST /stages/{id}/delay` | SERVING/CALLED → back to ACTIVE | staff |
| `POST /stages/{id}/priority` | set acuity / bump → **writes `audit_log`** (R2) | reception/manager |
| `POST /stages/{id}/cancel` | cancel stage/visit | reception |
| `POST /stages/{id}/requeue` | late-but-in-grace → ACTIVE (penalty pos) | system/reception (R4) |

### Staff status (OPS-3)
| `POST /staff/{id}/status` | `{status: online\|away\|break\|offline}` → triggers ETA recompute + ✉ affected | staff |

### Appointments
| `GET/POST /appointments` · `PATCH` | book (→ PRE_QUEUE), overbooking-aware (R9) | reception/customer |

---

## 5. Real-time (WebSocket) — `/v1/realtime`

**Connect:** `wss://api.queue.ai/v1/realtime?token=…`. Token scopes which channels you may subscribe to.

**Channels (sharded by branch — natural fan-out, CTO-3):**
| Channel | Who | Payload events |
|---------|-----|----------------|
| `visit:{visit_id}` | customer (ticket token) | `stage.updated`, `eta.updated`, `called`, `visit.completed` |
| `branch:{branch_id}:queue` | reception/manager | `stage.created`, `stage.updated`, `staff.status`, `queue.reordered` |
| `branch:{branch_id}:twin` | manager | `dept.load`, `prediction.warning` (F13) |
| `display:{branch_id}` | public screen | `now_serving`, `coming_up` (numbers only, R3) |

**Event envelope:** `{ type, channel, data, server_ts, seq }`. `seq` monotonic per channel → client detects gaps and re-syncs via REST (`GET /visits/{id}` or queue snapshot). **Degrades to polling** (`GET …?since=seq`) on poor networks.

**Consistency:** WS events are *derived* from committed Postgres state (published post-commit). The REST snapshot is always authoritative; WS is the fast path. Client reconciles on reconnect by snapshot + `seq`.

---

## 6. Flow Intelligence endpoints (F8/F11/F12/F13/F5 + assistant)

| Method · Path | Purpose | Feature |
|---------------|---------|---------|
| `GET /visits/{id}/eta` · `GET /stages/{id}/eta` | ETA range + confidence + **reasons** | F11 Trust Engine |
| `GET /branches/{id}/flow-score?date=` | daily score + delta + best/worst + summary | F8/F12 |
| `GET /branches/{id}/predictions` | upcoming load warnings + recommended action | F13 |
| `POST /branches/{id}/recommendations/{rec_id}/apply` | one-tap apply (rung 3/4) → may auto-create staff move | F13 |
| `POST /branches/{id}/simulate` | what-if (`{close_counter, add_staff,…}`) → projected deltas | F5 |
| `GET /branches/{id}/digital-twin` | live dept/counter status snapshot | F3 |
| `POST /assistant/query` | NL question → **grounded** answer + cited metrics/sources | R7 |
| `GET /branches/{id}/baseline` | baseline vs current, **time saved** | R8/Law #0 |

`assistant/query` is read-only: it runs structured metric queries + pgvector retrieval, returns `{answer, citations[], used_metrics[]}` (Claude with structured outputs; never ungrounded).

---

## 7. Notifications (R6)

| Method · Path | Purpose |
|---------------|---------|
| `GET /notifications?visit_id=` | history/status |
| `POST /notifications/test` | admin test send |
| `GET/PATCH /branches/{id}/notification-budget` | caps + routing policy (push-first) |
| `POST /webhooks/providers/{provider}` | inbound delivery receipts / inbound SMS keyword (status request) |

Routing is server-side & cost-aware: engine picks channel by event priority + budget (push free → SMS for "you're next" only).

---

## 8. Offline sync (R5)

Reception PWA queues mutations offline, then reconciles:

| Method · Path | Purpose |
|---------------|---------|
| `POST /sync/batch` | array of queued ops, each with `Idempotency-Key` + `client_ts` + `If-Match` ETag | 
| → response | per-op `{status: applied\|conflict\|duplicate}`; conflicts flagged for human review (E1) |

Server applies in `client_ts` order where safe; idempotency keys make replays harmless; ETag mismatches return `conflict` (last-writer + audit flag) rather than silently clobbering.

---

## 9. Public Queue (F10, opt-in)

| Method · Path | Purpose |
|---------------|---------|
| `GET /public/branches?near=lat,lng` | nearby branches with **anonymized current wait** — only where `publish_public_wait=true` | 
| `GET /public/branches/{id}/wait` | current wait band for a branch |

Strictly opt-in per branch; anonymized aggregates only; no PII.

---

## 10. Outbound webhooks (integrations / HMS, R10)

Org-registered HTTPS endpoints, HMAC-signed, thin payloads + fetch:
`visit.created · stage.completed · visit.completed · no_show · prediction.warning · flow_score.daily`
→ enables HMS/EMR sync, BI, custom automations. Retries w/ backoff; dedupe by event id.

---

## 11. Endpoint ↔ flow/screen traceability

| Flow/Screen | Endpoints |
|-------------|-----------|
| C1 Join | `POST /visits`, `POST /auth/ticket-token` |
| C2 Live Visit | `GET /visits/{id}`, WS `visit:{id}`, `GET …/eta` |
| C3 Activate | `POST /visits/{id}/activate`, `/location` |
| C4 Called | WS `called`, `POST /stages/{id}/serve` |
| R1 Reception | `call-next`, `transfer`, `priority`, `cancel`, WS `branch:{id}:queue`, `/sync/batch` |
| R2 Add walk-in | `POST /visits` (channel=receptionist) |
| S1 Staff | `call-next`, `serve`, `complete`, `transfer`, `staff/{id}/status` |
| M1 Manager | `digital-twin`, `flow-score`, `predictions`, `recommendations/apply`, `assistant/query`, `simulate`, `baseline` |
| A1 Flow Builder | `flows`, `/versions`, `/publish`, `/simulate` |
| P1 Public display | `display` WS channel, `public_queue_view` |

---

## 12. Cross-cutting
- **Idempotency + ETag** make the API offline- and retry-safe (critical for Nigerian connectivity).
- **All mutations emit `activity_events`** → the event log the API never bypasses (keeps F2/F3/F5/Law#0 correct).
- **RLS everywhere**; ticket/display tokens are minimum-scope.
- **OpenAPI 3.1 spec** generated from NestJS decorators (single source of truth for SDKs/docs).

## 13. Open questions for Phase 6 (Architecture)
1. WebSocket layer: in-process (Socket.IO + Redis adapter) vs dedicated service from day one?
2. ETA recompute: synchronous on write vs async worker (BullMQ) fan-out — latency vs load tradeoff.
3. `recommendations/apply` rung-4 automation: which actions are auto-applyable vs always-confirm (per-org policy)?
4. Assistant: Claude via API per-request vs cached/batched; rate-limit & cost guards.

---

## Approval
> ✅ **Approve Phase 5** to proceed to **Phase 6 — System Architecture** (services, real-time, workers, deployment topology over this API + schema).
> Or request API changes (resource shapes, more endpoints, GraphQL alternative).
