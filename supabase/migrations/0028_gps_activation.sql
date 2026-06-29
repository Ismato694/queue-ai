-- Queue.ai — 0028 (compliance gap, CTO-1): GPS geofence activation.
-- The client sends its coordinates; the geofence check + decision happen server-side
-- (branch coords never leave the DB). Activates the pre-queue stage only if within radius.

-- NOTE: PostGIS (st_distance/st_makepoint) lives in the `extensions` schema on Supabase;
-- include it in search_path so the spatial functions resolve there and on bare Postgres.
create or replace function public.activate_visit_gps(p_visit_id uuid, p_lat double precision, p_lng double precision)
returns jsonb language plpgsql security definer set search_path = public, app, extensions as $$
declare v_branch uuid; v_radius int; v_dist double precision; v_has_geo boolean;
begin
  select v.branch_id, b.geofence_radius_m, b.geo is not null
    into v_branch, v_radius, v_has_geo
  from visits v join branches b on b.id = v.branch_id
  where v.id = p_visit_id;
  if v_branch is null then raise exception 'visit not found'; end if;
  if not v_has_geo then return jsonb_build_object('ok', false, 'reason', 'no_geofence'); end if;

  select st_distance(b.geo, st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography)
    into v_dist from branches b where b.id = v_branch;

  if v_dist > v_radius then
    return jsonb_build_object('ok', false, 'reason', 'too_far', 'distance_m', round(v_dist));
  end if;

  perform public.activate_visit(p_visit_id, 'gps');
  return jsonb_build_object('ok', true, 'distance_m', round(v_dist));
end $$;
grant execute on function public.activate_visit_gps(uuid, double precision, double precision) to anon, authenticated;
