-- Transition parity (audit M1): SQL app.can_transition must mirror the TS STAGE_TRANSITIONS.
-- If these drift, the engine and the client disagree about legal moves. Raises on mismatch.
do $$
begin
  -- legal
  assert app.can_transition('pre_queue','active'),  'expected pre_queue->active legal';
  assert app.can_transition('active','called'),      'expected active->called legal';
  assert app.can_transition('called','serving'),     'expected called->serving legal';
  assert app.can_transition('called','active'),      'expected called->active (requeue) legal';
  assert app.can_transition('serving','completed'),  'expected serving->completed legal';
  assert app.can_transition('serving','transferred'),'expected serving->transferred legal';
  -- illegal
  assert not app.can_transition('pre_queue','serving'), 'pre_queue->serving must be illegal';
  assert not app.can_transition('active','completed'),  'active->completed must be illegal';
  assert not app.can_transition('completed','active'),  'completed->* must be illegal (terminal)';
  assert not app.can_transition('no_show','active'),    'no_show->* must be illegal (terminal)';
  raise notice 'TRANSITION PARITY OK ✓';
end $$;
