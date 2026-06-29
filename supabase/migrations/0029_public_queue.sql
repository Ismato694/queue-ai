-- Queue.ai — 0029 (F10): Anonymous Public Queue.
-- A no-PII, opt-in (branches.publish_public_wait) wait board people can check
-- *before* coming in. Aggregates per department only — never a name or phone (R3).

create or replace function public.get_public_wait(p_branch_token text)
returns jsonb language plpgsql security definer set search_path = public, app as $$
declare v_branch uuid; v_name text; v_opt boolean; v_depts jsonb;
begin
  select id, name, publish_public_wait into v_branch, v_name, v_opt
  from branches where qr_token = p_branch_token and deleted_at is null;
  if v_branch is null then raise exception 'branch not found'; end if;
  if not coalesce(v_opt, false) then
    return jsonb_build_object('available', false, 'branch_name', v_name);
  end if;

  select coalesce(jsonb_agg(d_row order by d_row->>'department_name'), '[]'::jsonb) into v_depts
  from (
    select jsonb_build_object(
      'department_name', d.name,
      'waiting', count(*) filter (where vs.state = 'active'),
      'now_serving', (
        select upper(substr(replace(s.id::text,'-',''),1,6))
        from visit_stages s where s.department_id = d.id and s.state in ('called','serving')
        order by s.entered_state_at desc limit 1
      ),
      'est_wait_min', greatest(1, round(
        (count(*) filter (where vs.state = 'active'))
        * coalesce((select avg(fs.est_duration_seconds) from flow_stages fs where fs.department_id = d.id), 600)
        / greatest((select count(*) from staff st where st.department_id = d.id and st.status='online' and st.deleted_at is null), 1)
        / 60.0
      ))
    ) as d_row
    from departments d
    left join visit_stages vs on vs.department_id = d.id and vs.state in ('active','called','serving')
    where d.branch_id = v_branch
    group by d.id, d.name
  ) t;

  return jsonb_build_object('available', true, 'branch_name', v_name, 'departments', v_depts);
end $$;
grant execute on function public.get_public_wait(text) to anon, authenticated;
