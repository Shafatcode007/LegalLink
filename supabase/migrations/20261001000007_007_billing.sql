-- db/migrations/20261004_007_billing.sql
-- Sprint 1: invoices + invoice_items + payments (money is numeric(12,2), never floats).
-- Sources: TRD section 5.4 (table DDL), section 5.5 (policies),
--          database_schema section 2.8.
-- Ruling e: VAT/total are structural — check constraints tie vat_bdt and
-- total_bdt to subtotal_bdt and vat_rate with round(..., 2) stability.
-- Ruling a: invoice_items with check (true) is replaced by the SAME ownership
-- predicate as the using clause, PLUS draft-state gating: items may only
-- touch invoices in state = 'draft', so settled records stay settled.

create table invoices (
  id            uuid primary key default gen_random_uuid(),
  invoice_no    text not null unique,        -- INV-{YEAR}-{SEQ} (per advocate)
  case_id       uuid not null references cases(id),
  advocate_id   uuid not null references profiles(id),
  client_id     uuid not null references profiles(id),
  subtotal_bdt  numeric(12,2) not null default 0,
  vat_rate      numeric(5,2)  not null default 15.00,
  vat_bdt       numeric(12,2) not null default 0,
  total_bdt     numeric(12,2) not null default 0,
  paid_bdt      numeric(12,2) not null default 0,
  state         invoice_state not null default 'draft',
  due_date      date,
  pdf_url       text,                        -- Worker-rendered, signed
  version       int not null default 1,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  -- Ruling e: the write path still recomputes from line items (create_invoice);
  -- these constraints make drift a hard error instead of silent corruption.
  check (vat_bdt   = round(subtotal_bdt * vat_rate / 100, 2)),
  check (total_bdt = round(subtotal_bdt + vat_bdt, 2))
);

create table invoice_items (
  id          uuid primary key default gen_random_uuid(),
  invoice_id  uuid not null references invoices(id) on delete cascade,
  description text not null,
  amount_bdt  numeric(12,2) not null,
  created_at  timestamptz not null default now()
);

create table payments (
  id          uuid primary key default gen_random_uuid(),
  invoice_id  uuid not null references invoices(id),
  amount_bdt  numeric(12,2) not null check (amount_bdt > 0),
  method      payment_method not null,
  txn_id      text,                        -- bKash/Nagad TrxID
  proof_url   text,
  recorded_by uuid not null references profiles(id),
  verified    boolean not null default false,
  dispute_note text,
  created_at  timestamptz not null default now()
);

alter table invoices enable row level security;
alter table invoice_items enable row level security;
alter table payments enable row level security;

-- invoices / invoice_items / payments: parties of the case only
create policy invoices_party on invoices for select
  using (advocate_id = auth.uid() or client_id = auth.uid() or is_admin());
create policy invoices_advocate_write on invoices for all
  using (advocate_id = auth.uid()) with check (advocate_id = auth.uid());
create policy invoice_items_party on invoice_items for select
  using (exists (select 1 from invoices i where i.id = invoice_items.invoice_id
                 and (i.advocate_id = auth.uid() or i.client_id = auth.uid())) or is_admin());

-- Ruling a: bounded write — ownership re-asserted on INSERT/UPDATE/DELETE,
-- and only while the parent invoice is still a draft.
create policy invoice_items_advocate_write on invoice_items for all
  using (exists (select 1 from invoices i where i.id = invoice_items.invoice_id
                 and i.advocate_id = auth.uid()))
  with check (exists (select 1 from invoices i where i.id = invoice_items.invoice_id
                      and i.advocate_id = auth.uid()
                      and i.state = 'draft'));

create policy payments_party on payments for all
  using (exists (select 1 from invoices i where i.id = payments.invoice_id
                 and (i.advocate_id = auth.uid() or i.client_id = auth.uid())) or is_admin())
  with check (exists (select 1 from invoices i where i.id = payments.invoice_id
                      and i.advocate_id = auth.uid()));
