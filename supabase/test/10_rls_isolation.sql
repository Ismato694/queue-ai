-- RLS tenant-isolation test (audit C1): an authenticated user scoped to Org A must NOT
-- see Org B's rows. Raises on leak. Run after migrations on a fresh test DB.

-- seed two orgs + branches as superuser (RLS bypassed here)
insert into organizations (id, name, slug) values
  ('11111111-1111-1111-1111-111111111111','Org A','org-a'),
  ('22222222-2222-2222-2222-222222222222','Org B','org-b')
on conflict (id) do nothing;
insert into branches (organization_id, name) values
  ('11111111-1111-1111-1111-111111111111','A-Branch'),
  ('22222222-2222-2222-2222-222222222222','B-Branch-1'),
  ('22222222-2222-2222-2222-222222222222','B-Branch-2');

-- act as an authenticated user whose org is A
begin;
  set local role authenticated;
  set local "request.jwt.claims" = '{"organization_id":"11111111-1111-1111-1111-111111111111"}';
  do $$
  declare c_branch int; c_org int;
  begin
    select count(*) into c_branch from branches;
    select count(*) into c_org from organizations;
    assert c_branch = 1, format('RLS LEAK: Org A sees %s branches (expected 1)', c_branch);
    assert c_org    = 1, format('RLS LEAK: Org A sees %s orgs (expected 1)', c_org);
    raise notice 'RLS ISOLATION PASSED ✓ (Org A sees only its own org + branch)';
  end $$;
rollback;
