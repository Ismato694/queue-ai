-- Queue.ai — 0020 grant access to the `app` schema (hotfix)
-- BUG: the `app` schema (app.current_org, app.next_position, app.log_event, …) was never
-- granted to the anon/authenticated roles, so RPCs that touch app.* failed with
-- "permission denied for schema app" (e.g. create_walkin_visit). Grant usage + execute.

grant usage on schema app to anon, authenticated;
grant execute on all functions in schema app to anon, authenticated;
alter default privileges in schema app grant execute on functions to anon, authenticated;
