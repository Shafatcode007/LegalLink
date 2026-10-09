-- db/migrations/20261001_002_advocates.sql
-- Sprint 1 core tables: advocates + advocate_public projection view.
-- Sources: TRD section 5.4 (advocates DDL), section 5.5 (policies),
--          database_schema section 2.2.
-- Depends on: 001 (profiles table, is_admin() helper, extensions).

create table advocates (
  profile_id        uuid primary key references profiles(id) on delete restrict,
  nid_number        text,
  bar_council_no    text not null,
  sanad_url         text,
  nid_url           text,
  years_practice    int  check (years_practice >= 0),
  specializations   text[] not null default '{}',  -- criminal|bail|family|property|labor|women_child
  courts            text[] not null default '{}',
  districts         text[] not null default '{}',
  languages         text[] not null default '{bn}',
  fee_min_bdt       numeric(12,2),
  fee_max_bdt       numeric(12,2),
  verification      verification_state not null default 'pending',
  rejection_reason  text,
  attempts          int  not null default 0,
  pin_hash          text,          -- bcrypt/pgcrypto hash of the 4-digit publish PIN
  pin_fail_count    int  not null default 0,
  pin_locked_until  timestamptz,
  verified_at       timestamptz,
  reverify_due_at   timestamptz,
  availability      jsonb not null default '{}'::jsonb,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  check (fee_max_bdt is null or fee_min_bdt is null or fee_max_bdt >= fee_min_bdt)
);

alter table advocates enable row level security;

-- Advocates own their row; admins manage verification. Clients do NOT read
-- this table directly — they see verified rows through advocate_public.
create policy advocates_self_rw on advocates for all
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());

create policy advocates_admin_all on advocates for all
  using (is_admin()) with check (is_admin());

-- Public projection: owner (migration role) bypasses RLS, so the
-- verification = 'verified' predicate below is the entire gate for clients.
-- Clients may read only the public projection (enforced on the view).
create view advocate_public as
  select p.id, p.full_name, p.avatar_url, a.specializations, a.courts,
         a.districts, a.languages, a.years_practice, a.fee_min_bdt,
         a.fee_max_bdt, a.verification
  from profiles p join advocates a on a.profile_id = p.id
  where a.verification = 'verified';

grant select on advocate_public to authenticated;


-- =====================================================================
-- Helper moved from file 001: is_verified_advocate()
-- Defined here because it queries the 'advocates' table created above.
-- =====================================================================
create or replace function is_verified_advocate() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from advocates
                 where profile_id = auth.uid() and verification = 'verified');
$$;

revoke execute on function is_verified_advocate() from public;