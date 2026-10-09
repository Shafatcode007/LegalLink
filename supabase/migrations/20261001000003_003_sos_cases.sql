-- db/migrations/20261002_003_sos_cases.sql
-- Sprint 1 core tables: sos_requests + cases (1:1 via cases.sos_id UNIQUE).
-- Sources: TRD section 5.4 (table DDL), section 5.5 (policies),
--          database_schema sections 2.3 (sos_requests), 2.4 (cases).
-- Depends on: 001 (profiles), 002 (advocates, is_verified_advocate()).

create table sos_requests (
  id            uuid primary key default gen_random_uuid(),
  client_id     uuid not null references profiles(id),
  person_name   text,                -- the arrested person
  thana         text not null,       -- police station
  district      text not null,
  court         text,
  charges       text,
  arrested_at   timestamptz,
  person_nid    text,
  urgency       text not null default 'high',
  contact_phone text not null,
  notes         text,
  status        sos_state not null default 'open',
  advocate_id   uuid references profiles(id),   -- set on accept
  accepted_at   timestamptz,
  expires_at    timestamptz not null default now() + interval '24 hours',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

alter table sos_requests enable row level security;

-- Client sees and creates only their own SOS
create policy sos_client_select on sos_requests for select
  using (client_id = auth.uid() or advocate_id = auth.uid() or is_admin());

create policy sos_client_insert on sos_requests for insert
  with check (client_id = auth.uid());

-- Client may cancel an open SOS only
create policy sos_client_update on sos_requests for update
  using (client_id = auth.uid() and status = 'open')
  with check (client_id = auth.uid());

-- Verified advocates see OPEN SOSs in their districts only
create policy sos_advocate_select_open on sos_requests for select
  using (
    is_verified_advocate()
    and status = 'open'
    and district in (select unnest(districts) from advocates where profile_id = auth.uid())
  );

create policy sos_admin_all on sos_requests for all
  using (is_admin()) with check (is_admin());

create table cases (
  id              uuid primary key default gen_random_uuid(),
  case_number     text,                       -- court-assigned, may be null at creation
  client_id       uuid not null references profiles(id),
  advocate_id     uuid references profiles(id),
  sos_id          uuid unique references sos_requests(id),  -- 1:1 when born from SOS
  case_type       text not null,              -- criminal|bail|family|property|labor|women_child
  court           text, district text,
  parties         jsonb not null default '{}'::jsonb,
  state           case_state not null default 'created',
  closed_at       timestamptz,
  transfer_log    jsonb not null default '[]'::jsonb,  -- [{from,to,at,reason}]
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

alter table cases enable row level security;

-- cases: client and assigned advocate only; admins read all
create policy cases_read  on cases for select
  using (client_id = auth.uid() or advocate_id = auth.uid() or is_admin());
create policy cases_client_write on cases for insert
  with check (client_id = auth.uid());
create policy cases_advocate_update on cases for update
  using (advocate_id = auth.uid() or is_admin())
  with check (advocate_id = auth.uid() or is_admin());

-- No DELETE policy (soft-delete doctrine); the TRD's cases_advocate_update
-- omits deletes entirely — an advocate may update only their own cases.


-- =====================================================================
-- Helper moved from file 001: has_case_access()
-- Defined here because it queries the 'cases' table created above.
-- =====================================================================
create or replace function has_case_access(p_case_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from cases c
    where c.id = p_case_id
      and (c.client_id = auth.uid() or c.advocate_id = auth.uid())
  ) or is_admin();
$$;

revoke execute on function has_case_access(uuid) from public;