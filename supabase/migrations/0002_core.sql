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
