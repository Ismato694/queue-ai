-- Queue.ai — 0017 fix RLS recursion (Sprint S1 hotfix)
-- BUG: staff RLS policy uses app.current_org(), and app.current_org() read from `staff`
-- under RLS → the lookup filtered itself out → org resolved to NULL → app stuck on onboarding.
-- FIX: make the resolver functions SECURITY DEFINER so their internal staff lookup
-- bypasses RLS (breaking the circular dependency).

create or replace function app.current_org() returns uuid
language sql stable security definer set search_path = public, app as $$
  select coalesce(
    nullif(current_setting('app.current_org', true), '')::uuid,
    nullif(current_setting('request.jwt.claims', true)::jsonb ->> 'organization_id', '')::uuid,
    (select s.organization_id from public.staff s
       where s.user_id = auth.uid() and s.deleted_at is null limit 1)
  )
$$;

create or replace function app.current_role() returns text
language sql stable security definer set search_path = public, app as $$
  select coalesce(
    nullif(current_setting('app.current_role', true), ''),
    current_setting('request.jwt.claims', true)::jsonb ->> 'role',
    (select s.role::text from public.staff s
       where s.user_id = auth.uid() and s.deleted_at is null limit 1)
  )
$$;

grant execute on function app.current_org()  to anon, authenticated;
grant execute on function app.current_role() to anon, authenticated;
