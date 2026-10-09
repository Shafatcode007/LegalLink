# LegalLink — Database Schema Reference

**Version:** 1.0  
**Date:** October 2026  
**Companion docs:** PRD v2.0, TRD v1.0

## Conventions
- Table names: plural snake_case
- Every table has: id (uuid PK), created_at, updated_at
- Money: numeric(12,2) in BDT
- Soft delete via deleted_at where needed
- Optimistic locking via version field
- RLS enforced on every table

## Sections (to be filled)
1. Enum Types
2. Core Tables
3. Helper Functions
4. RPC Functions
5. Cron Jobs
6. Storage Buckets
7. RLS Matrix
8. Indexes
9. ER Diagram

## 1. Enum Types

Source: TRD §5.2 — all state columns are Postgres enums; there are no free-text status columns. Values are added only via `alter type X add value '...'` in an expand migration; never reuse, reorder, or remove labels.

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

### 2.1 profiles

Source: TRD §5.4 + §5.5. Extends `auth.users`; one row per authenticated user. No `deleted_at` — users are never hard- or soft-deleted here (TRD §5.1).

| Column | Type | Constraints | Purpose |
|---|---|---|---|
| `id` | uuid | PK, `references auth.users(id) on delete restrict` | Mirrors the auth user id; join key for all other tables |
| `role` | user_role | not null, default `'client'` | Authorisation role; **never client-set** (see insert note) |
| `full_name` | text | nullable | Display name shown to counterparties |
| `phone` | text | not null | E.164 format, e.g. `+8801XXXXXXXXX` |
| `language` | text | not null, default `'bn'`, check in (`'bn'`,`'en'`) | UI + AI response language |
| `avatar_url` | text | nullable | Profile photo URL |
| `fcm_token` | text | nullable | Latest FCM registration token, last write wins |
| `fcm_updated_at` | timestamptz | nullable | When the device last refreshed its token |
| `created_at` | timestamptz | not null, default `now()` | Audit |
| `updated_at` | timestamptz | not null, default `now()` | Audit; maintained by shared `set_updated_at()` trigger |

**Foreign keys**

| Column | References | On delete |
|---|---|---|
| `id` | `auth.users(id)` | `restrict` |

Outbound: `profiles.id` is referenced by `advocates.profile_id`, `sos_requests.client_id`, `cases.client_id`, `cases.advocate_id`, `audit_logs.actor_id`, `notifications.user_id` (TRD §5.3).

**RLS policies**

```sql
alter table profiles enable row level security;

create policy profiles_select_self on profiles for select
  using (id = auth.uid() or is_admin());

create policy profiles_update_self on profiles for update
  using (id = auth.uid()) with check (id = auth.uid());
```

There is intentionally **no INSERT policy** on `profiles` — creation goes through `complete_signup()` so `role` cannot be self-assigned as `admin` (TRD §5.5). Adding one would let any client insert `role = 'admin'` and pass every `is_admin()` check. There is also no DELETE policy (soft-delete doctrine). Cross-advocate public data is exposed through the `advocate_public` view rather than by widening this policy.

### 2.2 advocates

Source: TRD §5.4 + §5.5. 1:1 extension of `profiles` (one advocate row per advocate profile). No `deleted_at`; availability is a free-form `jsonb` schedule.

| Column | Type | Constraints | Purpose |
|---|---|---|---|
| `profile_id` | uuid | PK, `references profiles(id) on delete restrict` | Owning profile; doubles as the row id (1:1) |
| `nid_number` | text | nullable | National ID number used for verification |
| `bar_council_no` | text | not null | Bar Council registration number |
| `sanad_url` | text | nullable | Uploaded sanad (certificate) URL |
| `nid_url` | text | nullable | Uploaded NID document URL |
| `years_practice` | int | check (`years_practice >= 0`) | Displayed experience |
| `specializations` | text[] | not null, default `'{}'` | e.g. criminal, bail, family, property, labor, women_child |
| `courts` | text[] | not null, default `'{}'` | Courts the advocate appears in |
| `districts` | text[] | not null, default `'{}'` | Served districts (SOS matching) |
| `languages` | text[] | not null, default `'{bn}'` | Spoken languages |
| `fee_min_bdt` | numeric(12,2) | nullable | Lower bound of quoted fee, BDT |
| `fee_max_bdt` | numeric(12,2) | nullable, table check (below) | Upper bound of quoted fee, BDT |
| `verification` | verification_state | not null, default `'pending'` | Admin decision on credentials |
| `rejection_reason` | text | nullable | Shown to advocate when rejected |
| `attempts` | int | not null, default 0 | Re-verification attempt counter |
| `pin_hash` | text | nullable | pgcrypto/bcrypt hash of the 4-digit publish PIN |
| `pin_fail_count` | int | not null, default 0 | Failed PIN attempts |
| `pin_locked_until` | timestamptz | nullable | Lockout expiry after repeated failures |
| `verified_at` | timestamptz | nullable | When verification was granted |
| `reverify_due_at` | timestamptz | nullable | Annual re-verification deadline |
| `availability` | jsonb | not null, default `'{}'` | Free-form availability schedule |
| `created_at` | timestamptz | not null, default `now()` | Audit |
| `updated_at` | timestamptz | not null, default `now()` | Audit; maintained by `set_updated_at()` |

**Foreign keys**

| Column | References | On delete |
|---|---|---|
| `profile_id` | `profiles(id)` | `restrict` |

**Fee-range check constraint**

```sql
check (fee_max_bdt is null or fee_min_bdt is null or fee_max_bdt >= fee_min_bdt)
```

Nullable on both sides, so an advocate may quote either bound alone or leave both empty; the constraint only rejects a populated inverted range.

**RLS policies**

```sql
alter table advocates enable row level security;

create policy advocates_self_rw on advocates for all
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());

create policy advocates_admin_all on advocates for all
  using (is_admin()) with check (is_admin());
```

Advocates own their row; admins manage verification. Clients do **not** read this table directly — they see only verified rows through the view below.

**advocate_public view**

```sql
create view advocate_public as
  select p.id, p.full_name, p.avatar_url, a.specializations, a.courts,
         a.districts, a.languages, a.years_practice, a.fee_min_bdt,
         a.fee_max_bdt, a.verification
  from profiles p join advocates a on a.profile_id = p.id
  where a.verification = 'verified';

grant select on advocate_public to authenticated;
```

The `where` clause on the view is the enforcement point: a client granted `select` can only ever see rows the table policy would have allowed anyway. Excluded deliberately: `phone`, `nid_number`, `pin_hash`, and all verification-internal columns.

### 2.3 sos_requests

Source: TRD §5.4 + §5.5. Emergency intake. This is the only table with a self-expiry (`expires_at`), enforced by the `expire_sos()` cron job (§5.7).

| Column | Type | Constraints | Purpose |
|---|---|---|---|
| `id` | uuid | PK, default `gen_random_uuid()` | SOS identifier |
| `client_id` | uuid | not null, references `profiles(id)` | Client who raised it |
| `person_name` | text | nullable | The arrested person (may differ from client) |
| `thana` | text | not null | Police station |
| `district` | text | not null | Used by advocate district matching |
| `court` | text | nullable | Court, if already assigned |
| `charges` | text | nullable | Charges as stated at intake |
| `arrested_at` | timestamptz | nullable | Arrest timestamp |
| `person_nid` | text | nullable | NID of the arrested person |
| `urgency` | text | not null, default `'high'` | Free-text urgency |
| `contact_phone` | text | not null | Reach-back number for the advocate |
| `notes` | text | nullable | Free-text intake notes |
| `status` | sos_state | not null, default `'open'` | Lifecycle state |
| `advocate_id` | uuid | references `profiles(id)` | Set on accept |
| `accepted_at` | timestamptz | nullable | When an advocate accepted |
| `expires_at` | timestamptz | not null, default `now() + interval '24 hours'` | Unaccepted SOS auto-expire |
| `created_at` | timestamptz | not null, default `now()` | Audit |
| `updated_at` | timestamptz | not null, default `now()` | Audit; `set_updated_at()` |

**Foreign keys:** `client_id → profiles(id)`, `advocate_id → profiles(id)` (both no explicit ON DELETE, i.e. `no action`). Outbound: `cases.sos_id → sos_requests(id)`.

**RLS policies**

```sql
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
```

### 2.4 cases

Source: TRD §5.4 + §5.5. A case may be created directly by a client or born from an accepted SOS.

| Column | Type | Constraints | Purpose |
|---|---|---|---|
| `id` | uuid | PK, default `gen_random_uuid()` | Case identifier |
| `case_number` | text | nullable | Court-assigned; null at creation |
| `client_id` | uuid | not null, references `profiles(id)` | Case owner |
| `advocate_id` | uuid | references `profiles(id)` | Assigned advocate, nullable while unassigned |
| `sos_id` | uuid | **unique**, references `sos_requests(id)` | Origin SOS; enforces the 1:1 |
| `case_type` | text | not null | criminal, bail, family, property, labor, women_child |
| `court` | text | nullable | Court |
| `district` | text | nullable | District |
| `parties` | jsonb | not null, default `'{}'` | Free-form party structure |
| `state` | case_state | not null, default `'created'` | Lifecycle state |
| `closed_at` | timestamptz | nullable | Set on close/archive |
| `transfer_log` | jsonb | not null, default `'[]'` | Append-only `[{from,to,at,reason}]` history |
| `created_at` | timestamptz | not null, default `now()` | Audit |
| `updated_at` | timestamptz | not null, default `now()` | Audit; `set_updated_at()` |

**Foreign keys:** `client_id → profiles(id)`, `advocate_id → profiles(id)`, `sos_id → sos_requests(id)`. Outbound: `consents.case_id`, `hearings.case_id`, `ai_summaries.case_id`, `invoices.case_id`, `documents.case_id`, `checklist_items.case_id`, `ai_triage_sessions.case_id` (TRD §5.3).

**The 1:1 with sos_requests**

```sql
sos_id uuid unique references sos_requests(id)  -- 1:1 when born from SOS
```

`unique` is what makes it one-to-one rather than one-to-many — no SOS can spawn two cases. The column stays nullable, so a client-originated case simply has `sos_id is null` and the reverse (`sos_requests → cases`) is genuinely 1-to-0..1. The row is created inside `accept_sos()`, which is what keeps the SOS `status` and the case creation atomic.

**RLS policies**

```sql
alter table cases enable row level security;

-- cases: client and assigned advocate only; admins read all
create policy cases_read  on cases for select
  using (client_id = auth.uid() or advocate_id = auth.uid() or is_admin());

create policy cases_client_write on cases for insert
  with check (client_id = auth.uid());

create policy cases_advocate_update on cases for update
  using (advocate_id = auth.uid() or is_admin())
  with check (advocate_id = auth.uid() or is_admin());
```

An advocate can read the case only once assigned; admins still read via `cases_read`'s own `is_admin()` branch. No DELETE policy (soft-delete doctrine).

### 2.5 consents

Source: TRD §5.4 + §5.5. Legal compliance record (PRD F8). One of only three tables carrying the `version` optimistic-lock column. Revocation is a state change (`revoked_at`), never a delete.

| Column | Type | Constraints | Purpose |
|---|---|---|---|
| `id` | uuid | PK, default `gen_random_uuid()` | Consent identifier |
| `case_id` | uuid | not null, references `cases(id)` | Case the consent covers |
| `client_id` | uuid | not null, references `profiles(id)` | Grantor |
| `advocate_id` | uuid | not null, references `profiles(id)` | Grantee |
| `scope` | text[] | not null, default `'{case_data}'` | What is shared; narrow the default explicitly |
| `granted_at` | timestamptz | not null, default `now()` | When consent was given |
| `revoked_at` | timestamptz | nullable | Set on revoke; null while active |
| `version` | int | not null, default 1 | **Optimistic lock** (PRD F8) |
| `created_at` | timestamptz | not null, default `now()` | Audit |
| `updated_at` | timestamptz | not null, default `now()` | Audit; `set_updated_at()` |

**Table constraint:** `unique (case_id, advocate_id, revoked_at)`. Because NULLs are distinct in Postgres, this permits many *active* consents for the same pair while blocking duplicate revoked rows with an identical timestamp — it is not a full "one live consent per pair" guarantee.

**Optimistic locking**

```sql
version int not null default 1,  -- optimistic lock (PRD F8)
```

`grant_consent()` / `revoke_consent()` (§5.6) take an expected `version` and fail on conflict when the stored value has moved on, which stops a stale client from revoking a consent that was re-granted underneath it. Two caveats: the column does nothing unless every write path checks it (a direct PostgREST `update` bypasses the RPC), and the TRD does not say whether the increment lives in the RPC or a trigger — worth pinning down before migration work.

**RLS policies**

```sql
alter table consents enable row level security;

-- consents: client grants/revokes; advocate reads
create policy consents_client_all on consents for all
  using (client_id = auth.uid()) with check (client_id = auth.uid());

create policy consents_advocate_read on consents for select
  using (advocate_id = auth.uid() or is_admin());
```

The client policy is `for all` with no predicate on `revoked_at`, so a client can insert a consent row whose `client_id` is themselves but whose `advocate_id` is any profile — fabricating consent *to* an arbitrary advocate — and can widen `scope` freely. That check belongs in `grant_consent()`; the policy alone does not enforce it.

### 2.6 hearings

Source: TRD §5.4 + §5.5. Append-only amendment chain — rows are never edited in place, only superseded.

| Column | Type | Constraints | Purpose |
|---|---|---|---|
| `id` | uuid | PK, default `gen_random_uuid()` | Hearing record id |
| `case_id` | uuid | not null, references `cases(id)` | Owning case |
| `hearing_date` | date | not null | Date of the hearing |
| `court` | text | nullable | Court |
| `outcome_notes` | text | nullable | Advocate raw notes (pre-AI input) |
| `next_hearing_date` | date | nullable | Next scheduled date |
| `entered_by` | uuid | not null, references `profiles(id)` | Advocate who entered it |
| `version` | int | not null, default 1 | Chain version counter |
| `supersedes_id` | uuid | references `hearings(id)` | Previous version this row amends |
| `is_amended` | boolean | not null, default `false` | Marks the row as replaced |
| `published_at` | timestamptz | nullable | Null = not visible to the client |
| `created_at` | timestamptz | not null, default `now()` | Audit |
| `updated_at` | timestamptz | not null, default `now()` | Audit; `set_updated_at()` |

**Immutability via the supersedes_id chain**

Amending inserts a *new* row pointing at its predecessor through `supersedes_id` and flips `is_amended = true` on the old one. Nothing is overwritten, so history stays auditable — the same reasoning as the no-hard-delete rule in §5.1. `published_at is null` is the second half of the model: the advocate drafts privately, and only publishing makes a version client-visible.

Two gaps the DDL does not close:

- The self-reference is not guarded — nothing prevents two rows claiming the same predecessor, or a cycle (`a → b → a`). A partial `unique (supersedes_id)` index plus a non-cycle trigger would harden it.
- `hearings_advocate_rw` below is `for all` on an immutable-by-design table. An advocate can `update` in place, which defeats the chain, and `with check` lets them rewrite `supersedes_id` / `published_at` freely. Either drop `update` and route amendments through an RPC, or add a trigger rejecting updates once `supersedes_id` is set.

**RLS policies**

```sql
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
```

`published_at is not null` is the visibility gate — it is why a draft cannot leak to a client even though the client policy has no advocate check. It does not filter superseded rows though: a client sees every published version in the chain, including ones later amended. If only the current version should be visible, add `and is_amended = false`.

### 2.7 ai_summaries

Source: TRD §5.4 (table) + §5.5 (policies) + §5.6 (RPCs) + §9.3 (PIN handling). Human-in-the-loop state machine; third and final table carrying the `version` optimistic lock.

| Column | Type | Constraints | Purpose |
|---|---|---|---|
| `id` | uuid | PK, default `gen_random_uuid()` | Summary identifier |
| `case_id` | uuid | not null, references `cases(id)` | Owning case |
| `hearing_id` | uuid | references `hearings(id)` | Source hearing, if generated from one |
| `raw_input` | text | not null | Advocate notes; the PII-redacted value is what gets stored |
| `draft_bn` | text | not null | Raw AI output |
| `final_bn` | text | nullable | Advocate-edited final text |
| `state` | summary_state | not null, default `'draft'` | `draft` → `published` / `archived` |
| `model` | text | nullable | e.g. qwen2.5-7b-instruct, qwen2.5-3b-instruct (HF Serverless / HF transformers) |
| `prompt_version` | text | nullable | e.g. summary_v3 |
| `tokens_used` | int | nullable | Cost/observability tracking |
| `approved_by` | uuid | references `profiles(id)` | Approver profile |
| `published_by` | text | nullable | `'advocate'` or `'admin_override'` |
| `override_reason` | text | nullable | Required when `published_by = 'admin_override'` |
| `flagged` | boolean | not null, default `false` | Quality/guardrail flag |
| `archived_at` | timestamptz | nullable | Set by the 7-day expiry sweep |
| `expires_at` | timestamptz | not null, default `now() + interval '7 days'` | Draft expiry deadline |
| `created_at` | timestamptz | not null, default `now()` | Audit |
| `updated_at` | timestamptz | not null, default `now()` | Audit; `set_updated_at()` |
| `version` | int | not null, default 1 | Optimistic lock |

**HITL state machine**

`draft` is the only client-invisible state. Two exits:

- `draft → published` via `publish_ai_summary(p_summary_id, p_pin, p_final_bn)`, which requires `state = 'draft'` **and** `expires_at > now()`, verifies the PIN, then sets `state`, `final_bn`, `approved_by`, `published_by = 'advocate'`. A trigger writes the `audit_logs` row and enqueues the notification.
- `draft → published` via `admin_force_publish(p_summary_id, p_reason)`, admin-only, requires `is_admin()` **and** a non-empty `p_reason`, sets `published_by = 'admin_override'`, and writes an `audit_logs` row with action `admin.override`.

`archived` is terminal and reached by the `archive_stale_summaries()` sweep (§5.7) setting `archived_at` at `expires_at`. There is no un-publish and no transition out of `published` — retraction, if ever needed, is a new row per the `hearings` chain pattern, which `ai_summaries` does not currently have.

**PIN hash fields — note the location**

The PIN columns are **not** on this table. They live on `advocates` (see §2.2): `pin_hash`, `pin_fail_count`, `pin_locked_until`. `publish_ai_summary` verifies by joining to `advocates` on the case's advocate and running `crypt(p_pin, pin_hash) = pin_hash` against the bcrypt hash produced by `crypt(pin, gen_salt('bf', 10))`. Rules (§9.3): never store the PIN in plain text; 5 failed attempts per 30 minutes sets `pin_locked_until = now() + 30 min`; 3 lockouts escalate to an admin-assisted reset requiring identity re-check plus an audit row.

Status (2026-10-08): both remedies are applied in db/migrations/20261008_017_hitl_hardening.sql and 20261008_018_rpc_hardening.sql — UPDATE/DELETE on ai_summaries revoked from authenticated, INSERT guarded to draft-only, a publish-guard trigger requires the transaction-local app.internal_write GUC set only by publish_ai_summary / admin_force_publish, and client reads go through the client_ai_summaries projection (excludes raw_input, draft_bn, model, prompt_version, flagged, override_reason; includes published_by). The RLS client policy remains as defence-in-depth.

**RLS policies**

```sql
alter table ai_summaries enable row level security;

-- ai_summaries: THE HITL GUARANTEE (client can never read a draft)
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

The client policy is read-only and double-gated on `state = 'published'` plus case ownership — that pairing is the HITL guarantee at the RLS layer. Caveat: `raw_input` and `draft_bn` remain in the same row, so a published summary exposes the advocate's unredacted source notes to the client. If `raw_input` is genuinely PII-bearing, the client-facing read should go through a projection rather than the base table. Closed for client reads by the client_ai_summaries projection (017).

### 2.8 invoices + invoice_items

Source: TRD §5.4 (tables) + §5.5 (policies) + §5.6 (`next_invoice_no`) + PRD F8. Money is `numeric(12,2)` BDT throughout, never floats (§5.1).

#### invoices

| Column | Type | Constraints | Purpose |
|---|---|---|---|
| `id` | uuid | PK, default `gen_random_uuid()` | Invoice identifier |
| `invoice_no` | text | not null, **unique** | `INV-{YEAR}-{SEQ}` (per advocate) |
| `case_id` | uuid | not null, references `cases(id)` | Billed case |
| `advocate_id` | uuid | not null, references `profiles(id)` | Issuer |
| `client_id` | uuid | not null, references `profiles(id)` | Billed party |
| `subtotal_bdt` | numeric(12,2) | not null, default 0 | Sum of line items |
| `vat_rate` | numeric(5,2) | not null, default `15.00` | VAT percentage |
| `vat_bdt` | numeric(12,2) | not null, default 0 | Computed VAT amount |
| `total_bdt` | numeric(12,2) | not null, default 0 | `subtotal + vat` |
| `paid_bdt` | numeric(12,2) | not null, default 0 | Running paid total from `payments` |
| `state` | invoice_state | not null, default `'draft'` | Lifecycle state |
| `due_date` | date | nullable | Payment due date |
| `pdf_url` | text | nullable | Worker-rendered, signed (15-minute expiry) |
| `version` | int | not null, default 1 | Optimistic lock |
| `created_at` | timestamptz | not null, default `now()` | Audit |
| `updated_at` | timestamptz | not null, default `now()` | Audit; `set_updated_at()` |

**INV-YEAR-SEQ numbering**

`next_invoice_no(p_advocate uuid) returns text` (§5.6) produces the number: sequence scoped **per advocate**, reset every 1 January, format `INV-{YEAR}-{SEQ}` (e.g. `INV-2026-0042`). Uniqueness is enforced by the `unique` constraint on `invoice_no`. Per PRD F8 the sequence is **never reused** — a voided invoice keeps its number with `state = 'void'` rather than freeing it. Worth noting: the `unique` is global across the table while the sequence is per advocate, so two advocates can each hold an `INV-2026-0001`. The PRD's "unique per advocate" phrasing holds by construction order, not by the constraint.

**VAT calculation**

`vat_rate` defaults to `15.00`, stored as a percentage in `numeric(5,2)`. `vat_bdt` and `total_bdt` are **denormalised stored columns with `default 0`** — there is no generated column, check constraint, or trigger tying them to `subtotal_bdt` or the line items. Nothing in the DDL enforces `vat_bdt = subtotal_bdt * vat_rate / 100` or `total_bdt = subtotal_bdt + vat_bdt`. An advocate holding update rights on `invoices` can write an arbitrary `total_bdt` and no database rule objects. The invariant must be maintained by the write path (recompute inside the invoice RPC after every line-item change); if any direct `update` path exists, totals will drift. A `check (total_bdt = subtotal_bdt + vat_bdt)` would make it structural, though percentage rounding at 2dp needs a `round(..., 2)` to be stable.

**RLS policies**

```sql
alter table invoices enable row level security;

create policy invoices_party on invoices for select
  using (advocate_id = auth.uid() or client_id = auth.uid() or is_admin());

create policy invoices_advocate_write on invoices for all
  using (advocate_id = auth.uid()) with check (advocate_id = auth.uid());
```

Advocates own the write path; clients read. Same `for all` caveat as earlier sections: `with check` pins `advocate_id` to self but not `case_id` or `client_id`, so an advocate can invoice an arbitrary case or arbitrary client. The state machine (`draft → sent → partially_paid → paid / overdue / void`) is enforced by the payment/voiding RPCs, not by the policy — `state` and `paid_bdt` are freely writable through this policy.

#### invoice_items

| Column | Type | Constraints | Purpose |
|---|---|---|---|
| `id` | uuid | PK, default `gen_random_uuid()` | Line item identifier |
| `invoice_id` | uuid | not null, references `invoices(id)` **on delete cascade** | Parent invoice |
| `description` | text | not null | Free-text line description |
| `amount_bdt` | numeric(12,2) | not null | Line amount; no positivity check |
| `created_at` | timestamptz | not null, default `now()` | Audit |

**Cascade delete**

`on delete cascade` on `invoice_id` is the one place in the schema where a hard delete propagates — a genuine departure from the no-hard-delete doctrine in §5.1. Deleting an `invoices` row silently removes its line items. That is defensible for a draft but not for `paid` or `void` invoices, which are financial records. The TRD defines no DELETE policy on `invoices`, so under RLS a direct delete is rejected by default and this cascade would only fire from `service_role` (the Worker or a maintenance script) or from an RPC running as owner. Worth an explicit decision: either restrict deletes to `state = 'draft'` inside an RPC, or accept that only privileged paths can cascade and note that `paid` invoices are protected by policy rather than by schema.

`invoice_items` has no `updated_at` (immutable by convention — edits are delete-and-reinsert) and no `version`, so line-item edits are not optimistically locked.

**RLS policies**

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

**`with check (true)` is the only unbounded clause in the schema.** Unlike every other write policy here, it does not re-assert that the parent invoice belongs to the caller, so any advocate can insert a line item against *any* invoice id — including one belonging to a different advocate — writing arbitrary amounts into someone else's invoice. It also permits inserting items onto an already-`paid` invoice, mutating a settled financial record. The `using` side is correct (it checks ownership for updates/deletes); only the insert path is unguarded. Reusing the same `exists (... and i.advocate_id = auth.uid())` predicate from the `using` clause as the `with check` closes the hole at no cost.

### 2.9 Remaining Tables

Source: TRD §5.4. Brief entries — purpose line plus key columns only. Full DDL lives in `db/migrations/`; this section exists so the table inventory is complete in one place. That brings the count to 16 tables across the 18-table / 16-group MVP scope.

#### payments

Partial payments against an invoice, verified manually (no payment gateway in the MVP).

Key columns: `invoice_id → invoices(id)`, `amount_bdt numeric(12,2) not null check (amount_bdt > 0)` — the only positivity check in the schema, `method payment_method`, `txn_id` (bKash/Nagad TrxID), `proof_url`, `recorded_by → profiles(id)`, `verified boolean not null default false`, `dispute_note`.

RLS: `payments_party` is `for all` with the `using` admitting case parties but `with check` admitting only the advocate — so a client can read their payment history but not insert rows. Correct as written. No `updated_at` (append-only).

#### documents

Case document vault with offline-aware upload. **The only table in the MVP with `deleted_at`** (TRD §5.1).

Key columns: `case_id`, `checklist_item_id → checklist_items(id)`, `uploaded_by`, `doc_type` (fir|arrest_memo|nid|invoice_proof|order|other), `storage_path` (null while offline-local only), `local_ref` (device-local reference per PRD F8), `mime_type`, `size_bytes`, `status doc_status`, `reject_reason`, `deleted_at`.

RLS: `documents_party` is `for all` using `case_id is not null and has_case_access(case_id) and deleted_at is null` with `with check (uploaded_by = auth.uid())`. Soft-deleted rows vanish from every select for case parties. The `with check` does not re-test `deleted_at`, so a client can insert a row already marked deleted — harmless, but the filter and the check are not symmetric.

#### checklist_templates + checklist_items

Admin-authored checklist definitions plus the per-case instances generated from them.

`checklist_templates` (admin-managed): `case_type`, `item_name_bn` / `item_name_en`, `importance text not null check (importance in ('high','medium','low'))`, `purpose_bn`, `sort_order`, `active boolean`. No `updated_at`; deactivation via `active`, never delete.

`checklist_items`: `case_id`, `template_id → checklist_templates(id)`, `item_name_bn`, `importance`, `status checklist_state not null default 'suggested_pending_advocate'`, `ai_reason_bn`, `approved_by`, `approved_at`, `reject_reason`.

RLS: `checklist_client_read` (parties read), `checklist_advocate_rw` (`for all`, `with check (true)` — **same unbounded insert as `invoice_items`**), and `checklist_client_upload`, which restricts clients to `status in ('uploaded','needs_review')`. That last policy is the one place the schema does it right: `using` scopes to the client's own case, `with check` pins the status transition to the upload path only. Worth using as the template when fixing `invoice_items`. Caveat: its `with check` does not restrict *which* columns change, so a client can also rewrite `item_name_bn` or `approved_by` on their own case items.

#### ai_triage_sessions

Audit and telemetry for AI triage runs — records what was sent and what came back.

Key columns: `user_id`, `case_id` (null before the case exists), `input_hash` (sha256 of the **pre-redaction** input), `input_redacted` (what was actually sent to the LLM), `output_json` (`{case_type, urgency, overview, actions[], checklist[]}`), `model`, `prompt_version`, `tokens_used`, `fallback_used boolean not null default false`.

Retention: `input_redacted` is nulled after 30 days by cron (PRD §10). Storing `input_hash` of the unredacted text alongside it is the deliberate design — the hash proves what was submitted without retaining the content. No `updated_at`; rows are immutable.

Note `case_id → cases` is 1-to-0..1 (§5.3), but the DDL does not enforce it: a second triage session can point at the same case. If one-triage-per-case is intended, it needs a partial unique index.

#### audit_logs

Append-only system of record for every privileged action.

Key columns: `id bigserial primary key`, `actor_id → profiles(id)` (nullable — system actions), `actor_role user_role`, `action` (`sos.accept` | `summary.publish` | `admin.override` | ...), `entity`, `entity_id`, `metadata jsonb`, `ip inet`, `device`, `created_at`. No `updated_at` by design.

**No UPDATE or DELETE policy is ever created for this table** (TRD line 619). RLS deny-by-default is the entire enforcement: with only a `select` policy, no authenticated role can mutate a row. That is stronger than the `for all` pattern used elsewhere and should be the model for the audit trail.

Two practical consequences. First, append-only is enforced only at the RLS layer — a `service_role` or table-owner path can still mutate rows, so a `before update or delete` trigger raising an exception would make the guarantee structural rather than policy-dependent. Second, `actor_id` is nullable and unconstrained, so a row can be written with a fabricated or absent actor; a policy requiring `actor_id = auth.uid()` for non-service writes would tighten it.

#### notifications

Per-user push / in-app message records.

Key columns: `user_id → profiles(id)`, `kind` (`sos.accepted` | `checklist.approved` | `hearing.reminder` | ...), `title_bn`, `body_bn`, `payload jsonb`, `channel` (`push` | `in_app`), `sent_at`, `read_at`, `dedupe_key text unique`, `created_at`.

RLS: `notifications_self` is `for all` using and checking `user_id = auth.uid()` — correct and tight. Two notes: the `unique dedupe_key` is global rather than scoped per user, so two users cannot share a dedupe key even for identical `kind` values; and `with check` lets a user insert rows with an arbitrary `kind` and `payload`, including a forged `sos.accepted`. Harmless for display, but if anything downstream trusts `kind`, it should be set by a trigger rather than the client.

#### legal_knowledge_base (P1, pgvector)

RAG corpus for the chatbot. Sourced from the `sakhadib/Bangladesh-Legal-Acts-Dataset` on Hugging Face. Standalone — no FK to any user or case table (§5.3).

Key columns: `id bigserial`, `source` (`'Penal Code 1860'`), `section` (`'Section 496'`), `chunk_no`, `content_bn not null`, `content_en`, `embedding vector(1024)` (bge-m3 dimension), `created_at`.

Index: `create index lkb_embedding_idx on legal_knowledge_base using hnsw (embedding vector_cosine_ops)` (§5.5). Requires the `pgvector` extension. Ingestion is offline (300-500 word chunks, 50-word overlap); queries take top-5 by `<=>` cosine distance, with a 0.35 similarity floor below which the answer is "consult an advocate".

**P1, not MVP.** The TRD scopes RAG to P1, so this table and `offline_sync_queue` sit outside the day-1 migration set.

#### offline_sync_queue (P1)

Server-side mirror of the client mutation queue, for telemetry and troubleshooting only — **not** the write path. The authoritative queue lives on-device in Hive (PRD F8).

Key columns: `id bigserial`, `device_id`, `user_id → profiles(id)`, `op` (`insert|update|delete`), `target` (table name), `payload jsonb`, `client_ts`, `synced_at`, `status` (`pending|applied|conflict|failed`).

`target` and `op` are free text naming an arbitrary table and mutation, and `payload` is unvalidated `jsonb`. Treat this as opaque diagnostic data: no RPC should ever replay a row from it, and it should be excluded from any client-facing grant. If it ever becomes a real write path it needs per-target allowlists and a schema per operation.

## 3. Helper Functions

Source: TRD §5.5. Three boolean predicates plus one trigger function. All are `security definer` — this is deliberate, not incidental: each one queries a table that has its own RLS policies calling back into these helpers, so without `security definer` the inner query would be evaluated against the caller's (empty) policy set and every predicate would return false. `set search_path = public` is set on each to prevent search-path hijacking.

```sql
create or replace function is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles
                 where id = auth.uid() and role = 'admin');
$$;

create or replace function is_verified_advocate() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from advocates
                 where profile_id = auth.uid() and verification = 'verified');
$$;

create or replace function has_case_access(p_case_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from cases c
    where c.id = p_case_id
      and (c.client_id = auth.uid() or c.advocate_id = auth.uid())
  ) or is_admin();
$$;
```

- **`is_admin()`** — is the caller an admin? Used in nearly every policy's admin branch. Reads `profiles.role`, not the JWT claim, so a stale token cannot confer admin rights.
- **`is_verified_advocate()`** — is the caller verified? Gates `sos_advocate_select_open` and `accept_sos()`.
- **`has_case_access(p_case_id uuid)`** — is the caller a party to this case, or an admin? Takes the case id explicitly so it composes into policies on child tables (`documents`) without a correlated subquery written inline.

Two notes on these. They are `stable`, so Postgres may cache the result within a statement — correct here, since role and verification do not change mid-statement. And because they are `security definer` owned by the migration role, they bypass RLS on `profiles`/`advocates`/`cases` for *any* caller; that is correct for a predicate function, but it does mean they must never be granted to `anon` — an unauthenticated caller passes `auth.uid() is null`, which matches no row, so the predicates correctly return false.

### 3.1 set_updated_at() trigger

Every `updated_at` on every mutable table is maintained by this one function. No application code writes `updated_at` manually (TRD §5.1).

```sql
create or replace function set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- applied to every mutable table, e.g.
create trigger profiles_set_updated_at before update on profiles
  for each row execute function set_updated_at();
create trigger cases_set_updated_at before update on cases
  for each row execute function set_updated_at();
create trigger hearings_set_updated_at before update on hearings
  for each row execute function set_updated_at();
create trigger ai_summaries_set_updated_at before update on ai_summaries
  for each row execute function set_updated_at();
-- ... one per mutable table
```

Intentionally **not** `security definer` — it mutates no tables and needs no privilege elevation. Tables carrying the trigger: `profiles`, `advocates`, `sos_requests`, `cases`, `consents`, `hearings`, `ai_summaries`, `invoices`, `documents`, `checklist_items`. Not applied to `payments`, `audit_logs`, `notifications`, `checklist_templates`, or `invoice_items`, none of which have an `updated_at` column.

⚠️ **The function body above is not in the TRD.** TRD §5.1 names `set_updated_at()` and `.docsbuild/db03.md` §4.4 shows the trigger wiring, but neither carries the `create or replace function` statement. What is shown here is the conventional implementation, not sourced text. Confirm it against the intended migration before treating it as authoritative.

A consequence worth knowing: because the trigger overwrites `updated_at` unconditionally, a client cannot forge it — good — but the column also cannot be used to detect "no-op" writes, since any `update` that passes RLS bumps it whether or not values actually changed.

## 4. RPC Functions

Source: TRD §5.7. These exist because the operations must be atomic and enforce business rules that RLS alone cannot express. All are `security definer` with `set search_path = public`, and all must be reachable via `POST /rest/v1/rpc/<name>`.

| RPC | Signature | Purpose |
|---|---|---|
| `accept_sos` | `(p_sos_id uuid) returns sos_requests` | Claims an open SOS under a row lock, writes the audit row, then creates the case via `create_case_from_sos`. |
| `create_case_from_sos` | `(p_sos_id uuid) returns uuid` | Creates the `cases` row from an accepted SOS and clones the admin checklist templates as `suggested_pending_advocate`. |
| `submit_triage` | `(p_input jsonb) returns ai_triage_sessions` | Records the triage session, materialises `checklist_items` from templates plus AI suggestions, enforces the 10-per-24h rate limit. |
| `publish_ai_summary` | `(p_summary_id uuid, p_pin text, p_final_bn text) returns ai_summaries` | Verifies the advocate's 4-digit PIN, enforces lockout, then publishes a draft summary and fans out audit + notification. |
| `admin_force_publish` | `(p_summary_id uuid, p_reason text)` | Admin-only override publish; requires `is_admin()` **and** a non-empty reason, sets `published_by='admin_override'`, writes `admin.override` to `audit_logs`. |
| `next_invoice_no` | `(p_advocate uuid) returns text` | Returns the next `INV-{YEAR}-{SEQ}` for one advocate, sequence reset each 1 January and never reused. |
| `advocate_search` | `(p_type text, p_district text, p_court text, p_max_fee numeric, p_lang text)` | Ranked, index-friendly search over the verified advocate projection. No win-rate input exists. |
| `request_update` | `(p_case_id uuid)` | Client asks the advocate to update the case; deduped to once per 24h so it cannot be used to spam. |
| `complete_signup` | `(p_role user_role, p_full_name text, p_language text)` | The only path that inserts a `profiles` row; copies `role` into `app_metadata` so RLS helpers and the JWT agree. |

### 4.1 accept_sos — row locking

```sql
create or replace function accept_sos(p_sos_id uuid)
returns sos_requests
language plpgsql security definer set search_path = public as $$
declare v_row sos_requests;
begin
  if not is_verified_advocate() then
    raise exception 'not_verified_advocate';
  end if;

  -- Row lock: exactly one advocate can win (PRD F3 invariant)
  update sos_requests
     set status = 'accepted', advocate_id = auth.uid(), accepted_at = now()
   where id = p_sos_id and status = 'open'
  returning * into v_row;

  if v_row.id is null then
    return null;                      -- lost the race -> client shows "already taken"
  end if;

  insert into audit_logs(actor_id, actor_role, action, entity, entity_id)
  values (auth.uid(), 'advocate', 'sos.accept', 'sos_requests', p_sos_id);

  -- Case creation + checklist instantiation happen in create_case_from_sos()
  perform create_case_from_sos(p_sos_id);
  return v_row;
end $$;
```

The PRD F3 invariant is "exactly one advocate wins a SOS", and the `where ... and status = 'open'` predicate inside a single `update` is what delivers it: the second concurrent caller matches zero rows, `v_row.id` is null, and the function returns null rather than raising. The lock is held for the transaction, and status change + audit row + case creation are atomic because they are one call.

**Signature discrepancy.** The TRD heading says `accept_sos(p_sos_id uuid, p_advocate_id uuid) returns setof sos_requests`, but the SQL body takes only `p_sos_id`, uses `auth.uid()` for the advocate, and returns a single `sos_requests`. The body is the safer of the two: a caller-supplied `p_advocate_id` would let any verified advocate accept a SOS *on behalf of* someone else. Treat the heading as a stale draft and the body as authoritative, and correct the TRD. Resolved: TRD §5.7 heading corrected to (p_sos_id uuid) returns sos_requests.

Note also that `accept_sos` is `security definer` and does **not** re-check that the caller is a party to the SOS — `is_verified_advocate()` is the only gate. Any verified advocate can accept *any* open SOS by id, including one in a district they do not serve. That may be deliberate in an emergency bail context, but it is a trade-off and should be recorded as one.

### 4.2 publish_ai_summary — PIN verification

```sql
-- 1) verify pin_hash with pgcrypto crypt()
-- 2) enforce pin_fail_count < 5 and pin_locked_until < now(); increment on failure
-- 3) require state = 'draft' and expires_at > now()
-- 4) set state='published', final_bn, approved_by=auth.uid(), published_by='advocate'
-- 5) audit_logs insert 'summary.publish'
-- 6) notifications insert (dedupe_key = 'summary:'||id)
```

These steps are specified in the TRD as pseudocode, not plpgsql — the body is not written out. Step 1 verifies against `advocates.pin_hash` (see §2.7 — the PIN columns live on `advocates`, not `ai_summaries`) using `crypt(p_pin, pin_hash) = pin_hash`. Step 6's `dedupe_key = 'summary:'||id` is the reminder-storm guard noted in §2.9.

Steps 3 and 4 carry the HITL weight. As flagged in §2.7 they are the *only* thing stopping a client from publishing a draft directly through PostgREST, because `summaries_advocate_all` is `for all`. The invariant lives entirely in this function; if `update` is ever granted on `ai_summaries` to `authenticated`, the guarantee is void.

Errata (2026-10-08): invalid PIN returns NULL with the counter committed (no raise); audit rows for summary.publish and admin.override are written function-level only; admin_force_publish is exempt from expires_at and publishes coalesce(final_bn, draft_bn).

### 4.3 RPCs specified by behaviour only

Only `accept_sos` and `annual_reverify_reminder` have plpgsql bodies in the TRD; `publish_ai_summary` has pseudocode. The remaining seven — `create_case_from_sos`, `submit_triage`, `admin_force_publish`, `next_invoice_no`, `advocate_search`, `request_update`, `complete_signup` — are specified by signature and behaviour alone, with no SQL anywhere in the document. The table above is the entire current specification; implementations belong in `db/migrations/`.

`complete_signup` deserves particular attention. It is the *only* insert path into `profiles` (§2.1), and `security definer` is what allows it to write a row that no RLS policy permits a client to create. But it must not insert whatever `p_role` it is handed — if it does, the missing INSERT policy buys nothing, because any client can call it with `'admin'` and then pass `is_admin()` everywhere. The TRD does not say how `p_role` is constrained, and this is the sharpest version of the privilege-escalation concern running through sections 2.1, 2.2, 2.4, 2.5, 2.6, 2.7, and 2.8: invariants delegated to RPCs that RLS cannot see. That check must exist before this ships.

`next_invoice_no` carries the second instance. §2.8 notes the VAT and total columns are unenforced by any constraint; this function is likewise the only thing that will produce correct totals if it recomputes them. Nothing forces it to.

## 5. Cron Jobs

Source: TRD §5.7. Six scheduled functions registered via `pg_cron` in migration `016_cron.sql`. All are `security definer` and all run outside any RLS context, so each must constrain its own `where` clause — a missed predicate means a table-wide `update`.

| Job | Schedule | Effect |
|---|---|---|
| `expire_drafts()` | hourly | `ai_summaries` where `state='draft'` and `expires_at < now()` → `archived`; notify advocate. |
| `escalate_pending_checklists()` | hourly | `checklist_items` in `suggested_pending_advocate` older than 48 h → state kept, case flagged "general list mode"; notify advocate. |
| `expire_sos()` | every 15 min | `sos_requests` where `status='open'` and `expires_at < now()` → `expired`; notify client. |
| `purge_triage_inputs()` | daily | Nulls `ai_triage_sessions.input_redacted` for rows older than 30 days. |
| `send_overdue_invoice_reminders()` | daily | 3/7/14-day reminders; at 30 days flags for the advocate. |
| `annual_reverify_reminder()` | daily 09:00 Asia/Dhaka | Implements the PRD F2 annual re-verification policy. |

Only `annual_reverify_reminder` has a full plpgsql body in the TRD (§5.7). Registration example:

```sql
select cron.schedule('annual_reverify_reminder', '0 3 * * *', $$select annual_reverify_reminder()$$);
-- 03:00 UTC = 09:00 Asia/Dhaka
```

⚠️ **`annual_reverify_reminder` is daily, not yearly.** It runs every day but only acts on advocates whose `reverify_due_at` falls inside the reminder window — 30 days before the anniversary. Its effects: reminder 30 days ahead, `verification` returns to `pending` on the due date, and a `reverify_swept` audit row marks the closed grace window. A lapsed advocate silently disappears from `advocate_public`, `advocate_search`, and the SOS feed (both filter on `verification = 'verified'`, and `is_verified_advocate()` returns false) while keeping read access to existing cases. That silent de-listing is correct per PRD F2 but has no user-facing notice in the schema, so it needs one in the app.

Two operational notes. Every job writes notifications, so each needs the same `dedupe_key` discipline as §2.9 or a retry loop will produce duplicate rows — note `dedupe_key` is globally unique, not per user, which constrains the key format. And `send_overdue_invoice_reminders` has no `payments` predicate given in the TRD; "3/7/14-day" is relative to what — `due_date` or `sent_at`? Unspecified. Worth pinning down, since the two give different answers for an invoice already partly paid.

## 6. ER Diagram

Source: TRD §5.3, restricted to the 10 core tables. Omitted: `payments`, `checklist_templates`, `ai_triage_sessions`, `audit_logs`, `notifications`, `invoice_items`, `legal_knowledge_base`, `offline_sync_queue`.

```mermaid
erDiagram
    profiles ||--o| advocates : "1:1 (profile_id PK)"
    profiles ||--o{ sos_requests : "client_id"
    profiles ||--o{ sos_requests : "advocate_id on accept"
    profiles ||--o{ cases : "client_id"
    profiles ||--o{ cases : "advocate_id"
    profiles ||--o{ consents : "client_id"
    profiles ||--o{ consents : "advocate_id"
    profiles ||--o{ hearings : "entered_by"
    profiles ||--o{ ai_summaries : "approved_by"

    sos_requests ||--o| cases : "sos_id UNIQUE (1:0..1)"
    cases ||--o{ consents : "case_id"
    cases ||--o{ hearings : "case_id"
    cases ||--o{ ai_summaries : "case_id"
    cases ||--o{ invoices : "case_id"
    cases ||--o{ documents : "case_id"
    cases ||--o{ checklist_items : "case_id"

    hearings ||--o{ ai_summaries : "hearing_id"
    invoices ||--o{ invoice_items : "on delete cascade"
    checklist_templates ||--o{ checklist_items : "template_id"
    checklist_items ||--o{ documents : "checklist_item_id"

    profiles {
        uuid id PK
        user_role role
        text phone
    }
    advocates {
        uuid profile_id PK_FK
        verification_state verification
        text_array districts
        text pin_hash
    }
    sos_requests {
        uuid id PK
        uuid client_id FK
        uuid advocate_id FK
        sos_state status
        timestamptz expires_at
    }
    cases {
        uuid id PK
        uuid sos_id UK_FK
        uuid client_id FK
        uuid advocate_id FK
        case_state state
    }
    consents {
        uuid id PK
        uuid case_id FK
        int version
        timestamptz revoked_at
    }
    hearings {
        uuid id PK
        uuid case_id FK
        uuid supersedes_id FK
        boolean is_amended
        timestamptz published_at
    }
    ai_summaries {
        uuid id PK
        uuid case_id FK
        summary_state state
        text published_by
        int version
    }
    invoices {
        uuid id PK
        text invoice_no UK
        numeric vat_bdt
        numeric total_bdt
        invoice_state state
        int version
    }
    documents {
        uuid id PK
        uuid case_id FK
        doc_status status
        timestamptz deleted_at
    }
    checklist_items {
        uuid id PK
        uuid case_id FK
        checklist_state status
    }
```

Two Mermaid limitations to be aware of. `profiles` is referenced by six relationships, so the rendering is wide — split it from the `cases`-centric half if it does not fit your target. And Mermaid has no notation for the RLS visibility rules; the diagram shows structure only, which is why `publish_ai_summary`'s PIN gate and the `sos_advocate_select_open` district filter are invisible here. Sections 2 and 7 carry those.