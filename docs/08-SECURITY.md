# Queue.ai — Security & Compliance

**Version:** 1.0 (for approval)
**Phase:** 8
**Posture:** **NDPR-compliant now**; HIPAA / GDPR / POPIA **architecturally ready** (no full HIPAA cert pre-PMF). Build security correctly from day one **without** premature enterprise-cert cost.
**Over:** [04 schema](04-DATABASE.md) (RLS, audit_log, consents), [06 architecture](06-ARCHITECTURE.md), [07 Flow Intelligence](07-FLOW-INTELLIGENCE.md).

> **Resolved from Phase 7:** the de-identified Claude payload spec (§7) and third-party data-flow/DPA model. **No PHI/PII ever leaves to the AI layer.**

---

## 1. Data classification (drives every control)

| Class | Examples | Controls |
|-------|----------|----------|
| **PHI/Sensitive** | patient name, phone, medical context (service/department implies condition), emergency contact | encrypt at rest + field-level for the most sensitive; RLS; audit on access; **never** to public display or AI |
| **PII** | staff names, customer profile | encrypt at rest; RLS; access-controlled |
| **Operational** | queue states, ETAs, throughput, metrics | tenant-scoped; aggregated freely; **AI-eligible when de-identified** |
| **Public (opt-in)** | branch wait bands (F10), ticket numbers | anonymized only; explicit branch opt-in |

**Privacy by design:** department/service names can imply diagnosis → treated as sensitive in any cross-boundary context (R3 — public screens show ticket numbers only).

---

## 2. Identity & Authentication

| Principal | Mechanism | Policy |
|-----------|-----------|--------|
| Staff/Admin/Manager | **Clerk** (JWT, MFA available) | short-lived access token + refresh; org+role claims; MFA encouraged for admin |
| Customer (no account) | **ticket token** (signed JWT, scoped to one `visit`) | short TTL, refreshable while visit active; read-own + activate + feedback only |
| Server/integration | **API key** (hashed at rest, scoped) | per-scope, rotatable, revocable, last-used tracked |
| Public display | **display token** (branch-scoped, read-only) | `public_queue_view` only |

- Tokens carry `organization_id` → sets `app.current_org` for RLS. **Never client-supplied tenancy.**
- Token rotation/expiry: access ~15 min, refresh rotating; display/ticket tokens scoped + revocable on visit end.

---

## 3. Authorization — RBAC matrix

| Capability | Super | Org-Admin | Manager | Reception | Staff | Customer |
|------------|:----:|:--------:|:------:|:--------:|:----:|:-------:|
| Tenant/billing config | ✅ | ✅ | — | — | — | — |
| Branch/flow/staff config | ✅ | ✅ | view | — | — | — |
| View dashboards / Flow Intelligence | ✅ | ✅ | ✅ | branch | — | — |
| Queue ops (call/transfer/complete) | — | ✅ | ✅ | ✅ | own | — |
| Priority override (audited) | — | ✅ | ✅ | ✅ | — | — |
| View patient PII | — | ✅ | ✅ | ✅ | own-stage | own |
| Public display (numbers only) | — | — | — | — | — | ambient |
| Own visit / activate / feedback | — | — | — | — | — | ✅ |

Enforced **twice**: application guards (NestJS) **and** Postgres RLS/column scoping (defense-in-depth, CTO-7). Patient full name hidden from any non-authorized role at the **view** layer.

---

## 4. Multi-tenant isolation

- `organization_id` on every tenant row; **RLS** policy `organization_id = current_setting('app.current_org')::uuid`.
- Global `customers` accessible **only** via RLS-scoped `customer_org_link` → no cross-org PII without `cross_org_share` consent (F6 stays safe-by-default).
- Per-org rate limits (noisy-neighbor); large enterprise → optional schema isolation later.
- Tenant-isolation tests are a **release gate** (Phase 14).

---

## 5. Encryption & secrets

- **In transit:** TLS 1.2+ everywhere (clients, internal, providers); HSTS.
- **At rest:** AWS KMS-encrypted RDS/Redis/S3; **field-level encryption** (pgcrypto/app-layer) for the most sensitive PII (phone, emergency contact).
- **Secrets:** AWS Secrets Manager; no secrets in code, env files in repo, DB rows, prompts, or logs. Rotated; least-privilege IAM access.
- **Backups:** encrypted, tested restore, access-controlled.

---

## 6. PII/PHI handling & minimization

- Collect the minimum (name, phone, service) — even sign-up is lean (Law #0 + privacy).
- **Public surfaces:** ticket numbers/initials only (R3); `public_queue_view` enforces it.
- **Logs/observability:** PII redacted; correlate by IDs, not names.
- **SMS/WhatsApp:** minimal content (ticket #, status) — no medical detail in messages.
- **Notifications:** content templated to avoid leaking condition (e.g. "Proceed to Room 3", not "Proceed to Oncology").

---

## 7. Third-party data flows (the trust boundaries)

| Provider | Purpose | Data sent | Safeguards |
|----------|---------|-----------|-----------|
| **Anthropic (Claude)** | Grounded assistant, reasons, reports | **De-identified, aggregated metrics + org knowledge docs only** (see below) | No PHI/PII; API not used for training; DPA; 30-day retention default |
| **Clerk** | Auth | staff/admin identity | their SOC2; PII minimized |
| **Google Maps** | travel time | coords/branch geo (no patient identity) | no PII tied to identity |
| **Termii / Africa's Talking** | SMS/WhatsApp | phone + minimal status text | DPA; data-residency review; no medical content |
| **Resend/Postmark** | email | email + status | DPA |
| **Sentry/observability** | errors | redacted, no PII | scrubbing rules |

### 7.1 The de-identified Claude payload (resolves P7 Q5)
The assistant/report generator receives **only**:
- Numeric metrics (waits, throughput, no-show %, utilization, flow score components).
- **Department/counter names** and time windows (operational, not patient-linked).
- Org **knowledge docs** the org chose to upload (RAG).
- Where an individual must be referenced, a **ticket number**, never a name/phone/condition.

**Explicitly never sent:** patient names, phone numbers, emergency contacts, individual medical context, raw `customers` rows. A pre-send **PII filter** strips/blocks any disallowed field; tool outputs are aggregated by construction. Because no PHI is sent, the AI path does not require a HIPAA BAA — but minimization is enforced regardless (NDPR).

---

## 8. Consent & data-subject rights (NDPR)

- **Roles:** the hospital is **Data Controller**, Queue.ai is **Data Processor** → a **DPA** governs every deployment.
- **Lawful basis:** service provision + explicit consent for anything beyond (marketing, `cross_org_share`).
- **Consent records:** `consents` table — granular, timestamped, revocable; `cross_org_share` (F6) default **off**.
- **Rights:** access/export (machine-readable), rectification, **erasure** (right to be forgotten → null PII on `customers`, retain anonymized stats), objection. Self-serve where possible; SLA on manual requests.
- **Residency:** primary data in **af-south-1**; cross-border transfer (e.g. Claude API) limited to de-identified data under DPA.

---

## 9. Retention & lifecycle

| Data | Retention | Then |
|------|-----------|------|
| Active visit PII | duration of relationship + policy window | erase/anonymize on request or expiry |
| `activity_events` (operational) | 12–24 mo hot | aggregate → archive (cold) |
| `predictions`, metrics | rolling; aggregates kept | raw pruned |
| `audit_log` | longest (compliance) | archived, immutable |
| Notifications | short (status) + cost record | pruned |

NDPR data-minimization + storage-limitation principles drive these windows.

---

## 10. Audit & accountability

- **`audit_log`** (write-once) records: priority overrides (R2), PHI access, config changes, exports, deletes, logins, API-key use. Includes actor, before/after, IP, time.
- Distinct from operational `activity_events`.
- Tamper-evidence: append-only, restricted IAM, longer retention.
- Supports breach forensics + NDPR accountability.

---

## 11. Network & application security

- **Network:** VPC, private subnets for DB/Redis, security groups least-privilege, no public DB, WAF on edge, DDoS protection (CloudFront/Shield).
- **App (OWASP):** input validation (zod/class-validator), parameterized queries (ORM), output encoding, CSRF protections, secure headers/CSP, rate limiting per token/IP.
- **QR security:** branch QR encodes a token resolving server-side to branch (no PII in QR); revocable/rotatable.
- **Ticket/display tokens:** minimum scope, signed, short-lived, revocable.
- **Dependency/supply chain:** lockfiles, automated vuln scanning (Dependabot/Snyk), image scanning, SBOM.

---

## 12. Anti-fraud / abuse (queue-specific)

| Abuse | Mitigation |
|-------|-----------|
| Slot hoarding / fake bookings | Pre-Queue + activation requirement (no active slot without QR/geofence/check-in) |
| Queue gaming (multi-book) | rate limits, dedupe by phone/customer, no-show penalties feed prediction |
| Ticket-token theft/replay | short TTL, signed, scoped to one visit, revocable; idempotency keys |
| Public-queue scraping (F10) | opt-in only, aggregated/anonymized, rate-limited, no per-person data |
| Display-token leak | read-only, numbers-only view, branch-scoped, rotatable |
| Priority-override abuse | every override audited (R2); manager-visible |

---

## 13. Threat model (STRIDE summary)

| Threat | Example | Mitigation |
|--------|---------|-----------|
| **S**poofing | impersonate staff/tenant | Clerk auth + MFA; signed scoped tokens; server-set tenancy |
| **T**ampering | alter another org's queue | RLS + app guards + ETag concurrency; immutable event log |
| **R**epudiation | deny an override | audit_log (actor/IP/time, write-once) |
| **I**nfo disclosure | cross-tenant/PHI leak | RLS, field encryption, view-layer redaction, AI minimization |
| **D**oS | flood join/activate | rate limits, WAF, queue/job backpressure, autoscale |
| **E**levation | role escalation | RBAC double-enforced (app + DB), least-priv IAM |

---

## 14. Incident response & breach notification

- IR runbook: detect (alerts) → contain → assess → notify → remediate → post-mortem.
- **NDPR breach notification:** notify NITDA + affected data subjects without undue delay (target ≤72h) where risk warrants; Data Controller (hospital) coordinated per DPA.
- On-call + Sentry alerting; severity classification; tabletop drills before scale.

---

## 15. SDLC & operational security
- Least-privilege IAM, separate prod/staging credentials, no prod data in dev.
- PR review + secret scanning + dependency scan in CI; signed images; IaC reviewed.
- Migrations reviewed; RLS policy changes gated.
- Pen-test before broad rollout; bug-bounty later.

---

## 16. Compliance roadmap (correct now → certified when it pays)

| Stage | Action |
|-------|--------|
| **MVP/Pilot (now)** | NDPR-compliant: DPA template, consent, residency, minimization, audit, breach plan; **DPIA** for the pilot |
| Post-PMF | NITDA filing/audit as thresholds require; SOC 2 Type I |
| Scale | SOC 2 Type II; **HIPAA** path (BAA, controls) if US/HIPAA market; **GDPR** (EU expansion); **POPIA** (SA) |

Architecture (RLS, encryption, audit, minimization, residency toggles) already supports all four — certification is process + evidence, not redesign.

---

## 17. Open questions for Phase 9
1. Field-level encryption scope — which exact columns beyond phone/emergency contact?
2. DPA template finalization with pilot hospital (legal).
3. Weather/3rd-party providers' data-handling review (Org Memory F14).
4. MFA: mandatory for admin in MVP, or encouraged?
5. Pen-test timing relative to pilot go-live.

---

## Approval
> ✅ **Approve Phase 8** to proceed to **Phase 9 — MVP Scope Lock (Hospitals)** — the final pre-build phase: exact feature cut, tech-stack lock, pilot plan, and build backlog.
> Or request security changes (deeper threat model, specific controls).
