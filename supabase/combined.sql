-- Queue.ai — GENERATED. Do not edit by hand. Source: supabase/migrations/* + seed.sql
-- Regenerate: bash scripts/build-combined.sh

-- ════════════════════════════════════════════════════════════
-- supabase/migrations/0001_init.sql
-- ════════════════════════════════════════════════════════════
-- Queue.ai — 0001 init: extensions, enums, tenancy helpers
-- Implements foundations from docs/04-DATABASE.md §1

create extension if not exists "pgcrypto";
create extension if not exists "postgis";
create extension if not exists "vector";
-- timescaledb is optional in MVP (enable on a Postgres that supports it):
-- create extension if not exists "timescaledb";

-- ─── Enums ──────────────────────────────────────────────────────────────────
create type plan_tier        as enum ('starter','growth','enterprise');
create type staff_role        as enum ('super_admin','org_admin','manager','receptionist','staff');
create type staff_status      as enum ('online','away','break','offline');
create type counter_status    as enum ('open','closed');
create type industry_template as enum ('hospital','bank','passport','custom');
create type acuity            as enum ('routine','priority','emergency');
create type visit_status      as enum ('active','completed','cancelled');
create type join_channel      as enum ('receptionist','qr','web','whatsapp','sms');
create type stage_state       as enum
  ('booked','pre_queue','active','called','serving','completed','transferred','no_show','expired','cancelled');
create type activation_trigger as enum ('gps','on_my_way','qr','receptionist');
create type appt_status       as enum ('booked','activated','expired','cancelled');
create type consent_scope     as enum ('service','marketing','cross_org_share');
create type prediction_kind   as enum ('stage_eta','visit_eta','leave_by','dept_load');
create type notif_channel     as enum ('push','sms','whatsapp','email','voice');
create type notif_status      as enum ('queued','sent','delivered','failed');
create type pattern_type      as enum ('dow','weather','season','holiday');

-- ─── Tenancy helper: org id from the JWT (Supabase sets request.jwt.claims) ───
-- The app issues JWTs carrying organization_id + role claims. RLS reads them here.
create schema if not exists app;

create or replace function app.current_org() returns uuid
language sql stable as $$
  select nullif(
    coalesce(
      current_setting('request.jwt.claims', true)::jsonb ->> 'organization_id',
      current_setting('app.current_org', true)            -- fallback for server/worker sessions
    ), ''
  )::uuid
$$;

create or replace function app.current_role() returns text
language sql stable as $$
  select coalesce(
    current_setting('request.jwt.claims', true)::jsonb ->> 'role',
    current_setting('app.current_role', true)
  )
$$;

-- updated_at trigger helper
create or replace function app.touch_updated_at() returns trigger
language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

-- ════════════════════════════════════════════════════════════
-- supabase/migrations/0002_core.sql
-- ════════════════════════════════════════════════════════════
-- Queue.ai — 0002 core tenancy & configuration (docs/04-DATABASE.md §3)

create table organizations (
  id               uuid primary key default gen_random_uuid(),
  name             text not null,
  slug             text unique not null,
  country          text not null default 'NG',
  default_locale   text not null default 'en',
  default_currency text not null default 'NGN',
  timezone         text not null default 'Africa/Lagos',
  plan_tier        plan_tier not null default 'growth',
  billing_status   text not null default 'trial',
  settings         jsonb not null default '{}',
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  deleted_at       timestamptz
);

create table branches (
  id                 uuid primary key default gen_random_uuid(),
  organization_id    uuid not null references organizations(id) on delete cascade,
  name               text not null,
  address            text,
  geo                geography(Point,4326),
  geofence_radius_m  int not null default 300,
  qr_token           text unique not null default encode(gen_random_bytes(16),'hex'),
  business_hours     jsonb not null default '{}',
  holiday_rules      jsonb not null default '[]',
  emergency_closed   boolean not null default false,
  publish_public_wait boolean not null default false,   -- F10 hook, opt-in
  settings           jsonb not null default '{}',
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  deleted_at         timestamptz
);
create index on branches (organization_id);
create index on branches using gist (geo);

create table departments (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  branch_id       uuid not null references branches(id) on delete cascade,
  name            text not null,
  type            text,
  settings        jsonb not null default '{}',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index on departments (organization_id, branch_id);

create table counters (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  department_id   uuid not null references departments(id) on delete cascade,
  name            text not null,
  status          counter_status not null default 'open',
  floor_coords    jsonb,                       -- F3 map (later)
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index on counters (organization_id, department_id);

create table services (
  id                   uuid primary key default gen_random_uuid(),
  organization_id      uuid not null references organizations(id) on delete cascade,
  department_id        uuid references departments(id) on delete set null,
  name                 text not null,
  avg_duration_seconds int not null default 600,   -- cold-start seed (CTO-4)
  appointment_only     boolean not null default false,
  default_flow_id      uuid,                        -- FK added after flows table
  active               boolean not null default true,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);
create index on services (organization_id);

create table staff (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  user_id         uuid,                        -- Supabase auth.users id
  display_name    text not null,
  role            staff_role not null default 'staff',
  department_id   uuid references departments(id) on delete set null,
  status          staff_status not null default 'offline',
  skills          jsonb not null default '[]',
  locale          text not null default 'en',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz
);
create index on staff (organization_id);
create index on staff (user_id);

create trigger _t_org    before update on organizations for each row execute function app.touch_updated_at();
create trigger _t_branch before update on branches      for each row execute function app.touch_updated_at();
create trigger _t_dept   before update on departments   for each row execute function app.touch_updated_at();
create trigger _t_ctr    before update on counters      for each row execute function app.touch_updated_at();
create trigger _t_svc    before update on services      for each row execute function app.touch_updated_at();
create trigger _t_staff  before update on staff         for each row execute function app.touch_updated_at();

-- ════════════════════════════════════════════════════════════
-- supabase/migrations/0003_flows.sql
-- ════════════════════════════════════════════════════════════
-- Queue.ai — 0003 Flow Builder (F1, flows-as-data) (docs/04-DATABASE.md §4)

create table flows (
  id                 uuid primary key default gen_random_uuid(),
  organization_id    uuid not null references organizations(id) on delete cascade,
  name               text not null,
  industry_template  industry_template not null default 'hospital',
  current_version_id uuid,                       -- FK added after flow_versions
  is_published       boolean not null default false,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);
create index on flows (organization_id);

create table flow_versions (
  id          uuid primary key default gen_random_uuid(),
  flow_id     uuid not null references flows(id) on delete cascade,
  version_no  int not null,
  created_by  uuid,
  notes       text,
  created_at  timestamptz not null default now(),
  unique (flow_id, version_no)
);

create table flow_stages (
  id                   uuid primary key default gen_random_uuid(),
  flow_version_id      uuid not null references flow_versions(id) on delete cascade,
  position             int not null,
  name                 text not null,
  department_id        uuid references departments(id) on delete set null,
  service_id           uuid references services(id) on delete set null,
  est_duration_seconds int not null default 600,
  requires_triage      boolean not null default false,
  appointment_only     boolean not null default false,
  is_optional          boolean not null default false,
  branch_rules         jsonb,                    -- linear + simple conditional (MVP)
  created_at           timestamptz not null default now(),
  unique (flow_version_id, position)
);

-- deferred FKs now that targets exist
alter table flows add constraint fk_flows_current_version
  foreign key (current_version_id) references flow_versions(id) on delete set null;
alter table services add constraint fk_services_default_flow
  foreign key (default_flow_id) references flows(id) on delete set null;

create trigger _t_flow before update on flows for each row execute function app.touch_updated_at();

-- ════════════════════════════════════════════════════════════
-- supabase/migrations/0004_identity.sql
-- ════════════════════════════════════════════════════════════
-- Queue.ai — 0004 identity & consent (F6/F9 hooks, NDPR) (docs/04-DATABASE.md §5)

-- GLOBAL identity (NOT org-scoped) — the F6 multi-org hook. Accessed only via links.
create table customers (
  id               uuid primary key default gen_random_uuid(),
  phone            text unique not null,        -- E.164; field-encrypt at app layer (08 §5)
  email            text,
  full_name        text,
  preferred_locale text not null default 'en',
  emergency_contact jsonb,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  deleted_at       timestamptz
);

create table customer_org_link (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  customer_id     uuid not null references customers(id) on delete cascade,
  external_ref    text,                          -- HMS/EMR id (R10)
  first_seen      timestamptz not null default now(),
  last_seen       timestamptz not null default now(),
  visit_count     int not null default 0,
  notes           jsonb not null default '{}',
  consent_status  text not null default 'service',
  unique (organization_id, customer_id)
);
create index on customer_org_link (organization_id, customer_id);

create table consents (
  id              uuid primary key default gen_random_uuid(),
  customer_id     uuid not null references customers(id) on delete cascade,
  organization_id uuid references organizations(id) on delete cascade,  -- null = global
  scope           consent_scope not null,
  granted         boolean not null default false, -- cross_org_share defaults OFF
  granted_at      timestamptz,
  revoked_at      timestamptz,
  source          text,
  created_at      timestamptz not null default now()
);
create index on consents (customer_id);

create trigger _t_cust before update on customers for each row execute function app.touch_updated_at();

-- ════════════════════════════════════════════════════════════
-- supabase/migrations/0005_visits.sql
-- ════════════════════════════════════════════════════════════
-- Queue.ai — 0005 visits & queue (R1 pipeline — the heart) (docs/04-DATABASE.md §6)

create table visit_groups (                       -- F7 family/group
  id                  uuid primary key default gen_random_uuid(),
  organization_id     uuid not null references organizations(id) on delete cascade,
  branch_id           uuid not null references branches(id) on delete cascade,
  primary_customer_id uuid references customers(id) on delete set null,
  size                int not null default 1,
  created_at          timestamptz not null default now()
);

create table visits (
  id                   uuid primary key default gen_random_uuid(),
  organization_id      uuid not null references organizations(id) on delete cascade,
  branch_id            uuid not null references branches(id) on delete cascade,
  customer_org_link_id uuid references customer_org_link(id) on delete set null,
  group_id             uuid references visit_groups(id) on delete set null,
  flow_version_id      uuid references flow_versions(id) on delete set null,
  status               visit_status not null default 'active',
  acuity               acuity not null default 'routine',  -- R2
  channel              join_channel not null,
  created_at           timestamptz not null default now(),
  completed_at         timestamptz
);
create index on visits (organization_id, branch_id, status, created_at);

-- The "ticket": one per pipeline stage. The active queue lives here.
create table visit_stages (
  id                 uuid primary key default gen_random_uuid(),
  organization_id    uuid not null references organizations(id) on delete cascade,
  visit_id           uuid not null references visits(id) on delete cascade,
  flow_stage_id      uuid references flow_stages(id) on delete set null,
  department_id      uuid not null references departments(id) on delete cascade,
  counter_id         uuid references counters(id) on delete set null,
  assigned_staff_id  uuid references staff(id) on delete set null,
  state              stage_state not null default 'pre_queue',
  position           int,
  acuity             acuity not null default 'routine',  -- R2 ordering
  entered_state_at   timestamptz not null default now(),
  pre_queue_at       timestamptz,
  activated_at       timestamptz,
  called_at          timestamptz,
  serving_at         timestamptz,
  completed_at       timestamptz,
  grace_deadline     timestamptz,                  -- R4
  activation_trigger activation_trigger,
  is_current         boolean not null default false,
  skipped            boolean not null default false, -- E5
  created_at         timestamptz not null default now()
);
-- hot path: the queue read (every few seconds)
create index on visit_stages (organization_id, department_id, state, acuity, position);
create index on visit_stages (visit_id);
-- no-show sweep
create index on visit_stages (grace_deadline) where state = 'called';

create table appointments (
  id                   uuid primary key default gen_random_uuid(),
  organization_id      uuid not null references organizations(id) on delete cascade,
  branch_id            uuid not null references branches(id) on delete cascade,
  customer_org_link_id uuid references customer_org_link(id) on delete set null,
  service_id           uuid references services(id) on delete set null,
  scheduled_for        timestamptz not null,
  status               appt_status not null default 'booked',
  visit_id             uuid references visits(id) on delete set null,
  overbooking_slot     boolean not null default false,  -- R9
  created_at           timestamptz not null default now()
);
create index on appointments (organization_id, branch_id, scheduled_for);

create table feedback (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  visit_id        uuid not null references visits(id) on delete cascade,
  rating          int check (rating between 1 and 5),
  comment         text,
  created_at      timestamptz not null default now()
);
create index on feedback (organization_id, visit_id);

-- ════════════════════════════════════════════════════════════
-- supabase/migrations/0006_intelligence.sql
-- ════════════════════════════════════════════════════════════
-- Queue.ai — 0006 Flow Intelligence & Trust (F8/F11/F12/F13/F14) (docs/04-DATABASE.md §7)

create table predictions (                        -- Trust Engine F11
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  visit_stage_id  uuid references visit_stages(id) on delete cascade,
  branch_id       uuid references branches(id) on delete cascade,
  department_id   uuid references departments(id) on delete set null,
  kind            prediction_kind not null,
  value_low_s     int,
  value_high_s    int,
  confidence      numeric(4,3),                   -- 0..1
  reasons         jsonb not null default '[]',    -- ["queue stable","all doctors available"]
  model_version   text not null default 'heuristic-v1',
  created_at      timestamptz not null default now()
);
create index on predictions (visit_stage_id, created_at desc);
create index on predictions (organization_id, branch_id, kind, created_at desc);

create table staff_throughput (                   -- F2/F13 — captured from day one
  id                 uuid primary key default gen_random_uuid(),
  organization_id    uuid not null references organizations(id) on delete cascade,
  staff_id           uuid references staff(id) on delete cascade,
  department_id      uuid references departments(id) on delete set null,
  window_start       timestamptz not null,
  window_end         timestamptz not null,
  served_count       int not null default 0,
  avg_service_seconds int,
  idle_seconds       int not null default 0
);
create index on staff_throughput (organization_id, staff_id, window_start);

create table daily_metrics (                      -- Flow Score F12 + Health F8 + Time-Saved (Law #0)
  id                 uuid primary key default gen_random_uuid(),
  organization_id    uuid not null references organizations(id) on delete cascade,
  branch_id          uuid not null references branches(id) on delete cascade,
  metric_date        date not null,
  flow_score         int,
  flow_score_delta   int,
  avg_wait_seconds   int,
  no_show_rate       numeric(5,4),
  utilization        numeric(5,4),
  csat               numeric(3,2),
  time_saved_seconds bigint,                       -- Law #0
  best_department_id uuid references departments(id) on delete set null,
  worst_department_id uuid references departments(id) on delete set null,
  ai_summary         text,
  created_at         timestamptz not null default now(),
  unique (branch_id, metric_date)
);

create table org_patterns (                       -- Organization Memory F14
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  branch_id       uuid references branches(id) on delete cascade,
  pattern_type    pattern_type not null,
  key             jsonb not null,                 -- {"dow":"mon"}
  factor          numeric(6,3),
  confidence      numeric(4,3),
  learned_at      timestamptz not null default now()
);
create index on org_patterns (organization_id, pattern_type);

create table knowledge_docs (                     -- grounded assistant RAG (pgvector)
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  title           text not null,
  body            text,
  source          text,
  created_at      timestamptz not null default now()
);

create table doc_chunks (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  doc_id          uuid not null references knowledge_docs(id) on delete cascade,
  chunk           text not null,
  embedding       vector(1024)                    -- Voyage voyage-3-class
);
-- semantic search index (HNSW)
create index on doc_chunks using hnsw (embedding vector_cosine_ops);

-- ════════════════════════════════════════════════════════════
-- supabase/migrations/0007_events.sql
-- ════════════════════════════════════════════════════════════
-- Queue.ai — 0007 eventing, notifications, audit (docs/04-DATABASE.md §8)

-- EVENT SOURCING — F5/F3/F2/Law#0. Append-only; written in the same txn as state changes.
create table activity_events (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  branch_id       uuid references branches(id) on delete cascade,
  entity_type     text not null,                  -- 'visit_stage','staff',...
  entity_id       uuid not null,
  event_type      text not null,                  -- 'state_change','staff_status','override',...
  from_state      text,
  to_state        text,
  actor_type      text,                           -- 'staff','customer','system'
  actor_id        uuid,
  payload         jsonb not null default '{}',
  occurred_at     timestamptz not null default now()
);
create index on activity_events (organization_id, occurred_at);
create index on activity_events (entity_id, occurred_at);
-- On a TimescaleDB-capable Postgres, convert to a hypertable:
-- select create_hypertable('activity_events','occurred_at', migrate_data => true);

create table notifications (                       -- R6 cost-aware routing
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  visit_id        uuid references visits(id) on delete set null,
  customer_id     uuid references customers(id) on delete set null,
  channel         notif_channel not null,
  event_type      text not null,
  status          notif_status not null default 'queued',
  cost            numeric(10,4) not null default 0,
  provider        text,
  provider_ref    text,
  created_at      timestamptz not null default now(),
  sent_at         timestamptz
);
create index on notifications (organization_id, created_at);

create table notification_budgets (                -- R6/INV-4
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  branch_id       uuid references branches(id) on delete cascade,
  period          text not null default to_char(now(),'YYYY-MM'),
  sms_cap         numeric(12,2),
  whatsapp_cap    numeric(12,2),
  spent           numeric(12,2) not null default 0,
  routing_policy  jsonb not null default '{"policy":"push-first"}'
);

-- SECURITY/COMPLIANCE trail (distinct from operational events) — NDPR/HIPAA (R2 overrides, PHI access)
create table audit_log (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  actor_id        uuid,
  action          text not null,                  -- 'priority_override','phi_access','export','delete','login',...
  target_type     text,
  target_id       uuid,
  before          jsonb,
  after           jsonb,
  ip              inet,
  occurred_at     timestamptz not null default now()
);
create index on audit_log (organization_id, occurred_at);

create table api_keys (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  name            text not null,
  key_hash        text not null,
  scopes          jsonb not null default '[]',
  last_used_at    timestamptz,
  revoked_at      timestamptz,
  created_at      timestamptz not null default now()
);
create index on api_keys (organization_id);

-- ════════════════════════════════════════════════════════════
-- supabase/migrations/0008_rls.sql
-- ════════════════════════════════════════════════════════════
-- Queue.ai — 0008 Row-Level Security (docs/04-DATABASE.md §9, docs/08-SECURITY.md §4)
-- Tenant isolation: every tenant table is readable/writable only within app.current_org().
-- The worker/service role connects with the Supabase service key, which BYPASSES RLS by design.

-- helper: generic tenant policy applied to a table with an organization_id column
do $$
declare t text;
begin
  foreach t in array array[
    'organizations','branches','departments','counters','services','staff',
    'flows','flow_versions','flow_stages',  -- versions/stages scoped via joins below, but keep simple in MVP
    'customer_org_link','consents','visit_groups','visits','visit_stages',
    'appointments','feedback','predictions','staff_throughput','daily_metrics',
    'org_patterns','knowledge_docs','doc_chunks','activity_events','notifications',
    'notification_budgets','audit_log','api_keys'
  ] loop
    execute format('alter table %I enable row level security;', t);
  end loop;
end $$;

-- organizations: a member sees only their own org
create policy org_isolation on organizations
  using (id = app.current_org()) with check (id = app.current_org());

-- tables that carry organization_id directly
do $$
declare t text;
begin
  foreach t in array array[
    'branches','departments','counters','services','staff','flows',
    'customer_org_link','consents','visit_groups','visits','visit_stages',
    'appointments','feedback','predictions','staff_throughput','daily_metrics',
    'org_patterns','knowledge_docs','doc_chunks','activity_events','notifications',
    'notification_budgets','audit_log','api_keys'
  ] loop
    execute format($f$
      create policy tenant_isolation on %I
        using (organization_id = app.current_org())
        with check (organization_id = app.current_org());
    $f$, t);
  end loop;
end $$;

-- flow_versions / flow_stages: scoped via their parent flow's org (no direct org column)
create policy fv_isolation on flow_versions
  using (exists (select 1 from flows f where f.id = flow_versions.flow_id and f.organization_id = app.current_org()))
  with check (exists (select 1 from flows f where f.id = flow_versions.flow_id and f.organization_id = app.current_org()));

create policy fs_isolation on flow_stages
  using (exists (
    select 1 from flow_versions v join flows f on f.id = v.flow_id
    where v.id = flow_stages.flow_version_id and f.organization_id = app.current_org()))
  with check (exists (
    select 1 from flow_versions v join flows f on f.id = v.flow_id
    where v.id = flow_stages.flow_version_id and f.organization_id = app.current_org()));

-- customers (GLOBAL): visible only if linked to the current org (F6 stays safe-by-default)
create policy cust_via_link on customers
  using (exists (
    select 1 from customer_org_link l
    where l.customer_id = customers.id and l.organization_id = app.current_org()))
  with check (true);  -- inserts happen via service role / app on join

-- ════════════════════════════════════════════════════════════
-- supabase/migrations/0009_views.sql
-- ════════════════════════════════════════════════════════════
-- Queue.ai — 0009 privacy-safe views (R3) (docs/04-DATABASE.md §9, docs/08-SECURITY.md §6)

-- Public display: ticket numbers / status ONLY. No patient names ever (R3).
create or replace view public_queue_view as
select
  vs.organization_id,
  vs.department_id,
  d.branch_id,
  d.name             as department_name,
  vs.state,
  vs.position,
  -- a stable short ticket label derived from the id (no PII)
  upper(substr(replace(vs.id::text,'-',''),1,6)) as ticket_no,
  c.name             as counter_name
from visit_stages vs
join departments d on d.id = vs.department_id
left join counters c on c.id = vs.counter_id
where vs.state in ('active','called','serving');

comment on view public_queue_view is
  'Privacy-safe (R3): exposes ticket number + status + location only. Never patient PII.';

-- ════════════════════════════════════════════════════════════
-- supabase/migrations/0010_auth_bootstrap.sql
-- ════════════════════════════════════════════════════════════
-- Queue.ai — 0010 auth wiring + bootstrap RPCs (Sprint S1)
-- Makes RLS work with plain Supabase Auth: current org/role resolve from the signed-in
-- user's staff row (no custom JWT-claims hook needed for MVP). Worker still uses the
-- explicit app.current_org setting / service role.

create or replace function app.current_org() returns uuid
language sql stable as $$
  select coalesce(
    nullif(current_setting('app.current_org', true), '')::uuid,
    nullif(current_setting('request.jwt.claims', true)::jsonb ->> 'organization_id', '')::uuid,
    (select s.organization_id from public.staff s
       where s.user_id = auth.uid() and s.deleted_at is null limit 1)
  )
$$;

create or replace function app.current_role() returns text
language sql stable as $$
  select coalesce(
    nullif(current_setting('app.current_role', true), ''),
    current_setting('request.jwt.claims', true)::jsonb ->> 'role',
    (select s.role::text from public.staff s
       where s.user_id = auth.uid() and s.deleted_at is null limit 1)
  )
$$;

-- Bootstrap: a newly-signed-up user creates their org + first admin staff + first branch,
-- atomically, bypassing RLS via SECURITY DEFINER. One org per user in MVP.
create or replace function public.bootstrap_organization(p_org_name text, p_branch_name text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_org uuid; v_email text;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if exists (select 1 from staff where user_id = auth.uid()) then
    raise exception 'user already belongs to an organization';
  end if;
  v_email := coalesce((auth.jwt() ->> 'email'), 'Admin');

  insert into organizations (name, slug)
  values (p_org_name,
          lower(regexp_replace(p_org_name, '[^a-zA-Z0-9]+', '-', 'g')) || '-' || substr(gen_random_uuid()::text,1,6))
  returning id into v_org;

  insert into staff (organization_id, user_id, display_name, role, status)
  values (v_org, auth.uid(), v_email, 'org_admin', 'offline');

  insert into branches (organization_id, name) values (v_org, p_branch_name);
  return v_org;
end $$;
grant execute on function public.bootstrap_organization(text, text) to authenticated;

-- Publish a flow: snapshot stages into a new immutable version and mark it current.
create or replace function public.publish_flow(p_flow_id uuid, p_stages jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_org uuid; v_ver uuid; v_no int; s jsonb; pos int := 0;
begin
  select organization_id into v_org from flows where id = p_flow_id;
  if v_org is null then raise exception 'flow not found'; end if;
  if v_org <> app.current_org() then raise exception 'forbidden'; end if;

  select coalesce(max(version_no), 0) + 1 into v_no from flow_versions where flow_id = p_flow_id;
  insert into flow_versions (flow_id, version_no, created_by)
  values (p_flow_id, v_no, auth.uid()) returning id into v_ver;

  for s in select * from jsonb_array_elements(p_stages) loop
    pos := pos + 1;
    insert into flow_stages
      (flow_version_id, position, name, department_id, service_id,
       est_duration_seconds, requires_triage, is_optional)
    values
      (v_ver, pos, s ->> 'name',
       nullif(s ->> 'department_id','')::uuid, nullif(s ->> 'service_id','')::uuid,
       coalesce((s ->> 'est_duration_seconds')::int, 600),
       coalesce((s ->> 'requires_triage')::boolean, false),
       coalesce((s ->> 'is_optional')::boolean, false));
  end loop;

  update flows set current_version_id = v_ver, is_published = true, updated_at = now()
  where id = p_flow_id;
  return v_ver;
end $$;
grant execute on function public.publish_flow(uuid, jsonb) to authenticated;

-- ════════════════════════════════════════════════════════════
-- supabase/migrations/0011_queue_engine.sql
-- ════════════════════════════════════════════════════════════
-- Queue.ai — 0011 Queue Engine (Sprint S2)
-- The ticket state machine as atomic RPCs: each transition updates the stage AND writes
-- an activity_event in the SAME transaction (docs/06-ARCHITECTURE.md §4 invariant — never bypassed).
-- SECURITY INVOKER (default) → RLS applies; callers must be staff in the org.

-- helper: next queue position within a department's live set
create or replace function app.next_position(p_org uuid, p_department uuid) returns int
language sql stable as $$
  select coalesce(max(position), 0) + 1
  from visit_stages
  where organization_id = p_org and department_id = p_department
    and state in ('active','called','serving')
$$;

-- helper: append an activity event (the event log the engine never bypasses)
create or replace function app.log_event(
  p_org uuid, p_branch uuid, p_entity_type text, p_entity_id uuid,
  p_event_type text, p_from text, p_to text, p_payload jsonb default '{}'
) returns void language sql as $$
  insert into activity_events
    (organization_id, branch_id, entity_type, entity_id, event_type, from_state, to_state,
     actor_type, actor_id, payload)
  values (p_org, p_branch, p_entity_type, p_entity_id, p_event_type, p_from, p_to,
          'staff', auth.uid(), p_payload)
$$;

-- ── Create a walk-in visit from a published flow; first stage goes ACTIVE ──────
create or replace function public.create_walkin_visit(
  p_branch_id uuid, p_flow_id uuid, p_name text, p_phone text, p_acuity acuity default 'routine'
) returns uuid language plpgsql set search_path = public, app as $$
declare
  v_org uuid; v_ver uuid; v_cust uuid; v_link uuid; v_visit uuid;
  v_first uuid; r record; v_pos int; first_done boolean := false;
begin
  select organization_id into v_org from branches where id = p_branch_id;
  if v_org is null or v_org <> app.current_org() then raise exception 'forbidden'; end if;

  if p_flow_id is null then
    select id into p_flow_id from flows where organization_id = v_org and is_published order by created_at limit 1;
  end if;
  select current_version_id into v_ver from flows where id = p_flow_id;
  if v_ver is null then raise exception 'no published flow'; end if;

  insert into customers (phone, full_name) values (p_phone, p_name)
    on conflict (phone) do update set full_name = coalesce(excluded.full_name, customers.full_name)
    returning id into v_cust;

  insert into customer_org_link (organization_id, customer_id)
    values (v_org, v_cust)
    on conflict (organization_id, customer_id)
      do update set last_seen = now(), visit_count = customer_org_link.visit_count + 1
    returning id into v_link;

  insert into visits (organization_id, branch_id, customer_org_link_id, flow_version_id, acuity, channel)
    values (v_org, p_branch_id, v_link, v_ver, p_acuity, 'receptionist')
    returning id into v_visit;

  for r in
    select fs.id, fs.department_id from flow_stages fs
    where fs.flow_version_id = v_ver order by fs.position
  loop
    if not first_done then
      v_pos := app.next_position(v_org, r.department_id);
      insert into visit_stages
        (organization_id, visit_id, flow_stage_id, department_id, state, position, acuity,
         entered_state_at, pre_queue_at, activated_at, activation_trigger, is_current)
      values (v_org, v_visit, r.id, r.department_id, 'active', v_pos, p_acuity,
              now(), now(), now(), 'receptionist', true)
      returning id into v_first;
      first_done := true;
    else
      insert into visit_stages
        (organization_id, visit_id, flow_stage_id, department_id, state, acuity)
      values (v_org, v_visit, r.id, r.department_id, 'booked', p_acuity);
    end if;
  end loop;

  perform app.log_event(v_org, p_branch_id, 'visit_stage', v_first, 'state_change', null, 'active',
                        jsonb_build_object('reason','walkin_created'));
  return v_visit;
end $$;
grant execute on function public.create_walkin_visit(uuid,uuid,text,text,acuity) to authenticated;

-- ── Call next (acuity-first, then position) ───────────────────────────────────
create or replace function public.call_next(
  p_branch_id uuid, p_department_id uuid, p_grace_seconds int default 300
) returns uuid language plpgsql set search_path = public, app as $$
declare v_org uuid; v_id uuid;
begin
  v_org := app.current_org();
  select vs.id into v_id
  from visit_stages vs join visits v on v.id = vs.visit_id
  where vs.organization_id = v_org and vs.department_id = p_department_id
    and v.branch_id = p_branch_id and vs.state = 'active'
  order by vs.acuity desc, vs.position asc nulls last, vs.entered_state_at asc
  limit 1 for update of vs skip locked;

  if v_id is null then return null; end if;

  update visit_stages set state = 'called', called_at = now(), entered_state_at = now(),
    grace_deadline = now() + make_interval(secs => p_grace_seconds)
  where id = v_id;

  perform app.log_event(v_org, p_branch_id, 'visit_stage', v_id, 'state_change', 'active', 'called');
  return v_id;
end $$;
grant execute on function public.call_next(uuid,uuid,int) to authenticated;

-- ── Serve (called → serving) ──────────────────────────────────────────────────
create or replace function public.serve_stage(p_stage_id uuid)
returns void language plpgsql set search_path = public, app as $$
declare v_org uuid; v_branch uuid;
begin
  v_org := app.current_org();
  update visit_stages vs set state = 'serving', serving_at = now(), entered_state_at = now()
  from visits v where vs.id = p_stage_id and vs.visit_id = v.id
    and vs.organization_id = v_org and vs.state = 'called'
  returning v.branch_id into v_branch;
  if v_branch is null then raise exception 'stage not callable'; end if;
  perform app.log_event(v_org, v_branch, 'visit_stage', p_stage_id, 'state_change', 'called', 'serving');
end $$;
grant execute on function public.serve_stage(uuid) to authenticated;

-- ── Complete (serving → completed) + auto-advance the pipeline (R1) ───────────
create or replace function public.complete_stage(p_stage_id uuid)
returns uuid language plpgsql set search_path = public, app as $$
declare v_org uuid; v_visit uuid; v_branch uuid; v_from text;
        v_next uuid; v_next_dept uuid; v_pos int;
begin
  v_org := app.current_org();
  select vs.visit_id, v.branch_id, vs.state::text
    into v_visit, v_branch, v_from
  from visit_stages vs join visits v on v.id = vs.visit_id
  where vs.id = p_stage_id and vs.organization_id = v_org
    and vs.state in ('serving','called') for update;
  if v_visit is null then raise exception 'stage not completable'; end if;

  update visit_stages set state = 'completed', completed_at = now(),
    entered_state_at = now(), is_current = false where id = p_stage_id;
  perform app.log_event(v_org, v_branch, 'visit_stage', p_stage_id, 'state_change', v_from, 'completed');

  -- next pending stage by flow position
  select ns.id, ns.department_id into v_next, v_next_dept
  from visit_stages ns join flow_stages nfs on nfs.id = ns.flow_stage_id
  where ns.visit_id = v_visit and ns.state = 'booked'
  order by nfs.position asc limit 1;

  if v_next is not null then
    v_pos := app.next_position(v_org, v_next_dept);
    update visit_stages set state = 'active', position = v_pos, is_current = true,
      activated_at = now(), pre_queue_at = now(), entered_state_at = now(),
      activation_trigger = 'receptionist'
    where id = v_next;
    perform app.log_event(v_org, v_branch, 'visit_stage', v_next, 'state_change', 'booked', 'active',
                          jsonb_build_object('reason','auto_advance'));
    return v_next;
  else
    update visits set status = 'completed', completed_at = now() where id = v_visit;
    perform app.log_event(v_org, v_branch, 'visit', v_visit, 'state_change', 'active', 'completed');
    return null;
  end if;
end $$;
grant execute on function public.complete_stage(uuid) to authenticated;

-- ── Priority override (R2) — writes the compliance audit_log ──────────────────
create or replace function public.set_stage_priority(p_stage_id uuid, p_acuity acuity)
returns void language plpgsql set search_path = public, app as $$
declare v_org uuid; v_branch uuid; v_before acuity;
begin
  v_org := app.current_org();
  select vs.acuity, v.branch_id into v_before, v_branch
  from visit_stages vs join visits v on v.id = vs.visit_id
  where vs.id = p_stage_id and vs.organization_id = v_org for update;
  if v_branch is null then raise exception 'stage not found'; end if;

  update visit_stages set acuity = p_acuity where id = p_stage_id;

  insert into audit_log (organization_id, actor_id, action, target_type, target_id, before, after)
  values (v_org, auth.uid(), 'priority_override', 'visit_stage', p_stage_id,
          jsonb_build_object('acuity', v_before), jsonb_build_object('acuity', p_acuity));
  perform app.log_event(v_org, v_branch, 'visit_stage', p_stage_id, 'override',
                        v_before::text, p_acuity::text);
end $$;
grant execute on function public.set_stage_priority(uuid,acuity) to authenticated;

-- ── Cancel a whole visit ──────────────────────────────────────────────────────
create or replace function public.cancel_visit(p_visit_id uuid)
returns void language plpgsql set search_path = public, app as $$
declare v_org uuid; v_branch uuid;
begin
  v_org := app.current_org();
  select branch_id into v_branch from visits where id = p_visit_id and organization_id = v_org;
  if v_branch is null then raise exception 'visit not found'; end if;
  update visit_stages set state = 'cancelled', entered_state_at = now()
  where visit_id = p_visit_id and state not in ('completed','cancelled','no_show','expired');
  update visits set status = 'cancelled' where id = p_visit_id;
  perform app.log_event(v_org, v_branch, 'visit', p_visit_id, 'state_change', null, 'cancelled');
end $$;
grant execute on function public.cancel_visit(uuid) to authenticated;

-- ── Reception queue view (staff-visible; RLS enforced via security_invoker) ────
create or replace view reception_queue
with (security_invoker = true) as
select
  vs.id              as stage_id,
  vs.organization_id,
  v.branch_id,
  vs.department_id,
  d.name             as department_name,
  vs.visit_id,
  vs.state,
  vs.acuity,
  vs.position,
  vs.entered_state_at,
  vs.grace_deadline,
  upper(substr(replace(vs.id::text,'-',''),1,6)) as ticket_no,
  c.full_name        as patient_name,
  c.phone            as patient_phone
from visit_stages vs
join visits v       on v.id = vs.visit_id
join departments d  on d.id = vs.department_id
left join customer_org_link l on l.id = v.customer_org_link_id
left join customers c on c.id = l.customer_id
where vs.state in ('active','called','serving');

-- ════════════════════════════════════════════════════════════
-- supabase/migrations/0012_realtime_customer.sql
-- ════════════════════════════════════════════════════════════
-- Queue.ai — 0012 real-time + customer self-service (Sprint S3)
-- Realtime publication for staff surfaces (RLS still applies to subscribers).
-- Public RPCs (SECURITY DEFINER) let customers join + track a visit without an account;
-- the unguessable visit UUID is the access capability (MVP; signed ticket tokens later).

-- Enable Realtime on the live tables (idempotent guards)
do $$
begin
  begin execute 'alter publication supabase_realtime add table visit_stages'; exception when others then null; end;
  begin execute 'alter publication supabase_realtime add table visits';       exception when others then null; end;
end $$;

-- Resolve a branch by its public QR token → branch + published flows (for the join page)
create or replace function public.get_branch_by_token(p_token text)
returns jsonb language sql security definer set search_path = public as $$
  select jsonb_build_object(
    'branch_id', b.id,
    'organization_id', b.organization_id,
    'branch_name', b.name,
    'flows', coalesce((
      select jsonb_agg(jsonb_build_object('id', f.id, 'name', f.name) order by f.created_at)
      from flows f where f.organization_id = b.organization_id and f.is_published
    ), '[]'::jsonb)
  )
  from branches b where b.qr_token = p_token and b.deleted_at is null
$$;
grant execute on function public.get_branch_by_token(text) to anon, authenticated;

-- Customer self-join (QR / web). immediate=true → first stage ACTIVE; else PRE_QUEUE.
create or replace function public.join_queue(
  p_branch_token text, p_flow_id uuid, p_name text, p_phone text,
  p_channel join_channel default 'web', p_immediate boolean default false
) returns uuid language plpgsql security definer set search_path = public, app as $$
declare
  v_org uuid; v_branch uuid; v_ver uuid; v_cust uuid; v_link uuid; v_visit uuid;
  v_first uuid; r record; first_done boolean := false; v_state stage_state; v_pos int;
begin
  select id, organization_id into v_branch, v_org from branches where qr_token = p_branch_token;
  if v_branch is null then raise exception 'branch not found'; end if;

  if p_flow_id is null then
    select id into p_flow_id from flows where organization_id = v_org and is_published order by created_at limit 1;
  end if;
  select current_version_id into v_ver from flows where id = p_flow_id and organization_id = v_org;
  if v_ver is null then raise exception 'no published flow'; end if;

  insert into customers (phone, full_name) values (p_phone, p_name)
    on conflict (phone) do update set full_name = coalesce(excluded.full_name, customers.full_name)
    returning id into v_cust;
  insert into customer_org_link (organization_id, customer_id) values (v_org, v_cust)
    on conflict (organization_id, customer_id)
      do update set last_seen = now(), visit_count = customer_org_link.visit_count + 1
    returning id into v_link;

  insert into visits (organization_id, branch_id, customer_org_link_id, flow_version_id, channel)
    values (v_org, v_branch, v_link, v_ver, p_channel) returning id into v_visit;

  for r in select id, department_id from flow_stages where flow_version_id = v_ver order by position loop
    if not first_done then
      if p_immediate then
        v_state := 'active'; v_pos := app.next_position(v_org, r.department_id);
      else
        v_state := 'pre_queue'; v_pos := null;
      end if;
      insert into visit_stages
        (organization_id, visit_id, flow_stage_id, department_id, state, position,
         entered_state_at, pre_queue_at, activated_at, activation_trigger, is_current)
      values (v_org, v_visit, r.id, r.department_id, v_state, v_pos, now(), now(),
              case when p_immediate then now() else null end,
              case when p_immediate then 'qr'::activation_trigger else null end, true)
      returning id into v_first;
      first_done := true;
    else
      insert into visit_stages (organization_id, visit_id, flow_stage_id, department_id, state)
      values (v_org, v_visit, r.id, r.department_id, 'booked');
    end if;
  end loop;

  perform app.log_event(v_org, v_branch, 'visit_stage', v_first, 'state_change', null, v_state::text,
                        jsonb_build_object('reason','self_join','channel',p_channel));
  return v_visit;
end $$;
grant execute on function public.join_queue(text,uuid,text,text,join_channel,boolean) to anon, authenticated;

-- Activate a pre-queued visit ("I'm on my way" / QR / geofence)
create or replace function public.activate_visit(p_visit_id uuid, p_trigger activation_trigger default 'on_my_way')
returns void language plpgsql security definer set search_path = public, app as $$
declare v_org uuid; v_branch uuid; v_stage uuid; v_dept uuid;
begin
  select vs.id, vs.department_id, v.organization_id, v.branch_id
    into v_stage, v_dept, v_org, v_branch
  from visit_stages vs join visits v on v.id = vs.visit_id
  where vs.visit_id = p_visit_id and vs.state = 'pre_queue' and vs.is_current
  limit 1;
  if v_stage is null then return; end if;  -- already active / not applicable

  update visit_stages set state = 'active', position = app.next_position(v_org, v_dept),
    activated_at = now(), entered_state_at = now(), activation_trigger = p_trigger
  where id = v_stage;
  perform app.log_event(v_org, v_branch, 'visit_stage', v_stage, 'state_change', 'pre_queue', 'active',
                        jsonb_build_object('trigger', p_trigger));
end $$;
grant execute on function public.activate_visit(uuid, activation_trigger) to anon, authenticated;

-- Customer-facing visit status: journey + a simple position-based estimate (NO PII).
-- Full Trust Engine (confidence + reasons) lands in S4.
create or replace function public.get_visit_status(p_visit_id uuid)
returns jsonb language plpgsql security definer set search_path = public, app as $$
declare v jsonb; v_branch text; v_status visit_status;
        v_eta int := null; cur record; v_ahead int; v_servers int; v_avg int;
begin
  select b.name, vv.status into v_branch, v_status
  from visits vv join branches b on b.id = vv.branch_id where vv.id = p_visit_id;
  if v_branch is null then return null; end if;

  -- current stage estimate
  select vs.department_id, vs.position, vs.acuity, fs.est_duration_seconds
    into cur from visit_stages vs join flow_stages fs on fs.id = vs.flow_stage_id
  where vs.visit_id = p_visit_id and vs.is_current and vs.state in ('active','called','serving') limit 1;

  if cur.department_id is not null then
    select count(*) into v_ahead from visit_stages a
      where a.department_id = cur.department_id and a.state = 'active'
        and (a.acuity > cur.acuity or (a.acuity = cur.acuity and coalesce(a.position,0) < coalesce(cur.position,0)));
    select greatest(count(*),1) into v_servers from staff s
      where s.department_id = cur.department_id and s.status = 'online';
    v_avg := coalesce(cur.est_duration_seconds, 600);
    v_eta := (v_ahead * v_avg) / v_servers;
  end if;

  select jsonb_build_object(
    'branch_name', v_branch,
    'status', v_status,
    'eta_seconds', v_eta,
    'stages', coalesce((
      select jsonb_agg(jsonb_build_object(
        'name', fs.name, 'state', vs.state, 'is_current', vs.is_current
      ) order by fs.position)
      from visit_stages vs join flow_stages fs on fs.id = vs.flow_stage_id
      where vs.visit_id = p_visit_id
    ), '[]'::jsonb)
  ) into v;
  return v;
end $$;
grant execute on function public.get_visit_status(uuid) to anon, authenticated;

-- Queue a "your turn" notification when a patient is called (worker dispatches it).
create or replace function public.call_next(
  p_branch_id uuid, p_department_id uuid, p_grace_seconds int default 300
) returns uuid language plpgsql set search_path = public, app as $$
declare v_org uuid; v_id uuid; v_visit uuid; v_cust uuid;
begin
  v_org := app.current_org();
  select vs.id, vs.visit_id into v_id, v_visit
  from visit_stages vs join visits v on v.id = vs.visit_id
  where vs.organization_id = v_org and vs.department_id = p_department_id
    and v.branch_id = p_branch_id and vs.state = 'active'
  order by vs.acuity desc, vs.position asc nulls last, vs.entered_state_at asc
  limit 1 for update of vs skip locked;
  if v_id is null then return null; end if;

  update visit_stages set state = 'called', called_at = now(), entered_state_at = now(),
    grace_deadline = now() + make_interval(secs => p_grace_seconds) where id = v_id;
  perform app.log_event(v_org, p_branch_id, 'visit_stage', v_id, 'state_change', 'active', 'called');

  select l.customer_id into v_cust from visits v join customer_org_link l on l.id = v.customer_org_link_id
  where v.id = v_visit;
  insert into notifications (organization_id, visit_id, customer_id, channel, event_type, status)
  values (v_org, v_visit, v_cust, 'sms', 'your_turn', 'queued');
  return v_id;
end $$;
grant execute on function public.call_next(uuid,uuid,int) to authenticated;

-- ════════════════════════════════════════════════════════════
-- supabase/migrations/0013_trust_engine.sql
-- ════════════════════════════════════════════════════════════
-- Queue.ai — 0013 Trust Engine + public display (Sprint S4)
-- Heuristic ETA with confidence + reasons (docs/07-FLOW-INTELLIGENCE.md §1, F11).
-- Honest by construction: range widens as confidence drops; reasons explain why.

create or replace function public.get_visit_status(p_visit_id uuid)
returns jsonb language plpgsql security definer set search_path = public, app as $$
declare
  v jsonb; v_branch text; v_status visit_status;
  cur record; v_ahead int; v_servers int; v_expected int; v_avg int;
  v_pending_sum int; v_pending_cnt int; v_eta int := null;
  v_availability numeric; v_conf numeric := null; v_half int := 0;
  v_low int := null; v_high int := null; v_reasons jsonb := '[]'::jsonb;
begin
  select b.name, vv.status into v_branch, v_status
  from visits vv join branches b on b.id = vv.branch_id where vv.id = p_visit_id;
  if v_branch is null then return null; end if;

  select vs.department_id, vs.position, vs.acuity, vs.state, fs.est_duration_seconds
    into cur from visit_stages vs join flow_stages fs on fs.id = vs.flow_stage_id
  where vs.visit_id = p_visit_id and vs.is_current and vs.state in ('active','called','serving') limit 1;

  if cur.department_id is not null then
    select count(*) into v_ahead from visit_stages a
      where a.department_id = cur.department_id and a.state = 'active'
        and (a.acuity > cur.acuity or (a.acuity = cur.acuity and coalesce(a.position,0) < coalesce(cur.position,0)));
    select greatest(count(*),1) into v_servers from staff s
      where s.department_id = cur.department_id and s.status = 'online' and s.deleted_at is null;
    select greatest(count(*),1) into v_expected from staff s
      where s.department_id = cur.department_id and s.deleted_at is null;
    v_avg := coalesce(cur.est_duration_seconds, 600);

    select coalesce(sum(fs.est_duration_seconds),0), count(*) into v_pending_sum, v_pending_cnt
    from visit_stages vs join flow_stages fs on fs.id = vs.flow_stage_id
    where vs.visit_id = p_visit_id and vs.state = 'booked';

    v_eta := (v_ahead * v_avg) / v_servers + coalesce(v_pending_sum,0);

    -- confidence (07 §1.4): cold-start uses neutral stability/history priors
    v_availability := least(v_servers::numeric / v_expected, 1);
    v_conf := round(greatest(0.40, least(0.95,
      0.45 * v_availability + 0.30 * 0.7 + 0.25 * 0.7 - 0.04 * v_pending_cnt)), 2);

    v_half := floor((1 - v_conf) * v_eta * 0.4);
    v_low  := greatest(v_eta - v_half, 0);
    v_high := v_eta + v_half;

    -- reasons (rule-based v1)
    v_reasons := to_jsonb(array_remove(array[
      case when v_availability >= 1 then 'All staff available' else 'Some staff unavailable' end,
      case when v_pending_cnt <= 1 then 'Queue stable' else null end,
      'Still learning this branch'
    ], null));
  end if;

  select jsonb_build_object(
    'branch_name', v_branch,
    'status', v_status,
    'eta_low_s', v_low, 'eta_high_s', v_high,
    'confidence', v_conf, 'reasons', v_reasons,
    'stages', coalesce((
      select jsonb_agg(jsonb_build_object('name', fs.name, 'state', vs.state, 'is_current', vs.is_current)
        order by fs.position)
      from visit_stages vs join flow_stages fs on fs.id = vs.flow_stage_id
      where vs.visit_id = p_visit_id
    ), '[]'::jsonb)
  ) into v;
  return v;
end $$;
grant execute on function public.get_visit_status(uuid) to anon, authenticated;

-- Public display (R3): now-serving + coming-up, TICKET NUMBERS ONLY, no PII.
create or replace function public.get_public_display(p_branch_token text)
returns jsonb language plpgsql security definer set search_path = public, app as $$
declare v_org uuid; v_branch uuid; v_name text;
begin
  select id, organization_id, name into v_branch, v_org, v_name
  from branches where qr_token = p_branch_token;
  if v_branch is null then return null; end if;

  return jsonb_build_object(
    'branch_name', v_name,
    'now_serving', coalesce((
      select jsonb_agg(jsonb_build_object(
        'ticket', upper(substr(replace(vs.id::text,'-',''),1,6)),
        'dept', d.name, 'counter', c.name) order by vs.called_at desc)
      from visit_stages vs join visits v on v.id = vs.visit_id
      join departments d on d.id = vs.department_id
      left join counters c on c.id = vs.counter_id
      where v.branch_id = v_branch and vs.state in ('called','serving')
    ), '[]'::jsonb),
    'coming_up', coalesce((
      select jsonb_agg(jsonb_build_object(
        'ticket', upper(substr(replace(vs.id::text,'-',''),1,6)),
        'dept', d.name) order by vs.acuity desc, vs.position asc)
      from visit_stages vs join visits v on v.id = vs.visit_id
      join departments d on d.id = vs.department_id
      where v.branch_id = v_branch and vs.state = 'active'
    ), '[]'::jsonb)
  );
end $$;
grant execute on function public.get_public_display(text) to anon, authenticated;

-- ════════════════════════════════════════════════════════════
-- supabase/migrations/0014_flow_overview.sql
-- ════════════════════════════════════════════════════════════
-- Queue.ai — 0014 Manager overview: Flow Score + Digital Twin + Time-Saved (Sprint S5)
-- All computed from LIVE data (docs/07 §8, F8/F12/F3-lite, Law #0). No AI here.

create or replace function public.get_flow_overview(p_branch_id uuid)
returns jsonb language plpgsql security definer set search_path = public, app as $$
declare
  v_org uuid; v_baseline int;
  v_waiting int; v_avg_wait numeric; v_served int; v_created int;
  v_no_show int; v_done_stages int; v_no_show_rate numeric;
  v_wait_perf numeric; v_completion numeric; v_score int;
  v_time_saved bigint; v_depts jsonb;
begin
  select organization_id, coalesce((settings->>'baseline_wait_seconds')::int, 2400)
    into v_org, v_baseline from branches where id = p_branch_id;
  if v_org is null or v_org <> app.current_org() then raise exception 'forbidden'; end if;

  -- live waiting
  select count(*) into v_waiting from visit_stages vs join visits v on v.id = vs.visit_id
   where v.branch_id = p_branch_id and vs.state = 'active';

  -- today's actual wait (active -> called)
  select coalesce(avg(extract(epoch from (vs.called_at - vs.activated_at))), 0)
    into v_avg_wait from visit_stages vs join visits v on v.id = vs.visit_id
   where v.branch_id = p_branch_id and vs.called_at >= current_date and vs.activated_at is not null;

  select count(*) into v_served from visits
   where branch_id = p_branch_id and status = 'completed' and completed_at >= current_date;
  select count(*) into v_created from visits
   where branch_id = p_branch_id and created_at >= current_date;
  select count(*) into v_no_show from visit_stages vs join visits v on v.id = vs.visit_id
   where v.branch_id = p_branch_id and vs.state = 'no_show' and vs.entered_state_at >= current_date;
  select count(*) into v_done_stages from visit_stages vs join visits v on v.id = vs.visit_id
   where v.branch_id = p_branch_id and vs.state = 'completed' and vs.completed_at >= current_date;

  v_no_show_rate := case when (v_no_show + v_done_stages) > 0
    then v_no_show::numeric / (v_no_show + v_done_stages) else 0 end;
  v_wait_perf := least(v_baseline::numeric / greatest(v_avg_wait, 1), 1);
  v_completion := case when v_created > 0 then least(v_served::numeric / v_created, 1) else 1 end;

  -- Flow Score (F12) — weighted composite, 0..100
  v_score := round(100 * (0.5 * v_wait_perf + 0.25 * (1 - v_no_show_rate) + 0.25 * v_completion));

  -- Total Time Saved estimate (Law #0): served × (baseline − actual avg wait)
  v_time_saved := greatest(0, v_served * (v_baseline - round(v_avg_wait)));

  -- Digital Twin (F3-lite): per-department live status
  select coalesce(jsonb_agg(t order by t->>'name'), '[]'::jsonb) into v_depts from (
    select jsonb_build_object(
      'name', d.name,
      'waiting', count(vs.id) filter (where vs.state = 'active'),
      'longest_wait_s', coalesce(max(extract(epoch from (now() - vs.entered_state_at)))
                                 filter (where vs.state = 'active'), 0),
      'status', case
        when coalesce(max(extract(epoch from (now() - vs.entered_state_at)))
              filter (where vs.state = 'active'),0) > 1200
          or count(vs.id) filter (where vs.state = 'active') > 8 then 'delayed'
        when count(vs.id) filter (where vs.state = 'active') > 3 then 'busy'
        else 'calm' end
    ) as t
    from departments d
    left join visit_stages vs on vs.department_id = d.id
      and vs.organization_id = v_org
    left join visits v on v.id = vs.visit_id and v.branch_id = p_branch_id
    where d.branch_id = p_branch_id
    group by d.id, d.name
  ) sub;

  return jsonb_build_object(
    'flow_score', v_score,
    'waiting_total', v_waiting,
    'avg_wait_seconds', round(v_avg_wait),
    'no_show_rate', round(v_no_show_rate, 4),
    'served_today', v_served,
    'time_saved_seconds', v_time_saved,
    'departments', v_depts
  );
end $$;
grant execute on function public.get_flow_overview(uuid) to authenticated;

-- ════════════════════════════════════════════════════════════
-- supabase/migrations/0015_hardening.sql
-- ════════════════════════════════════════════════════════════
-- Queue.ai — 0015 hardening (Sprint S6): supporting indexes for overview + sweep queries.
-- Keeps the manager dashboard and no-show sweep fast as data grows (docs/04 §10).

-- Flow overview: today's completed visits, created visits
create index if not exists idx_visits_branch_status_completed on visits (branch_id, status, completed_at);
create index if not exists idx_visits_branch_created           on visits (branch_id, created_at);

-- Flow overview: today's wait (active->called) + completed stages
create index if not exists idx_vs_called_at    on visit_stages (called_at) where called_at is not null;
create index if not exists idx_vs_completed_at on visit_stages (completed_at) where completed_at is not null;

-- Event log read path (twin/simulation later)
create index if not exists idx_events_branch_time on activity_events (branch_id, occurred_at);

-- ════════════════════════════════════════════════════════════
-- supabase/migrations/0016_hours_returned.sql
-- ════════════════════════════════════════════════════════════
-- Queue.ai — 0016 Hours Returned (first-class mission KPI, Law #0)
-- Today / This Month / Since joining, per branch. Estimate: served × (baseline − avg wait).

create or replace function app.hours_returned_since(p_branch uuid, p_baseline int, p_since timestamptz)
returns bigint language sql stable as $$
  with served as (
    select count(*) c from visits
    where branch_id = p_branch and status = 'completed'
      and (p_since is null or completed_at >= p_since)
  ),
  wait as (
    select coalesce(avg(extract(epoch from (vs.called_at - vs.activated_at))), 0) w
    from visit_stages vs join visits v on v.id = vs.visit_id
    where v.branch_id = p_branch and vs.activated_at is not null and vs.called_at is not null
      and (p_since is null or vs.called_at >= p_since)
  )
  select greatest(0, (select c from served) * (p_baseline - round((select w from wait))))::bigint
$$;

create or replace function public.get_hours_returned(p_branch_id uuid)
returns jsonb language plpgsql security definer set search_path = public, app as $$
declare v_org uuid; v_baseline int;
begin
  select organization_id, coalesce((settings->>'baseline_wait_seconds')::int, 2400)
    into v_org, v_baseline from branches where id = p_branch_id;
  if v_org is null or v_org <> app.current_org() then raise exception 'forbidden'; end if;

  return jsonb_build_object(
    'today_seconds',    app.hours_returned_since(p_branch_id, v_baseline, current_date),
    'month_seconds',    app.hours_returned_since(p_branch_id, v_baseline, date_trunc('month', now())),
    'lifetime_seconds', app.hours_returned_since(p_branch_id, v_baseline, null)
  );
end $$;
grant execute on function public.get_hours_returned(uuid) to authenticated;

-- ════════════════════════════════════════════════════════════
-- supabase/migrations/0017_fix_current_org_recursion.sql
-- ════════════════════════════════════════════════════════════
-- Queue.ai — 0017 fix RLS recursion (Sprint S1 hotfix)
-- BUG: staff RLS policy uses app.current_org(), and app.current_org() read from `staff`
-- under RLS → the lookup filtered itself out → org resolved to NULL → app stuck on onboarding.
-- FIX: make the resolver functions SECURITY DEFINER so their internal staff lookup
-- bypasses RLS (breaking the circular dependency).

create or replace function app.current_org() returns uuid
language sql stable security definer set search_path = public, app as $$
  select coalesce(
    nullif(current_setting('app.current_org', true), '')::uuid,
    nullif(current_setting('request.jwt.claims', true)::jsonb ->> 'organization_id', '')::uuid,
    (select s.organization_id from public.staff s
       where s.user_id = auth.uid() and s.deleted_at is null limit 1)
  )
$$;

create or replace function app.current_role() returns text
language sql stable security definer set search_path = public, app as $$
  select coalesce(
    nullif(current_setting('app.current_role', true), ''),
    current_setting('request.jwt.claims', true)::jsonb ->> 'role',
    (select s.role::text from public.staff s
       where s.user_id = auth.uid() and s.deleted_at is null limit 1)
  )
$$;

grant execute on function app.current_org()  to anon, authenticated;
grant execute on function app.current_role() to anon, authenticated;

-- ════════════════════════════════════════════════════════════
-- supabase/migrations/0018_queue_rpcs_definer.sql
-- ════════════════════════════════════════════════════════════
-- Queue.ai — 0018 queue RPCs → SECURITY DEFINER (Sprint S2 hotfix)
-- The reception/staff queue RPCs ran as SECURITY INVOKER and could be blocked by RLS
-- on their internal writes for the `authenticated` role. Each already enforces org
-- membership internally (via app.current_org()), so DEFINER is tenant-safe and matches
-- the customer-facing RPC pattern (join_queue, activate_visit, …).

alter function public.create_walkin_visit(uuid,uuid,text,text,acuity) security definer;
alter function public.call_next(uuid,uuid,int)                        security definer;
alter function public.serve_stage(uuid)                               security definer;
alter function public.complete_stage(uuid)                            security definer;
alter function public.set_stage_priority(uuid,acuity)                 security definer;
alter function public.cancel_visit(uuid)                              security definer;

-- ════════════════════════════════════════════════════════════
-- supabase/migrations/0019_flow_intelligence_v2.sql
-- ════════════════════════════════════════════════════════════
-- Queue.ai — 0019 Flow Intelligence v2 (Phase 16.5): Predictive Operations (F13),
-- Capacity AI (F2), and Simulation (F5) — heuristic now, improves with pilot data.
-- All computed live from the queue + staff state; honest estimates (labeled in UI).

-- Predictive Operations: per-department forward look + a recommended action.
create or replace function public.get_predictive_ops(p_branch_id uuid, p_threshold_min int default 20)
returns jsonb language plpgsql security definer set search_path = public, app as $$
declare v_org uuid; v_out jsonb;
begin
  select organization_id into v_org from branches where id = p_branch_id;
  if v_org is null or v_org <> app.current_org() then raise exception 'forbidden'; end if;

  select coalesce(jsonb_agg(w order by (w->>'clear_min')::numeric desc), '[]'::jsonb) into v_out
  from (
    select jsonb_build_object(
      'department', d.name,
      'waiting', wq.waiting,
      'servers', wq.servers,
      'clear_min', round(wq.clear_s / 60.0),
      'recommend', 'Move 1 staff to ' || d.name || ' (or open a counter)',
      'projected_clear_min', round((wq.waiting * wq.avg_s) / ((wq.servers + 1)) / 60.0)
    ) as w
    from departments d
    join lateral (
      select
        count(vs.id) filter (where vs.state = 'active') as waiting,
        greatest((select count(*) from staff s
                   where s.department_id = d.id and s.status = 'online' and s.deleted_at is null), 1) as servers,
        coalesce((select avg(sv.avg_duration_seconds) from services sv where sv.department_id = d.id), 600) as avg_s,
        (count(vs.id) filter (where vs.state = 'active')
           * coalesce((select avg(sv.avg_duration_seconds) from services sv where sv.department_id = d.id), 600))
          / greatest((select count(*) from staff s
                       where s.department_id = d.id and s.status = 'online' and s.deleted_at is null), 1) as clear_s
      from visit_stages vs
      join visits v on v.id = vs.visit_id and v.branch_id = p_branch_id
      where vs.department_id = d.id
    ) wq on true
    where d.branch_id = p_branch_id
      and wq.clear_s / 60.0 > p_threshold_min          -- only surface real risks
  ) sub;
  return v_out;
end $$;
grant execute on function public.get_predictive_ops(uuid, int) to authenticated;

-- Simulation: project branch-wide avg wait under a staffing change (what-if).
create or replace function public.simulate_branch(p_branch_id uuid, p_add_staff int default 0, p_remove_staff int default 0)
returns jsonb language plpgsql security definer set search_path = public, app as $$
declare v_org uuid; v_wait int; v_servers int; v_avg numeric; v_new int; v_cur_min numeric; v_proj_min numeric;
begin
  select organization_id into v_org from branches where id = p_branch_id;
  if v_org is null or v_org <> app.current_org() then raise exception 'forbidden'; end if;

  select count(*) into v_wait from visit_stages vs join visits v on v.id = vs.visit_id
   where v.branch_id = p_branch_id and vs.state = 'active';
  select greatest(count(*),1) into v_servers from staff s join departments d on d.id = s.department_id
   where d.branch_id = p_branch_id and s.status = 'online' and s.deleted_at is null;
  select coalesce(avg(sv.avg_duration_seconds), 600) into v_avg from services sv
   join departments d on d.id = sv.department_id where d.branch_id = p_branch_id;

  v_new := greatest(v_servers + p_add_staff - p_remove_staff, 1);
  v_cur_min  := round((v_wait * v_avg) / v_servers / 60.0, 1);
  v_proj_min := round((v_wait * v_avg) / v_new     / 60.0, 1);

  return jsonb_build_object(
    'waiting', v_wait, 'servers', v_servers, 'new_servers', v_new,
    'current_avg_wait_min', v_cur_min, 'projected_avg_wait_min', v_proj_min,
    'delta_pct', case when v_cur_min > 0 then round((v_proj_min - v_cur_min) / v_cur_min * 100) else 0 end
  );
end $$;
grant execute on function public.simulate_branch(uuid, int, int) to authenticated;

-- ════════════════════════════════════════════════════════════
-- supabase/migrations/0020_grant_app_schema.sql
-- ════════════════════════════════════════════════════════════
-- Queue.ai — 0020 grant access to the `app` schema (hotfix)
-- BUG: the `app` schema (app.current_org, app.next_position, app.log_event, …) was never
-- granted to the anon/authenticated roles, so RPCs that touch app.* failed with
-- "permission denied for schema app" (e.g. create_walkin_visit). Grant usage + execute.

grant usage on schema app to anon, authenticated;
grant execute on all functions in schema app to anon, authenticated;
alter default privileges in schema app grant execute on functions to anon, authenticated;

-- ════════════════════════════════════════════════════════════
-- supabase/migrations/0021_staff_status_rpc.sql
-- ════════════════════════════════════════════════════════════
-- Queue.ai — 0021 (audit H4): staff status via an event-emitting RPC.
-- Was a direct table write → no activity_event, no ETA-impact signal (broke 06 §4 + OPS-3).

create or replace function public.set_staff_status(p_status staff_status)
returns void language plpgsql security definer set search_path = public, app as $$
declare v_org uuid; v_staff uuid; v_before staff_status;
begin
  select id, organization_id, status into v_staff, v_org, v_before
  from staff where user_id = auth.uid() and deleted_at is null limit 1;
  if v_staff is null then raise exception 'not a staff member'; end if;

  update staff set status = p_status, updated_at = now() where id = v_staff;
  -- the event lets the worker recompute ETAs / notify affected patients (OPS-3)
  perform app.log_event(v_org, null, 'staff', v_staff, 'staff_status', v_before::text, p_status::text);
end $$;
grant execute on function public.set_staff_status(staff_status) to authenticated;

-- ════════════════════════════════════════════════════════════
-- supabase/migrations/0022_phone_encryption.sql
-- ════════════════════════════════════════════════════════════
-- Queue.ai — 0022 (audit C2 + H3): encrypt patient phone at rest + rate-limit public join.
-- C2: phone stored as pgcrypto-encrypted bytea + HMAC blind index for unique lookup.
--     Decrypt key lives in app.crypto_key (locked down); only SECURITY DEFINER funcs use it.
-- H3: join_queue throttles repeat joins per phone+branch (anti-spam/DoS).

-- ── Key store (no direct access by app roles) ──────────────────────────────────
create table if not exists app.crypto_key (id int primary key default 1, key bytea not null);
insert into app.crypto_key (id, key) values (1, gen_random_bytes(32)) on conflict (id) do nothing;
revoke all on app.crypto_key from public;

-- ── Crypto helpers (definer; key never leaves these functions) ─────────────────
-- NOTE: pgcrypto lives in the `extensions` schema on Supabase (in `public` on a bare
-- Postgres). Include both in search_path so pgp_sym_*/hmac resolve in either env.
create or replace function app.enc(p text) returns bytea
  language sql security definer set search_path = app, public, extensions as
$$ select pgp_sym_encrypt(p, encode((select key from app.crypto_key where id=1),'hex')) $$;

create or replace function app.dec(p bytea) returns text
  language sql security definer set search_path = app, public, extensions as
$$ select case when p is null then null
              else pgp_sym_decrypt(p, encode((select key from app.crypto_key where id=1),'hex')) end $$;

create or replace function app.bidx(p text) returns text
  language sql security definer set search_path = app, public, extensions as
$$ select encode(hmac(p, encode((select key from app.crypto_key where id=1),'hex'), 'sha256'),'hex') $$;

-- masked display for staff (last 4 only) — the only crypto helper app roles may call
create or replace function app.phone_last4(p bytea) returns text
  language sql security definer set search_path = app, public, extensions as
$$ select case when p is null then null else '••••' || right(app.dec(p), 4) end $$;

-- 0020 default-grants new app functions to anon/authenticated; lock the sensitive ones back down
revoke execute on function app.enc(text)  from anon, authenticated;
revoke execute on function app.dec(bytea) from anon, authenticated;
revoke execute on function app.bidx(text) from anon, authenticated;
revoke execute on function app.phone_last4(bytea) from anon;        -- staff only
grant  execute on function app.phone_last4(bytea) to authenticated;

-- ── Migrate customers.phone → encrypted columns ───────────────────────────────
alter table customers add column if not exists phone_enc  bytea;
alter table customers add column if not exists phone_bidx text;
update customers set phone_enc = app.enc(phone), phone_bidx = app.bidx(phone)
  where phone is not null and phone_bidx is null;
alter table customers drop constraint if exists customers_phone_key;
-- reception_queue (0011) reads customers.phone; drop it first, recreated below with phone_last4
drop view if exists reception_queue;
alter table customers drop column if exists phone;
create unique index if not exists customers_phone_bidx_key on customers (phone_bidx);

-- ── Rewrite join RPCs to use enc/bidx (+ H3 throttle) ─────────────────────────
create or replace function public.join_queue(
  p_branch_token text, p_flow_id uuid, p_name text, p_phone text,
  p_channel join_channel default 'web', p_immediate boolean default false
) returns uuid language plpgsql security definer set search_path = public, app as $$
declare
  v_org uuid; v_branch uuid; v_ver uuid; v_cust uuid; v_link uuid; v_visit uuid;
  v_first uuid; r record; first_done boolean := false; v_state stage_state; v_pos int; v_recent int;
begin
  select id, organization_id into v_branch, v_org from branches where qr_token = p_branch_token;
  if v_branch is null then raise exception 'branch not found'; end if;

  if p_flow_id is null then
    select id into p_flow_id from flows where organization_id = v_org and is_published order by created_at limit 1;
  end if;
  select current_version_id into v_ver from flows where id = p_flow_id and organization_id = v_org;
  if v_ver is null then raise exception 'no published flow'; end if;

  insert into customers (phone_enc, phone_bidx, full_name)
    values (app.enc(p_phone), app.bidx(p_phone), p_name)
    on conflict (phone_bidx) do update set full_name = coalesce(excluded.full_name, customers.full_name)
    returning id into v_cust;
  insert into customer_org_link (organization_id, customer_id) values (v_org, v_cust)
    on conflict (organization_id, customer_id)
      do update set last_seen = now(), visit_count = customer_org_link.visit_count + 1
    returning id into v_link;

  -- H3: throttle repeat joins (max 3 per phone per branch / 2 min)
  select count(*) into v_recent from visits v
    where v.customer_org_link_id = v_link and v.branch_id = v_branch
      and v.created_at > now() - interval '2 minutes';
  if v_recent >= 3 then raise exception 'too many requests — please wait a moment'; end if;

  insert into visits (organization_id, branch_id, customer_org_link_id, flow_version_id, channel)
    values (v_org, v_branch, v_link, v_ver, p_channel) returning id into v_visit;

  for r in select id, department_id from flow_stages where flow_version_id = v_ver order by position loop
    if not first_done then
      if p_immediate then v_state := 'active'; v_pos := app.next_position(v_org, r.department_id);
      else v_state := 'pre_queue'; v_pos := null; end if;
      insert into visit_stages
        (organization_id, visit_id, flow_stage_id, department_id, state, position,
         entered_state_at, pre_queue_at, activated_at, activation_trigger, is_current)
      values (v_org, v_visit, r.id, r.department_id, v_state, v_pos, now(), now(),
              case when p_immediate then now() else null end,
              case when p_immediate then 'qr'::activation_trigger else null end, true)
      returning id into v_first;
      first_done := true;
    else
      insert into visit_stages (organization_id, visit_id, flow_stage_id, department_id, state)
      values (v_org, v_visit, r.id, r.department_id, 'booked');
    end if;
  end loop;

  perform app.log_event(v_org, v_branch, 'visit_stage', v_first, 'state_change', null, v_state::text,
                        jsonb_build_object('reason','self_join','channel',p_channel));
  return v_visit;
end $$;
grant execute on function public.join_queue(text,uuid,text,text,join_channel,boolean) to anon, authenticated;

create or replace function public.create_walkin_visit(
  p_branch_id uuid, p_flow_id uuid, p_name text, p_phone text, p_acuity acuity default 'routine'
) returns uuid language plpgsql security definer set search_path = public, app as $$
declare
  v_org uuid; v_ver uuid; v_cust uuid; v_link uuid; v_visit uuid;
  v_first uuid; r record; v_pos int; first_done boolean := false;
begin
  select organization_id into v_org from branches where id = p_branch_id;
  if v_org is null or v_org <> app.current_org() then raise exception 'forbidden'; end if;
  if p_flow_id is null then
    select id into p_flow_id from flows where organization_id = v_org and is_published order by created_at limit 1;
  end if;
  select current_version_id into v_ver from flows where id = p_flow_id;
  if v_ver is null then raise exception 'no published flow'; end if;

  insert into customers (phone_enc, phone_bidx, full_name)
    values (app.enc(p_phone), app.bidx(p_phone), p_name)
    on conflict (phone_bidx) do update set full_name = coalesce(excluded.full_name, customers.full_name)
    returning id into v_cust;
  insert into customer_org_link (organization_id, customer_id) values (v_org, v_cust)
    on conflict (organization_id, customer_id)
      do update set last_seen = now(), visit_count = customer_org_link.visit_count + 1
    returning id into v_link;

  insert into visits (organization_id, branch_id, customer_org_link_id, flow_version_id, acuity, channel)
    values (v_org, p_branch_id, v_link, v_ver, p_acuity, 'receptionist') returning id into v_visit;

  for r in select fs.id, fs.department_id from flow_stages fs where fs.flow_version_id = v_ver order by fs.position loop
    if not first_done then
      v_pos := app.next_position(v_org, r.department_id);
      insert into visit_stages
        (organization_id, visit_id, flow_stage_id, department_id, state, position, acuity,
         entered_state_at, pre_queue_at, activated_at, activation_trigger, is_current)
      values (v_org, v_visit, r.id, r.department_id, 'active', v_pos, p_acuity,
              now(), now(), now(), 'receptionist', true)
      returning id into v_first;
      first_done := true;
    else
      insert into visit_stages (organization_id, visit_id, flow_stage_id, department_id, state, acuity)
      values (v_org, v_visit, r.id, r.department_id, 'booked', p_acuity);
    end if;
  end loop;

  perform app.log_event(v_org, p_branch_id, 'visit_stage', v_first, 'state_change', null, 'active',
                        jsonb_build_object('reason','walkin_created'));
  return v_visit;
end $$;
grant execute on function public.create_walkin_visit(uuid,uuid,text,text,acuity) to authenticated;

-- ── reception_queue: mask phone (last 4 only) ─────────────────────────────────
create or replace view reception_queue with (security_invoker = true) as
select
  vs.id as stage_id, vs.organization_id, v.branch_id, vs.department_id, d.name as department_name,
  vs.visit_id, vs.state, vs.acuity, vs.position, vs.entered_state_at, vs.grace_deadline,
  upper(substr(replace(vs.id::text,'-',''),1,6)) as ticket_no,
  c.full_name as patient_name,
  app.phone_last4(c.phone_enc) as patient_phone
from visit_stages vs
join visits v on v.id = vs.visit_id
join departments d on d.id = vs.department_id
left join customer_org_link l on l.id = v.customer_org_link_id
left join customers c on c.id = l.customer_id
where vs.state in ('active','called','serving');

-- ════════════════════════════════════════════════════════════
-- supabase/migrations/0023_intelligence_rollups.sql
-- ════════════════════════════════════════════════════════════
-- Queue.ai — 0023 (audit H1 + M5): populate the intelligence/metric backbone.
-- Worker (service_role) calls these on a schedule. Turns the empty tables into real
-- history → Flow Score trend, Capacity AI/Org-Memory data source, cheaper dashboards.
-- (Per-staff throughput needs assigned-staff capture; for now we roll up per department.)

create or replace function public.rollup_throughput(p_window_min int default 60)
returns int language plpgsql security definer set search_path = public, app as $$
declare n int := 0; r record;
begin
  for r in
    select vs.organization_id, vs.department_id,
           count(*) c, avg(extract(epoch from (vs.completed_at - vs.serving_at)))::int avg_s
    from visit_stages vs
    where vs.completed_at > now() - make_interval(mins => p_window_min)
      and vs.serving_at is not null
    group by vs.organization_id, vs.department_id
  loop
    insert into staff_throughput
      (organization_id, staff_id, department_id, window_start, window_end, served_count, avg_service_seconds, idle_seconds)
    values (r.organization_id, null, r.department_id,
            now() - make_interval(mins => p_window_min), now(), r.c, r.avg_s, 0);
    n := n + 1;
  end loop;
  return n;
end $$;
grant execute on function public.rollup_throughput(int) to service_role;

create or replace function public.rollup_daily_metrics()
returns int language plpgsql security definer set search_path = public, app as $$
declare n int := 0; b record;
        v_avg numeric; v_served int; v_created int; v_noshow int; v_done int;
        v_nsr numeric; v_wp numeric; v_comp numeric; v_score int; v_saved bigint;
begin
  for b in select id, organization_id,
                  coalesce((settings->>'baseline_wait_seconds')::int, 2400) baseline from branches loop
    select coalesce(avg(extract(epoch from (vs.called_at - vs.activated_at))), 0) into v_avg
      from visit_stages vs join visits v on v.id = vs.visit_id
      where v.branch_id = b.id and vs.called_at >= current_date and vs.activated_at is not null;
    select count(*) into v_served from visits where branch_id = b.id and status='completed' and completed_at >= current_date;
    select count(*) into v_created from visits where branch_id = b.id and created_at >= current_date;
    select count(*) into v_noshow from visit_stages vs join visits v on v.id = vs.visit_id
      where v.branch_id = b.id and vs.state='no_show' and vs.entered_state_at >= current_date;
    select count(*) into v_done from visit_stages vs join visits v on v.id = vs.visit_id
      where v.branch_id = b.id and vs.state='completed' and vs.completed_at >= current_date;

    v_nsr  := case when (v_noshow+v_done) > 0 then v_noshow::numeric/(v_noshow+v_done) else 0 end;
    v_wp   := least(b.baseline::numeric / greatest(v_avg,1), 1);
    v_comp := case when v_created > 0 then least(v_served::numeric/v_created, 1) else 1 end;
    v_score := round(100 * (0.5*v_wp + 0.25*(1-v_nsr) + 0.25*v_comp));
    v_saved := greatest(0, v_served * (b.baseline - round(v_avg)));

    insert into daily_metrics
      (organization_id, branch_id, metric_date, flow_score, avg_wait_seconds, no_show_rate, time_saved_seconds)
    values (b.organization_id, b.id, current_date, v_score, round(v_avg), round(v_nsr,4), v_saved)
    on conflict (branch_id, metric_date) do update set
      flow_score = excluded.flow_score, avg_wait_seconds = excluded.avg_wait_seconds,
      no_show_rate = excluded.no_show_rate, time_saved_seconds = excluded.time_saved_seconds;
    n := n + 1;
  end loop;
  return n;
end $$;
grant execute on function public.rollup_daily_metrics() to service_role;

-- ════════════════════════════════════════════════════════════
-- supabase/migrations/0024_consistency_helpers.sql
-- ════════════════════════════════════════════════════════════
-- Queue.ai — 0024 (audit M1/M2/M5): single transition authority, baseline helper,
-- and rollup-backed Hours Returned (stop scanning all history per dashboard load).

-- M1 — canonical state-machine transitions in SQL (mirrors packages/shared STAGE_TRANSITIONS).
create or replace function app.can_transition(p_from stage_state, p_to stage_state)
returns boolean language sql immutable as $$
  select (p_from, p_to) in (
    ('booked','pre_queue'), ('booked','active'), ('booked','cancelled'), ('booked','expired'),
    ('pre_queue','active'), ('pre_queue','cancelled'), ('pre_queue','expired'),
    ('active','called'), ('active','cancelled'),
    ('called','serving'), ('called','no_show'), ('called','active'),
    ('serving','completed'), ('serving','transferred'), ('serving','active'),
    ('transferred','active')
  )
$$;
create or replace function app.assert_transition(p_from stage_state, p_to stage_state)
returns void language plpgsql as $$
begin
  if not app.can_transition(p_from, p_to) then
    raise exception 'illegal stage transition: % -> %', p_from, p_to;
  end if;
end $$;

-- M2 — single source for a branch's baseline wait (was duplicated in 4 functions).
create or replace function app.branch_baseline(p_branch uuid)
returns int language sql stable as $$
  select coalesce((settings->>'baseline_wait_seconds')::int, 2400) from branches where id = p_branch
$$;

-- M5 — Hours Returned reads pre-aggregated daily_metrics (cheap) + live "today",
-- instead of scanning every visit in history on each dashboard load.
create or replace function public.get_hours_returned(p_branch_id uuid)
returns jsonb language plpgsql security definer set search_path = public, app as $$
declare v_org uuid; v_baseline int; v_today bigint; v_month bigint; v_life bigint;
begin
  select organization_id into v_org from branches where id = p_branch_id;
  if v_org is null or v_org <> app.current_org() then raise exception 'forbidden'; end if;
  v_baseline := app.branch_baseline(p_branch_id);

  v_today := app.hours_returned_since(p_branch_id, v_baseline, current_date);
  v_month := coalesce((select sum(time_saved_seconds) from daily_metrics
              where branch_id = p_branch_id
                and metric_date >= date_trunc('month', now())::date
                and metric_date < current_date), 0) + v_today;
  v_life  := coalesce((select sum(time_saved_seconds) from daily_metrics
              where branch_id = p_branch_id and metric_date < current_date), 0) + v_today;

  return jsonb_build_object('today_seconds', v_today, 'month_seconds', v_month, 'lifetime_seconds', v_life);
end $$;
grant execute on function public.get_hours_returned(uuid) to authenticated;

-- ════════════════════════════════════════════════════════════
-- supabase/migrations/0025_queue_verbs.sql
-- ════════════════════════════════════════════════════════════
-- Queue.ai — 0025 (compliance gap): transfer / delay / requeue / skip verbs.
-- Completes the staff/reception action set (wireframe S1). Uses app.assert_transition
-- (0024) as the single authority; each emits an activity_event (06 §4).

-- helper: activate a specific (booked) next stage, optionally overriding its department
create or replace function app.activate_next(p_visit uuid, p_org uuid, p_branch uuid, p_to_dept uuid default null)
returns uuid language plpgsql set search_path = public, app as $$
declare v_next uuid; v_dept uuid;
begin
  select ns.id, coalesce(p_to_dept, ns.department_id) into v_next, v_dept
  from visit_stages ns join flow_stages nfs on nfs.id = ns.flow_stage_id
  where ns.visit_id = p_visit and ns.state = 'booked'
  order by nfs.position asc limit 1;

  if v_next is null then
    update visits set status = 'completed', completed_at = now() where id = p_visit;
    perform app.log_event(p_org, p_branch, 'visit', p_visit, 'state_change', 'active', 'completed');
    return null;
  end if;

  update visit_stages set state = 'active', department_id = v_dept,
    position = app.next_position(p_org, v_dept), is_current = true,
    activated_at = now(), pre_queue_at = now(), entered_state_at = now(), activation_trigger = 'receptionist'
  where id = v_next;
  perform app.log_event(p_org, p_branch, 'visit_stage', v_next, 'state_change', 'booked', 'active',
                        jsonb_build_object('reason','advance'));
  return v_next;
end $$;

-- TRANSFER: finish current stage and route to the next (optionally to a chosen department)
create or replace function public.transfer_stage(p_stage_id uuid, p_to_department_id uuid default null)
returns uuid language plpgsql security definer set search_path = public, app as $$
declare v_org uuid; v_visit uuid; v_branch uuid; v_from text;
begin
  v_org := app.current_org();
  select vs.visit_id, v.branch_id, vs.state::text into v_visit, v_branch, v_from
  from visit_stages vs join visits v on v.id = vs.visit_id
  where vs.id = p_stage_id and vs.organization_id = v_org and vs.state in ('serving','called','active') for update;
  if v_visit is null then raise exception 'stage not transferable'; end if;
  perform app.assert_transition(v_from::stage_state, 'transferred');

  update visit_stages set state = 'transferred', completed_at = now(), entered_state_at = now(), is_current = false
  where id = p_stage_id;
  perform app.log_event(v_org, v_branch, 'visit_stage', p_stage_id, 'state_change', v_from, 'transferred');
  return app.activate_next(v_visit, v_org, v_branch, p_to_department_id);
end $$;
grant execute on function public.transfer_stage(uuid, uuid) to authenticated;

-- DELAY: send a serving/called stage back to the active queue (re-positioned at the end)
create or replace function public.delay_stage(p_stage_id uuid)
returns void language plpgsql security definer set search_path = public, app as $$
declare v_org uuid; v_branch uuid; v_from text; v_dept uuid;
begin
  v_org := app.current_org();
  select v.branch_id, vs.state::text, vs.department_id into v_branch, v_from, v_dept
  from visit_stages vs join visits v on v.id = vs.visit_id
  where vs.id = p_stage_id and vs.organization_id = v_org and vs.state in ('serving','called') for update;
  if v_branch is null then raise exception 'stage not delayable'; end if;
  perform app.assert_transition(v_from::stage_state, 'active');

  update visit_stages set state = 'active', position = app.next_position(v_org, v_dept),
    entered_state_at = now(), called_at = null, grace_deadline = null
  where id = p_stage_id;
  perform app.log_event(v_org, v_branch, 'visit_stage', p_stage_id, 'state_change', v_from, 'active',
                        jsonb_build_object('reason','delay'));
end $$;
grant execute on function public.delay_stage(uuid) to authenticated;

-- REQUEUE: a late-but-present patient (called → active) within the grace window (R4)
create or replace function public.requeue_stage(p_stage_id uuid)
returns void language plpgsql security definer set search_path = public, app as $$
declare v_org uuid; v_branch uuid; v_dept uuid;
begin
  v_org := app.current_org();
  select v.branch_id, vs.department_id into v_branch, v_dept
  from visit_stages vs join visits v on v.id = vs.visit_id
  where vs.id = p_stage_id and vs.organization_id = v_org and vs.state = 'called' for update;
  if v_branch is null then raise exception 'stage not requeuable'; end if;

  update visit_stages set state = 'active', position = app.next_position(v_org, v_dept),
    entered_state_at = now(), called_at = null, grace_deadline = null
  where id = p_stage_id;
  perform app.log_event(v_org, v_branch, 'visit_stage', p_stage_id, 'state_change', 'called', 'active',
                        jsonb_build_object('reason','requeue_in_grace'));
end $$;
grant execute on function public.requeue_stage(uuid) to authenticated;

-- SKIP: mark an optional stage skipped and advance (E5)
create or replace function public.skip_stage(p_stage_id uuid)
returns uuid language plpgsql security definer set search_path = public, app as $$
declare v_org uuid; v_visit uuid; v_branch uuid; v_from text;
begin
  v_org := app.current_org();
  select vs.visit_id, v.branch_id, vs.state::text into v_visit, v_branch, v_from
  from visit_stages vs join visits v on v.id = vs.visit_id
  where vs.id = p_stage_id and vs.organization_id = v_org and vs.state in ('active','called','serving') for update;
  if v_visit is null then raise exception 'stage not skippable'; end if;

  update visit_stages set state = 'completed', skipped = true, completed_at = now(),
    entered_state_at = now(), is_current = false where id = p_stage_id;
  perform app.log_event(v_org, v_branch, 'visit_stage', p_stage_id, 'state_change', v_from, 'completed',
                        jsonb_build_object('reason','skipped'));
  return app.activate_next(v_visit, v_org, v_branch, null);
end $$;
grant execute on function public.skip_stage(uuid) to authenticated;

-- ════════════════════════════════════════════════════════════
-- supabase/migrations/0026_prediction_accuracy.sql
-- ════════════════════════════════════════════════════════════
-- Queue.ai — 0026 (compliance gap, audit H1/07 §11): Trust-Engine accuracy loop.
-- Snapshot a prediction when a stage goes active; score it (actual vs band) when called.
-- Worker (service_role) runs these on a schedule → predictions table populated + calibratable.

alter table predictions add column if not exists actual_seconds int;
alter table predictions add column if not exists within_band   boolean;

-- snapshot ETA predictions for current active stages that don't have one yet
create or replace function public.snapshot_active_predictions()
returns int language plpgsql security definer set search_path = public, app as $$
declare n int := 0; r record;
        v_ahead int; v_servers int; v_avg int; v_pending int; v_eta int; v_conf numeric; v_half int;
begin
  for r in
    select vs.id, vs.organization_id, vs.department_id, vs.position, vs.acuity, v.branch_id, fs.est_duration_seconds
    from visit_stages vs
    join visits v on v.id = vs.visit_id
    join flow_stages fs on fs.id = vs.flow_stage_id
    where vs.state = 'active' and vs.is_current
      and not exists (select 1 from predictions p where p.visit_stage_id = vs.id)
  loop
    select count(*) into v_ahead from visit_stages a
      where a.department_id = r.department_id and a.state = 'active'
        and (a.acuity > r.acuity or (a.acuity = r.acuity and coalesce(a.position,0) < coalesce(r.position,0)));
    select greatest(count(*),1) into v_servers from staff s
      where s.department_id = r.department_id and s.status='online' and s.deleted_at is null;
    v_avg := coalesce(r.est_duration_seconds, 600);
    select coalesce(sum(fs.est_duration_seconds),0) into v_pending
      from visit_stages vs2 join flow_stages fs on fs.id = vs2.flow_stage_id
      where vs2.visit_id = (select visit_id from visit_stages where id = r.id) and vs2.state = 'booked';
    v_eta := (v_ahead * v_avg) / v_servers + v_pending;
    v_conf := 0.7;  -- snapshot confidence prior (calibrated over time from within_band rate)
    v_half := floor((1 - v_conf) * v_eta * 0.4);

    insert into predictions
      (organization_id, visit_stage_id, branch_id, department_id, kind, value_low_s, value_high_s, confidence, reasons)
    values (r.organization_id, r.id, r.branch_id, r.department_id, 'stage_eta',
            greatest(v_eta - v_half, 0), v_eta + v_half, v_conf,
            jsonb_build_array('snapshot at activation'));
    n := n + 1;
  end loop;
  return n;
end $$;
grant execute on function public.snapshot_active_predictions() to service_role;

-- score predictions once their stage has been called (actual wait known)
create or replace function public.score_pending_predictions()
returns int language plpgsql security definer set search_path = public, app as $$
declare n int := 0; r record; v_actual int;
begin
  for r in
    select p.id, vs.activated_at, vs.called_at, p.value_low_s, p.value_high_s
    from predictions p join visit_stages vs on vs.id = p.visit_stage_id
    where p.actual_seconds is null and vs.called_at is not null and vs.activated_at is not null
  loop
    v_actual := extract(epoch from (r.called_at - r.activated_at))::int;
    update predictions set actual_seconds = v_actual,
      within_band = (v_actual between coalesce(value_low_s,0) and coalesce(value_high_s, 2147483647))
    where id = r.id;
    n := n + 1;
  end loop;
  return n;
end $$;
grant execute on function public.score_pending_predictions() to service_role;

-- accuracy summary (for the Trust-Engine honesty metric: % within band)
create or replace function public.prediction_accuracy(p_branch_id uuid)
returns jsonb language plpgsql security definer set search_path = public, app as $$
declare v_org uuid; v_total int; v_hit int;
begin
  select organization_id into v_org from branches where id = p_branch_id;
  if v_org is null or v_org <> app.current_org() then raise exception 'forbidden'; end if;
  select count(*), count(*) filter (where within_band) into v_total, v_hit
  from predictions where branch_id = p_branch_id and actual_seconds is not null;
  return jsonb_build_object('scored', v_total, 'within_band', v_hit,
    'accuracy', case when v_total > 0 then round(v_hit::numeric/v_total, 3) else null end);
end $$;
grant execute on function public.prediction_accuracy(uuid) to authenticated;

-- ════════════════════════════════════════════════════════════
-- supabase/migrations/0027_sms_target.sql
-- ════════════════════════════════════════════════════════════
-- Queue.ai — 0027 (compliance gap, R6): let the trusted worker resolve an SMS recipient.
-- Phone is encrypted (0022); the SMS provider needs the real number. This definer RPC
-- decrypts ONLY for service_role (the worker), keeping phones opaque to app roles.

create or replace function public.get_sms_target(p_notification_id uuid)
returns jsonb language sql security definer set search_path = public, app as $$
  select jsonb_build_object('phone', app.dec(c.phone_enc), 'event_type', n.event_type)
  from notifications n
  join customers c on c.id = n.customer_id
  where n.id = p_notification_id and c.phone_enc is not null
$$;
revoke execute on function public.get_sms_target(uuid) from anon, authenticated;
grant execute on function public.get_sms_target(uuid) to service_role;

-- ════════════════════════════════════════════════════════════
-- supabase/migrations/0028_gps_activation.sql
-- ════════════════════════════════════════════════════════════
-- Queue.ai — 0028 (compliance gap, CTO-1): GPS geofence activation.
-- The client sends its coordinates; the geofence check + decision happen server-side
-- (branch coords never leave the DB). Activates the pre-queue stage only if within radius.

-- NOTE: PostGIS (st_distance/st_makepoint) lives in the `extensions` schema on Supabase;
-- include it in search_path so the spatial functions resolve there and on bare Postgres.
create or replace function public.activate_visit_gps(p_visit_id uuid, p_lat double precision, p_lng double precision)
returns jsonb language plpgsql security definer set search_path = public, app, extensions as $$
declare v_branch uuid; v_radius int; v_dist double precision; v_has_geo boolean;
begin
  select v.branch_id, b.geofence_radius_m, b.geo is not null
    into v_branch, v_radius, v_has_geo
  from visits v join branches b on b.id = v.branch_id
  where v.id = p_visit_id;
  if v_branch is null then raise exception 'visit not found'; end if;
  if not v_has_geo then return jsonb_build_object('ok', false, 'reason', 'no_geofence'); end if;

  select st_distance(b.geo, st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography)
    into v_dist from branches b where b.id = v_branch;

  if v_dist > v_radius then
    return jsonb_build_object('ok', false, 'reason', 'too_far', 'distance_m', round(v_dist));
  end if;

  perform public.activate_visit(p_visit_id, 'gps');
  return jsonb_build_object('ok', true, 'distance_m', round(v_dist));
end $$;
grant execute on function public.activate_visit_gps(uuid, double precision, double precision) to anon, authenticated;

-- ════════════════════════════════════════════════════════════
-- supabase/migrations/0029_public_queue.sql
-- ════════════════════════════════════════════════════════════
-- Queue.ai — 0029 (F10): Anonymous Public Queue.
-- A no-PII, opt-in (branches.publish_public_wait) wait board people can check
-- *before* coming in. Aggregates per department only — never a name or phone (R3).

create or replace function public.get_public_wait(p_branch_token text)
returns jsonb language plpgsql security definer set search_path = public, app as $$
declare v_branch uuid; v_name text; v_opt boolean; v_depts jsonb;
begin
  select id, name, publish_public_wait into v_branch, v_name, v_opt
  from branches where qr_token = p_branch_token and deleted_at is null;
  if v_branch is null then raise exception 'branch not found'; end if;
  if not coalesce(v_opt, false) then
    return jsonb_build_object('available', false, 'branch_name', v_name);
  end if;

  select coalesce(jsonb_agg(d_row order by d_row->>'department_name'), '[]'::jsonb) into v_depts
  from (
    select jsonb_build_object(
      'department_name', d.name,
      'waiting', count(*) filter (where vs.state = 'active'),
      'now_serving', (
        select upper(substr(replace(s.id::text,'-',''),1,6))
        from visit_stages s where s.department_id = d.id and s.state in ('called','serving')
        order by s.entered_state_at desc limit 1
      ),
      'est_wait_min', greatest(1, round(
        (count(*) filter (where vs.state = 'active'))
        * coalesce((select avg(fs.est_duration_seconds) from flow_stages fs where fs.department_id = d.id), 600)
        / greatest((select count(*) from staff st where st.department_id = d.id and st.status='online' and st.deleted_at is null), 1)
        / 60.0
      ))
    ) as d_row
    from departments d
    left join visit_stages vs on vs.department_id = d.id and vs.state in ('active','called','serving')
    where d.branch_id = v_branch
    group by d.id, d.name
  ) t;

  return jsonb_build_object('available', true, 'branch_name', v_name, 'departments', v_depts);
end $$;
grant execute on function public.get_public_wait(text) to anon, authenticated;

-- ════════════════════════════════════════════════════════════
-- supabase/migrations/0030_leave_now.sql
-- ════════════════════════════════════════════════════════════
-- Queue.ai — 0030 (F-leave-by / Law #0): "Leave now" alert.
-- A pre-queue patient tells us roughly how far away they are; the system watches the
-- department's live wait and, the moment "wait for a new joiner" ≈ their travel time,
-- it (a) pulls them into the active queue and (b) notifies them to leave — so they
-- arrive right as they're called. Removes the decision "when should I leave?".

alter table visit_stages add column if not exists travel_seconds  int;
alter table visit_stages add column if not exists leave_now_sent  boolean not null default false;

-- shared estimator: how long a NEW joiner would wait in this department right now
create or replace function app.dept_wait_for_new(p_dept uuid)
returns int language sql stable set search_path = public, app as $$
  select (
    (select count(*) from visit_stages vs where vs.department_id = p_dept and vs.state = 'active')
    * coalesce((select avg(sv.avg_duration_seconds) from services sv where sv.department_id = p_dept), 600)
    / greatest((select count(*) from staff s
                 where s.department_id = p_dept and s.status = 'online' and s.deleted_at is null), 1)
  )::int
$$;

-- customer-facing: record "I'm about X minutes away" on the current pre-queue stage
create or replace function public.set_travel_time(p_visit_id uuid, p_travel_seconds int)
returns void language plpgsql security definer set search_path = public, app as $$
begin
  -- negative clears the choice (re-shows the picker); otherwise store the travel time
  update visit_stages set travel_seconds = case when p_travel_seconds < 0 then null else p_travel_seconds end
  where visit_id = p_visit_id and is_current and state = 'pre_queue';
end $$;
grant execute on function public.set_travel_time(uuid, int) to anon, authenticated;

-- customer-facing: should I leave yet? (drives the visit-page banner)
create or replace function public.get_leave_status(p_visit_id uuid)
returns jsonb language plpgsql security definer set search_path = public, app as $$
declare cur record; v_wait int; v_leave boolean := false;
begin
  select vs.department_id, vs.state, vs.travel_seconds, vs.leave_now_sent
    into cur from visit_stages vs
  where vs.visit_id = p_visit_id and vs.is_current limit 1;
  if cur.department_id is null then return jsonb_build_object('state', null); end if;

  v_wait := app.dept_wait_for_new(cur.department_id);
  -- leave now if already alerted, or (still parked) the new-joiner wait has dropped to travel time
  v_leave := coalesce(cur.leave_now_sent, false)
    or (cur.travel_seconds is not null and cur.state = 'pre_queue' and v_wait <= cur.travel_seconds);

  return jsonb_build_object(
    'state', cur.state,
    'travel_seconds', cur.travel_seconds,
    'wait_if_join_now_s', v_wait,
    'leave_now', v_leave
  );
end $$;
grant execute on function public.get_leave_status(uuid) to anon, authenticated;

-- worker (service_role): pull parked patients into the queue + notify when it's time to leave
create or replace function public.process_leave_now()
returns int language plpgsql security definer set search_path = public, app as $$
declare n int := 0; r record; v_cust uuid;
begin
  for r in
    select vs.id, vs.visit_id, vs.organization_id, vs.department_id, vs.travel_seconds, v.branch_id
    from visit_stages vs join visits v on v.id = vs.visit_id
    where vs.is_current and vs.state = 'pre_queue'
      and vs.travel_seconds is not null and not vs.leave_now_sent
  loop
    if app.dept_wait_for_new(r.department_id) <= r.travel_seconds then
      perform public.activate_visit(r.visit_id, 'on_my_way');   -- pre_queue → active
      update visit_stages set leave_now_sent = true where id = r.id;

      select l.customer_id into v_cust from visits v join customer_org_link l on l.id = v.customer_org_link_id
      where v.id = r.visit_id;
      insert into notifications (organization_id, visit_id, customer_id, channel, event_type, status)
      values (r.organization_id, r.visit_id, v_cust, 'sms', 'leave_now', 'queued');
      perform app.log_event(r.organization_id, r.branch_id, 'visit_stage', r.id, 'state_change', 'pre_queue', 'active',
                            jsonb_build_object('reason','leave_now'));
      n := n + 1;
    end if;
  end loop;
  return n;
end $$;
grant execute on function public.process_leave_now() to service_role;

-- ════════════════════════════════════════════════════════════
-- supabase/seed.sql
-- ════════════════════════════════════════════════════════════
-- Queue.ai — seed: one medium Nigerian private hospital + the hospital care pathway (F1 template)
-- Demonstrable foundation: an org, a branch, departments, services, staff, and a published flow.
-- Run after migrations. Idempotent-ish: wrap in a transaction; safe to re-run on a fresh DB.

begin;

-- Organization + branch
insert into organizations (id, name, slug, plan_tier)
values ('00000000-0000-0000-0000-000000000001','Lagoon Hospital (Demo)','lagoon-demo','growth');

insert into branches (id, organization_id, name, address, geo, geofence_radius_m)
values ('00000000-0000-0000-0000-0000000000b1','00000000-0000-0000-0000-000000000001',
        'Lagoon — Ikeja','Ikeja, Lagos',
        ST_SetSRID(ST_MakePoint(3.3515, 6.6018),4326)::geography, 300);

-- Departments (the hospital pipeline)
insert into departments (id, organization_id, branch_id, name, type) values
 ('00000000-0000-0000-0000-0000000000d1','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-0000000000b1','Reception','reception'),
 ('00000000-0000-0000-0000-0000000000d2','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-0000000000b1','Consultation','clinical'),
 ('00000000-0000-0000-0000-0000000000d3','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-0000000000b1','Laboratory','clinical'),
 ('00000000-0000-0000-0000-0000000000d4','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-0000000000b1','Pharmacy','clinical'),
 ('00000000-0000-0000-0000-0000000000d5','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-0000000000b1','Cashier','billing');

-- A counter/room per serving dept
insert into counters (organization_id, department_id, name) values
 ('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-0000000000d1','Front Desk'),
 ('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-0000000000d2','Room 3'),
 ('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-0000000000d3','Lab Bench 1'),
 ('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-0000000000d4','Pharmacy Window'),
 ('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-0000000000d5','Cashier 1');

-- Services with cold-start duration seeds (seconds)
insert into services (id, organization_id, department_id, name, avg_duration_seconds) values
 ('00000000-0000-0000-0000-0000000000a1','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-0000000000d1','Registration',180),
 ('00000000-0000-0000-0000-0000000000a2','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-0000000000d2','General Consultation',720),
 ('00000000-0000-0000-0000-0000000000a3','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-0000000000d3','Lab Test',540),
 ('00000000-0000-0000-0000-0000000000a4','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-0000000000d4','Dispense Medication',300),
 ('00000000-0000-0000-0000-0000000000a5','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-0000000000d5','Payment',180);

-- Staff
insert into staff (organization_id, display_name, role, department_id, status) values
 ('00000000-0000-0000-0000-000000000001','Admin (Demo)','org_admin', null, 'offline'),
 ('00000000-0000-0000-0000-000000000001','Mrs Adeyemi','receptionist','00000000-0000-0000-0000-0000000000d1','online'),
 ('00000000-0000-0000-0000-000000000001','Dr. Okafor','staff','00000000-0000-0000-0000-0000000000d2','online'),
 ('00000000-0000-0000-0000-000000000001','Lab Tech Bello','staff','00000000-0000-0000-0000-0000000000d3','online'),
 ('00000000-0000-0000-0000-000000000001','Pharmacist Musa','staff','00000000-0000-0000-0000-0000000000d4','online'),
 ('00000000-0000-0000-0000-000000000001','Cashier Eze','staff','00000000-0000-0000-0000-0000000000d5','online');

-- Flow (F1): the canonical outpatient care pathway, published v1
insert into flows (id, organization_id, name, industry_template, is_published)
values ('00000000-0000-0000-0000-0000000000f1','00000000-0000-0000-0000-000000000001','Outpatient Visit','hospital',true);

insert into flow_versions (id, flow_id, version_no, notes)
values ('00000000-0000-0000-0000-0000000000f2','00000000-0000-0000-0000-0000000000f1',1,'Seed: Reception→Consult→Lab→Review→Pharmacy→Cashier');

update flows set current_version_id='00000000-0000-0000-0000-0000000000f2'
 where id='00000000-0000-0000-0000-0000000000f1';

insert into flow_stages (flow_version_id, position, name, department_id, service_id, est_duration_seconds, requires_triage, is_optional) values
 ('00000000-0000-0000-0000-0000000000f2',1,'Reception',   '00000000-0000-0000-0000-0000000000d1','00000000-0000-0000-0000-0000000000a1',180,false,false),
 ('00000000-0000-0000-0000-0000000000f2',2,'Consultation','00000000-0000-0000-0000-0000000000d2','00000000-0000-0000-0000-0000000000a2',720,true ,false),
 ('00000000-0000-0000-0000-0000000000f2',3,'Laboratory',  '00000000-0000-0000-0000-0000000000d3','00000000-0000-0000-0000-0000000000a3',540,false,true ),
 ('00000000-0000-0000-0000-0000000000f2',4,'Review',      '00000000-0000-0000-0000-0000000000d2','00000000-0000-0000-0000-0000000000a2',300,false,true ),
 ('00000000-0000-0000-0000-0000000000f2',5,'Pharmacy',    '00000000-0000-0000-0000-0000000000d4','00000000-0000-0000-0000-0000000000a4',300,false,true ),
 ('00000000-0000-0000-0000-0000000000f2',6,'Cashier',     '00000000-0000-0000-0000-0000000000d5','00000000-0000-0000-0000-0000000000a5',180,false,false);

commit;
