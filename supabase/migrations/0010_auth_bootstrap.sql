-- Queue.ai — 0010 auth wiring + bootstrap RPCs (Sprint S1)
-- Makes RLS work with plain Supabase Auth: current org/role resolve from the signed-in
-- user's staff row (no custom JWT-claims hook needed for MVP). Worker still uses the
-- explicit app.current_org setting / service role.

create or replace function app.current_org() returns uuid
language sql stable as $$
  select coalesce(
    nullif(current_setting('app.current_org', true), '')::uuid,
    nullif(current_setting('request.jwt.claims', true)::jsonb ->> 'organization_id', '')::uuid,
    (select s.organization_id from public.staff s
       where s.user_id = auth.uid() and s.deleted_at is null limit 1)
  )
$$;

create or replace function app.current_role() returns text
language sql stable as $$
  select coalesce(
    nullif(current_setting('app.current_role', true), ''),
    current_setting('request.jwt.claims', true)::jsonb ->> 'role',
    (select s.role::text from public.staff s
       where s.user_id = auth.uid() and s.deleted_at is null limit 1)
  )
$$;

-- Bootstrap: a newly-signed-up user creates their org + first admin staff + first branch,
-- atomically, bypassing RLS via SECURITY DEFINER. One org per user in MVP.
create or replace function public.bootstrap_organization(p_org_name text, p_branch_name text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_org uuid; v_email text;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if exists (select 1 from staff where user_id = auth.uid()) then
    raise exception 'user already belongs to an organization';
  end if;
  v_email := coalesce((auth.jwt() ->> 'email'), 'Admin');

  insert into organizations (name, slug)
  values (p_org_name,
          lower(regexp_replace(p_org_name, '[^a-zA-Z0-9]+', '-', 'g')) || '-' || substr(gen_random_uuid()::text,1,6))
  returning id into v_org;

  insert into staff (organization_id, user_id, display_name, role, status)
  values (v_org, auth.uid(), v_email, 'org_admin', 'offline');

  insert into branches (organization_id, name) values (v_org, p_branch_name);
  return v_org;
end $$;
grant execute on function public.bootstrap_organization(text, text) to authenticated;

-- Publish a flow: snapshot stages into a new immutable version and mark it current.
create or replace function public.publish_flow(p_flow_id uuid, p_stages jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_org uuid; v_ver uuid; v_no int; s jsonb; pos int := 0;
begin
  select organization_id into v_org from flows where id = p_flow_id;
  if v_org is null then raise exception 'flow not found'; end if;
  if v_org <> app.current_org() then raise exception 'forbidden'; end if;

  select coalesce(max(version_no), 0) + 1 into v_no from flow_versions where flow_id = p_flow_id;
  insert into flow_versions (flow_id, version_no, created_by)
  values (p_flow_id, v_no, auth.uid()) returning id into v_ver;

  for s in select * from jsonb_array_elements(p_stages) loop
    pos := pos + 1;
    insert into flow_stages
      (flow_version_id, position, name, department_id, service_id,
       est_duration_seconds, requires_triage, is_optional)
    values
      (v_ver, pos, s ->> 'name',
       nullif(s ->> 'department_id','')::uuid, nullif(s ->> 'service_id','')::uuid,
       coalesce((s ->> 'est_duration_seconds')::int, 600),
       coalesce((s ->> 'requires_triage')::boolean, false),
       coalesce((s ->> 'is_optional')::boolean, false));
  end loop;

  update flows set current_version_id = v_ver, is_published = true, updated_at = now()
  where id = p_flow_id;
  return v_ver;
end $$;
grant execute on function public.publish_flow(uuid, jsonb) to authenticated;
