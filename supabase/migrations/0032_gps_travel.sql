-- Queue.ai — 0032: derive travel time from GPS for the "Leave now" alert (0030).
-- Instead of the patient self-reporting "~15 min away", we measure their real distance
-- to the branch and estimate travel time. Feeds the same travel_seconds the leave-now
-- loop already uses. Branch coords never leave the DB (server-side st_distance).

-- assumed average door-to-door speed in city traffic: ~24 km/h ≈ 6.7 m/s (floor 1 min)
create or replace function public.set_travel_from_gps(p_visit_id uuid, p_lat double precision, p_lng double precision)
returns jsonb language plpgsql security definer set search_path = public, app, extensions as $$
declare v_branch uuid; v_has_geo boolean; v_dist double precision; v_travel int;
begin
  select v.branch_id, b.geo is not null into v_branch, v_has_geo
  from visits v join branches b on b.id = v.branch_id where v.id = p_visit_id;
  if v_branch is null then raise exception 'visit not found'; end if;
  if not v_has_geo then return jsonb_build_object('ok', false, 'reason', 'no_geofence'); end if;

  select st_distance(b.geo, st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography)
    into v_dist from branches b where b.id = v_branch;

  v_travel := greatest(60, round(v_dist / 6.7)::int);   -- seconds
  update visit_stages set travel_seconds = v_travel
  where visit_id = p_visit_id and is_current and state = 'pre_queue';

  return jsonb_build_object('ok', true, 'distance_m', round(v_dist), 'travel_seconds', v_travel);
end $$;
grant execute on function public.set_travel_from_gps(uuid, double precision, double precision) to anon, authenticated;
