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
