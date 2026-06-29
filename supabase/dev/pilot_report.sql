-- Queue.ai — pilot report snapshot. Run in the SQL Editor for the pilot branch.
-- Prints the numbers for the pilot scorecard (docs/13c-PILOT-TOOLKIT.md §2).
-- Set the org/branch below (defaults to the seeded demo).

with cfg as (
  select b.id as branch_id, b.organization_id as org,
         coalesce((b.settings->>'baseline_wait_seconds')::int, 2400) as baseline
  from branches b
  where b.organization_id = '00000000-0000-0000-0000-000000000001'   -- ← change to your org
  order by b.created_at limit 1
)
select
  (select count(*) from visits v, cfg
     where v.branch_id = cfg.branch_id and v.status='completed' and v.completed_at >= current_date) as served_today,
  (select count(*) from visit_stages vs join visits v on v.id=vs.visit_id, cfg
     where v.branch_id=cfg.branch_id and vs.state='active') as waiting_now,
  (select round(coalesce(avg(extract(epoch from (vs.called_at - vs.activated_at))),0)/60)
     from visit_stages vs join visits v on v.id=vs.visit_id, cfg
     where v.branch_id=cfg.branch_id and vs.called_at >= current_date and vs.activated_at is not null) as avg_wait_min_today,
  (select count(*) from visit_stages vs join visits v on v.id=vs.visit_id, cfg
     where v.branch_id=cfg.branch_id and vs.state='no_show' and vs.entered_state_at >= current_date) as no_shows_today,
  (select round(app.hours_returned_since(cfg.branch_id, cfg.baseline, current_date)/3600.0,1) from cfg) as hours_returned_today,
  (select round(app.hours_returned_since(cfg.branch_id, cfg.baseline, date_trunc('month',now()))/3600.0,1) from cfg) as hours_returned_month,
  (select round(app.hours_returned_since(cfg.branch_id, cfg.baseline, null)/3600.0,1) from cfg) as hours_returned_lifetime;

-- Per-department live load
with cfg as (
  select b.id as branch_id from branches b
  where b.organization_id = '00000000-0000-0000-0000-000000000001'
  order by b.created_at limit 1
)
select d.name as department,
       count(vs.id) filter (where vs.state='active')  as waiting,
       count(vs.id) filter (where vs.state='serving') as serving,
       count(vs.id) filter (where vs.state='completed' and vs.completed_at >= current_date) as completed_today
from departments d
left join visit_stages vs on vs.department_id = d.id
left join visits v on v.id = vs.visit_id
join cfg on d.branch_id = cfg.branch_id
group by d.id, d.name
order by waiting desc;
