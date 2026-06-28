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
