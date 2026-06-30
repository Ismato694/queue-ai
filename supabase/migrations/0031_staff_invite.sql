-- Queue.ai — 0031: staff invite + claim-by-email (multi-person logins).
-- Admin creates a staff row with an invite_email (no login yet). When that person signs
-- up with the same email, claim_staff_membership() links their auth user to the row —
-- so reception/nurse/manager each get their OWN login + screen (Admin stops doing all).
-- Claim is SECURITY DEFINER: a not-yet-linked user has no org, so RLS would hide the row.

alter table staff add column if not exists invite_email text;
create index if not exists staff_invite_email_idx on staff (lower(invite_email));

create or replace function public.claim_staff_membership()
returns uuid language plpgsql security definer set search_path = public, app as $$
declare v_uid uuid; v_email text; v_org uuid;
begin
  v_uid := auth.uid();
  if v_uid is null then return null; end if;

  -- already linked → idempotent
  select organization_id into v_org from staff where user_id = v_uid and deleted_at is null limit 1;
  if v_org is not null then return v_org; end if;

  v_email := lower(coalesce(auth.jwt() ->> 'email', ''));
  if v_email = '' then return null; end if;

  -- claim the oldest unclaimed invite for this email
  update staff set user_id = v_uid, invite_email = null, updated_at = now()
  where id = (
    select id from staff
    where lower(invite_email) = v_email and user_id is null and deleted_at is null
    order by created_at asc limit 1
  )
  returning organization_id into v_org;

  return v_org;
end $$;
grant execute on function public.claim_staff_membership() to authenticated;
