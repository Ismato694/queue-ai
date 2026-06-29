-- Queue.ai — 0024 (audit M1/M2/M5): single transition authority, baseline helper,
-- and rollup-backed Hours Returned (stop scanning all history per dashboard load).

-- M1 — canonical state-machine transitions in SQL (mirrors packages/shared STAGE_TRANSITIONS).
create or replace function app.can_transition(p_from stage_state, p_to stage_state)
returns boolean language sql immutable as $$
  select (p_from, p_to) in (
    ('booked','pre_queue'), ('booked','active'), ('booked','cancelled'), ('booked','expired'),
    ('pre_queue','active'), ('pre_queue','cancelled'), ('pre_queue','expired'),
    ('active','called'), ('active','cancelled'),
    ('called','serving'), ('called','no_show'), ('called','active'),
    ('serving','completed'), ('serving','transferred'), ('serving','active'),
    ('transferred','active')
  )
$$;
create or replace function app.assert_transition(p_from stage_state, p_to stage_state)
returns void language plpgsql as $$
begin
  if not app.can_transition(p_from, p_to) then
    raise exception 'illegal stage transition: % -> %', p_from, p_to;
  end if;
end $$;

-- M2 — single source for a branch's baseline wait (was duplicated in 4 functions).
create or replace function app.branch_baseline(p_branch uuid)
returns int language sql stable as $$
  select coalesce((settings->>'baseline_wait_seconds')::int, 2400) from branches where id = p_branch
$$;

-- M5 — Hours Returned reads pre-aggregated daily_metrics (cheap) + live "today",
-- instead of scanning every visit in history on each dashboard load.
create or replace function public.get_hours_returned(p_branch_id uuid)
returns jsonb language plpgsql security definer set search_path = public, app as $$
declare v_org uuid; v_baseline int; v_today bigint; v_month bigint; v_life bigint;
begin
  select organization_id into v_org from branches where id = p_branch_id;
  if v_org is null or v_org <> app.current_org() then raise exception 'forbidden'; end if;
  v_baseline := app.branch_baseline(p_branch_id);

  v_today := app.hours_returned_since(p_branch_id, v_baseline, current_date);
  v_month := coalesce((select sum(time_saved_seconds) from daily_metrics
              where branch_id = p_branch_id
                and metric_date >= date_trunc('month', now())::date
                and metric_date < current_date), 0) + v_today;
  v_life  := coalesce((select sum(time_saved_seconds) from daily_metrics
              where branch_id = p_branch_id and metric_date < current_date), 0) + v_today;

  return jsonb_build_object('today_seconds', v_today, 'month_seconds', v_month, 'lifetime_seconds', v_life);
end $$;
grant execute on function public.get_hours_returned(uuid) to authenticated;
