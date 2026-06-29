-- Queue.ai — 0019 Flow Intelligence v2 (Phase 16.5): Predictive Operations (F13),
-- Capacity AI (F2), and Simulation (F5) — heuristic now, improves with pilot data.
-- All computed live from the queue + staff state; honest estimates (labeled in UI).

-- Predictive Operations: per-department forward look + a recommended action.
create or replace function public.get_predictive_ops(p_branch_id uuid, p_threshold_min int default 20)
returns jsonb language plpgsql security definer set search_path = public, app as $$
declare v_org uuid; v_out jsonb;
begin
  select organization_id into v_org from branches where id = p_branch_id;
  if v_org is null or v_org <> app.current_org() then raise exception 'forbidden'; end if;

  select coalesce(jsonb_agg(w order by (w->>'clear_min')::numeric desc), '[]'::jsonb) into v_out
  from (
    select jsonb_build_object(
      'department', d.name,
      'waiting', wq.waiting,
      'servers', wq.servers,
      'clear_min', round(wq.clear_s / 60.0),
      'recommend', 'Move 1 staff to ' || d.name || ' (or open a counter)',
      'projected_clear_min', round((wq.waiting * wq.avg_s) / ((wq.servers + 1)) / 60.0)
    ) as w
    from departments d
    join lateral (
      select
        count(vs.id) filter (where vs.state = 'active') as waiting,
        greatest((select count(*) from staff s
                   where s.department_id = d.id and s.status = 'online' and s.deleted_at is null), 1) as servers,
        coalesce((select avg(sv.avg_duration_seconds) from services sv where sv.department_id = d.id), 600) as avg_s,
        (count(vs.id) filter (where vs.state = 'active')
           * coalesce((select avg(sv.avg_duration_seconds) from services sv where sv.department_id = d.id), 600))
          / greatest((select count(*) from staff s
                       where s.department_id = d.id and s.status = 'online' and s.deleted_at is null), 1) as clear_s
      from visit_stages vs
      join visits v on v.id = vs.visit_id and v.branch_id = p_branch_id
      where vs.department_id = d.id
    ) wq on true
    where d.branch_id = p_branch_id
      and wq.clear_s / 60.0 > p_threshold_min          -- only surface real risks
  ) sub;
  return v_out;
end $$;
grant execute on function public.get_predictive_ops(uuid, int) to authenticated;

-- Simulation: project branch-wide avg wait under a staffing change (what-if).
create or replace function public.simulate_branch(p_branch_id uuid, p_add_staff int default 0, p_remove_staff int default 0)
returns jsonb language plpgsql security definer set search_path = public, app as $$
declare v_org uuid; v_wait int; v_servers int; v_avg numeric; v_new int; v_cur_min numeric; v_proj_min numeric;
begin
  select organization_id into v_org from branches where id = p_branch_id;
  if v_org is null or v_org <> app.current_org() then raise exception 'forbidden'; end if;

  select count(*) into v_wait from visit_stages vs join visits v on v.id = vs.visit_id
   where v.branch_id = p_branch_id and vs.state = 'active';
  select greatest(count(*),1) into v_servers from staff s join departments d on d.id = s.department_id
   where d.branch_id = p_branch_id and s.status = 'online' and s.deleted_at is null;
  select coalesce(avg(sv.avg_duration_seconds), 600) into v_avg from services sv
   join departments d on d.id = sv.department_id where d.branch_id = p_branch_id;

  v_new := greatest(v_servers + p_add_staff - p_remove_staff, 1);
  v_cur_min  := round((v_wait * v_avg) / v_servers / 60.0, 1);
  v_proj_min := round((v_wait * v_avg) / v_new     / 60.0, 1);

  return jsonb_build_object(
    'waiting', v_wait, 'servers', v_servers, 'new_servers', v_new,
    'current_avg_wait_min', v_cur_min, 'projected_avg_wait_min', v_proj_min,
    'delta_pct', case when v_cur_min > 0 then round((v_proj_min - v_cur_min) / v_cur_min * 100) else 0 end
  );
end $$;
grant execute on function public.simulate_branch(uuid, int, int) to authenticated;
