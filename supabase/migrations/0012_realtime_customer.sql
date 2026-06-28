-- Queue.ai — 0012 real-time + customer self-service (Sprint S3)
-- Realtime publication for staff surfaces (RLS still applies to subscribers).
-- Public RPCs (SECURITY DEFINER) let customers join + track a visit without an account;
-- the unguessable visit UUID is the access capability (MVP; signed ticket tokens later).

-- Enable Realtime on the live tables (idempotent guards)
do $$
begin
  begin execute 'alter publication supabase_realtime add table visit_stages'; exception when others then null; end;
  begin execute 'alter publication supabase_realtime add table visits';       exception when others then null; end;
end $$;

-- Resolve a branch by its public QR token → branch + published flows (for the join page)
create or replace function public.get_branch_by_token(p_token text)
returns jsonb language sql security definer set search_path = public as $$
  select jsonb_build_object(
    'branch_id', b.id,
    'organization_id', b.organization_id,
    'branch_name', b.name,
    'flows', coalesce((
      select jsonb_agg(jsonb_build_object('id', f.id, 'name', f.name) order by f.created_at)
      from flows f where f.organization_id = b.organization_id and f.is_published
    ), '[]'::jsonb)
  )
  from branches b where b.qr_token = p_token and b.deleted_at is null
$$;
grant execute on function public.get_branch_by_token(text) to anon, authenticated;

-- Customer self-join (QR / web). immediate=true → first stage ACTIVE; else PRE_QUEUE.
create or replace function public.join_queue(
  p_branch_token text, p_flow_id uuid, p_name text, p_phone text,
  p_channel join_channel default 'web', p_immediate boolean default false
) returns uuid language plpgsql security definer set search_path = public, app as $$
declare
  v_org uuid; v_branch uuid; v_ver uuid; v_cust uuid; v_link uuid; v_visit uuid;
  v_first uuid; r record; first_done boolean := false; v_state stage_state; v_pos int;
begin
  select id, organization_id into v_branch, v_org from branches where qr_token = p_branch_token;
  if v_branch is null then raise exception 'branch not found'; end if;

  if p_flow_id is null then
    select id into p_flow_id from flows where organization_id = v_org and is_published order by created_at limit 1;
  end if;
  select current_version_id into v_ver from flows where id = p_flow_id and organization_id = v_org;
  if v_ver is null then raise exception 'no published flow'; end if;

  insert into customers (phone, full_name) values (p_phone, p_name)
    on conflict (phone) do update set full_name = coalesce(excluded.full_name, customers.full_name)
    returning id into v_cust;
  insert into customer_org_link (organization_id, customer_id) values (v_org, v_cust)
    on conflict (organization_id, customer_id)
      do update set last_seen = now(), visit_count = customer_org_link.visit_count + 1
    returning id into v_link;

  insert into visits (organization_id, branch_id, customer_org_link_id, flow_version_id, channel)
    values (v_org, v_branch, v_link, v_ver, p_channel) returning id into v_visit;

  for r in select id, department_id from flow_stages where flow_version_id = v_ver order by position loop
    if not first_done then
      if p_immediate then
        v_state := 'active'; v_pos := app.next_position(v_org, r.department_id);
      else
        v_state := 'pre_queue'; v_pos := null;
      end if;
      insert into visit_stages
        (organization_id, visit_id, flow_stage_id, department_id, state, position,
         entered_state_at, pre_queue_at, activated_at, activation_trigger, is_current)
      values (v_org, v_visit, r.id, r.department_id, v_state, v_pos, now(), now(),
              case when p_immediate then now() else null end,
              case when p_immediate then 'qr'::activation_trigger else null end, true)
      returning id into v_first;
      first_done := true;
    else
      insert into visit_stages (organization_id, visit_id, flow_stage_id, department_id, state)
      values (v_org, v_visit, r.id, r.department_id, 'booked');
    end if;
  end loop;

  perform app.log_event(v_org, v_branch, 'visit_stage', v_first, 'state_change', null, v_state::text,
                        jsonb_build_object('reason','self_join','channel',p_channel));
  return v_visit;
end $$;
grant execute on function public.join_queue(text,uuid,text,text,join_channel,boolean) to anon, authenticated;

-- Activate a pre-queued visit ("I'm on my way" / QR / geofence)
create or replace function public.activate_visit(p_visit_id uuid, p_trigger activation_trigger default 'on_my_way')
returns void language plpgsql security definer set search_path = public, app as $$
declare v_org uuid; v_branch uuid; v_stage uuid; v_dept uuid;
begin
  select vs.id, vs.department_id, v.organization_id, v.branch_id
    into v_stage, v_dept, v_org, v_branch
  from visit_stages vs join visits v on v.id = vs.visit_id
  where vs.visit_id = p_visit_id and vs.state = 'pre_queue' and vs.is_current
  limit 1;
  if v_stage is null then return; end if;  -- already active / not applicable

  update visit_stages set state = 'active', position = app.next_position(v_org, v_dept),
    activated_at = now(), entered_state_at = now(), activation_trigger = p_trigger
  where id = v_stage;
  perform app.log_event(v_org, v_branch, 'visit_stage', v_stage, 'state_change', 'pre_queue', 'active',
                        jsonb_build_object('trigger', p_trigger));
end $$;
grant execute on function public.activate_visit(uuid, activation_trigger) to anon, authenticated;

-- Customer-facing visit status: journey + a simple position-based estimate (NO PII).
-- Full Trust Engine (confidence + reasons) lands in S4.
create or replace function public.get_visit_status(p_visit_id uuid)
returns jsonb language plpgsql security definer set search_path = public, app as $$
declare v jsonb; v_branch text; v_status visit_status;
        v_eta int := null; cur record; v_ahead int; v_servers int; v_avg int;
begin
  select b.name, vv.status into v_branch, v_status
  from visits vv join branches b on b.id = vv.branch_id where vv.id = p_visit_id;
  if v_branch is null then return null; end if;

  -- current stage estimate
  select vs.department_id, vs.position, vs.acuity, fs.est_duration_seconds
    into cur from visit_stages vs join flow_stages fs on fs.id = vs.flow_stage_id
  where vs.visit_id = p_visit_id and vs.is_current and vs.state in ('active','called','serving') limit 1;

  if cur.department_id is not null then
    select count(*) into v_ahead from visit_stages a
      where a.department_id = cur.department_id and a.state = 'active'
        and (a.acuity > cur.acuity or (a.acuity = cur.acuity and coalesce(a.position,0) < coalesce(cur.position,0)));
    select greatest(count(*),1) into v_servers from staff s
      where s.department_id = cur.department_id and s.status = 'online';
    v_avg := coalesce(cur.est_duration_seconds, 600);
    v_eta := (v_ahead * v_avg) / v_servers;
  end if;

  select jsonb_build_object(
    'branch_name', v_branch,
    'status', v_status,
    'eta_seconds', v_eta,
    'stages', coalesce((
      select jsonb_agg(jsonb_build_object(
        'name', fs.name, 'state', vs.state, 'is_current', vs.is_current
      ) order by fs.position)
      from visit_stages vs join flow_stages fs on fs.id = vs.flow_stage_id
      where vs.visit_id = p_visit_id
    ), '[]'::jsonb)
  ) into v;
  return v;
end $$;
grant execute on function public.get_visit_status(uuid) to anon, authenticated;

-- Queue a "your turn" notification when a patient is called (worker dispatches it).
create or replace function public.call_next(
  p_branch_id uuid, p_department_id uuid, p_grace_seconds int default 300
) returns uuid language plpgsql set search_path = public, app as $$
declare v_org uuid; v_id uuid; v_visit uuid; v_cust uuid;
begin
  v_org := app.current_org();
  select vs.id, vs.visit_id into v_id, v_visit
  from visit_stages vs join visits v on v.id = vs.visit_id
  where vs.organization_id = v_org and vs.department_id = p_department_id
    and v.branch_id = p_branch_id and vs.state = 'active'
  order by vs.acuity desc, vs.position asc nulls last, vs.entered_state_at asc
  limit 1 for update of vs skip locked;
  if v_id is null then return null; end if;

  update visit_stages set state = 'called', called_at = now(), entered_state_at = now(),
    grace_deadline = now() + make_interval(secs => p_grace_seconds) where id = v_id;
  perform app.log_event(v_org, p_branch_id, 'visit_stage', v_id, 'state_change', 'active', 'called');

  select l.customer_id into v_cust from visits v join customer_org_link l on l.id = v.customer_org_link_id
  where v.id = v_visit;
  insert into notifications (organization_id, visit_id, customer_id, channel, event_type, status)
  values (v_org, v_visit, v_cust, 'sms', 'your_turn', 'queued');
  return v_id;
end $$;
grant execute on function public.call_next(uuid,uuid,int) to authenticated;
