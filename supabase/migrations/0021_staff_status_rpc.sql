-- Queue.ai — 0021 (audit H4): staff status via an event-emitting RPC.
-- Was a direct table write → no activity_event, no ETA-impact signal (broke 06 §4 + OPS-3).

create or replace function public.set_staff_status(p_status staff_status)
returns void language plpgsql security definer set search_path = public, app as $$
declare v_org uuid; v_staff uuid; v_before staff_status;
begin
  select id, organization_id, status into v_staff, v_org, v_before
  from staff where user_id = auth.uid() and deleted_at is null limit 1;
  if v_staff is null then raise exception 'not a staff member'; end if;

  update staff set status = p_status, updated_at = now() where id = v_staff;
  -- the event lets the worker recompute ETAs / notify affected patients (OPS-3)
  perform app.log_event(v_org, null, 'staff', v_staff, 'staff_status', v_before::text, p_status::text);
end $$;
grant execute on function public.set_staff_status(staff_status) to authenticated;
