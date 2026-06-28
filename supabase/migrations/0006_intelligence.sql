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
