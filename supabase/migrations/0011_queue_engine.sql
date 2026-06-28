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
