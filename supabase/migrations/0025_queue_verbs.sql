-- Queue.ai — 0025 (compliance gap): transfer / delay / requeue / skip verbs.
-- Completes the staff/reception action set (wireframe S1). Uses app.assert_transition
-- (0024) as the single authority; each emits an activity_event (06 §4).

-- helper: activate a specific (booked) next stage, optionally overriding its department
create or replace function app.activate_next(p_visit uuid, p_org uuid, p_branch uuid, p_to_dept uuid default null)
returns uuid language plpgsql set search_path = public, app as $$
declare v_next uuid; v_dept uuid;
begin
  select ns.id, coalesce(p_to_dept, ns.department_id) into v_next, v_dept
  from visit_stages ns join flow_stages nfs on nfs.id = ns.flow_stage_id
  where ns.visit_id = p_visit and ns.state = 'booked'
  order by nfs.position asc limit 1;

  if v_next is null then
    update visits set status = 'completed', completed_at = now() where id = p_visit;
    perform app.log_event(p_org, p_branch, 'visit', p_visit, 'state_change', 'active', 'completed');
    return null;
  end if;

  update visit_stages set state = 'active', department_id = v_dept,
    position = app.next_position(p_org, v_dept), is_current = true,
    activated_at = now(), pre_queue_at = now(), entered_state_at = now(), activation_trigger = 'receptionist'
  where id = v_next;
  perform app.log_event(p_org, p_branch, 'visit_stage', v_next, 'state_change', 'booked', 'active',
                        jsonb_build_object('reason','advance'));
  return v_next;
end $$;

-- TRANSFER: finish current stage and route to the next (optionally to a chosen department)
create or replace function public.transfer_stage(p_stage_id uuid, p_to_department_id uuid default null)
returns uuid language plpgsql security definer set search_path = public, app as $$
declare v_org uuid; v_visit uuid; v_branch uuid; v_from text;
begin
  v_org := app.current_org();
  select vs.visit_id, v.branch_id, vs.state::text into v_visit, v_branch, v_from
  from visit_stages vs join visits v on v.id = vs.visit_id
  where vs.id = p_stage_id and vs.organization_id = v_org and vs.state in ('serving','called','active') for update;
  if v_visit is null then raise exception 'stage not transferable'; end if;
  perform app.assert_transition(v_from::stage_state, 'transferred');

  update visit_stages set state = 'transferred', completed_at = now(), entered_state_at = now(), is_current = false
  where id = p_stage_id;
  perform app.log_event(v_org, v_branch, 'visit_stage', p_stage_id, 'state_change', v_from, 'transferred');
  return app.activate_next(v_visit, v_org, v_branch, p_to_department_id);
end $$;
grant execute on function public.transfer_stage(uuid, uuid) to authenticated;

-- DELAY: send a serving/called stage back to the active queue (re-positioned at the end)
create or replace function public.delay_stage(p_stage_id uuid)
returns void language plpgsql security definer set search_path = public, app as $$
declare v_org uuid; v_branch uuid; v_from text; v_dept uuid;
begin
  v_org := app.current_org();
  select v.branch_id, vs.state::text, vs.department_id into v_branch, v_from, v_dept
  from visit_stages vs join visits v on v.id = vs.visit_id
  where vs.id = p_stage_id and vs.organization_id = v_org and vs.state in ('serving','called') for update;
  if v_branch is null then raise exception 'stage not delayable'; end if;
  perform app.assert_transition(v_from::stage_state, 'active');

  update visit_stages set state = 'active', position = app.next_position(v_org, v_dept),
    entered_state_at = now(), called_at = null, grace_deadline = null
  where id = p_stage_id;
  perform app.log_event(v_org, v_branch, 'visit_stage', p_stage_id, 'state_change', v_from, 'active',
                        jsonb_build_object('reason','delay'));
end $$;
grant execute on function public.delay_stage(uuid) to authenticated;

-- REQUEUE: a late-but-present patient (called → active) within the grace window (R4)
create or replace function public.requeue_stage(p_stage_id uuid)
returns void language plpgsql security definer set search_path = public, app as $$
declare v_org uuid; v_branch uuid; v_dept uuid;
begin
  v_org := app.current_org();
  select v.branch_id, vs.department_id into v_branch, v_dept
  from visit_stages vs join visits v on v.id = vs.visit_id
  where vs.id = p_stage_id and vs.organization_id = v_org and vs.state = 'called' for update;
  if v_branch is null then raise exception 'stage not requeuable'; end if;

  update visit_stages set state = 'active', position = app.next_position(v_org, v_dept),
    entered_state_at = now(), called_at = null, grace_deadline = null
  where id = p_stage_id;
  perform app.log_event(v_org, v_branch, 'visit_stage', p_stage_id, 'state_change', 'called', 'active',
                        jsonb_build_object('reason','requeue_in_grace'));
end $$;
grant execute on function public.requeue_stage(uuid) to authenticated;

-- SKIP: mark an optional stage skipped and advance (E5)
create or replace function public.skip_stage(p_stage_id uuid)
returns uuid language plpgsql security definer set search_path = public, app as $$
declare v_org uuid; v_visit uuid; v_branch uuid; v_from text;
begin
  v_org := app.current_org();
  select vs.visit_id, v.branch_id, vs.state::text into v_visit, v_branch, v_from
  from visit_stages vs join visits v on v.id = vs.visit_id
  where vs.id = p_stage_id and vs.organization_id = v_org and vs.state in ('active','called','serving') for update;
  if v_visit is null then raise exception 'stage not skippable'; end if;

  update visit_stages set state = 'completed', skipped = true, completed_at = now(),
    entered_state_at = now(), is_current = false where id = p_stage_id;
  perform app.log_event(v_org, v_branch, 'visit_stage', p_stage_id, 'state_change', v_from, 'completed',
                        jsonb_build_object('reason','skipped'));
  return app.activate_next(v_visit, v_org, v_branch, null);
end $$;
grant execute on function public.skip_stage(uuid) to authenticated;
