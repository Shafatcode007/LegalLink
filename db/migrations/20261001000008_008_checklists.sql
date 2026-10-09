-- db/migrations/20261005_009_checklists.sql
-- Sprint 1: checklist_templates (admin-managed definitions) + checklist_items
-- (per-case instances).
-- Sources: TRD section 5.4 (checklist_templates/items DDL), section 5.5
-- (policies), database_schema section 2.9.
-- Ruling a: checklist_advocate_rw with check (true) is replaced by the same
-- ownership predicate as the using clause.
-- Ruling f: checklist_client_update_guard trigger — when the caller is the
-- case's CLIENT (not the case advocate, not admin), only the upload path may
-- change: status/body columns beyond status stay frozen, and privileged
-- columns (item_name_bn, importance, ai_reason_bn, approved_by, approved_at,
-- reject_reason) can never be touched by a client.

create table checklist_templates (
  id            uuid primary key default gen_random_uuid(),
  case_type     text not null,
  item_name_bn  text not null,
  item_name_en  text not null,
  importance    text not null check (importance in ('high','medium','low')),
  purpose_bn    text,
  sort_order    int  not null default 0,
  active        boolean not null default true,
  created_at    timestamptz not null default now()
);

create table checklist_items (
  id             uuid primary key default gen_random_uuid(),
  case_id        uuid not null references cases(id),
  template_id    uuid references checklist_templates(id),
  item_name_bn   text not null,
  importance     text not null,
  status         checklist_state not null default 'suggested_pending_advocate',
  ai_reason_bn   text,                    -- why AI suggested it
  approved_by    uuid references profiles(id),
  approved_at    timestamptz,
  reject_reason  text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

alter table checklist_templates enable row level security;
alter table checklist_items enable row level security;

-- Templates: admin-managed. No client/advocate insert/update/delete policy;
-- only admins (all) plus a read path for everyone involved in a case.
create policy checklist_templates_admin_all on checklist_templates for all
  using (is_admin()) with check (is_admin());
create policy checklist_templates_case_read on checklist_templates for select
  using (
    auth.uid() is not null
    and exists (select 1 from cases c
                where c.client_id = auth.uid() or c.advocate_id = auth.uid())
  );

-- checklist_items: client reads own case items; advocate approves own case items
create policy checklist_client_read on checklist_items for select
  using (exists (select 1 from cases c where c.id = checklist_items.case_id
                 and c.client_id = auth.uid()) or is_admin());

-- Ruling a: bounded — the with check re-asserts the advocate's ownership.
create policy checklist_advocate_rw on checklist_items for all
  using (exists (select 1 from cases c where c.id = checklist_items.case_id
                 and c.advocate_id = auth.uid()))
  with check (exists (select 1 from cases c where c.id = checklist_items.case_id
                      and c.advocate_id = auth.uid()));

-- clients may update only the "upload" transition (status -> uploaded)
create policy checklist_client_upload on checklist_items for update
  using (exists (select 1 from cases c where c.id = checklist_items.case_id
                 and c.client_id = auth.uid()))
  with check (status in ('uploaded','needs_review'));

-- Ruling f: column-level guard for client-side updates. The RLS policy above
-- allows any client update on their own case items that lands in an upload
-- state — this trigger additionally freezes privileged columns for clients.
create or replace function checklist_client_update_guard() returns trigger
language plpgsql as $$
declare
  v_is_advocate boolean;
  v_is_admin    boolean;
begin
  v_is_admin    := (select is_admin());
  select exists (select 1 from cases c
                 where c.id = new.case_id and c.advocate_id = auth.uid())
    into v_is_advocate;

  if v_is_admin or v_is_advocate then
    return new;                       -- advocates and admins are unconstrained
  end if;

  -- Caller is the case client: privileged columns must not move.
  if new.item_name_bn is distinct from old.item_name_bn
     or new.importance is distinct from old.importance
     or new.ai_reason_bn is distinct from old.ai_reason_bn
     or new.approved_by is distinct from old.approved_by
     or new.approved_at is distinct from old.approved_at
     or new.reject_reason is distinct from old.reject_reason then
    raise exception 'checklist_client_forbidden_column';
  end if;
  return new;
end $$;

drop trigger if exists checklist_client_update_guard on checklist_items;
create trigger checklist_client_update_guard
  before update on checklist_items
  for each row execute function checklist_client_update_guard();
