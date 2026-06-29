-- Queue.ai — 0026 (compliance gap, audit H1/07 §11): Trust-Engine accuracy loop.
-- Snapshot a prediction when a stage goes active; score it (actual vs band) when called.
-- Worker (service_role) runs these on a schedule → predictions table populated + calibratable.

alter table predictions add column if not exists actual_seconds int;
alter table predictions add column if not exists within_band   boolean;

-- snapshot ETA predictions for current active stages that don't have one yet
create or replace function public.snapshot_active_predictions()
returns int language plpgsql security definer set search_path = public, app as $$
declare n int := 0; r record;
        v_ahead int; v_servers int; v_avg int; v_pending int; v_eta int; v_conf numeric; v_half int;
begin
  for r in
    select vs.id, vs.organization_id, vs.department_id, vs.position, vs.acuity, v.branch_id, fs.est_duration_seconds
    from visit_stages vs
    join visits v on v.id = vs.visit_id
    join flow_stages fs on fs.id = vs.flow_stage_id
    where vs.state = 'active' and vs.is_current
      and not exists (select 1 from predictions p where p.visit_stage_id = vs.id)
  loop
    select count(*) into v_ahead from visit_stages a
      where a.department_id = r.department_id and a.state = 'active'
        and (a.acuity > r.acuity or (a.acuity = r.acuity and coalesce(a.position,0) < coalesce(r.position,0)));
    select greatest(count(*),1) into v_servers from staff s
      where s.department_id = r.department_id and s.status='online' and s.deleted_at is null;
    v_avg := coalesce(r.est_duration_seconds, 600);
    select coalesce(sum(fs.est_duration_seconds),0) into v_pending
      from visit_stages vs2 join flow_stages fs on fs.id = vs2.flow_stage_id
      where vs2.visit_id = (select visit_id from visit_stages where id = r.id) and vs2.state = 'booked';
    v_eta := (v_ahead * v_avg) / v_servers + v_pending;
    v_conf := 0.7;  -- snapshot confidence prior (calibrated over time from within_band rate)
    v_half := floor((1 - v_conf) * v_eta * 0.4);

    insert into predictions
      (organization_id, visit_stage_id, branch_id, department_id, kind, value_low_s, value_high_s, confidence, reasons)
    values (r.organization_id, r.id, r.branch_id, r.department_id, 'stage_eta',
            greatest(v_eta - v_half, 0), v_eta + v_half, v_conf,
            jsonb_build_array('snapshot at activation'));
    n := n + 1;
  end loop;
  return n;
end $$;
grant execute on function public.snapshot_active_predictions() to service_role;

-- score predictions once their stage has been called (actual wait known)
create or replace function public.score_pending_predictions()
returns int language plpgsql security definer set search_path = public, app as $$
declare n int := 0; r record; v_actual int;
begin
  for r in
    select p.id, vs.activated_at, vs.called_at, p.value_low_s, p.value_high_s
    from predictions p join visit_stages vs on vs.id = p.visit_stage_id
    where p.actual_seconds is null and vs.called_at is not null and vs.activated_at is not null
  loop
    v_actual := extract(epoch from (r.called_at - r.activated_at))::int;
    update predictions set actual_seconds = v_actual,
      within_band = (v_actual between coalesce(value_low_s,0) and coalesce(value_high_s, 2147483647))
    where id = r.id;
    n := n + 1;
  end loop;
  return n;
end $$;
grant execute on function public.score_pending_predictions() to service_role;

-- accuracy summary (for the Trust-Engine honesty metric: % within band)
create or replace function public.prediction_accuracy(p_branch_id uuid)
returns jsonb language plpgsql security definer set search_path = public, app as $$
declare v_org uuid; v_total int; v_hit int;
begin
  select organization_id into v_org from branches where id = p_branch_id;
  if v_org is null or v_org <> app.current_org() then raise exception 'forbidden'; end if;
  select count(*), count(*) filter (where within_band) into v_total, v_hit
  from predictions where branch_id = p_branch_id and actual_seconds is not null;
  return jsonb_build_object('scored', v_total, 'within_band', v_hit,
    'accuracy', case when v_total > 0 then round(v_hit::numeric/v_total, 3) else null end);
end $$;
grant execute on function public.prediction_accuracy(uuid) to authenticated;
