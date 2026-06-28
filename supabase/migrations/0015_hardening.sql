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
