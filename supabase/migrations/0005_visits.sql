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
