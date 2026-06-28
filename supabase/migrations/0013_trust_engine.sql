-- Queue.ai — 0013 Trust Engine + public display (Sprint S4)
-- Heuristic ETA with confidence + reasons (docs/07-FLOW-INTELLIGENCE.md §1, F11).
-- Honest by construction: range widens as confidence drops; reasons explain why.

create or replace function public.get_visit_status(p_visit_id uuid)
returns jsonb language plpgsql security definer set search_path = public, app as $$
declare
  v jsonb; v_branch text; v_status visit_status;
  cur record; v_ahead int; v_servers int; v_expected int; v_avg int;
  v_pending_sum int; v_pending_cnt int; v_eta int := null;
  v_availability numeric; v_conf numeric := null; v_half int := 0;
  v_low int := null; v_high int := null; v_reasons jsonb := '[]'::jsonb;
begin
  select b.name, vv.status into v_branch, v_status
  from visits vv join branches b on b.id = vv.branch_id where vv.id = p_visit_id;
  if v_branch is null then return null; end if;

  select vs.department_id, vs.position, vs.acuity, vs.state, fs.est_duration_seconds
    into cur from visit_stages vs join flow_stages fs on fs.id = vs.flow_stage_id
  where vs.visit_id = p_visit_id and vs.is_current and vs.state in ('active','called','serving') limit 1;

  if cur.department_id is not null then
    select count(*) into v_ahead from visit_stages a
      where a.department_id = cur.department_id and a.state = 'active'
        and (a.acuity > cur.acuity or (a.acuity = cur.acuity and coalesce(a.position,0) < coalesce(cur.position,0)));
    select greatest(count(*),1) into v_servers from staff s
      where s.department_id = cur.department_id and s.status = 'online' and s.deleted_at is null;
    select greatest(count(*),1) into v_expected from staff s
      where s.department_id = cur.department_id and s.deleted_at is null;
    v_avg := coalesce(cur.est_duration_seconds, 600);

    select coalesce(sum(fs.est_duration_seconds),0), count(*) into v_pending_sum, v_pending_cnt
    from visit_stages vs join flow_stages fs on fs.id = vs.flow_stage_id
    where vs.visit_id = p_visit_id and vs.state = 'booked';

    v_eta := (v_ahead * v_avg) / v_servers + coalesce(v_pending_sum,0);

    -- confidence (07 §1.4): cold-start uses neutral stability/history priors
    v_availability := least(v_servers::numeric / v_expected, 1);
    v_conf := round(greatest(0.40, least(0.95,
      0.45 * v_availability + 0.30 * 0.7 + 0.25 * 0.7 - 0.04 * v_pending_cnt)), 2);

    v_half := floor((1 - v_conf) * v_eta * 0.4);
    v_low  := greatest(v_eta - v_half, 0);
    v_high := v_eta + v_half;

    -- reasons (rule-based v1)
    v_reasons := to_jsonb(array_remove(array[
      case when v_availability >= 1 then 'All staff available' else 'Some staff unavailable' end,
      case when v_pending_cnt <= 1 then 'Queue stable' else null end,
      'Still learning this branch'
    ], null));
  end if;

  select jsonb_build_object(
    'branch_name', v_branch,
    'status', v_status,
    'eta_low_s', v_low, 'eta_high_s', v_high,
    'confidence', v_conf, 'reasons', v_reasons,
    'stages', coalesce((
      select jsonb_agg(jsonb_build_object('name', fs.name, 'state', vs.state, 'is_current', vs.is_current)
        order by fs.position)
      from visit_stages vs join flow_stages fs on fs.id = vs.flow_stage_id
      where vs.visit_id = p_visit_id
    ), '[]'::jsonb)
  ) into v;
  return v;
end $$;
grant execute on function public.get_visit_status(uuid) to anon, authenticated;

-- Public display (R3): now-serving + coming-up, TICKET NUMBERS ONLY, no PII.
create or replace function public.get_public_display(p_branch_token text)
returns jsonb language plpgsql security definer set search_path = public, app as $$
declare v_org uuid; v_branch uuid; v_name text;
begin
  select id, organization_id, name into v_branch, v_org, v_name
  from branches where qr_token = p_branch_token;
  if v_branch is null then return null; end if;

  return jsonb_build_object(
    'branch_name', v_name,
    'now_serving', coalesce((
      select jsonb_agg(jsonb_build_object(
        'ticket', upper(substr(replace(vs.id::text,'-',''),1,6)),
        'dept', d.name, 'counter', c.name) order by vs.called_at desc)
      from visit_stages vs join visits v on v.id = vs.visit_id
      join departments d on d.id = vs.department_id
      left join counters c on c.id = vs.counter_id
      where v.branch_id = v_branch and vs.state in ('called','serving')
    ), '[]'::jsonb),
    'coming_up', coalesce((
      select jsonb_agg(jsonb_build_object(
        'ticket', upper(substr(replace(vs.id::text,'-',''),1,6)),
        'dept', d.name) order by vs.acuity desc, vs.position asc)
      from visit_stages vs join visits v on v.id = vs.visit_id
      join departments d on d.id = vs.department_id
      where v.branch_id = v_branch and vs.state = 'active'
    ), '[]'::jsonb)
  );
end $$;
grant execute on function public.get_public_display(text) to anon, authenticated;
