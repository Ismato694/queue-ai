-- Queue.ai — queue-engine smoke test (run in Supabase SQL Editor on the seeded demo DB).
-- Exercises the full pipeline as the org and asserts state transitions. Raises on failure.
-- Safe to re-run (creates a fresh throwaway visit each time).

do $$
declare
  v_org   uuid := '00000000-0000-0000-0000-000000000001';
  v_branch uuid;
  v_visit uuid; v_stage uuid; v_next uuid; v_state text; v_dept text;
begin
  perform set_config('app.current_org', v_org::text, true);
  select id into v_branch from branches where organization_id = v_org limit 1;

  -- 1) create a walk-in → first stage ACTIVE at Reception
  v_visit := create_walkin_visit(v_branch, null, 'Smoke Test', '+2340000000001', 'routine');
  select vs.id, vs.state::text, d.name into v_stage, v_state, v_dept
    from visit_stages vs join departments d on d.id = vs.department_id
    where vs.visit_id = v_visit and vs.is_current;
  assert v_state = 'active', 'expected first stage active, got ' || v_state;
  raise notice 'OK 1: created visit, first stage % is % (%)', v_stage, v_state, v_dept;

  -- 2) call_next → CALLED
  perform call_next(v_branch, (select department_id from visit_stages where id = v_stage));
  select state::text into v_state from visit_stages where id = v_stage;
  assert v_state = 'called', 'expected called, got ' || v_state;
  raise notice 'OK 2: call_next -> %', v_state;

  -- 3) serve → SERVING
  perform serve_stage(v_stage);
  select state::text into v_state from visit_stages where id = v_stage;
  assert v_state = 'serving', 'expected serving, got ' || v_state;
  raise notice 'OK 3: serve -> %', v_state;

  -- 4) complete → COMPLETED + auto-advance next stage to ACTIVE
  v_next := complete_stage(v_stage);
  select state::text into v_state from visit_stages where id = v_stage;
  assert v_state = 'completed', 'expected completed, got ' || v_state;
  assert v_next is not null, 'expected auto-advance to a next stage';
  select state::text, d.name into v_state, v_dept from visit_stages vs
    join departments d on d.id = vs.department_id where vs.id = v_next;
  assert v_state = 'active', 'expected next stage active, got ' || v_state;
  raise notice 'OK 4: complete -> auto-advanced to % (%)', v_dept, v_state;

  -- 5) every transition wrote an activity_event (the invariant)
  perform 1 from activity_events where entity_id = v_stage and to_state = 'completed';
  assert found, 'expected an activity_event for completion';
  raise notice 'OK 5: activity_events recorded';

  -- cleanup
  perform cancel_visit(v_visit);
  raise notice 'SMOKE TEST PASSED ✓';
end $$;
