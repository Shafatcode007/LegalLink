-- db/migrations/20261002_004_consents.sql
-- Sprint 1: consents (legal compliance record, optimistic-locked).
-- Sources: TRD section 5.4 (consents DDL), database_schema section 2.5.
-- Ruling d: split policies — the INSERT check binds BOTH case ownership AND
-- the advocate named on the row, so a client cannot forge consent to an
-- arbitrary profile; the UPDATE path (revocation) stays client_id-only so
-- revocation still works after a case transfer.
-- Ruling h: version check lives in a BEFORE UPDATE trigger raising
-- conflict_stale_version; revoked_at, once set, can never be cleared.

create table consents (
  id           uuid primary key default gen_random_uuid(),
  case_id      uuid not null references cases(id),
  client_id    uuid not null references profiles(id),
  advocate_id  uuid not null references profiles(id),
  scope        text[] not null default '{case_data}',
  granted_at   timestamptz not null default now(),
  revoked_at   timestamptz,
  version      int not null default 1,       -- optimistic lock (PRD F8)
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (case_id, advocate_id, revoked_at)
);

alter table consents enable row level security;

-- INSERT: client must own the case AND name that case's actual advocate.
create policy consents_client_insert on consents for insert
  with check (
    client_id = auth.uid()
    and exists (select 1 from cases c
                where c.id = consents.case_id
                  and c.client_id = auth.uid()
                  and c.advocate_id = consents.advocate_id)
  );

create policy consents_client_read on consents for select
  using (client_id = auth.uid() or is_admin());

-- UPDATE (revocation): client_id only — works even after a case transfer.
create policy consents_client_revoke on consents for update
  using (client_id = auth.uid())
  with check (client_id = auth.uid());

create policy consents_advocate_read on consents for select
  using (advocate_id = auth.uid() or is_admin());

-- No DELETE policy (revocation is a state change, never a delete).

-- Ruling h: optimistic-lock check + no un-revoke, enforced structurally.
create or replace function consents_version_guard() returns trigger
language plpgsql as $$
begin
  if new.version is distinct from old.version + 1 then
    raise exception 'conflict_stale_version';
  end if;
  if old.revoked_at is not null and new.revoked_at is distinct from old.revoked_at then
    raise exception 'consent_revoked_cannot_unrevoke';
  end if;
  return new;
end $$;

drop trigger if exists consents_version_guard on consents;
create trigger consents_version_guard
  before update on consents
  for each row execute function consents_version_guard();
