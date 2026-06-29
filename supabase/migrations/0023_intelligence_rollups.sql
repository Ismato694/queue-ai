-- Queue.ai — 0023 (audit H1 + M5): populate the intelligence/metric backbone.
-- Worker (service_role) calls these on a schedule. Turns the empty tables into real
-- history → Flow Score trend, Capacity AI/Org-Memory data source, cheaper dashboards.
-- (Per-staff throughput needs assigned-staff capture; for now we roll up per department.)

create or replace function public.rollup_throughput(p_window_min int default 60)
returns int language plpgsql security definer set search_path = public, app as $$
declare n int := 0; r record;
begin
  for r in
    select vs.organization_id, vs.department_id,
           count(*) c, avg(extract(epoch from (vs.completed_at - vs.serving_at)))::int avg_s
    from visit_stages vs
    where vs.completed_at > now() - make_interval(mins => p_window_min)
      and vs.serving_at is not null
    group by vs.organization_id, vs.department_id
  loop
    insert into staff_throughput
      (organization_id, staff_id, department_id, window_start, window_end, served_count, avg_service_seconds, idle_seconds)
    values (r.organization_id, null, r.department_id,
            now() - make_interval(mins => p_window_min), now(), r.c, r.avg_s, 0);
    n := n + 1;
  end loop;
  return n;
end $$;
grant execute on function public.rollup_throughput(int) to service_role;

create or replace function public.rollup_daily_metrics()
returns int language plpgsql security definer set search_path = public, app as $$
declare n int := 0; b record;
        v_avg numeric; v_served int; v_created int; v_noshow int; v_done int;
        v_nsr numeric; v_wp numeric; v_comp numeric; v_score int; v_saved bigint;
begin
  for b in select id, organization_id,
                  coalesce((settings->>'baseline_wait_seconds')::int, 2400) baseline from branches loop
    select coalesce(avg(extract(epoch from (vs.called_at - vs.activated_at))), 0) into v_avg
      from visit_stages vs join visits v on v.id = vs.visit_id
      where v.branch_id = b.id and vs.called_at >= current_date and vs.activated_at is not null;
    select count(*) into v_served from visits where branch_id = b.id and status='completed' and completed_at >= current_date;
    select count(*) into v_created from visits where branch_id = b.id and created_at >= current_date;
    select count(*) into v_noshow from visit_stages vs join visits v on v.id = vs.visit_id
      where v.branch_id = b.id and vs.state='no_show' and vs.entered_state_at >= current_date;
    select count(*) into v_done from visit_stages vs join visits v on v.id = vs.visit_id
      where v.branch_id = b.id and vs.state='completed' and vs.completed_at >= current_date;

    v_nsr  := case when (v_noshow+v_done) > 0 then v_noshow::numeric/(v_noshow+v_done) else 0 end;
    v_wp   := least(b.baseline::numeric / greatest(v_avg,1), 1);
    v_comp := case when v_created > 0 then least(v_served::numeric/v_created, 1) else 1 end;
    v_score := round(100 * (0.5*v_wp + 0.25*(1-v_nsr) + 0.25*v_comp));
    v_saved := greatest(0, v_served * (b.baseline - round(v_avg)));

    insert into daily_metrics
      (organization_id, branch_id, metric_date, flow_score, avg_wait_seconds, no_show_rate, time_saved_seconds)
    values (b.organization_id, b.id, current_date, v_score, round(v_avg), round(v_nsr,4), v_saved)
    on conflict (branch_id, metric_date) do update set
      flow_score = excluded.flow_score, avg_wait_seconds = excluded.avg_wait_seconds,
      no_show_rate = excluded.no_show_rate, time_saved_seconds = excluded.time_saved_seconds;
    n := n + 1;
  end loop;
  return n;
end $$;
grant execute on function public.rollup_daily_metrics() to service_role;
