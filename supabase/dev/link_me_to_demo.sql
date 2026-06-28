-- DEV ONLY — explore the seeded demo hospital with your own login.
-- After you sign up in the app, run this in the Supabase SQL Editor with YOUR email.
-- It makes your auth user an org_admin of the seeded "Lagoon Hospital (Demo)" org,
-- so the admin/reception/manager screens show the rich seed data immediately.
--
-- NOTE: run this INSTEAD of creating your own org via onboarding. If you already
-- bootstrapped your own org, delete that staff row first (or just use your own org).

insert into staff (organization_id, user_id, display_name, role, status)
select '00000000-0000-0000-0000-000000000001', u.id, coalesce(u.email, 'Admin'), 'org_admin', 'offline'
from auth.users u
where u.email = 'YOUR_EMAIL_HERE'
  and not exists (select 1 from staff s where s.user_id = u.id);

-- The seeded branch's QR token (use it for /join/<token> and /display/<token>):
select name, qr_token from branches where organization_id = '00000000-0000-0000-0000-000000000001';
