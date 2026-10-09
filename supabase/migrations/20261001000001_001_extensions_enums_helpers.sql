-- db/migrations/20261001_001_extensions_enums_helpers.sql
-- File 1 of 16-file Supabase chain for LegalLink: extensions, enums, profiles table, RLS helpers.
-- Date: 2026-10-01
-- Source docs: docs/trd.md sections 5.1, 5.5, 5.6; docs/database_schema.md sections 2 (profiles), 3, 3.1.
-- NOTE (fix): is_verified_advocate() moved to file 002 and has_case_access() moved to file 003,
--          because they query tables (advocates, cases) that do not exist yet in file 001.

-- =====================================================================
-- Extensions
-- =====================================================================
create extension if not exists "pgcrypto" with schema extensions;
create extension if not exists "pg_trgm";
create extension if not exists "vector";
create extension if not exists "pg_cron" with schema extensions;

-- =====================================================================
-- Enum types
-- =====================================================================
create type user_role as enum ('client', 'advocate', 'admin');
create type verification_state as enum ('pending', 'verified', 'rejected');
create type sos_state as enum ('open', 'accepted', 'declined', 'cancelled', 'expired');
create type case_state as enum ('created', 'active', 'closed', 'archived');
create type checklist_state as enum ('suggested_pending_advocate', 'approved', 'rejected', 'uploaded', 'needs_review');
create type summary_state as enum ('draft', 'published', 'archived');
create type invoice_state as enum ('draft', 'sent', 'partially_paid', 'paid', 'overdue', 'void');
create type payment_method as enum ('bkash', 'nagad', 'cash', 'bank');
create type doc_status as enum ('uploaded', 'needs_review', 'approved', 'rejected');
create type ai_feature as enum ('triage', 'summary', 'chatbot');

-- =====================================================================
-- profiles table
-- =====================================================================
create table profiles (
  id uuid primary key references auth.users (id) on delete restrict,
  role user_role not null default 'client',
  full_name text,
  phone text not null,
  language text not null default 'bn' check (language in ('bn', 'en')),
  avatar_url text,
  fcm_token text,
  fcm_updated_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- =====================================================================
-- Helper functions (TRD 5.6) — security definer, avoids recursive RLS
-- Only is_admin() lives here because it depends only on profiles (created above).
-- is_verified_advocate() -> file 002 (needs advocates table).
-- has_case_access()      -> file 003 (needs cases table).
-- =====================================================================
create or replace function is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles
                 where id = auth.uid() and role = 'admin');
$$;

-- Ruling j: helpers must not be callable by anonymous public.
revoke execute on function is_admin() from public;

-- =====================================================================
-- RLS: profiles
-- =====================================================================
alter table profiles enable row level security;

create policy profiles_select_self on profiles for select
  using (id = auth.uid() or is_admin());

create policy profiles_update_self on profiles for update
  using (id = auth.uid()) with check (id = auth.uid());

-- No insert/delete policies on profiles: rows are created by signup trigger / service_role only.

-- =====================================================================
-- advocate_public view: NOT created here.
-- advocates table does not exist yet in file 1, and a view referencing a
-- missing table fails. Created in 002 after advocates.
-- =====================================================================

-- =====================================================================
-- set_updated_at() trigger function (body only; triggers go in 015)
-- =====================================================================
create or replace function set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;