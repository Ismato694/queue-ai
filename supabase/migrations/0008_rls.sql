-- Queue.ai — 0008 Row-Level Security (docs/04-DATABASE.md §9, docs/08-SECURITY.md §4)
-- Tenant isolation: every tenant table is readable/writable only within app.current_org().
-- The worker/service role connects with the Supabase service key, which BYPASSES RLS by design.

-- helper: generic tenant policy applied to a table with an organization_id column
do $$
declare t text;
begin
  foreach t in array array[
    'organizations','branches','departments','counters','services','staff',
    'flows','flow_versions','flow_stages',  -- versions/stages scoped via joins below, but keep simple in MVP
    'customer_org_link','consents','visit_groups','visits','visit_stages',
    'appointments','feedback','predictions','staff_throughput','daily_metrics',
    'org_patterns','knowledge_docs','doc_chunks','activity_events','notifications',
    'notification_budgets','audit_log','api_keys'
  ] loop
    execute format('alter table %I enable row level security;', t);
  end loop;
end $$;

-- organizations: a member sees only their own org
create policy org_isolation on organizations
  using (id = app.current_org()) with check (id = app.current_org());

-- tables that carry organization_id directly
do $$
declare t text;
begin
  foreach t in array array[
    'branches','departments','counters','services','staff','flows',
    'customer_org_link','consents','visit_groups','visits','visit_stages',
    'appointments','feedback','predictions','staff_throughput','daily_metrics',
    'org_patterns','knowledge_docs','doc_chunks','activity_events','notifications',
    'notification_budgets','audit_log','api_keys'
  ] loop
    execute format($f$
      create policy tenant_isolation on %I
        using (organization_id = app.current_org())
        with check (organization_id = app.current_org());
    $f$, t);
  end loop;
end $$;

-- flow_versions / flow_stages: scoped via their parent flow's org (no direct org column)
create policy fv_isolation on flow_versions
  using (exists (select 1 from flows f where f.id = flow_versions.flow_id and f.organization_id = app.current_org()))
  with check (exists (select 1 from flows f where f.id = flow_versions.flow_id and f.organization_id = app.current_org()));

create policy fs_isolation on flow_stages
  using (exists (
    select 1 from flow_versions v join flows f on f.id = v.flow_id
    where v.id = flow_stages.flow_version_id and f.organization_id = app.current_org()))
  with check (exists (
    select 1 from flow_versions v join flows f on f.id = v.flow_id
    where v.id = flow_stages.flow_version_id and f.organization_id = app.current_org()));

-- customers (GLOBAL): visible only if linked to the current org (F6 stays safe-by-default)
create policy cust_via_link on customers
  using (exists (
    select 1 from customer_org_link l
    where l.customer_id = customers.id and l.organization_id = app.current_org()))
  with check (true);  -- inserts happen via service role / app on join
