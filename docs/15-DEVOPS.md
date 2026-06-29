# Queue.ai — DevOps & Deployment

**Version:** 1.0
**Phase:** 15
**Goal:** get the pilot hospital running on real URLs/devices (not localhost), securely, cheaply. Stack from [09-MVP-SCOPE](09-MVP-SCOPE.md): **Supabase + Next.js + Node worker + Claude**.

> Managed-first to ship fast (Founder Rule #1). Three hosted pieces: **Supabase** (DB/auth/realtime — already up), **Vercel** (Next.js web), **Render/Railway** (the worker). Custom domain + HTTPS everywhere.

---

## Topology
```
Patients / staff devices ──► Vercel (Next.js PWA)  ──► Supabase (Postgres+Auth+Realtime+RLS, eu-west)
                                                   └─► Claude (Flow Intelligence, when enabled)
Worker host (Render/Railway) ──► Supabase (service role)  ──► Termii/Africa's Talking (SMS), no-show sweep
```

---

## 1. Supabase (production project)
- Already created (pilot region **West EU / London**; af-south-1 = production target later).
- Apply schema once: SQL Editor → run `supabase/combined.sql` (includes migrations `0001–0018` + seed). For a clean prod (no demo data) run the migrations only — paste each `0001…0018` and **skip `seed.sql`**.
- **Auth:** keep "Confirm email" **on** for production (off only for dev).
- **Realtime:** confirm `visit_stages` + `visits` are in the `supabase_realtime` publication (Database → Replication).
- **Backups:** enable PITR/daily backups on a paid tier before real patient data.
- Keys: copy **URL**, **anon**, **service_role** (service_role → worker only).

## 2. Web app → Vercel
1. **Import** the GitHub repo `Ismato694/queue-ai` into Vercel.
2. **Root directory:** `apps/web`. Framework auto-detected (Next.js). Build `next build`.
   - Monorepo note: set the project root to `apps/web`; Vercel installs from the repo root workspaces. If the `@queue-ai/shared` workspace isn't resolved, set **Install Command** to `npm install` at repo root and **Root Directory** to `apps/web` with "Include source files outside root" enabled.
3. **Environment variables** (Production + Preview):
   ```
   NEXT_PUBLIC_SUPABASE_URL=...
   NEXT_PUBLIC_SUPABASE_ANON_KEY=...
   ```
4. Deploy → you get `https://queue-ai.vercel.app`. Add a **custom domain** (e.g. `app.queue.ai`) later.

## 3. Worker → Render / Railway
The worker runs notification dispatch + no-show sweep (needs the service-role key).
1. New **Background Worker / Web Service** from the repo; root `services/worker`.
2. **Start command:** `node --experimental-strip-types src/index.ts` (or add a build to JS later).
3. **Env:**
   ```
   NEXT_PUBLIC_SUPABASE_URL=...
   SUPABASE_SERVICE_ROLE_KEY=...        # secret — worker only
   TERMII_API_KEY=...                   # optional, for real SMS
   WORKER_PORT=4000
   ```
4. Health check path: `/health`.

> Alternative (less infra): move the no-show sweep + notification dispatch to **Supabase pg_cron + Edge Functions** and skip a separate worker host for the pilot. The worker is the simpler mental model; pick one.

## 4. Flow Intelligence (Claude) — when you enable it
- Currently **mocked** ([lib/assistant.ts](../apps/web/src/lib/assistant.ts)). To go live: add `ANTHROPIC_API_KEY` server-side (an API route or the worker), replace `mockGenerate` with a Claude call (Sonnet 4.6, structured outputs), passing **only de-identified metrics** ([08-SECURITY §7.1](08-SECURITY.md)). Never expose the key to the browser.

## 5. CI/CD
- GitHub Actions (`.github/workflows/ci.yml`) already runs typecheck + tests + build on push/PR.
- Vercel auto-deploys `main` (production) and PRs (previews). Keep CI green as the merge gate.

## 6. Monitoring (pilot-grade)
- **Sentry** in web + worker (DSN via env) for errors.
- Supabase dashboard: DB load, realtime connections, auth.
- Product metrics: the Manager dashboard (Flow Score, Hours Returned) is the live business view.

## 7. Security go-live checklist (from [08-SECURITY](08-SECURITY.md))
- [ ] RLS enabled on all tenant tables (it is, via `0008`); spot-check with two orgs.
- [ ] `service_role` key only on the worker host; **never** in the web app or repo.
- [ ] "Confirm email" on; strong password policy; admin MFA recommended.
- [ ] HTTPS everywhere (Vercel/Render default); custom domain on HTTPS.
- [ ] DPA signed with the pilot hospital (NDPR; controller=hospital, processor=us).
- [ ] No PII in logs; no secrets in client bundles or git.
- [ ] Backups/PITR enabled.

## 8. Go-live (pilot) checklist → hands to [13b-PILOT-VALIDATION](13b-PILOT-VALIDATION.md)
- [ ] Prod Supabase (migrations only, no demo seed) + backups.
- [ ] Web on Vercel with prod env; custom domain.
- [ ] Worker running (or pg_cron path); SMS provider keys set.
- [ ] Admin creates the **real** hospital: branches, departments, services, staff, and the **published flow** (Flow Builder).
- [ ] Print branch **QR** (links to `/join/<qr_token>`); set up the waiting-room **/display/<qr_token>** screen.
- [ ] Baseline-capture week begins (R8).

## 9. Rollback
- Vercel: instant redeploy of a previous build.
- DB: migrations are forward-only; for a bad change, write a corrective migration (don't edit applied ones). Restore from backup only as a last resort.

---

> After deploy, the product is reachable by a real hospital → proceed to **Phase 13.5 Pilot Validation**.
