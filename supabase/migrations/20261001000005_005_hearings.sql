-- db/migrations/20261003_005_hearings.sql
-- Sprint 1: hearings (append-only amendment chain).
-- Sources: TRD section 5.4 (hearings DDL), section 5.5 (policies),
--          database_schema section 2.6.
-- Ruling c: the FOR ALL advocate policy is NOT enough (docs flag in-place
-- mutation of an append-only table). hearings_immutable trigger permits only:
--   * publishing (published_at set on an unpublished, non-superseded row),
--   * the amendment flag flip (is_amended false -> true with
--     version = old.version + 1 and every other column unchanged).
-- Everything else raises hearing_immutable. Amendments are INSERTs carrying
-- supersedes_id; partial unique index prevents double-claims of a predecessor.

create table hearings (
  id                uuid primary key default gen_random_uuid(),
  case_id           uuid not null references cases(id),
  hearing_date      date not null,
  court             text,
  outcome_notes     text,                    -- advocate raw notes
  next_hearing_date date,
  entered_by        uuid not null references profiles(id),
  version           int  not null default 1,
  supersedes_id     uuid references hearings(id),   -- amendment chain
  is_amended        boolean not null default false,
  published_at      timestamptz,             -- null = not visible to client
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

alter table hearings enable row level security;

-- hearings: client sees PUBLISHED only; advocate writes own cases
create policy hearings_client_read on hearings for select
  using (
    published_at is not null
    and exists (select 1 from cases c where c.id = hearings.case_id
                and c.client_id = auth.uid())
  );

create policy hearings_advocate_rw on hearings for all
  using (exists (select 1 from cases c where c.id = hearings.case_id
                 and c.advocate_id = auth.uid()))
  with check (exists (select 1 from cases c where c.id = hearings.case_id
                      and c.advocate_id = auth.uid()));

create policy hearings_admin_all on hearings for all
  using (is_admin()) with check (is_admin());

-- Ruling c: structural immutability. The trigger — not the FOR ALL policy —
-- is what makes the chain append-only.
create or replace function hearings_immutable() returns trigger
language plpgsql as $$
begin
  -- Publishing: allowed on a row that is still private and not superseded.
  if old.published_at is null
     and old.supersedes_id is null
     and new.published_at is not null
     and new.supersedes_id is not distinct from old.supersedes_id
     and new.is_amended = old.is_amended
     and new.version = old.version
     and new.case_id = old.case_id
     and new.hearing_date is not distinct from old.hearing_date
     and new.court is not distinct from old.court
     and new.outcome_notes is not distinct from old.outcome_notes
     and new.next_hearing_date is not distinct from old.next_hearing_date
     and new.entered_by = old.entered_by then
    return new;
  end if;

  -- Amendment flag flip: the new-version INSERT marks the old row replaced.
  -- Exactly is_amended (false -> true) and version (+1) may change.
  if old.is_amended = false
     and new.is_amended = true
     and new.version = old.version + 1
     and new.case_id = old.case_id
     and new.hearing_date is not distinct from old.hearing_date
     and new.court is not distinct from old.court
     and new.outcome_notes is not distinct from old.outcome_notes
     and new.next_hearing_date is not distinct from old.next_hearing_date
     and new.entered_by = old.entered_by
     and new.supersedes_id is not distinct from old.supersedes_id
     and new.published_at is not distinct from old.published_at then
    return new;
  end if;

  raise exception 'hearing_immutable';
end $$;

drop trigger if exists hearings_immutable on hearings;
create trigger hearings_immutable
  before update on hearings
  for each row execute function hearings_immutable();

-- One predecessor, one successor: prevents two rows claiming the same
-- amended version (and, with it, quiet cycles).
create unique index hearings_supersedes_unique on hearings (supersedes_id)
  where supersedes_id is not null;
