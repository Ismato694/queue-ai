-- Queue.ai — 0030 (F-leave-by / Law #0): "Leave now" alert.
-- A pre-queue patient tells us roughly how far away they are; the system watches the
-- department's live wait and, the moment "wait for a new joiner" ≈ their travel time,
-- it (a) pulls them into the active queue and (b) notifies them to leave — so they
-- arrive right as they're called. Removes the decision "when should I leave?".

alter table visit_stages add column if not exists travel_seconds  int;
alter table visit_stages add column if not exists leave_now_sent  boolean not null default false;

-- shared estimator: how long a NEW joiner would wait in this department right now
create or replace function app.dept_wait_for_new(p_dept uuid)
returns int language sql stable set search_path = public, app as $$
  select (
    (select count(*) from visit_stages vs where vs.department_id = p_dept and vs.state = 'active')
    * coalesce((select avg(sv.avg_duration_seconds) from services sv where sv.department_id = p_dept), 600)
    / greatest((select count(*) from staff s
                 where s.department_id = p_dept and s.status = 'online' and s.deleted_at is null), 1)
  )::int
$$;

-- customer-facing: record "I'm about X minutes away" on the current pre-queue stage
create or replace function public.set_travel_time(p_visit_id uuid, p_travel_seconds int)
returns void language plpgsql security definer set search_path = public, app as $$
begin
  -- negative clears the choice (re-shows the picker); otherwise store the travel time
  update visit_stages set travel_seconds = case when p_travel_seconds < 0 then null else p_travel_seconds end
  where visit_id = p_visit_id and is_current and state = 'pre_queue';
end $$;
grant execute on function public.set_travel_time(uuid, int) to anon, authenticated;

-- customer-facing: should I leave yet? (drives the visit-page banner)
create or replace function public.get_leave_status(p_visit_id uuid)
returns jsonb language plpgsql security definer set search_path = public, app as $$
declare cur record; v_wait int; v_leave boolean := false;
begin
  select vs.department_id, vs.state, vs.travel_seconds, vs.leave_now_sent
    into cur from visit_stages vs
  where vs.visit_id = p_visit_id and vs.is_current limit 1;
  if cur.department_id is null then return jsonb_build_object('state', null); end if;

  v_wait := app.dept_wait_for_new(cur.department_id);
  -- leave now if already alerted, or (still parked) the new-joiner wait has dropped to travel time
  v_leave := coalesce(cur.leave_now_sent, false)
    or (cur.travel_seconds is not null and cur.state = 'pre_queue' and v_wait <= cur.travel_seconds);

  return jsonb_build_object(
    'state', cur.state,
    'travel_seconds', cur.travel_seconds,
    'wait_if_join_now_s', v_wait,
    'leave_now', v_leave
  );
end $$;
grant execute on function public.get_leave_status(uuid) to anon, authenticated;

-- worker (service_role): pull parked patients into the queue + notify when it's time to leave
create or replace function public.process_leave_now()
returns int language plpgsql security definer set search_path = public, app as $$
declare n int := 0; r record; v_cust uuid;
begin
  for r in
    select vs.id, vs.visit_id, vs.organization_id, vs.department_id, vs.travel_seconds, v.branch_id
    from visit_stages vs join visits v on v.id = vs.visit_id
    where vs.is_current and vs.state = 'pre_queue'
      and vs.travel_seconds is not null and not vs.leave_now_sent
  loop
    if app.dept_wait_for_new(r.department_id) <= r.travel_seconds then
      perform public.activate_visit(r.visit_id, 'on_my_way');   -- pre_queue → active
      update visit_stages set leave_now_sent = true where id = r.id;

      select l.customer_id into v_cust from visits v join customer_org_link l on l.id = v.customer_org_link_id
      where v.id = r.visit_id;
      insert into notifications (organization_id, visit_id, customer_id, channel, event_type, status)
      values (r.organization_id, r.visit_id, v_cust, 'sms', 'leave_now', 'queued');
      perform app.log_event(r.organization_id, r.branch_id, 'visit_stage', r.id, 'state_change', 'pre_queue', 'active',
                            jsonb_build_object('reason','leave_now'));
      n := n + 1;
    end if;
  end loop;
  return n;
end $$;
grant execute on function public.process_leave_now() to service_role;
