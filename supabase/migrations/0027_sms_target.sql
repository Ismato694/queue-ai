-- Queue.ai — 0027 (compliance gap, R6): let the trusted worker resolve an SMS recipient.
-- Phone is encrypted (0022); the SMS provider needs the real number. This definer RPC
-- decrypts ONLY for service_role (the worker), keeping phones opaque to app roles.

create or replace function public.get_sms_target(p_notification_id uuid)
returns jsonb language sql security definer set search_path = public, app as $$
  select jsonb_build_object('phone', app.dec(c.phone_enc), 'event_type', n.event_type)
  from notifications n
  join customers c on c.id = n.customer_id
  where n.id = p_notification_id and c.phone_enc is not null
$$;
revoke execute on function public.get_sms_target(uuid) from anon, authenticated;
grant execute on function public.get_sms_target(uuid) to service_role;
