-- Queue.ai — 0014 Manager overview: Flow Score + Digital Twin + Time-Saved (Sprint S5)
-- All computed from LIVE data (docs/07 §8, F8/F12/F3-lite, Law #0). No AI here.

create or replace function public.get_flow_overview(p_branch_id uuid)
returns jsonb language plpgsql security definer set search_path = public, app as $$
declare
  v_org uuid; v_baseline int;
  v_waiting int; v_avg_wait numeric; v_served int; v_created int;
  v_no_show int; v_done_stages int; v_no_show_rate numeric;
  v_wait_perf numeric; v_completion numeric; v_score int;
  v_time_saved bigint; v_depts jsonb;
begin
  select organization_id, coalesce((settings->>'baseline_wait_seconds')::int, 2400)
    into v_org, v_baseline from branches where id = p_branch_id;
  if v_org is null or v_org <> app.current_org() then raise exception 'forbidden'; end if;

  -- live waiting
  select count(*) into v_waiting from visit_stages vs join visits v on v.id = vs.visit_id
   where v.branch_id = p_branch_id and vs.state = 'active';

  -- today's actual wait (active -> called)
  select coalesce(avg(extract(epoch from (vs.called_at - vs.activated_at))), 0)
    into v_avg_wait from visit_stages vs join visits v on v.id = vs.visit_id
   where v.branch_id = p_branch_id and vs.called_at >= current_date and vs.activated_at is not null;

  select count(*) into v_served from visits
   where branch_id = p_branch_id and status = 'completed' and completed_at >= current_date;
  select count(*) into v_created from visits
   where branch_id = p_branch_id and created_at >= current_date;
  select count(*) into v_no_show from visit_stages vs join visits v on v.id = vs.visit_id
   where v.branch_id = p_branch_id and vs.state = 'no_show' and vs.entered_state_at >= current_date;
  select count(*) into v_done_stages from visit_stages vs join visits v on v.id = vs.visit_id
   where v.branch_id = p_branch_id and vs.state = 'completed' and vs.completed_at >= current_date;

  v_no_show_rate := case when (v_no_show + v_done_stages) > 0
    then v_no_show::numeric / (v_no_show + v_done_stages) else 0 end;
  v_wait_perf := least(v_baseline::numeric / greatest(v_avg_wait, 1), 1);
  v_completion := case when v_created > 0 then least(v_served::numeric / v_created, 1) else 1 end;

  -- Flow Score (F12) — weighted composite, 0..100
  v_score := round(100 * (0.5 * v_wait_perf + 0.25 * (1 - v_no_show_rate) + 0.25 * v_completion));

  -- Total Time Saved estimate (Law #0): served × (baseline − actual avg wait)
  v_time_saved := greatest(0, v_served * (v_baseline - round(v_avg_wait)));

  -- Digital Twin (F3-lite): per-department live status
  select coalesce(jsonb_agg(t order by t->>'name'), '[]'::jsonb) into v_depts from (
    select jsonb_build_object(
      'name', d.name,
      'waiting', count(vs.id) filter (where vs.state = 'active'),
      'longest_wait_s', coalesce(max(extract(epoch from (now() - vs.entered_state_at)))
                                 filter (where vs.state = 'active'), 0),
      'status', case
        when coalesce(max(extract(epoch from (now() - vs.entered_state_at)))
              filter (where vs.state = 'active'),0) > 1200
          or count(vs.id) filter (where vs.state = 'active') > 8 then 'delayed'
        when count(vs.id) filter (where vs.state = 'active') > 3 then 'busy'
        else 'calm' end
    ) as t
    from departments d
    left join visit_stages vs on vs.department_id = d.id
      and vs.organization_id = v_org
    left join visits v on v.id = vs.visit_id and v.branch_id = p_branch_id
    where d.branch_id = p_branch_id
    group by d.id, d.name
  ) sub;

  return jsonb_build_object(
    'flow_score', v_score,
    'waiting_total', v_waiting,
    'avg_wait_seconds', round(v_avg_wait),
    'no_show_rate', round(v_no_show_rate, 4),
    'served_today', v_served,
    'time_saved_seconds', v_time_saved,
    'departments', v_depts
  );
end $$;
grant execute on function public.get_flow_overview(uuid) to authenticated;
