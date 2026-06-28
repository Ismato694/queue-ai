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
