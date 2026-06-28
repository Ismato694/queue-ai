-- Queue.ai — 0016 Hours Returned (first-class mission KPI, Law #0)
-- Today / This Month / Since joining, per branch. Estimate: served × (baseline − avg wait).

create or replace function app.hours_returned_since(p_branch uuid, p_baseline int, p_since timestamptz)
returns bigint language sql stable as $$
  with served as (
    select count(*) c from visits
    where branch_id = p_branch and status = 'completed'
      and (p_since is null or completed_at >= p_since)
  ),
  wait as (
    select coalesce(avg(extract(epoch from (vs.called_at - vs.activated_at))), 0) w
    from visit_stages vs join visits v on v.id = vs.visit_id
    where v.branch_id = p_branch and vs.activated_at is not null and vs.called_at is not null
      and (p_since is null or vs.called_at >= p_since)
  )
  select greatest(0, (select c from served) * (p_baseline - round((select w from wait))))::bigint
$$;

create or replace function public.get_hours_returned(p_branch_id uuid)
returns jsonb language plpgsql security definer set search_path = public, app as $$
declare v_org uuid; v_baseline int;
begin
  select organization_id, coalesce((settings->>'baseline_wait_seconds')::int, 2400)
    into v_org, v_baseline from branches where id = p_branch_id;
  if v_org is null or v_org <> app.current_org() then raise exception 'forbidden'; end if;

  return jsonb_build_object(
    'today_seconds',    app.hours_returned_since(p_branch_id, v_baseline, current_date),
    'month_seconds',    app.hours_returned_since(p_branch_id, v_baseline, date_trunc('month', now())),
    'lifetime_seconds', app.hours_returned_since(p_branch_id, v_baseline, null)
  );
end $$;
grant execute on function public.get_hours_returned(uuid) to authenticated;
