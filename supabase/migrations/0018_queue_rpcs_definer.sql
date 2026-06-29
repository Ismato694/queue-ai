-- Queue.ai — 0018 queue RPCs → SECURITY DEFINER (Sprint S2 hotfix)
-- The reception/staff queue RPCs ran as SECURITY INVOKER and could be blocked by RLS
-- on their internal writes for the `authenticated` role. Each already enforces org
-- membership internally (via app.current_org()), so DEFINER is tenant-safe and matches
-- the customer-facing RPC pattern (join_queue, activate_visit, …).

alter function public.create_walkin_visit(uuid,uuid,text,text,acuity) security definer;
alter function public.call_next(uuid,uuid,int)                        security definer;
alter function public.serve_stage(uuid)                               security definer;
alter function public.complete_stage(uuid)                            security definer;
alter function public.set_stage_priority(uuid,acuity)                 security definer;
alter function public.cancel_visit(uuid)                              security definer;
