-- Queue.ai — 0022 (audit C2 + H3): encrypt patient phone at rest + rate-limit public join.
-- C2: phone stored as pgcrypto-encrypted bytea + HMAC blind index for unique lookup.
--     Decrypt key lives in app.crypto_key (locked down); only SECURITY DEFINER funcs use it.
-- H3: join_queue throttles repeat joins per phone+branch (anti-spam/DoS).

-- ── Key store (no direct access by app roles) ──────────────────────────────────
create table if not exists app.crypto_key (id int primary key default 1, key bytea not null);
insert into app.crypto_key (id, key) values (1, gen_random_bytes(32)) on conflict (id) do nothing;
revoke all on app.crypto_key from public;

-- ── Crypto helpers (definer; key never leaves these functions) ─────────────────
-- NOTE: pgcrypto lives in the `extensions` schema on Supabase (in `public` on a bare
-- Postgres). Include both in search_path so pgp_sym_*/hmac resolve in either env.
create or replace function app.enc(p text) returns bytea
  language sql security definer set search_path = app, public, extensions as
$$ select pgp_sym_encrypt(p, encode((select key from app.crypto_key where id=1),'hex')) $$;

create or replace function app.dec(p bytea) returns text
  language sql security definer set search_path = app, public, extensions as
$$ select case when p is null then null
              else pgp_sym_decrypt(p, encode((select key from app.crypto_key where id=1),'hex')) end $$;

create or replace function app.bidx(p text) returns text
  language sql security definer set search_path = app, public, extensions as
$$ select encode(hmac(p, encode((select key from app.crypto_key where id=1),'hex'), 'sha256'),'hex') $$;

-- masked display for staff (last 4 only) — the only crypto helper app roles may call
create or replace function app.phone_last4(p bytea) returns text
  language sql security definer set search_path = app, public, extensions as
$$ select case when p is null then null else '••••' || right(app.dec(p), 4) end $$;

-- 0020 default-grants new app functions to anon/authenticated; lock the sensitive ones back down
revoke execute on function app.enc(text)  from anon, authenticated;
revoke execute on function app.dec(bytea) from anon, authenticated;
revoke execute on function app.bidx(text) from anon, authenticated;
revoke execute on function app.phone_last4(bytea) from anon;        -- staff only
grant  execute on function app.phone_last4(bytea) to authenticated;

-- ── Migrate customers.phone → encrypted columns ───────────────────────────────
alter table customers add column if not exists phone_enc  bytea;
alter table customers add column if not exists phone_bidx text;
update customers set phone_enc = app.enc(phone), phone_bidx = app.bidx(phone)
  where phone is not null and phone_bidx is null;
alter table customers drop constraint if exists customers_phone_key;
alter table customers drop column if exists phone;
create unique index if not exists customers_phone_bidx_key on customers (phone_bidx);

-- ── Rewrite join RPCs to use enc/bidx (+ H3 throttle) ─────────────────────────
create or replace function public.join_queue(
  p_branch_token text, p_flow_id uuid, p_name text, p_phone text,
  p_channel join_channel default 'web', p_immediate boolean default false
) returns uuid language plpgsql security definer set search_path = public, app as $$
declare
  v_org uuid; v_branch uuid; v_ver uuid; v_cust uuid; v_link uuid; v_visit uuid;
  v_first uuid; r record; first_done boolean := false; v_state stage_state; v_pos int; v_recent int;
begin
  select id, organization_id into v_branch, v_org from branches where qr_token = p_branch_token;
  if v_branch is null then raise exception 'branch not found'; end if;

  if p_flow_id is null then
    select id into p_flow_id from flows where organization_id = v_org and is_published order by created_at limit 1;
  end if;
  select current_version_id into v_ver from flows where id = p_flow_id and organization_id = v_org;
  if v_ver is null then raise exception 'no published flow'; end if;

  insert into customers (phone_enc, phone_bidx, full_name)
    values (app.enc(p_phone), app.bidx(p_phone), p_name)
    on conflict (phone_bidx) do update set full_name = coalesce(excluded.full_name, customers.full_name)
    returning id into v_cust;
  insert into customer_org_link (organization_id, customer_id) values (v_org, v_cust)
    on conflict (organization_id, customer_id)
      do update set last_seen = now(), visit_count = customer_org_link.visit_count + 1
    returning id into v_link;

  -- H3: throttle repeat joins (max 3 per phone per branch / 2 min)
  select count(*) into v_recent from visits v
    where v.customer_org_link_id = v_link and v.branch_id = v_branch
      and v.created_at > now() - interval '2 minutes';
  if v_recent >= 3 then raise exception 'too many requests — please wait a moment'; end if;

  insert into visits (organization_id, branch_id, customer_org_link_id, flow_version_id, channel)
    values (v_org, v_branch, v_link, v_ver, p_channel) returning id into v_visit;

  for r in select id, department_id from flow_stages where flow_version_id = v_ver order by position loop
    if not first_done then
      if p_immediate then v_state := 'active'; v_pos := app.next_position(v_org, r.department_id);
      else v_state := 'pre_queue'; v_pos := null; end if;
      insert into visit_stages
        (organization_id, visit_id, flow_stage_id, department_id, state, position,
         entered_state_at, pre_queue_at, activated_at, activation_trigger, is_current)
      values (v_org, v_visit, r.id, r.department_id, v_state, v_pos, now(), now(),
              case when p_immediate then now() else null end,
              case when p_immediate then 'qr'::activation_trigger else null end, true)
      returning id into v_first;
      first_done := true;
    else
      insert into visit_stages (organization_id, visit_id, flow_stage_id, department_id, state)
      values (v_org, v_visit, r.id, r.department_id, 'booked');
    end if;
  end loop;

  perform app.log_event(v_org, v_branch, 'visit_stage', v_first, 'state_change', null, v_state::text,
                        jsonb_build_object('reason','self_join','channel',p_channel));
  return v_visit;
end $$;
grant execute on function public.join_queue(text,uuid,text,text,join_channel,boolean) to anon, authenticated;

create or replace function public.create_walkin_visit(
  p_branch_id uuid, p_flow_id uuid, p_name text, p_phone text, p_acuity acuity default 'routine'
) returns uuid language plpgsql security definer set search_path = public, app as $$
declare
  v_org uuid; v_ver uuid; v_cust uuid; v_link uuid; v_visit uuid;
  v_first uuid; r record; v_pos int; first_done boolean := false;
begin
  select organization_id into v_org from branches where id = p_branch_id;
  if v_org is null or v_org <> app.current_org() then raise exception 'forbidden'; end if;
  if p_flow_id is null then
    select id into p_flow_id from flows where organization_id = v_org and is_published order by created_at limit 1;
  end if;
  select current_version_id into v_ver from flows where id = p_flow_id;
  if v_ver is null then raise exception 'no published flow'; end if;

  insert into customers (phone_enc, phone_bidx, full_name)
    values (app.enc(p_phone), app.bidx(p_phone), p_name)
    on conflict (phone_bidx) do update set full_name = coalesce(excluded.full_name, customers.full_name)
    returning id into v_cust;
  insert into customer_org_link (organization_id, customer_id) values (v_org, v_cust)
    on conflict (organization_id, customer_id)
      do update set last_seen = now(), visit_count = customer_org_link.visit_count + 1
    returning id into v_link;

  insert into visits (organization_id, branch_id, customer_org_link_id, flow_version_id, acuity, channel)
    values (v_org, p_branch_id, v_link, v_ver, p_acuity, 'receptionist') returning id into v_visit;

  for r in select fs.id, fs.department_id from flow_stages fs where fs.flow_version_id = v_ver order by fs.position loop
    if not first_done then
      v_pos := app.next_position(v_org, r.department_id);
      insert into visit_stages
        (organization_id, visit_id, flow_stage_id, department_id, state, position, acuity,
         entered_state_at, pre_queue_at, activated_at, activation_trigger, is_current)
      values (v_org, v_visit, r.id, r.department_id, 'active', v_pos, p_acuity,
              now(), now(), now(), 'receptionist', true)
      returning id into v_first;
      first_done := true;
    else
      insert into visit_stages (organization_id, visit_id, flow_stage_id, department_id, state, acuity)
      values (v_org, v_visit, r.id, r.department_id, 'booked', p_acuity);
    end if;
  end loop;

  perform app.log_event(v_org, p_branch_id, 'visit_stage', v_first, 'state_change', null, 'active',
                        jsonb_build_object('reason','walkin_created'));
  return v_visit;
end $$;
grant execute on function public.create_walkin_visit(uuid,uuid,text,text,acuity) to authenticated;

-- ── reception_queue: mask phone (last 4 only) ─────────────────────────────────
create or replace view reception_queue with (security_invoker = true) as
select
  vs.id as stage_id, vs.organization_id, v.branch_id, vs.department_id, d.name as department_name,
  vs.visit_id, vs.state, vs.acuity, vs.position, vs.entered_state_at, vs.grace_deadline,
  upper(substr(replace(vs.id::text,'-',''),1,6)) as ticket_no,
  c.full_name as patient_name,
  app.phone_last4(c.phone_enc) as patient_phone
from visit_stages vs
join visits v on v.id = vs.visit_id
join departments d on d.id = vs.department_id
left join customer_org_link l on l.id = v.customer_org_link_id
left join customers c on c.id = l.customer_id
where vs.state in ('active','called','serving');
