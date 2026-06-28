-- Queue.ai — 0001 init: extensions, enums, tenancy helpers
-- Implements foundations from docs/04-DATABASE.md §1

create extension if not exists "pgcrypto";
create extension if not exists "postgis";
create extension if not exists "vector";
-- timescaledb is optional in MVP (enable on a Postgres that supports it):
-- create extension if not exists "timescaledb";

-- ─── Enums ──────────────────────────────────────────────────────────────────
create type plan_tier        as enum ('starter','growth','enterprise');
create type staff_role        as enum ('super_admin','org_admin','manager','receptionist','staff');
create type staff_status      as enum ('online','away','break','offline');
create type counter_status    as enum ('open','closed');
create type industry_template as enum ('hospital','bank','passport','custom');
create type acuity            as enum ('routine','priority','emergency');
create type visit_status      as enum ('active','completed','cancelled');
create type join_channel      as enum ('receptionist','qr','web','whatsapp','sms');
create type stage_state       as enum
  ('booked','pre_queue','active','called','serving','completed','transferred','no_show','expired','cancelled');
create type activation_trigger as enum ('gps','on_my_way','qr','receptionist');
create type appt_status       as enum ('booked','activated','expired','cancelled');
create type consent_scope     as enum ('service','marketing','cross_org_share');
create type prediction_kind   as enum ('stage_eta','visit_eta','leave_by','dept_load');
create type notif_channel     as enum ('push','sms','whatsapp','email','voice');
create type notif_status      as enum ('queued','sent','delivered','failed');
create type pattern_type      as enum ('dow','weather','season','holiday');

-- ─── Tenancy helper: org id from the JWT (Supabase sets request.jwt.claims) ───
-- The app issues JWTs carrying organization_id + role claims. RLS reads them here.
create schema if not exists app;

create or replace function app.current_org() returns uuid
language sql stable as $$
  select nullif(
    coalesce(
      current_setting('request.jwt.claims', true)::jsonb ->> 'organization_id',
      current_setting('app.current_org', true)            -- fallback for server/worker sessions
    ), ''
  )::uuid
$$;

create or replace function app.current_role() returns text
language sql stable as $$
  select coalesce(
    current_setting('request.jwt.claims', true)::jsonb ->> 'role',
    current_setting('app.current_role', true)
  )
$$;

-- updated_at trigger helper
create or replace function app.touch_updated_at() returns trigger
language plpgsql as $$
begin new.updated_at = now(); return new; end $$;
