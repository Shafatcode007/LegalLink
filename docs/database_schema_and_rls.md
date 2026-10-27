# LegalLink — Database Schema & RLS Specification

**Version:** 1.0  
**Date:** October 2026  
**Source:** `docs/trd.md` §5, §6; `docs/prd.md` §10; `docs/database_schema.md`  
**Stack:** Supabase PostgreSQL 15+ · Row Level Security (RLS) · pgcrypto · pgvector  
**Conventions:** Plural snake_case tables · Singular snake_case columns · Every table has `id uuid PK default gen_random_uuid()`, `created_at timestamptz default now()`, `updated_at timestamptz default now()` · Soft delete via `deleted_at` where needed · Money: `numeric(12,2)` BDT · No hard-delete policies · Optimistic locking via `version` on `consents`, `invoices`, `ai_summaries`

---

## 1. Enum Types — exact SQL

All state columns are Postgres enums. Values added only via `alter type X add value '...'` in an expand migration; never reused, reordered, or removed.

```sql
create type user_role          as enum ('client','advocate','admin');
create type verification_state as enum ('pending','verified','rejected');
create type sos_state          as enum ('open','accepted','declined','cancelled','expired');
create type case_state         as enum ('created','active','closed','archived');
create type checklist_state    as enum ('suggested_pending_advocate','approved',
                                        'rejected','uploaded','needs_review');
create type summary_state      as enum ('draft','published','archived');
create type invoice_state      as enum ('draft','sent','partially_paid','paid','overdue','void');
create type payment_method     as enum ('bkash','nagad','cash','bank');
create type doc_status         as enum ('uploaded','needs_review','approved','rejected');
create type ai_feature         as enum ('triage','summary','chatbot');
```

---

## 2. Core Tables — exact DDL

### 2.1 `profiles`

Extends `auth.users`; one row per authenticated user. No `deleted_at`.

```sql
create table profiles (
  id          uuid primary key references auth.users(id) on delete restrict,
  role        user_role   not null default 'client',
  full_name   text,
  phone       text        not null,
  language    text        not null default 'bn' check (language in ('bn','en')),
  avatar_url  text,
  fcm_token      text,
  fcm_updated_at timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
```

**FK:** `id → auth.users(id)` restrict.

**RLS:**
```sql
alter table profiles enable row level security;

create policy profiles_select_self on profiles for select
  using (id = auth.uid() or is_admin());

create policy profiles_update_self on profiles for update
  using (id = auth.uid()) with check (id = auth.uid());
```
**No INSERT policy** — creation via `complete_signup()` RPC only (prevents client self-assigning `role='admin'`). **No DELETE policy.**

---

### 2.2 `advocates`

1:1 extension of `profiles`.

```sql
create table advocates (
  profile_id        uuid primary key references profiles(id) on delete restrict,
  nid_number        text,
  bar_council_no    text not null,
  sanad_url         text,
  nid_url           text,
  years_practice    int  check (years_practice >= 0),
  specializations   text[] not null default '{}',
  courts            text[] not null default '{}',
  districts         text[] not null default '{}',
  languages         text[] not null default '{bn}',
  fee_min_bdt       numeric(12,2),
  fee_max_bdt       numeric(12,2),
  verification      verification_state not null default 'pending',
  rejection_reason  text,
  attempts          int  not null default 0,
  pin_hash          text,
  pin_fail_count    int  not null default 0,
  pin_locked_until  timestamptz,
  verified_at       timestamptz,
  reverify_due_at   timestamptz,
  availability      jsonb not null default '{}'::jsonb,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  check (fee_max_bdt is null or fee_min_bdt is null or fee_max_bdt >= fee_min_bdt)
);
```

**FK:** `profile_id → profiles(id)` restrict.

**Check constraint:** `fee_max_bdt is null or fee_min_bdt is null or fee_max_bdt >= fee_min_bdt`.

**RLS:**
```sql
alter table advocates enable row level security;

create policy advocates_self_rw on advocates for all
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());

create policy advocates_admin_all on advocates for all
  using (is_admin()) with check (is_admin());
```

**View `advocate_public`:**
```sql
create view advocate_public as
  select p.id, p.full_name, p.avatar_url, a.specializations, a.courts,
         a.districts, a.languages, a.years_practice, a.fee_min_bdt,
         a.fee_max_bdt, a.verification
  from profiles p join advocates a on a.profile_id = p.id
  where a.verification = 'verified';

grant select on advocate_public to authenticated;
```

---

### 2.3 `sos_requests`

Emergency intake. Only table with self-expiry (`expires_at`), enforced by `expire_sos()` cron.

```sql
create table sos_requests (
  id            uuid primary key default gen_random_uuid(),
  client_id     uuid not null references profiles(id),
  person_name   text,
  thana         text not null,
  district      text not null,
  court         text,
  charges       text,
  arrested_at   timestamptz,
  person_nid    text,
  urgency       text not null default 'high',
  contact_phone text not null,
  notes         text,
  status        sos_state not null default 'open',
  advocate_id   uuid references profiles(id),
  accepted_at   timestamptz,
  expires_at    timestamptz not null default now() + interval '24 hours',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
```

**FK:** `client_id → profiles(id)`, `advocate_id → profiles(id)` (no action). Outbound: `cases.sos_id → sos_requests(id)`.

**RLS:**
```sql
alter table sos_requests enable row level security;

create policy sos_client_select on sos_requests for select
  using (client_id = auth.uid() or advocate_id = auth.uid() or is_admin());

create policy sos_client_insert on sos_requests for insert
  with check (client_id = auth.uid());

create policy sos_client_update on sos_requests for update
  using (client_id = auth.uid() and status = 'open')
  with check (client_id = auth.uid());

create policy sos_advocate_select_open on sos_requests for select
  using (
    is_verified_advocate()
    and status = 'open'
    and district in (select unnest(districts) from advocates where profile_id = auth.uid())
  );

create policy sos_admin_all on sos_requests for all
  using (is_admin()) with check (is_admin());
```

---

### 2.4 `cases`

A case may be created directly by a client or born from an accepted SOS.

```sql
create table cases (
  id              uuid primary key default gen_random_uuid(),
  case_number     text,
  client_id       uuid not null references profiles(id),
  advocate_id     uuid references profiles(id),
  sos_id          uuid unique references sos_requests(id),
  case_type       text not null,
  court           text,
  district        text,
  parties         jsonb not null default '{}'::jsonb,
  state           case_state not null default 'created',
  closed_at       timestamptz,
  transfer_log    jsonb not null default '[]'::jsonb,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
```

**FK:** `client_id → profiles(id)`, `advocate_id → profiles(id)`, `sos_id → sos_requests(id)`. Outbound: `consents.case_id`, `hearings.case_id`, `ai_summaries.case_id`, `invoices.case_id`, `documents.case_id`, `checklist_items.case_id`, `ai_triage_sessions.case_id`.

**1:1 note:** `sos_id uuid unique references sos_requests(id)` — no SOS spawns two cases; nullable so client-originated case has `sos_id is null`.

**RLS:**
```sql
alter table cases enable row level security;

create policy cases_read on cases for select
  using (client_id = auth.uid() or advocate_id = auth.uid() or is_admin());

create policy cases_client_write on cases for insert
  with check (client_id = auth.uid());

create policy cases_advocate_update on cases for update
  using (advocate_id = auth.uid() or is_admin())
  with check (advocate_id = auth.uid() or is_admin());
```

---

### 2.5 `consents`

Legal compliance record (PRD F8). Optimistic-lock column `version`.

```sql
create table consents (
  id           uuid primary key default gen_random_uuid(),
  case_id      uuid not null references cases(id),
  client_id    uuid not null references profiles(id),
  advocate_id  uuid not null references profiles(id),
  scope        text[] not null default '{case_data}',
  granted_at   timestamptz not null default now(),
  revoked_at   timestamptz,
  version      int not null default 1,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (case_id, advocate_id, revoked_at)
);
```

**RLS:**
```sql
alter table consents enable row level security;

create policy consents_client_all on consents for all
  using (client_id = auth.uid()) with check (client_id = auth.uid());

create policy consents_advocate_read on consents for select
  using (advocate_id = auth.uid() or is_admin());
```

**Gap:** Client policy has no predicate on `revoked_at` and no check on `advocate_id` scope; enforce in `grant_consent()` RPC.

---

### 2.6 `hearings`

Append-only amendment chain — rows never edited in place, only superseded.

```sql
create table hearings (
  id                uuid primary key default gen_random_uuid(),
  case_id           uuid not null references cases(id),
  hearing_date      date not null,
  court             text,
  outcome_notes     text,
  next_hearing_date date,
  entered_by        uuid not null references profiles(id),
  version           int  not null default 1,
  supersedes_id     uuid references hearings(id),
  is_amended        boolean not null default false,
  published_at      timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
```

**RLS:**
```sql
alter table hearings enable row level security;

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
```

**Gap:** Self-reference not cycle-guarded; `for all` on immutable table allows in-place update defeating chain.

---

### 2.7 `ai_summaries`

HITL state machine. Third table with `version` optimistic lock.

```sql
create table ai_summaries (
  id             uuid primary key default gen_random_uuid(),
  case_id        uuid not null references cases(id),
  hearing_id     uuid references hearings(id),
  raw_input      text not null,
  draft_bn       text not null,
  final_bn       text,
  state          summary_state not null default 'draft',
  model          text,
  prompt_version text,
  tokens_used    int,
  approved_by    uuid references profiles(id),
  published_by   text,
  override_reason text,
  flagged        boolean not null default false,
  archived_at    timestamptz,
  expires_at     timestamptz not null default now() + interval '7 days',
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  version        int not null default 1
);
```

**PIN fields live on `advocates` (`pin_hash`, `pin_fail_count`, `pin_locked_until`), not here.**

**RLS:**
```sql
alter table ai_summaries enable row level security;

create policy summaries_client_published on ai_summaries for select
  using (
    state = 'published'
    and exists (select 1 from cases c where c.id = ai_summaries.case_id
                and c.client_id = auth.uid())
  );

create policy summaries_advocate_all on ai_summaries for all
  using (exists (select 1 from cases c where c.id = ai_summaries.case_id
                 and c.advocate_id = auth.uid()))
  with check (exists (select 1 from cases c where c.id = ai_summaries.case_id
                      and c.advocate_id = auth.uid()));

create policy summaries_admin_all on ai_summaries for all
  using (is_admin()) with check (is_admin());
```

**HITL guarantee:** Client cannot read `draft`; enforce in `publish_ai_summary` RPC because `summaries_advocate_all` is `for all`.

---

### 2.8 `invoices` + `invoice_items`

#### `invoices`

```sql
create table invoices (
  id            uuid primary key default gen_random_uuid(),
  invoice_no    text not null unique,
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
  pdf_url       text,
  version       int not null default 1,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
```

**Gap:** No constraint enforcing `vat_bdt = subtotal_bdt * vat_rate / 100` or `total_bdt = subtotal_bdt + vat_bdt`; maintained by write path RPC.

**RLS:**
```sql
alter table invoices enable row level security;

create policy invoices_party on invoices for select
  using (advocate_id = auth.uid() or client_id = auth.uid() or is_admin());

create policy invoices_advocate_write on invoices for all
  using (advocate_id = auth.uid()) with check (advocate_id = auth.uid());
```

**Gap:** `with check` does not pin `case_id` or `client_id`; advocate can invoice arbitrary case/client.

#### `invoice_items`

```sql
create table invoice_items (
  id          uuid primary key default gen_random_uuid(),
  invoice_id  uuid not null references invoices(id) on delete cascade,
  description text not null,
  amount_bdt  numeric(12,2) not null,
  created_at  timestamptz not null default now()
);
```

**Gap:** `with check (true)` on insert — unbounded clause; any advocate can insert line item against any invoice id.

**RLS:**
```sql
alter table invoice_items enable row level security;

create policy invoice_items_party on invoice_items for select
  using (exists (select 1 from invoices i where i.id = invoice_items.invoice_id
                 and (i.advocate_id = auth.uid() or i.client_id = auth.uid())) or is_admin());

create policy invoice_items_advocate_write on invoice_items for all
  using (exists (select 1 from invoices i where i.id = invoice_items.invoice_id
                 and i.advocate_id = auth.uid()))
  with check (true);
```

---

### 2.9 `payments`

Partial payments against invoice; manual verification.

```sql
create table payments (
  id          uuid primary key default gen_random_uuid(),
  invoice_id  uuid not null references invoices(id),
  amount_bdt  numeric(12,2) not null check (amount_bdt > 0),
  method      payment_method not null,
  txn_id      text,
  proof_url   text,
  recorded_by uuid not null references profiles(id),
  verified    boolean not null default false,
  dispute_note text,
  created_at  timestamptz not null default now()
);
```

**RLS:** All with `using` admitting case parties, `with check` admitting only advocate.

---

### 2.10 `documents`

Case document vault; **only MVP table with `deleted_at`**.

```sql
create table documents (
  id               uuid primary key default gen_random_uuid(),
  case_id          uuid not null references cases(id),
  checklist_item_id uuid references checklist_items(id),
  uploaded_by      uuid not null references profiles(id),
  doc_type         text not null,
  storage_path     text,
  local_ref        text,
  mime_type        text,
  size_bytes       bigint,
  status           doc_status not null default 'uploaded',
  reject_reason    text,
  deleted_at       timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
```

**RLS:**
```sql
alter table documents enable row level security;

create policy documents_party on documents for all
  using (case_id is not null and has_case_access(case_id) and deleted_at is null)
  with check (uploaded_by = auth.uid());
```

---

### 2.11 `checklist_templates` + `checklist_items`

#### `checklist_templates`

```sql
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
```

No `updated_at`; deactivate via `active`, never delete.

#### `checklist_items`

```sql
create table checklist_items (
  id             uuid primary key default gen_random_uuid(),
  case_id        uuid not null references cases(id),
  template_id    uuid references checklist_templates(id),
  item_name_bn   text not null,
  importance     text not null,
  status         checklist_state not null default 'suggested_pending_advocate',
  ai_reason_bn   text,
  approved_by    uuid references profiles(id),
  approved_at    timestamptz,
  reject_reason  text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
```

**RLS:**
```sql
create policy checklist_client_read on checklist_items for select
  using (exists (select 1 from cases c where c.id = checklist_items.case_id
                 and c.client_id = auth.uid()) or is_admin());

create policy checklist_advocate_rw on checklist_items for all
  using (exists (select 1 from cases c where c.id = checklist_items.case_id
                 and c.advocate_id = auth.uid()))
  with check (true);

create policy checklist_client_upload on checklist_items for update
  using (exists (select 1 from cases c where c.id = checklist_items.case_id
                 and c.client_id = auth.uid()))
  with check (status in ('uploaded','needs_review'));
```

**Gap:** `checklist_advocate_rw` has `with check (true)` — unbounded insert (same gap as invoice_items).

---

### 2.12 `ai_triage_sessions`

```sql
create table ai_triage_sessions (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references profiles(id),
  case_id        uuid references cases(id),
  input_hash     text not null,
  input_redacted text not null,
  output_json    jsonb not null,
  model          text,
  prompt_version text,
  tokens_used    int,
  fallback_used  boolean not null default false,
  created_at     timestamptz not null default now()
);
```

Retention: `input_redacted` nulled after 30 days by cron.

**Gap:** `case_id → cases` is 1-to-0..1 but not enforced; partial unique index needed if one triage per case intended.

---

### 2.13 `audit_logs`

Append-only system of record.

```sql
create table audit_logs (
  id         bigserial primary key,
  actor_id   uuid references profiles(id),
  actor_role user_role,
  action     text not null,
  entity     text,
  entity_id  uuid,
  metadata   jsonb not null default '{}'::jsonb,
  ip         inet,
  device     text,
  created_at timestamptz not null default now()
);
```

No `updated_at`. **No UPDATE or DELETE policy ever created.**

**RLS:**
```sql
create policy audit_admin_read on audit_logs for select using (is_admin());
```
No insert/update/delete via API.

---

### 2.14 `notifications`

Per-user push / in-app message records.

```sql
create table notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references profiles(id),
  kind        text not null,
  title_bn    text,
  body_bn     text,
  payload     jsonb not null default '{}'::jsonb,
  channel     text not null default 'push',
  sent_at     timestamptz,
  read_at     timestamptz,
  dedupe_key  text unique,
  created_at  timestamptz not null default now()
);
```

**RLS:**
```sql
create policy notifications_self on notifications for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
```

**Gap:** `dedupe_key` globally unique, not per user. `with check` lets user insert arbitrary `kind`/`payload`.

---

### 2.15 `legal_knowledge_base` (P1, pgvector)

```sql
create table legal_knowledge_base (
  id         bigserial primary key,
  source     text not null,
  section    text,
  chunk_no   int  not null,
  content_bn text not null,
  content_en text,
  embedding  vector(1024),
  created_at timestamptz not null default now()
);
```

**Index:** `create index lkb_embedding_idx on legal_knowledge_base using hnsw (embedding vector_cosine_ops);`

---

### 2.16 `offline_sync_queue` (P1)

Server-side mirror of client mutation queue; telemetry/troubleshooting only, not write path.

```sql
create table offline_sync_queue (
  id         bigserial primary key,
  device_id  text not null,
  user_id    uuid not null references profiles(id),
  op         text not null,
  target     text not null,
  payload    jsonb not null,
  client_ts  timestamptz not null,
  synced_at  timestamptz,
  status     text not null default 'pending'
);
```

`target`/`op` free text; `payload` unvalidated `jsonb`. Opaque diagnostic data; exclude from client-facing grant.

---

## 3. Helper Functions — exact

| Function | SQL | Purpose |
|----------|-----|---------|
| `is_admin()` | `language sql stable security definer set search_path = public as $$ select exists (select 1 from profiles where id = auth.uid() and role = 'admin'); $$;` | Returns true if `profiles.role = 'admin'` |
| `is_verified_advocate()` | `language sql stable security definer set search_path = public as $$ select exists (select 1 from advocates where profile_id = auth.uid() and verification = 'verified'); $$;` | Returns true if advocate `verification = 'verified'` |
| `has_case_access(p_case_id uuid)` | `language sql stable security definer set search_path = public as $$ select exists (select 1 from cases c where c.id = p_case_id and (c.client_id = auth.uid() or c.advocate_id = auth.uid())) or is_admin(); $$;` | Returns true if caller is case party or admin |
| `set_updated_at()` | `language plpgsql as $$ begin new.updated_at := now(); return new; end; $$;` | Trigger maintains `updated_at` on every mutable table |

Tables carrying `set_updated_at()` trigger: `profiles`, `advocates`, `sos_requests`, `cases`, `consents`, `hearings`, `ai_summaries`, `invoices`, `documents`, `checklist_items`. Not applied to `payments`, `audit_logs`, `notifications`, `checklist_templates`, `invoice_items`.

---

## 4. RPC Functions — exact signatures

| RPC | Signature | Purpose |
|-----|-----------|---------|
| `complete_signup` | `(p_role user_role, p_full_name text, p_language text)` | Only insert path into `profiles`; copies role into JWT `app_metadata` |
| `submit_verification` | — | Advocate verification submission |
| `admin_decide` | `(p_advocate_id uuid, p_decision text, p_rejection_reason text)` | Approve/reject advocate; audit trail |
| `accept_sos` | `(p_sos_id uuid) returns sos_requests` | Row-locked single accept; returns `NULL` if race lost |
| `create_case_from_sos` | `(p_sos_id uuid) returns uuid` | Creates case row + clones checklist templates |
| `submit_triage` | `(p_input jsonb) returns ai_triage_sessions` | Records triage session; enforces 10/24h rate limit |
| `publish_ai_summary` | `(p_summary_id uuid, p_pin text, p_final_bn text) returns ai_summaries` | PIN-gated publish; draft->published |
| `admin_force_publish` | `(p_summary_id uuid, p_reason text)` | Admin override publish; requires `is_admin()` + non-empty reason |
| `next_invoice_no` | `(p_advocate uuid) returns text` | `INV-{YEAR}-{SEQ}` per advocate, reset Jan 1 |
| `advocate_search` | `(p_type text, p_district text, p_court text, p_max_fee numeric, p_lang text)` | Ranked search over verified advocates |
| `request_update` | `(p_case_id uuid)` | Client requests advocate update; deduped 1/24h |
| `expire_drafts` | — | Cron: drafts older than 7 days -> archived |
| `expire_sos` | — | Cron: open SOS older than 24h -> expired |

### 4.1 `accept_sos` — exact body

```sql
create or replace function accept_sos(p_sos_id uuid)
returns sos_requests
language plpgsql security definer set search_path = public as $$
declare v_row sos_requests;
begin
  if not is_verified_advocate() then
    raise exception 'not_verified_advocate';
  end if;

  update sos_requests
     set status = 'accepted', advocate_id = auth.uid(), accepted_at = now()
   where id = p_sos_id and status = 'open'
  returning * into v_row;

  if v_row.id is null then
    return null;
  end if;

  insert into audit_logs(actor_id, actor_role, action, entity, entity_id)
  values (auth.uid(), 'advocate', 'sos.accept', 'sos_requests', p_sos_id);

  perform create_case_from_sos(p_sos_id);
  return v_row;
end $$;
```

### 4.2 `publish_ai_summary` — pseudocode exact

```sql
-- 1) verify pin_hash with pgcrypto crypt()
-- 2) enforce pin_fail_count < 5 and pin_locked_until < now(); increment on failure
-- 3) require state = 'draft' and expires_at > now()
-- 4) set state='published', final_bn, approved_by=auth.uid(), published_by='advocate'
-- 5) audit_logs insert 'summary.publish'
-- 6) notifications insert (dedupe_key = 'summary:'||id)
```

---

## 5. Cron Jobs — exact

| Job | Schedule | Effect |
|-----|----------|--------|
| `expire_drafts()` | hourly | `ai_summaries` where `state='draft'` and `expires_at < now()` → `archived`; notify advocate |
| `escalate_pending_checklists()` | hourly | `checklist_items` in `suggested_pending_advocate` older than 48 h → flag case general list mode; notify advocate |
| `expire_sos()` | every 15 min | `sos_requests` where `status='open'` and `expires_at < now()` → `expired`; notify client |
| `purge_triage_inputs()` | daily | Nulls `ai_triage_sessions.input_redacted` for rows older than 30 days |
| `send_overdue_invoice_reminders()` | daily | 3/7/14-day reminders; at 30 days flags for advocate |
| `annual_reverify_reminder()` | daily 09:00 Asia/Dhaka | PRD F2 annual re-verification |

**`annual_reverify_reminder` body:**
```sql
create or replace function annual_reverify_reminder() returns void
language plpgsql security definer set search_path = public as $$
begin
  insert into notifications(user_id, kind, title_bn, body_bn, dedupe_key)
  select a.profile_id, 'advocate.reverify_due',
         'বার কাউন্সিল যাচাই নবায়ন করুন',
         'আপনার সনদ বার্ষিক যাচাইয়ের সময় হয়েছে।',
         'reverify:' || a.profile_id || ':' || date_trunc('day', now())::date
  from advocates a
  where a.verification = 'verified'
    and a.reverify_due_at between now() and now() + interval '30 days';

  update advocates
     set verification = 'pending',
         reverify_due_at = now() + interval '90 days'
   where verification = 'verified'
     and reverify_due_at is not null
     and reverify_due_at <= now();

  insert into audit_logs(actor_id, actor_role, action, entity, metadata)
  select null, 'admin', 'advocate.reverify_swept', 'advocates',
         jsonb_build_object('profile_id', a.profile_id, 'due_at', a.reverify_due_at)
  from advocates a
  where a.verification = 'pending'
    and a.reverify_due_at is not null
    and a.reverify_due_at <= now() - interval '90 days';
end $$;
```

---

## 6. Storage Buckets — exact

| Bucket | Public | Path Convention | Read Access | Write Access |
|--------|--------|-----------------|-------------|--------------|
| `documents` | No | `{case_id}/{doc_id}/{filename}` | Signed URLs, 15-min expiry, case parties only | Case parties |
| `sanad` | No | `{advocate_id}/sanad.{ext}` | Admin only | Advocate (own) |
| `avatars` | Yes | `{profile_id}/avatar.{ext}` | Public | Owner |

**Storage policy example (documents):**
```sql
create policy docs_read on storage.objects for select
using (
  bucket_id = 'documents'
  and has_case_access((storage.foldername(name))[1]::uuid)
);

create policy docs_write on storage.objects for insert
using (
  bucket_id = 'documents'
  and has_case_access((storage.foldername(name))[1]::uuid)
);
```

---

## 7. RLS Denial Assertions — exact test contract

Every PR touching `db/**` must add assertions to `db/tests/rls_test.sql` and run twice (drift guard). Denial matrix:

| # | Actor | Table / Action | Expected Result |
|---|-------|----------------|-----------------|
| D-1 | Client A | Select `cases` where `client_id = client B` | 0 rows / access denied |
| D-2 | Client A | Select `hearings` where case belongs to client B | 0 rows |
| D-3 | Client A | Select `documents` where case belongs to client B | 0 rows |
| D-4 | Client A | Select `invoices` where `client_id = client B` | 0 rows |
| D-5 | Client A | Select `ai_summaries` where `state = 'draft'` | 0 rows |
| D-6 | Client A | Insert into `audit_logs` | Rejected (no insert policy) |
| D-7 | Client A | Call `admin_force_publish(...)` | Raised exception / error |
| D-8 | Unverified advocate | Select `sos_requests` where `status = 'open'` | 0 rows |
| D-9 | Unverified advocate | Call `accept_sos(...)` | `not_verified_advocate` exception |
| D-10 | Client A | Select `profiles` where `id = client B` AND `role = 'admin'` | 0 rows / denied |
| D-11 | Client A | Insert into `profiles` with `role = 'admin'` | Rejected (no INSERT policy) |
| D-12 | Advocate A | Update `invoices` where `advocate_id = advocate B` | Denied / 0 rows affected |
| D-13 | Client A | Update `checklist_items` status to `approved` | Denied (advocate-only transition) |
| D-14 | Any authenticated | Delete from `audit_logs` | Rejected (no delete policy) |

**Signed URL denial:** Document signed URL returns `403 expired` after 15 minutes.

**PIN lockout denial:** After 5 failed `publish_ai_summary` attempts within 30 min → `pin_locked_until` set; subsequent attempts rejected until lockout expires.

**Race denial:** Two concurrent `accept_sos` calls on same open SOS → exactly one returns row; second returns `NULL` (`sos_already_taken`).

---

## 8. Indexes — exact

| Index | Table | Purpose |
|-------|-------|---------|
| `advocates_districts_gin` | advocates | GIN on `districts` |
| `advocates_courts_gin` | advocates | GIN on `courts` |
| `advocates_spec_gin` | advocates | GIN on `specializations` |
| `advocates_verified_idx` | advocates | `verification = 'verified'` |
| `sos_open_by_district` | sos_requests | `(district, created_at desc) where status = 'open'` |
| `sos_client_recent` | sos_requests | `(client_id, created_at desc)` rate limiting |
| `cases_client_idx` | cases | `(client_id, state)` |
| `cases_advocate_idx` | cases | `(advocate_id, state)` |
| `hearings_case_idx` | hearings | `(case_id, hearing_date desc)` |
| `hearings_next_idx` | hearings | `(next_hearing_date) where published_at is not null` |
| `summaries_draft_expiry` | ai_summaries | `(expires_at) where state = 'draft'` |
| `summaries_case_idx` | ai_summaries | `(case_id, state)` |
| `checklist_case_idx` | checklist_items | `(case_id, status)` |
| `checklist_pending_idx` | checklist_items | `(approved_at) where status = 'suggested_pending_advocate'` |
| `invoices_case_idx` | invoices | `(case_id, state)` |
| `invoices_due_idx` | invoices | `(due_date) where state in ('sent','partially_paid')` |
| `payments_invoice_idx` | payments | `(invoice_id)` |
| `documents_case_idx` | documents | `(case_id) where deleted_at is null` |
| `triage_user_day_idx` | ai_triage_sessions | `(user_id, created_at desc)` rate limit |
| `audit_entity_idx` | audit_logs | `(entity, entity_id, created_at desc)` |
| `audit_actor_idx` | audit_logs | `(actor_id, created_at desc)` |
| `lkb_embedding_idx` | legal_knowledge_base | HNSW `(embedding vector_cosine_ops)` |

---

## 9. Migration & Seeding Strategy — exact

- Migrations live in `db/migrations/*.sql`, applied with `supabase db push` (never edited after merge).
- Pattern per change: **expand → migrate → contract**.
- Seed data (`db/seed.sql`): 5 checklist templates (criminal, bail, family, property, women & child) with BN/EN names; 3 test advocates; 3 test clients; 1 admin.
- `db/tests/rls_test.sql` runs after migrations in CI: asserts per-table "client A cannot see client B's row" and "advocate cannot see unassigned cases".
- Dual-folder sync: every `db/migrations/` edit copied to `supabase/migrations/`.
