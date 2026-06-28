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
