# LegalLink - Technical Requirements Document (TRD)

| Field | Value |
|---|---|
| Product | LegalLink - Emergency Legal Access & Case Transparency Platform |
| Document | Technical Requirements Document (TRD) v1.1 |
| Companion document | `D:\LegalLink\prd.md` (PRD v2.0) |
| Audience | 4-person engineering team, faculty reviewers, future contributors |
| Scope | System architecture, tech stack, system design detail, APIs, tools |
| Constraint | $0/month MVP (free tiers + local AI) |
| Platforms | Flutter Web + Flutter Android (single codebase) |
| v1.1 adds | `fcm_token` columns (5.4), `annual_reverify_reminder()` (5.7), accessibility rules (8.8), readiness gates incl. day-1 RLS suite, dual-provider AI validation, 20-step pilot script, hybrid-AI and RLS demo gates (16.1-16.3) |
| Status | Approved for implementation |

## 1. Purpose and Scope

This TRD converts the 8-feature MVP defined in the PRD into a buildable technical design. Every functional requirement in the PRD maps to a component, table, API, or policy in this document.

**In scope:** architecture (C4 levels 1-3), tech stack with versions, data design (schema, indexes, RLS, storage, migrations), API design (REST/PostgREST, Edge Functions, Cloudflare Worker, Realtime, webhooks), AI subsystem design (router, prompts, schemas, RAG, guardrails), Flutter client architecture, offline sync engine, security architecture and threat model, non-functional design, DevOps/CI-CD, observability, testing architecture, tool inventory, and ADRs.

**Out of scope:** court-system integrations, payment gateway automation, multi-country localization, model fine-tuning (optional bonus only).

## 2. How to Read This Document

| If you need to... | Go to |
|---|---|
| Understand the big picture | Section 3 (Architecture) |
| Know which library/version to install | Section 4 (Tech Stack) |
| Write or review the database | Section 5 (Data Design) |
| Build a screen or call an endpoint | Section 6 (API Design) |
| Work on AI features | Section 7 (AI Subsystem) |
| Work on the Flutter app | Section 8 (Client Architecture) |
| Audit security | Section 9 (Security) |
| Set up CI/CD or the local environment | Sections 11 and 13 |
| Know what must be done **immediately** and what gates block the demo | Section 16 (Build Order and Readiness Gates) |

## 3. Architecture

### 3.1 Architecture Principles

| # | Principle | Concrete consequence |
|---|---|---|
| P1 | **Zero-trust authorization at the database** | All access control lives in Postgres RLS. The client is never trusted. No "security by UI hiding". |
| P2 | **Single source of truth** | Supabase Postgres. Hive is only a cache + offline queue, never authoritative. |
| P3 | **One codebase, two form factors** | Flutter/Dart for web and Android; responsive by `LayoutBuilder`, not by separate apps. |
| P4 | **Human-in-the-Loop for anything legal** | AI produces `draft`; a verified advocate's PIN publishes. Enforced by RLS, not just UI. |
| P5 | **AI must never block the core flow** | Every AI feature has a rule-based fallback path (PRD section 8.2 / 14). |
| P6 | **Off-device AI** | No LLM inference inside the Flutter app. Cloud (Groq) or local llama.cpp server only. |
| P7 | **Provider-pluggable AI** | A single `AIService` interface; backend switched by `AI_PROVIDER` env var, same prompts/schemas. |
| P8 | **Fail loud, fail safe** | Conflicts, RLS rejections and quota breaches surface to the user; never silent data loss. |
| P9 | **Auditability by default** | Every sensitive mutation writes an append-only `audit_logs` row. |
| P10 | **$0 until proven** | Free tiers + local tooling until the pilot proves retention (PRD section 15). |

### 3.2 C4 Level 1 - System Context

```
                        +-------------------------------------------+
                        |        Bangladesh legal ecosystem         |
                        |  advocates, clients/families, admins,     |
                        |  Bar Council, police (Thana), courts      |
                        +---------------------+---------------------+
                                              |
                                              | uses (Bangla-first UI)
                                              v
+---------------------+       +---------------------------------------------+
|  LLM provider       |       |                LegalLink                    |
|  - Groq API (cloud) |<----->|  Flutter Web  +  Flutter Android client     |
|  - llama.cpp (local)|       |  Supabase backend + Cloudflare edge         |
+---------------------+       +--------+----------------+-------------------+
                                       |                |
                    +------------------+                +------------------+
                    v                                                      v
        +-----------------------+                        +------------------------+
        | Firebase Cloud        |                        | Cloudflare (edge)      |
        | Messaging (push)      |                        | Workers, Pages, R2     |
        +-----------------------+                        +------------------------+
```

### 3.3 C4 Level 2 - Containers

```
 CLIENT TIER
 +-------------------------------------------------------------------------+
 | [C1] Flutter Web app           [C2] Flutter Android app                 |
 |      (same Dart codebase; Riverpod state; Hive cache;                   |
 |       supabase_flutter SDK; go_router; intl; flutter_local_notifications)|
 +------------------------------------+------------------------------------+
                                      |
                      HTTPS (JWT) + WSS (Realtime)
                                      v
 EDGE TIER
 +-------------------------------------------------------------------------+
 | [C3] Cloudflare Worker "llm-gateway"                                    |
 |      - PII redaction before LLM                                         |
 |      - rate limiting (PRD section 13)                                   |
 |      - AI response caching (KV)                                         |
 |      - invoice PDF rendering                                            |
 |      - OpenAI-compatible passthrough to Groq or llama.cpp                |
 +------------------------------------+------------------------------------+
                                      |
                                      v
 BACKEND TIER (Supabase managed)
 +-------------------------------------------------------------------------+
 | [C4] PostgREST (auto REST API)     [C5] Postgres + RLS + pgvector        |
 | [C6] Supabase Auth (phone OTP, JWT) [C7] Supabase Realtime (WSS)         |
 | [C8] Supabase Storage (documents)   [C9] Edge Functions (Deno, TS)       |
 |      - SOS accept transaction       - FCM dispatch                       |
 |      - invoice numbering            - draft expiry cron                  |
 |      - checklist instantiation      - retention/archival cron            |
 +-------------------------------------------------------------------------+
                                      |
                                      v
 EXTERNAL TIER
 +-------------------------------------------------------------------------+
 | [C10] Firebase Cloud Messaging (push)                                    |
 | [C11] Groq API (production LLM)     [C12] llama.cpp server (local LLM)   |
 | [C13] bge-m3 local embedder (dev/CI only)                                |
 +-------------------------------------------------------------------------+
```

### 3.4 Container Responsibilities and Trust Levels

| ID | Container | Trust | Responsibility | Failure impact |
|---|---|---|---|---|
| C1 | Flutter Web | Untrusted | Responsive UI, offline cache, sync engine | Degraded UI only |
| C2 | Flutter Android | Untrusted | Same + push, camera, voice input | Degraded UI only |
| C3 | Cloudflare Worker | Semi-trusted (holds no JWT secret, only AI key) | PII redaction, rate limits, AI cache, PDF | AI features degrade; core flows unaffected |
| C4 | PostgREST | Trusted (inside Supabase) | Auto-generated REST over tables/views/RPC | Total outage of data access |
| C5 | Postgres + RLS | Trusted - the security boundary | Data, constraints, RLS, triggers, pgvector | Total outage; highest criticality |
| C6 | Supabase Auth | Trusted | OTP issuance/verification, JWT minting, refresh | Login outage; queued client sessions survive 7-day refresh |
| C7 | Supabase Realtime | Trusted | Postgres change broadcast over WSS | Stale UI until delta refetch |
| C8 | Supabase Storage | Trusted | Document blobs, signed URL issuance | Upload/view outage; cached metadata remains |
| C9 | Edge Functions | Trusted | Multi-step atomic operations, cron jobs | Those specific operations fail; DB stays consistent |
| C10 | FCM | External, best-effort | Push delivery | Silent; in-app timeline remains source of truth |
| C11 | Groq API | External (no PII sent) | Production LLM inference | Fallback to rule-based output |
| C12 | llama.cpp | Local, dev/demo | Offline LLM for faculty demo | Fallback to Groq if online |
| C13 | bge-m3 | Local, build-time | Embeddings for RAG index (P1) | Chatbot not shipped; no MVP impact |

### 3.5 C4 Level 3 - Components (client app)

```
 lib/
 +-- main.dart                     boot, env load, DI, Supabase init
 +-- app/
 |    +-- router.dart              go_router, auth guards, role guards
 |    +-- theme.dart               color tokens, Bangla typography
 |    +-- l10n/                    ARB bn/en, generated localizations
 +-- core/
 |    +-- env/                     AppConfig (supabaseUrl, anonKey, aiProvider)
 |    +-- error/                   Failure, Result<T>, error mappers
 |    +-- network/                 SupabaseClient wrapper, ApiClient (Worker)
 |    +-- security/                secure storage, PIN hashing client-side
 |    +-- utils/                   formatters (BDT, dates), validators (BD phone)
 +-- features/
 |    +-- auth/                    data  domain  presentation
 |    +-- onboarding/              role selection, advocate onboarding + PIN
 |    +-- advocate_profile/        profile CRUD, verification upload
 |    +-- sos/                     form, list, accept transaction
 |    +-- triage/                  intake questions, AI triage, checklist gen
 |    +-- checklist/               templates, item states, upload
 |    +-- cases/                   case CRUD, assignment, transfer
 |    +-- timeline/                hearings, amendments, reminders
 |    +-- ai_summary/              draft edit, PIN publish, client view
 |    +-- invoices/                line items, VAT, payments, PDF link
 |    +-- documents/               vault, signed URLs, upload queue
 |    +-- notifications/           FCM handler, in-app inbox
 |    +-- admin/                   verification queue, moderation, audit
 +-- shared/
      +-- widgets/                 EmptyState, SyncBadge, StatusChip
      +-- models/                  cross-feature DTOs
      +-- offline/                 outbox, sync engine, conflict resolver
```

Each feature folder follows the same three-layer split:

| Layer | Contains | Depends on |
|---|---|---|
| `domain` | Entities, value objects, use cases, repository **interfaces** | Nothing (pure Dart) |
| `data` | DTOs (`fromJson/toJson`), repository **implementations**, data sources | domain, supabase SDK, Hive |
| `presentation` | Riverpod providers/notifiers, pages, widgets | domain (never `data` directly) |

Dependency rule: `presentation -> domain <- data`. No layer may import "upward".

### 3.6 6-Layer Runtime Model

| Layer | Components | Notes |
|---|---|---|
| L1 Presentation | C1, C2 | Flutter widgets; responsive breakpoint at 600 px |
| L2 API/Auth | C4, C6 | PostgREST + RPC; JWT with `role` claim |
| L3 Data | C5, C8 | Postgres + RLS + Storage buckets |
| L4 Realtime | C7 | Channel-per-case and channel-per-district |
| L5 Edge/AI | C3, C9, C11, C12 | Worker gateway + Edge Functions + LLM |
| L6 Infrastructure | GitHub Actions, Cloudflare Pages, FCM | CI/CD, hosting, push |

### 3.7 Request Lifecycle Walkthroughs

**W1 - Client reads a case timeline (read path, cached)**
```
1. User opens Case screen
2. Riverpod provider checks Hive cache -> render immediately (instant paint)
3. In parallel: supabase.from('hearings').select().eq('case_id', id).order('date')
4. Postgres evaluates RLS: client_id = auth.uid() AND summary status published
5. Rows return -> DTO -> domain entity -> provider state update -> UI refresh
6. Provider subscribes to Realtime channel case:{id} for live updates
```

**W2 - Advocate publishes an AI summary (write path, HITL)**
```
1. Advocate types/dictates raw notes
2. POST /llm/v1/summarize (Cloudflare Worker) with JWT
3. Worker: verify JWT -> rate limit -> PII redaction -> AI call (Groq | llama.cpp)
4. Worker returns {summary_bn, model, prompt_version, tokens}
5. App inserts ai_summaries row with status='draft' (advocate-scoped RLS)
6. Advocate edits, taps Publish, enters 4-digit PIN
7. App calls RPC publish_ai_summary(p_summary_id, p_pin)
8. RPC: verify pin_hash -> check attempts -> set status='published', approved_at
9. Trigger writes audit_logs row + enqueues notification row
10. Edge Function sends FCM push to client; Realtime broadcasts to all client devices
```

**W3 - SOS accept under concurrency (critical path)**
```
Advocate A and B both tap Accept on the same SOS at the same moment
1. Both call RPC accept_sos(p_sos_id)
2. RPC runs UPDATE ... WHERE id = p_sos_id AND status = 'open' in a transaction
3. Row lock serializes them; the second UPDATE matches 0 rows
4. Winner: status='accepted', advocate_id set, returns the row
5. Loser: RPC returns NULL -> app shows "already taken by another advocate"
6. Winner's call chains case creation + checklist instantiation in the same tx
```

## 4. Tech Stack

### 4.1 Client Tier

| Concern | Choice | Version | Why | Cost |
|---|---|---|---|---|
| Language | Dart | 3.x (bundled with Flutter) | Type-safe, null-safe, single language for both platforms | $0 |
| Framework | Flutter | 3.x stable | One codebase for Web + Android | $0 |
| State management | `flutter_riverpod` | 2.x | Compile-time safe, testable, no `BuildContext` coupling | $0 |
| Routing | `go_router` | 14.x | Declarative routes, auth/role redirect guards | $0 |
| Local cache | `hive` + `hive_flutter` | 2.x | Fast, no native code, works on web | $0 |
| Backend SDK | `supabase_flutter` | 2.x | Auth, PostgREST, Realtime, Storage in one SDK | $0 |
| HTTP | `http` / `dio` | 1.x / 5.x | Calls to the Cloudflare Worker | $0 |
| Localization | `flutter_localizations` + `intl` | SDK | ARB files `bn` primary / `en` fallback, BDT formatting | $0 |
| Secure storage | `flutter_secure_storage` | 9.x | Session token + PIN salt on Android | $0 |
| Notifications | `firebase_messaging` + `flutter_local_notifications` | 14.x / 17.x | FCM push + local reminders | $0 |
| Voice input | `speech_to_text` | 6.x | Bangla dictation for advocates (PRD F3/F6) | $0 |
| Forms/validation | `reactive_forms` | 17.x | Bangla phone/NID validation | $0 |
| File handling | `image_picker`, `file_picker`, `path_provider` | latest | Document capture/upload | $0 |
| PDF viewing | `flutter_pdfview` (Android) / `pdfx` (web-capable) | latest | View advocate-issued invoice PDFs | $0 |
| Charting (admin) | `fl_chart` | latest | Analytics dashboard (P1) | $0 |
| Testing | `flutter_test`, `mocktail`, `integration_test` | SDK | Unit/widget/integration | $0 |
| Lint | `flutter_lints` + custom `analysis_options.yaml` | latest | Enforced style, forbid `data` imports in domain | $0 |

### 4.2 Backend Tier

| Concern | Choice | Detail | Cost |
|---|---|---|---|
| Database | Supabase Postgres | Managed Postgres 15+, RLS, triggers, extensions | $0 (free tier) |
| Auth | Supabase Auth | Phone OTP (`+880`), JWT (15-min access / 7-day refresh), `role` claim in `app_metadata` | $0 |
| REST API | PostgREST (built-in) | Auto REST over tables/views; RPC for atomic operations | $0 |
| Realtime | Supabase Realtime | Postgres changes over WSS; channel per case / per district | $0 |
| Storage | Supabase Storage | Buckets: `documents` (private), `avatars`, `sanad` | 1 GB free |
| Extensions | `pgvector`, `pgcrypto`, `pg_trgm` | RAG (P1), hashing, fuzzy advocate search | $0 |
| Edge Functions | Deno + TypeScript | Multi-step atomic ops, FCM dispatch, cron | $0 |
| Cron | Supabase `pg_cron` / scheduled Edge Functions | Draft expiry, retention/archival, overdue invoices | $0 |
| Backups | Supabase daily (free tier) + `pg_dump` to GitHub Artifact | Migration safety | $0 |

### 4.3 Edge / AI Tier

| Concern | Choice | Detail | Cost |
|---|---|---|---|
| Edge compute | Cloudflare Workers | `llm-gateway` route namespace `/v1/*` | $0 (100k req/day) |
| KV cache | Cloudflare KV | Caches deterministic AI responses keyed by input hash | $0 |
| Web hosting | Cloudflare Pages | Flutter Web build output, auto SSL, global CDN | $0 |
| Object store (optional) | Cloudflare R2 | Overflow for large docs if Supabase 1 GB is exceeded | $0 (10 GB) |
| Production LLM | Groq API - `llama-3.x` | OpenAI-compatible `/chat/completions`, JSON mode | $0 (free tier) |
| Local LLM | llama.cpp server + Qwen 2.5-7B GGUF (Q4_K_M) | `localhost:8080`, OpenAI-compatible | $0 |
| Embeddings | `BAAI/bge-m3` via Python/ONNX at build time | RAG index build (P1) | $0 |
| RAG store | Supabase `pgvector` | Table `legal_knowledge_base` | $0 |

### 4.4 Tooling, DevOps, QA Tier

| Concern | Choice | Detail | Cost |
|---|---|---|---|
| Repo | GitHub (monorepo) | `apps/legal_link` (Flutter), `edge/worker`, `edge/functions`, `db/migrations`, `ai/` | $0 |
| CI | GitHub Actions | analyze, test, RLS test, golden AI set, build | 2000 min/mo free |
| Web deploy | Cloudflare Pages Action | On merge to `main`; preview per PR | $0 |
| Android release | GitHub Actions + Gradle | Signed APK on version tag -> GitHub Release | $0 |
| Secrets | GitHub Secrets + Supabase Vault | Service key, Groq key, FCM key, keystore | $0 |
| Local DB | Supabase CLI + Docker | `supabase start` for local Postgres/Auth/Storage | $0 |
| DB migrations | Supabase CLI migrations (SQL files) | `expand -> migrate -> contract` | $0 |
| Code quality | `flutter analyze`, `dart format`, `sqlfluff` | Pre-commit + CI | $0 |
| API testing | `curl` / `.http` files, Postman (free) | Endpoint smoke tests | $0 |
| Load sanity | `k6` (OSS) | 50 concurrent Realtime subscribers | $0 |
| Diagrams | Mermaid/ASCII in repo | Kept in this TRD and `docs/` | $0 |
| AI-assisted dev | OpenCode + Mimo 2.5 (per project history) with TDD | RED -> GREEN -> REFACTOR loop | $0 |

## 5. Data Design

### 5.1 Conventions

- Table names: plural snake_case (`sos_requests`). Columns: singular snake_case.
- Every table has: `id uuid primary key default gen_random_uuid()`, `created_at timestamptz default now()`, `updated_at timestamptz default now()`.
- Soft delete only where required: `deleted_at timestamptz null`.
- **No hard-delete policies anywhere.** Deletions are soft (`deleted_at`) so the audit trail stays intact.
- Money: `numeric(12,2)` in BDT. Never floats.
- Enums: Postgres `create type ... as enum` (documented below).
- Optimistic locking: `version integer not null default 1` on `consents`, `invoices`, `ai_summaries` (PRD F8 conflict rule).
- All `updated_at` maintained by a shared trigger `set_updated_at()`.

### 5.2 Enum Types

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

### 5.3 Entity Relationship Overview

```
profiles 1--1 advocates
profiles 1--* sos_requests (client_id)
sos_requests 1--0..1 cases        (a case is created when an SOS is accepted)
profiles 1--* cases (client_id)   profiles 1--* cases (advocate_id)
cases 1--* consents               cases 1--* hearings
cases 1--* ai_summaries           cases 1--* invoices 1--* invoice_items
cases 1--* documents              cases 1--* checklist_items
checklist_templates 1--* checklist_items   ai_triage_sessions 1--0..1 cases
profiles 1--* audit_logs          profiles 1--* notifications
legal_knowledge_base (pgvector, standalone, RAG only)
offline_sync_queue (client-side mirror, server table for telemetry)
```

### 5.4 Core Table Definitions (MVP)

**profiles** - extends `auth.users`
```sql
create table profiles (
  id          uuid primary key references auth.users(id) on delete restrict,
  role        user_role   not null default 'client',
  full_name   text,
  phone       text        not null,   -- E.164, e.g. +8801XXXXXXXXX
  language    text        not null default 'bn' check (language in ('bn','en')),
  avatar_url  text,
  fcm_token      text,                -- latest FCM registration token (last write wins)
  fcm_updated_at timestamptz,         -- when a device last refreshed its token
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
```

*FCM token note:* `profiles.fcm_token` holds the most recent registration token (last write wins) and `fcm_updated_at` records the refresh time. In the MVP a user with a phone **and** a browser has two devices but one row, so only the newest device receives push; a P1 migration introduces `device_tokens(user_id, token, platform, updated_at)` and `dispatch-fcm` fans out to every row. The token is cleared by the dispatcher when FCM answers `UNREGISTERED` or `INVALID_ARGUMENT` (section 6.6), so dead tokens do not accumulate.

**advocates** - professional profile + verification
```sql
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
```
**sos_requests** - emergency intake
```sql
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
```

**cases**
```sql
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
```

**consents** - legal compliance, optimistic-locked
```sql
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
```

**hearings** - immutable, amended via new version
```sql
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
```
**ai_summaries** - HITL state machine
```sql
create table ai_summaries (
  id             uuid primary key default gen_random_uuid(),
  case_id        uuid not null references cases(id),
  hearing_id     uuid references hearings(id),
  raw_input      text not null,              -- advocate notes (PII redacted value stored)
  draft_bn       text not null,              -- AI output
  final_bn       text,                       -- advocate-edited final text
  state          summary_state not null default 'draft',
  model          text,                       -- e.g. llama-3.3-70b | qwen2.5-7b-instruct
  prompt_version text,                       -- e.g. summary_v3
  tokens_used    int,
  approved_by    uuid references profiles(id),
  published_by   text,                       -- 'advocate' | 'admin_override'
  override_reason text,
  flagged        boolean not null default false,
  archived_at    timestamptz,                -- 7-day expiry sweep
  expires_at     timestamptz not null default now() + interval '7 days',
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  version        int not null default 1
);
```

**invoices** + **invoice_items**
```sql
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
  updated_at    timestamptz not null default now()
);

create table invoice_items (
  id          uuid primary key default gen_random_uuid(),
  invoice_id  uuid not null references invoices(id) on delete cascade,
  description text not null,
  amount_bdt  numeric(12,2) not null,
  created_at  timestamptz not null default now()
);
```

**payments** (partial payments, manual verification)
```sql
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
```
**documents** - vault with offline-aware upload
```sql
create table documents (
  id               uuid primary key default gen_random_uuid(),
  case_id          uuid not null references cases(id),
  checklist_item_id uuid references checklist_items(id),
  uploaded_by      uuid not null references profiles(id),
  doc_type         text not null,            -- fir|arrest_memo|nid|invoice_proof|order|other
  storage_path     text,                     -- null while offline-local only
  local_ref        text,                     -- device-local reference (F8 rule)
  mime_type        text, size_bytes bigint,
  status           doc_status not null default 'uploaded',
  reject_reason    text,
  deleted_at       timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
```

**checklist_templates** (admin) + **checklist_items** (per case)
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
```

**ai_triage_sessions** - audit + telemetry for AI
```sql
create table ai_triage_sessions (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references profiles(id),
  case_id        uuid references cases(id),
  input_hash     text not null,           -- sha256 of the raw (pre-redaction) input
  input_redacted text not null,           -- what we actually sent to the LLM
  output_json    jsonb not null,          -- {case_type, urgency, overview, actions[], checklist[]}
  model          text, prompt_version text, tokens_used int,
  fallback_used  boolean not null default false,
  created_at     timestamptz not null default now()
);
```
Retention: `input_redacted` nulled after 30 days by cron (PRD section 10).

**audit_logs** - append-only
```sql
create table audit_logs (
  id         bigserial primary key,
  actor_id   uuid references profiles(id),
  actor_role user_role,
  action     text not null,         -- sos.accept | summary.publish | admin.override | ...
  entity     text, entity_id uuid,
  metadata   jsonb not null default '{}'::jsonb,
  ip         inet, device text,
  created_at timestamptz not null default now()
);
-- no UPDATE/DELETE policy is ever created for this table
```

**notifications**
```sql
create table notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references profiles(id),
  kind        text not null,     -- sos.accepted | checklist.approved | hearing.reminder | ...
  title_bn    text, body_bn text,
  payload     jsonb not null default '{}'::jsonb,
  channel     text not null default 'push',   -- push | in_app
  sent_at     timestamptz, read_at timestamptz,
  dedupe_key  text unique,       -- prevents duplicate reminder storms
  created_at  timestamptz not null default now()
);
```

**legal_knowledge_base** (P1 - RAG)
```sql
create table legal_knowledge_base (
  id         bigserial primary key,
  source     text not null,      -- 'Penal Code 1860'
  section    text,               -- 'Section 496'
  chunk_no   int  not null,
  content_bn text not null,
  content_en text,
  embedding  vector(1024),       -- bge-m3 dimension
  created_at timestamptz not null default now()
);
```

**offline_sync_queue** (server mirror for telemetry/troubleshooting)
```sql
create table offline_sync_queue (
  id         bigserial primary key,
  device_id  text not null,
  user_id    uuid not null references profiles(id),
  op         text not null,      -- insert|update|delete
  target     text not null,      -- table name
  payload    jsonb not null,
  client_ts  timestamptz not null,
  synced_at  timestamptz,
  status     text not null default 'pending'  -- pending|applied|conflict|failed
);
```

### 5.5 Indexes

```sql
-- Advocate discovery (PRD F2): filter by district/court/specialization
create index advocates_districts_gin   on advocates using gin (districts);
create index advocates_courts_gin      on advocates using gin (courts);
create index advocates_spec_gin        on advocates using gin (specializations);
create index advocates_verified_idx    on advocates (verification) where verification = 'verified';

-- SOS live queue (advocates subscribe per district)
create index sos_open_by_district on sos_requests (district, created_at desc)
  where status = 'open';
create index sos_client_recent on sos_requests (client_id, created_at desc);  -- rate limiting

-- Case and timeline access (RLS predicates)
create index cases_client_idx   on cases (client_id, state);
create index cases_advocate_idx on cases (advocate_id, state);
create index hearings_case_idx  on hearings (case_id, hearing_date desc);
create index hearings_next_idx  on hearings (next_hearing_date) where published_at is not null;

-- HITL queues and sweeps
create index summaries_draft_expiry on ai_summaries (expires_at) where state = 'draft';
create index summaries_case_idx     on ai_summaries (case_id, state);

-- Checklists
create index checklist_case_idx    on checklist_items (case_id, status);
create index checklist_pending_idx on checklist_items (approved_at)
  where status = 'suggested_pending_advocate';   -- 48h escalation sweep

-- Billing
create index invoices_case_idx     on invoices (case_id, state);
create index invoices_due_idx      on invoices (due_date) where state in ('sent','partially_paid');
create index payments_invoice_idx  on payments (invoice_id);

-- Documents / triage / audit
create index documents_case_idx    on documents (case_id) where deleted_at is null;
create index triage_user_day_idx   on ai_triage_sessions (user_id, created_at desc); -- rate limit
create index audit_entity_idx      on audit_logs (entity, entity_id, created_at desc);
create index audit_actor_idx       on audit_logs (actor_id, created_at desc);

-- RAG (P1)
create index lkb_embedding_idx on legal_knowledge_base
  using hnsw (embedding vector_cosine_ops);
```

### 5.6 Row Level Security Policies

RLS is enabled on **every** table. `auth.uid()` is the only identity source.

```sql
alter table profiles         enable row level security;
alter table advocates        enable row level security;
alter table sos_requests     enable row level security;
alter table cases            enable row level security;
alter table consents         enable row level security;
alter table hearings         enable row level security;
alter table ai_summaries     enable row level security;
alter table invoices         enable row level security;
alter table invoice_items    enable row level security;
alter table payments         enable row level security;
alter table documents        enable row level security;
alter table checklist_items  enable row level security;
alter table ai_triage_sessions enable row level security;
alter table audit_logs       enable row level security;
alter table notifications    enable row level security;
```

**Helper functions (security definer, avoids recursive RLS)**

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

**profiles**
```sql
create policy profiles_select_self on profiles for select
  using (id = auth.uid() or is_admin());

create policy profiles_update_self on profiles for update
  using (id = auth.uid()) with check (id = auth.uid());

-- Advocates need to see each other's public profile fields via a view
create view advocate_public as
  select p.id, p.full_name, p.avatar_url, a.specializations, a.courts,
         a.districts, a.languages, a.years_practice, a.fee_min_bdt,
         a.fee_max_bdt, a.verification
  from profiles p join advocates a on a.profile_id = p.id
  where a.verification = 'verified';
```

**advocates** - advocates own their row; clients read only verified rows via `advocate_public`; admins manage verification.

```sql
create policy advocates_self_rw on advocates for all
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());

create policy advocates_admin_all on advocates for all
  using (is_admin()) with check (is_admin());

-- Clients may read only the public projection (enforced on the view)
grant select on advocate_public to authenticated;
```
**sos_requests**
```sql
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

**cases / consents / hearings / summaries / invoices / documents / checklist_items / payments / notifications**
```sql
-- cases: client and assigned advocate only; admins read all
create policy cases_read  on cases for select
  using (client_id = auth.uid() or advocate_id = auth.uid() or is_admin());
create policy cases_client_write on cases for insert
  with check (client_id = auth.uid());
create policy cases_advocate_update on cases for update
  using (advocate_id = auth.uid() or is_admin())
  with check (advocate_id = auth.uid() or is_admin());

-- consents: client grants/revokes; advocate reads
create policy consents_client_all on consents for all
  using (client_id = auth.uid()) with check (client_id = auth.uid());
create policy consents_advocate_read on consents for select
  using (advocate_id = auth.uid() or is_admin());

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

-- invoices / invoice_items / payments: parties of the case only
create policy invoices_party on invoices for select
  using (advocate_id = auth.uid() or client_id = auth.uid() or is_admin());
create policy invoices_advocate_write on invoices for all
  using (advocate_id = auth.uid()) with check (advocate_id = auth.uid());
create policy invoice_items_party on invoice_items for select
  using (exists (select 1 from invoices i where i.id = invoice_items.invoice_id
                 and (i.advocate_id = auth.uid() or i.client_id = auth.uid())) or is_admin());
create policy invoice_items_advocate_write on invoice_items for all
  using (exists (select 1 from invoices i where i.id = invoice_items.invoice_id
                 and i.advocate_id = auth.uid()))
  with check (true);
create policy payments_party on payments for all
  using (exists (select 1 from invoices i where i.id = payments.invoice_id
                 and (i.advocate_id = auth.uid() or i.client_id = auth.uid())) or is_admin())
  with check (exists (select 1 from invoices i where i.id = payments.invoice_id
                      and i.advocate_id = auth.uid()));

-- documents: case parties; storage access via signed URLs only
create policy documents_party on documents for all
  using (case_id is not null and has_case_access(case_id) and deleted_at is null)
  with check (uploaded_by = auth.uid());

-- checklist_items: client reads own case items; advocate approves own case items
create policy checklist_client_read on checklist_items for select
  using (exists (select 1 from cases c where c.id = checklist_items.case_id
                 and c.client_id = auth.uid()) or is_admin());
create policy checklist_advocate_rw on checklist_items for all
  using (exists (select 1 from cases c where c.id = checklist_items.case_id
                 and c.advocate_id = auth.uid()))
  with check (true);
-- clients may update only the "upload" transition (status -> uploaded)
create policy checklist_client_upload on checklist_items for update
  using (exists (select 1 from cases c where c.id = checklist_items.case_id
                 and c.client_id = auth.uid()))
  with check (status in ('uploaded','needs_review'));

-- notifications: own rows only
create policy notifications_self on notifications for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- audit_logs: admins read; nobody writes via API (only triggers / definer functions)
create policy audit_admin_read on audit_logs for select using (is_admin());
-- no insert/update/delete policy => API writes are impossible; only security-definer triggers write
```

### 5.7 Atomic RPC Functions (Postgres functions exposed over PostgREST)

These exist because the operations must be atomic and enforce business rules that RLS alone cannot express.

**`accept_sos(p_sos_id uuid, p_advocate_id uuid) returns setof sos_requests`**
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

**`create_case_from_sos(p_sos_id uuid) returns uuid`** - creates the case and clones the admin checklist template rows as `suggested_pending_advocate`.

**`submit_triage(p_input jsonb) returns ai_triage_sessions`** - inserts the triage session, creates `checklist_items` from template + AI suggestions, enforces the 10/24h rate limit.

**`publish_ai_summary(p_summary_id uuid, p_pin text, p_final_bn text) returns ai_summaries`**
```sql
-- 1) verify pin_hash with pgcrypto crypt()
-- 2) enforce pin_fail_count < 5 and pin_locked_until < now(); increment on failure
-- 3) require state = 'draft' and expires_at > now()
-- 4) set state='published', final_bn, approved_by=auth.uid(), published_by='advocate'
-- 5) audit_logs insert 'summary.publish'
-- 6) notifications insert (dedupe_key = 'summary:'||id)
```

**`admin_force_publish(p_summary_id uuid, p_reason text)`** - admin-only, requires `is_admin()` **and** a non-empty `p_reason`; sets `published_by='admin_override'`; writes `audit_logs` with action `admin.override`.

**`next_invoice_no(p_advocate uuid) returns text`** - sequence per advocate, reset every 1 January (`INV-{YEAR}-{SEQ}`), `INV-{YEAR}-{SEQ}` uniqueness enforced by the unique index.

**`advocate_search(p_type text, p_district text, p_court text, p_max_fee numeric, p_lang text)`** - ranked, index-friendly search over the verified advocate projection. No win-rate input exists.

**`expire_drafts()`** (cron, hourly) - `state='draft'` and `expires_at < now()` -> `archived`, notify advocate.

**`escalate_pending_checklists()`** (cron, hourly) - items `suggested_pending_advocate` older than 48 h -> keep state but flag case as "general list mode" and notify the advocate (PRD F3).

**`expire_sos()`** (cron, every 15 min) - `status='open'` and `expires_at < now()` -> `expired`, notify client.

**`purge_triage_inputs()`** (cron, daily) - nulls `input_redacted` for rows older than 30 days (retention policy).

**`send_overdue_invoice_reminders()`** (cron, daily) - 3/7/14-day reminders; 30 days -> flag for the advocate.

**`annual_reverify_reminder()`** (cron, daily at 09:00 Asia/Dhaka) - implements the PRD F2 annual re-verification policy.
```sql
create or replace function annual_reverify_reminder() returns void
language plpgsql security definer set search_path = public as $$
begin
  -- 1) 30 days before the anniversary: remind the advocate
  insert into notifications(user_id, kind, title_bn, body_bn, dedupe_key)
  select a.profile_id, 'advocate.reverify_due',
         'বার কাউন্সিল যাচাই নবায়ন করুন',
         'আপনার সনদ বার্ষিক যাচাইয়ের সময় হয়েছে।',
         'reverify:' || a.profile_id || ':' || date_trunc('day', now())::date
  from advocates a
  where a.verification = 'verified'
    and a.reverify_due_at between now() and now() + interval '30 days';

  -- 2) on the due date: move back to the review queue (admin decides)
  update advocates
     set verification = 'pending',
         reverify_due_at = now() + interval '90 days'   -- grace window
   where verification = 'verified'
     and reverify_due_at is not null
     and reverify_due_at <= now();

  -- 3) grace window closed: audit the sweep (admin follow-up)
  insert into audit_logs(actor_id, actor_role, action, entity, metadata)
  select null, 'admin', 'advocate.reverify_swept', 'advocates',
         jsonb_build_object('profile_id', a.profile_id, 'due_at', a.reverify_due_at)
  from advocates a
  where a.verification = 'pending'
    and a.reverify_due_at is not null
    and a.reverify_due_at <= now() - interval '90 days';
end $$;
```
- **Effects:** reminder 30 days before the anniversary; state returns to `pending` on the due date; a `reverify_swept` audit row marks a closed grace window.
- **Automatic consequences of a lapse:** `advocate_public` and `advocate_search` filter on `verification = 'verified'`, and `is_verified_advocate()` returns false, so a lapsed advocate silently drops out of **discovery and the SOS feed** while keeping read access to existing cases (PRD F2).
- **Cron registration:** `select cron.schedule('annual_reverify_reminder', '0 3 * * *', $$select annual_reverify_reminder()$$);` (03:00 UTC = 09:00 Asia/Dhaka).

### 5.8 Storage Buckets

| Bucket | Public | Path convention | Read access | Write access |
|---|---|---|---|---|
| `documents` | No | `{case_id}/{doc_id}/{filename}` | Signed URLs, 15-min expiry, issued only to case parties | Case parties |
| `sanad` | No | `{advocate_id}/sanad.{ext}` | Admin only | Advocate (own) |
| `avatars` | Yes | `{profile_id}/avatar.{ext}` | Public | Owner |

```sql
-- Storage policy example (documents bucket)
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
Client flow: request a signed URL (15-min expiry) -> view/download. **No public file URL ever exists.**

### 5.9 Migration and Seeding Strategy

- Migrations live in `db/migrations/*.sql`, applied with `supabase db push` (never edited after merge).
- Pattern per change: **expand -> migrate -> contract**. Add nullable column -> backfill -> switch reads -> drop old (next release). Guarantees the previous app version keeps working, enabling rollback.
- Seed data (`db/seed.sql`): 5 checklist templates (criminal, bail, family, property, women & child) with BN/EN names; 3 test advocates; 3 test clients; 1 admin.
- `db/tests/rls_test.sql` runs after migrations in CI: for each table it asserts "client A cannot see client B's row" and "advocate cannot see unassigned cases".

## 6. API Design

### 6.1 Conventions

| Concern | Decision |
|---|---|
| Base URLs | Data: `https://<project>.supabase.co/rest/v1` - Auth: `https://<project>.supabase.co/auth/v1` - Realtime: `wss://<project>.supabase.co/realtime/v1` - AI/PDF: `https://api.legallink.bd/v1` (Cloudflare Worker) |
| Versioning | Worker namespace is versioned in the path (`/v1/...`). PostgREST is not versioned; breaking changes go through the expand/migrate/contract cycle instead. |
| Auth | `Authorization: Bearer <jwt>` on every call. Anonymous key only for auth endpoints. |
| Content type | `application/json` (Worker accepts `multipart/form-data` for PDF/upload helpers). |
| Pagination | PostgREST `Range` header + `Prefer: count=exact`; default page 20, max 100. Worker uses `limit`/`cursor`. |
| Idempotency | Mutating Worker calls accept `Idempotency-Key`; SOS accept and publish are naturally idempotent by state check. |
| Naming | snake_case JSON keys matching DB columns (no translation layer) - reduces mapping bugs. |
| Timestamps | ISO-8601 UTC (`2026-03-12T09:15:00Z`). UI converts to Asia/Dhaka. |
| Money | Integer-free: `numeric` serialized as string with 2 decimals (`"15000.00"`) to avoid float drift. |
| Errors | Uniform envelope (section 6.7). |

### 6.2 Authentication API (Supabase Auth)

| Operation | Call | Notes |
|---|---|---|
| Request OTP | `POST /auth/v1/otp` `{ "phone": "+8801XXXXXXXXX" }` | Rate limit 3/5 min/phone (PRD section 13). Supports email OTP fallback. |
| Verify OTP | `POST /auth/v1/verify` `{ "phone": "...", "token": "123456", "type": "sms" }` | Returns `access_token` (15 min), `refresh_token` (7 days), `user`. |
| Refresh session | `POST /auth/v1/token?grant_type=refresh_token` | Silent refresh handled by `supabase_flutter`. |
| Sign out | `POST /auth/v1/logout` | Revokes refresh token. |
| Current user | `GET /auth/v1/user` | Used on boot to hydrate role. |

**Role claim:** on first successful verify, the app calls `POST /rest/v1/rpc/complete_signup` with `{p_role, p_full_name, p_language}`, which writes `profiles` and copies `role` into `app_metadata` so RLS helper functions and the JWT agree.

```json
// Authorization JWT payload (decoded)
{
  "sub": "b1c2...uuid",
  "role": "authenticated",
  "app_metadata": { "role": "advocate" },
  "exp": 1770000000,
  "iat": 1769999100
}
```

### 6.3 Data API - Endpoint Catalog (PostgREST)

Calls are expressed here as resource + filter so they map 1:1 to `supabase_flutter` queries.

**F1 Onboarding**
| Purpose | Call |
|---|---|
| Create/refresh profile | `POST /rest/v1/rpc/complete_signup` |
| Read own profile | `GET /rest/v1/profiles?select=*&id=eq.{uid}` |
| Update language | `PATCH /rest/v1/profiles?id=eq.{uid}` `{ "language": "bn" }` |

**F2 Advocate profile & verification**
| Purpose | Call |
|---|---|
| Create advocate profile | `POST /rest/v1/advocates` (body: bar_council_no, specializations, courts, ...) |
| Upload Sanad | `POST /storage/v1/object/sanad/{uid}/sanad.jpg` then `PATCH /advocates` with `sanad_url` |
| Read own verification state | `GET /rest/v1/advocates?select=verification,rejection_reason,attempts&profile_id=eq.{uid}` |
| Public verified list | `GET /rest/v1/advocate_public?select=*&limit=20` |
| Search advocates | `POST /rest/v1/rpc/advocate_search` |
| Admin: verification queue | `GET /rest/v1/advocates?verification=eq.pending&order=created_at.asc` |
| Admin: approve | `PATCH /rest/v1/advocates?profile_id=eq.{uid}` `{ "verification": "verified", "verified_at": "now()" }` |
| Admin: reject | `PATCH` with `{ "verification": "rejected", "rejection_reason": "..." }` |

**F3 SOS**
| Purpose | Call |
|---|---|
| Post SOS | `POST /rest/v1/sos_requests` `{ person_name, thana, district, court, charges, contact_phone, urgency }` |
| Open SOS feed (advocate) | `GET /rest/v1/sos_requests?status=eq.open&district=in.(...)&order=created_at.desc` |
| Accept SOS (atomic) | `POST /rest/v1/rpc/accept_sos` `{ "p_sos_id": "uuid" }` -> `null` means lost the race |
| Cancel SOS | `PATCH /rest/v1/sos_requests?id=eq.{id}&status=eq.open` `{ "status": "cancelled" }` |
| My SOS history | `GET /rest/v1/sos_requests?client_id=eq.{uid}&order=created_at.desc` |

**F4 Triage + checklist**
| Purpose | Call |
|---|---|
| Run AI triage | `POST /rest/v1/rpc/submit_triage` `{ p_input: {...answers} }` |
| Read checklist | `GET /rest/v1/checklist_items?case_id=eq.{id}&order=importance.desc` |
| Advocate approve item | `PATCH /rest/v1/checklist_items?id=eq.{id}` `{ "status": "approved", "approved_at": "now()" }` |
| Advocate reject item | `PATCH` `{ "status": "rejected", "reject_reason": "..." }` |
| Client mark uploaded | `PATCH /rest/v1/checklist_items?id=eq.{id}` `{ "status": "uploaded" }` |
| Templates (admin) | `GET /rest/v1/checklist_templates?active=is.true&order=sort_order` |
**F5 Case timeline**
| Purpose | Call |
|---|---|
| Create case manually | `POST /rest/v1/cases` |
| My cases (client) | `GET /rest/v1/cases?client_id=eq.{uid}&state=in.(created,active)` |
| My cases (advocate) | `GET /rest/v1/cases?advocate_id=eq.{uid}&order=updated_at.desc` |
| Case detail | `GET /rest/v1/cases?select=*,hearings(*),checklist_items(*),ai_summaries(*)&id=eq.{id}` |
| Add hearing | `POST /rest/v1/hearings` `{ case_id, hearing_date, court, outcome_notes, next_hearing_date, published_at: null }` |
| Publish hearing to client | `PATCH /rest/v1/hearings?id=eq.{id}` `{ "published_at": "now()" }` |
| Amend a published hearing | `POST /rest/v1/hearings` with `supersedes_id` + `is_amended: true` (never UPDATE a published row) |
| Timeline feed | `GET /rest/v1/hearings?case_id=eq.{id}&published_at=not.is.null&order=hearing_date.desc` |
| Sign consent | `POST /rest/v1/consents` `{ case_id, advocate_id, scope }` |
| Revoke consent | `PATCH /rest/v1/consents?id=eq.{id}` `{ "revoked_at": "now()", "version": <current+1> }` |

**F6 AI summary (HITL)**
| Purpose | Call |
|---|---|
| Generate draft | `POST /v1/ai/summarize` (Worker) -> returns `{draft_bn, model, prompt_version, tokens}` |
| Persist draft | `POST /rest/v1/ai_summaries` `{ case_id, hearing_id, raw_input, draft_bn, state: "draft" }` |
| Read my drafts (advocate) | `GET /rest/v1/ai_summaries?case_id=eq.{id}&state=eq.draft` |
| Publish with PIN | `POST /rest/v1/rpc/publish_ai_summary` `{ p_summary_id, p_pin, p_final_bn }` |
| Client reads published | `GET /rest/v1/ai_summaries?case_id=eq.{id}&state=eq.published` (RLS enforces the filter anyway) |
| Client requests update | `POST /rest/v1/rpc/request_update` `{ p_case_id }` (deduped to 1/24h) |
| Admin force-publish | `POST /rest/v1/rpc/admin_force_publish` `{ p_summary_id, p_reason }` |

**F7 Invoices**
| Purpose | Call |
|---|---|
| Create invoice | `POST /rest/v1/rpc/create_invoice` `{ p_case_id, p_items: [{description, amount_bdt}], p_due_date }` |
| List invoices | `GET /rest/v1/invoices?select=*,invoice_items(*)&case_id=eq.{id}&order=created_at.desc` |
| Record payment | `POST /rest/v1/payments` `{ invoice_id, amount_bdt, method, txn_id }` |
| Send invoice | `PATCH /rest/v1/invoices?id=eq.{id}` `{ "state": "sent" }` |
| Render PDF | `POST /v1/invoice/pdf` `{ "invoice_id": "uuid" }` -> `{ "url": "signed", "expires_in": 900 }` |

**F8 Sync support**
| Purpose | Call |
|---|---|
| Delta pull on reconnect | `GET /rest/v1/{table}?updated_at=gt.{last_sync_ts}` per subscribed table |
| Push queued op | normal `POST`/`PATCH`/`DELETE` per op in FIFO order |
| Report queue telemetry | `POST /rest/v1/offline_sync_queue` (batch) |

**Notifications**
| Purpose | Call |
|---|---|
| In-app inbox | `GET /rest/v1/notifications?user_id=eq.{uid}&order=created_at.desc&limit=50` |
| Mark read | `PATCH /rest/v1/notifications?id=eq.{id}` `{ "read_at": "now()" }` |
| Register FCM token | `PATCH /rest/v1/profiles?id=eq.{uid}` `{ "fcm_token": "...", "fcm_updated_at": "now()" }` (columns defined in section 5.4; called on every app start and on `onTokenRefresh`) |

### 6.4 Cloudflare Worker API (`POST /v1/*`)

Every route: JWT required -> verify with Supabase JWKS -> rate limit (KV) -> PII redact -> act -> log.

| Route | Method | Body | Response | Notes |
|---|---|---|---|---|
| `/v1/ai/triage` | POST | `{ "answers": {...}, "case_type": "bail" }` | `{ case_type, urgency, overview_bn, actions_bn[], checklist[], disclaimer_bn, model, prompt_version, cached }` | Rule-based template merged with AI suggestions; template-only on AI failure |
| `/v1/ai/summarize` | POST | `{ "raw_notes": "...", "case_type": "bail", "language": "bn" }` | `{ draft_bn, model, prompt_version, tokens, fallback_used }` | JSON mode, temperature 0.2, 30s timeout |
| `/v1/ai/chat` (P1) | POST | `{ "question_bn": "..." }` | `{ answer_bn, sources[], disclaimer_bn }` | RAG; no chunk found -> `answer_bn` = "consult an advocate" |
| `/v1/ai/health` | GET | - | `{ provider: "groq\|local", reachable: bool, latency_ms }` | Used by the app's health badge |
| `/v1/invoice/pdf` | POST | `{ "invoice_id": "uuid" }` | `{ url, expires_in }` | Reads invoice via service role after verifying the caller is a party |
| `/v1/rate/check` | POST | `{ "action": "sos\|triage\|pin\|..." }` | `{ allowed, remaining, reset_at }` | Shared limiter used by the app for pre-flight UX |

**Worker internals (design)**

```
request -> [1] JWT verify (JWKS cached 1h)
        -> [2] rate limit key = uid:action (KV counter, sliding window)
        -> [3] body schema validate (zod)
        -> [4] PII redaction:
               NID: /\b\d{10,17}\b/ -> [NID]
               BD phone: /\+?8801\d{9}/ -> [PHONE]
               names: from a provided name list in the payload
               -> keep a local map to re-hydrate placeholders in the response
        -> [5] KV cache lookup (sha256 of model+prompt_version+redacted input); TTL 24h
        -> [6] provider call: AI_PROVIDER=groq -> api.groq.com/openai/v1/chat/completions
                              AI_PROVIDER=local -> http://localhost:8080/v1/chat/completions
        -> [7] JSON schema validation of the model output
        -> [8] re-hydrate placeholders -> response + logging to Supabase (service role)
```

### 6.5 Realtime Channels

| Channel | Topic | Subscribers | Payload used for |
|---|---|---|---|
| `case:{case_id}` | `postgres_changes` on `cases`, `hearings`, `ai_summaries`, `checklist_items`, `documents` filtered by `case_id` | Case parties + admins | Live timeline, "your lawyer posted an update", sync badge |
| `sos:{district}` | `postgres_changes` INSERT+UPDATE on `sos_requests` filtered by `district` | Verified advocates in that district | Live SOS queue; removal on accept (status change) |
| `inbox:{user_id}` | INSERT on `notifications` filtered by `user_id` | That user's devices | In-app toast/inbox |
| `admin:{queue}` | INSERT on `advocates` (verification=pending), `audit_logs` (flagged), complaints | Admins | Verification and safety dashboards |

Client subscription lifecycle:
```
on screen mount -> channel.subscribe()
on screen unmount -> channel.unsubscribe()
on app resume -> re-subscribe + delta fetch (updated_at > last_sync_ts)
on auth change -> unsubscribe all, clear Hive token-sensitive caches
```

### 6.6 Notifications and Webhooks

- **Outbound push:** trigger on `notifications` INSERT -> Edge Function `dispatch-fcm` -> FCM HTTP v1. The dispatcher reads `profiles.fcm_token` (section 5.4) and nulls it when FCM answers `UNREGISTERED` or `INVALID_ARGUMENT`, so stale tokens never accumulate.
- **FCM payload:** `{ title_bn, body_bn, data: { kind, entity_id, deep_link } }`; data-only messages so the app controls UI and Bangla rendering.
- **Deep links:** `legallink://case/{id}?tab=timeline`, `legallink://sos/{id}`, `legallink://invoice/{id}`.
- **Inbound webhooks (future):** none in MVP. Reserved namespace `/v1/hooks/*` with HMAC verification for a future bKash/Nagad callback and SMS DLR receipts.

### 6.7 Error Model

Worker errors:
```json
{ "error": { "code": "AI_UNAVAILABLE", "message": "AI is busy",
             "message_bn": "AI এখন ব্যস্ত", "retryable": true, "request_id": "..." } }
```
PostgREST/RPC errors (mapped in the client to Bangla messages):

| Code | Source | Client behavior |
|---|---|---|
| `not_verified_advocate` | `accept_sos` | "Your account is not verified yet." |
| `sos_already_taken` (null result) | `accept_sos` | "Another advocate already accepted this SOS." |
| `rate_limited` | Worker / RPC | Show remaining time from `reset_at`. |
| `invalid_pin` | `publish_ai_summary` | Show attempts left; lock after 5. |
| `pin_locked` | `publish_ai_summary` | Show lock expiry time. |
| `draft_expired` | `publish_ai_summary` | "This draft expired. Generate a new summary." |
| `conflict_stale_version` | consent/invoice/publish writes | Show the conflict sheet -> "reload and reapply". |
| `rls_denied` (42501) | any | Never silent: show "you do not have access" + log. |
| `quota_exceeded` | Worker | Fall back to template output where applicable. |

### 6.8 Rate Limits (implementation mapping - PRD section 13)

| Action | Key | Window | Limit | Enforced at |
|---|---|---|---|---|
| `sos.post` | `uid` | 24 h | 3 | RPC `submit_sos` + Worker `/v1/rate/check` |
| `sos.active` | `uid` (advocate) | concurrent | 5 | RPC `accept_sos` guard |
| `triage.run` | `uid` | 24 h | 10 | RPC `submit_triage` |
| `summary.draft` | `case_id` | 24 h | 20 | RPC insert guard |
| `pin.attempt` | `advocate_id` | 30 min | 5 | `publish_ai_summary` |
| `review.create` | `uid` | per case + 7 d | 1 | RLS + trigger (P1) |
| `complaint.create` | `uid` | 30 d | 5 | trigger (P1) |
| `otp.request` | `phone` | 5 min | 3 | Supabase Auth config + captcha on web |
| `upload.file` | `case_id` | per case | 50 files / 20 MB | Storage policy + Worker check |
| `api.general` | `uid` / `ip` | 1 min | 300 / 1000 | Worker middleware |

### 6.9 API Security Checklist

- JWT verified on every Worker route via cached JWKS (no shared secrets in the client).
- Service-role key exists **only** in Edge Functions and the Worker environment - never in the Flutter app.
- CORS: Worker allows only `https://legallink.bd` and `localhost:*` origins.
- All Storage reads go through 15-minute signed URLs.
- All writes go through RLS or security-definer RPCs that re-check the caller.
- `audit_logs` is not writable through the API at all (no INSERT policy).

## 7. AI Subsystem Design

### 7.1 Components

```
AIService (Dart interface)
    +-- TriageRepository      -> POST /v1/ai/triage
    +-- SummaryRepository     -> POST /v1/ai/summarize
    +-- ChatRepository (P1)   -> POST /v1/ai/chat
    +-- AISettings            -> reads AI_PROVIDER, base URL, timeouts
```

```dart
abstract class AIService {
  Future<TriageResult> triage(TriageInput input);
  Future<SummaryDraft> summarize(SummaryInput input);
  Future<ChatAnswer> ask(String questionBn);       // P1
}

class WorkerAIService implements AIService { /* calls api.legallink.bd/v1/ai/* */ }
class TemplateAIService implements AIService {    // zero-network fallback
  Future<TriageResult> triage(TriageInput i) async =>
      TriageResult.fromTemplate(i.caseType);      // rule-based, no AI
  ...
}
class AIServiceFactory {
  static AIService build(AppConfig c) =>
      c.aiEnabled ? WorkerAIService(c) : TemplateAIService();
}
```
Switching `AI_PROVIDER` between `groq` and `local` happens **inside the Worker** - the Flutter app never changes. This satisfies the PRD's hybrid-AI requirement (`AI_PROVIDER=local` demo runs with no internet on the app side).

### 7.2 Prompt Contracts and JSON Schemas

**Triage output (strict JSON, `response_format: json_object`)**
```json
{
  "case_type": "bail",
  "urgency": "high",
  "overview_bn": "গ্রেপ্তারের পর জামিনের জন্য আবেদন করতে হবে...",
  "actions_bn": ["থানা থেকে এফআইআর কপি নিন", "..."],
  "checklist": [
    { "template_id": "uuid-or-null", "item_name_bn": "এফআইআর কপি",
      "importance": "high", "reason_bn": "মামলার মূল দলিল" }
  ],
  "questions_to_ask_lawyer_bn": ["..."],
  "disclaimer_bn": "এটি সাধারণ তথ্য, আইনি পরামর্শ নয়।"
}
```
Rules the Worker enforces on the response:
1. Every `checklist[].item_name_bn` must exist in the admin template set for that case type (or be explicitly marked `ai_extra: true`). Anything else is dropped - **the AI cannot invent a document list**.
2. `importance` must be one of `high|medium|low`.
3. `disclaimer_bn` must be present, non-empty; if missing the Worker injects the canonical string.
4. Max 15 checklist items, max 5 actions.

**Summary output (strict JSON)**
```json
{
  "summary_bn": "১২ মার্চের শুনানিতে জামিনের আবেদন ... পরবর্তী তারিখ ২০ মার্চ।",
  "next_hearing_date": "2026-03-20",
  "events": ["জামিন আবেদন দাখিল", "বিপক্ষ সময় চেয়েছে"],
  "disclaimer_bn": "এটি আপনার আইনজীবীর অনুমোদন সাপেক্ষ।"
}
```
Prohibited patterns (blocked by a post-filter, not just the prompt): any prediction wording (`জামিন পাবেন`, `হেরে যাবেন`), any explicit advice (`আপনার করা উচিত` outside procedural steps), any monetary guarantee. On match -> the draft is regenerated once; on second match -> template fallback + flag `flagged=true` for admin review.

### 7.3 Prompt Versioning

Prompts live in `edge/worker/prompts/{feature}_{version}.ts` (e.g. `triage_v3.ts`, `summary_v3.ts`). Every AI row stores `prompt_version` and `model`, so outputs are reproducible and regression-testable. Prompt changes require a new version file and a CI golden-set run.

### 7.4 RAG Pipeline (P1)

```
OFFLINE (build time, weekly)
1. Crawl bdlaws.minlaw.gov.bd (15-20 acts)
2. Clean: strip HTML/nav, normalize Bangla Unicode, drop headers/footers
3. Chunk: 300-500 words with 50-word overlap -> legal_knowledge_base rows
4. Embed with bge-m3 (1024-dim) locally
5. INSERT into legal_knowledge_base (source, section, chunk_no, content_bn, embedding)

ONLINE (per question)
1. Embed the question with bge-m3 (Worker calls a tiny embedding endpoint or local build)
2. SELECT ... ORDER BY embedding <=> $q LIMIT 5
3. If the best similarity < threshold (0.35) -> answer = "consult an advocate"
4. Build prompt: retrieved chunks + question + "cite the section" instruction
5. LLM -> answer_bn + sources[] + disclaimer_bn
```

### 7.5 AI Guardrails Summary

| Guardrail | Mechanism | Failure behavior |
|---|---|---|
| No invented checklist items | Template membership check | Drop unknown items |
| No legal advice / prediction | Prompt + banned-phrase filter | Regenerate once, then template + flag |
| PII never leaves the boundary | Worker redaction before provider call | Request rejected if redaction fails |
| No client-facing direct AI | RLS (drafts unreadable by clients) + PIN publish | Database-enforced, not UI |
| Schema drift | JSON schema validation | Retry once -> template fallback |
| Timeout / provider down | 30 s timeout, one retry | Template fallback, `fallback_used=true` |
| Cost/abuse | KV rate limits + KV response cache | 429 with `reset_at` |

## 8. Client Architecture (Flutter)

### 8.1 Clean Architecture Mapping

```
presentation (Riverpod + widgets)
      |  calls
      v
domain (entities, use cases, repository interfaces)   <-- pure Dart, unit-tested
      ^  implements
      |  
data (repository impls, DTOs, Supabase/Hive sources)
```

Rules enforced in `analysis_options.yaml` and CI:
- `domain/**` may not import `flutter`, `supabase_flutter`, or `hive`.
- `presentation/**` may not import `data/**`.
- Every use case is a class with a single `call()`; unit tests call it with a mocked repository.

### 8.2 State Management

| Concern | Pattern |
|---|---|
| Session/auth | `authStateProvider` (stream from Supabase auth changes) |
| Case data | `StreamProvider` on Realtime channel + `AsyncNotifier` for mutations |
| Checklist | `AsyncNotifier` with optimistic item status updates |
| Sync status | `syncStatusProvider` (idle / syncing / pending:n / conflict) |
| Role gating | `currentRoleProvider` derived from JWT `app_metadata.role` |
| Offline | `connectivityProvider` (connectivity_plus) + outbox notifier |

### 8.3 Repository Contract (example - SOS)

```dart
abstract class SosRepository {
  Future<Result<SosRequest>> create(SosDraft draft);
  Future<Result<SosRequest?>> accept(String sosId);   // null => lost the race
  Stream<List<SosRequest>> watchOpenInDistricts(List<String> districts);
  Future<List<SosRequest>> history();
}
```
`Result<T>` is `Ok<T> | Err(Failure)`; `Failure` carries a code, Bangla message, and `retryable`.

### 8.4 Offline Sync Engine

```
        +-------------------+        +---------------------+
        |  UI action        |        |  Realtime / pull     |
        +---------+---------+        +----------+----------+
                  v                             v
        +-------------------+        +---------------------+
        |  Hive write       |        |  Hive merge         |
        |  (optimistic)     |        |  (server wins on    |
        +---------+---------+        |   conflict rules)   |
                  v                  +----------+----------+
        +-------------------+                   |
        |  Outbox enqueue   |                   |
        +---------+---------+                   |
                  v                             v
        +-----------------------------------------------+
        |  Sync worker (FIFO, connectivity-triggered)    |
        |  - normal field: last-write-wins (updated_at)  |
        |  - critical: version check -> conflict state   |
        |  - delete: tombstone -> soft delete server     |
        |  - file:    resume chunk upload                |
        +-----------------------------------------------+
```

Outbox record (Hive box `outbox`):
```json
{ "id": "uuid", "op": "update", "target": "checklist_items",
  "payload": {...}, "client_ts": "2026-03-12T09:15:00Z",
  "base_version": 3, "attempts": 0, "status": "pending" }
```

| Rule | Implementation |
|---|---|
| Queue cap 100, warn at 50 | `outbox.length` guard in the sync notifier + UI banner |
| FIFO with per-entity ordering | Sort by `client_ts`; dependencies (case before hearing) respected by target order |
| Retry | Exponential backoff 2s/8s/32s, max 5 attempts -> `failed` with a user-visible retry button |
| Conflict | Server write returns `conflict_stale_version` -> item marked `conflict`, UI shows both versions |
| Consent revocation wins | Client-side: on receiving a revocation, drop queued advocate writes for that case |
| File uploads | `documents` row written with `local_ref` immediately; bytes uploaded on connectivity; then `storage_path` + status update |
| Visibility | `SyncBadge` widget bound to `syncStatusProvider` |

### 8.5 Responsive Design

```
LayoutBuilder
  maxWidth < 600  -> mobile shell: bottom navigation (5 tabs), single column, FAB for SOS
  maxWidth >= 600 -> desktop shell: left navigation rail + master-detail split
                     (case list left, detail right; keyboard shortcuts; right-click menus)
```

### 8.6 Role-Based Navigation Guards

| Route | Guard |
|---|---|
| `/sos/new`, `/cases/*` (client view) | authenticated + role=client |
| `/advocate/*`, `/sos/inbox` | authenticated + role=advocate + verification=verified |
| `/admin/*` | role=admin |
| `/onboarding/role` | authenticated + profile.role is null |

### 8.7 Push Notification Handling

- Foreground: show an in-app toast + insert into the inbox (no system notification).
- Background/terminated: FCM data message -> `flutter_local_notifications` renders Bangla title/body.
- Tap: `deep_link` parsed by `go_router` -> route push.
- Hearing reminders are scheduled **server-side** (cron) and delivered as push, so they work even if the app was never opened (local scheduling is used only as a redundant booster).

### 8.8 Accessibility Implementation (WCAG 2.1 AA baseline)

The primary audience includes rural and low-literacy users on low-end Android devices, so accessibility is a build requirement, not polish. Every rule has a named verification method so it can be gated in CI or in the pre-demo script.

| Requirement | Implementation | Verified by |
|---|---|---|
| **Touch targets >= 48x48 dp** | Every tappable widget is wrapped in a shared `MinTapTarget` widget (>= 48 dp box, >= 8 dp separation). Icon-only buttons are banned by lint rule; the SOS button is >= 64 dp | Widget test asserting `size >= Size(48,48)` on every `Semantics` tap node; manual audit on a 5-inch device |
| **Bangla font fallback** | Bundle a subsetted Noto Sans Bengali as the app default; never depend on the system font; missing glyphs fall back to bundled English, never to tofu boxes | Font-render golden test on Android 8 (oldest target) and in the Chrome build |
| **Semantic labels** | `Semantics(label:)` on every interactive element (Bangla); `MergeSemantics` on card rows; `SemanticsService.announce` for status changes (SOS accepted, summary published, sync pending/saved) | `SemanticsTester` in `flutter_test`: every interactive node must expose a non-empty Bangla label |
| **Status never by color alone** | Status chips carry text + icon ("জরুরি" + alert icon; checklist and invoice states likewise) | Manual audit + contrast check on the token palette |
| **Contrast** | Body text >= 4.5:1, large text >= 3:1; palette defined as tokens in `app/theme.dart` with documented contrast pairs | Automated contrast assertion in the theme unit test |
| **Text scaling** | Layouts survive `textScaleFactor` 1.0-2.0 (no fixed-height text containers; use `Flexible`/`Wrap`) | Widget tests executed at 1.0 and 2.0 |
| **Voice input** | `speech_to_text` (bn-BD) offered on every free-text field: SOS description, triage answers, hearing notes, complaint text | Manual test on a device with Bangla speech |
| **Keyboard navigation (web)** | Tab order follows visual order; `FocusTraversalGroup` per screen; Enter activates, Esc closes dialogs | Web widget test for Tab traversal on SOS + checklist screens |
| **Screen-reader support** | TalkBack (Android) and NVDA (web) complete the SOS -> accept -> checklist -> timeline -> summary flow with no dead end; documents/images expose an alt-description field | Manual pass inside gate D-1 |
| **Timeout accommodation** | OTP and PIN screens warn before expiry and offer resend/retry; no silent timeouts | Manual test of the OTP expiry path |
| **Reduced motion** | `MediaQuery.disableAnimations` respected (no parallax or auto-scrolling carousels) | Widget test with `disableAnimations: true` |

Non-goals for the MVP: full WCAG 2.2, sign-language content, and an audio-only mode (tracked as P2).

## 9. Security Architecture

### 9.1 The 5 Layers (with implementation)

| Layer | Implementation | Verification |
|---|---|---|
| L1 Transport | TLS 1.3 everywhere, WSS for Realtime, HSTS on Pages | `curl -v` check in CI smoke test |
| L2 Authentication | Supabase phone OTP, JWT 15-min access / 7-day refresh, `role` in `app_metadata` | Auth integration tests |
| L3 Authorization | RLS on all tables + security-definer RPCs + storage policies | `db/tests/rls_test.sql` in CI |
| L4 Encryption | AES-256 at rest (Supabase), pgcrypto for PIN hashing, 15-min signed URLs | Policy review + manual pen-test checklist |
| L5 Audit | Append-only `audit_logs`, no INSERT/UPDATE/DELETE policy | Attempt an API insert in tests -> must fail |

### 9.2 Threat Model (STRIDE, scoped to LegalLink)

| Threat | Vector | Mitigation |
|---|---|---|
| **Spoofing** | Fake advocate registration | Admin verification against Bar Council number + Sanad; verified-only SOS feed; annual re-verification |
| **Spoofing** | Stolen device/session | Short access-token TTL, refresh rotation, secure storage, sign-out-all-devices |
| **Tampering** | Client writes `advocate_id` on a case to hijack it | RLS `with check` clauses + RPC-only state transitions |
| **Tampering** | Editing a published hearing to hide information | Published rows are immutable; amendments are new versions with a chain |
| **Repudiation** | Advocate denies publishing a summary | PIN-verified publish + `audit_logs` `approved_by`, `published_by`, IP, device |
| **Information disclosure** | Client A reading Client B's case | RLS `client_id = auth.uid()`; dedicated CI test asserts a 0-row result |
| **Information disclosure** | Leaked document via public URL | Private bucket; signed URLs only, 15-min expiry; no public path |
| **Information disclosure** | PII sent to the LLM provider | Worker redaction before provider call; input hash stored, not raw |
| **DoS** | SOS flooding, review bombing, OTP spam | Rate limits (section 6.8) + audit logging of abusers |
| **Elevation of privilege** | Client calls an admin RPC | Every admin RPC starts with `if not is_admin() then raise`; RLS blocks admin reads for non-admins |
| **Elevation of privilege** | Client reads a draft summary via PostgREST | RLS policy `state='published'`; test asserts 0 rows for drafts |
| **Extortion/ransom** | Attacker demands data deletion | Immutable audit trail, daily backups, RLS containment, no public document URLs |

### 9.3 PIN Handling (HITL security)

- 4-digit PIN is **never stored in plain text**. Hash with pgcrypto `crypt(pin, gen_salt('bf', 10))`; verification uses `crypt(pin, pin_hash) = pin_hash`.
- 5 failed attempts per 30 minutes -> `pin_locked_until = now() + 30 min`.
- 3 lockouts -> admin-assisted reset (requires identity re-check + audit row).
- PIN is required for: publishing an AI summary. Changeable in profile (old PIN required).
- PIN attempts are logged with actor, time, IP, device.

### 9.4 Privacy Controls

| Control | Detail |
|---|---|
| Consent before sharing | `consents` row required before an advocate can read case data (RLS predicates join through `cases`; consent is checked at transfer time) |
| Scope-limited | `scope text[]` - MVP uses `{case_data}`; extensible to `{documents}`, `{billing}` |
| Revocable | Client sets `revoked_at`; revocation wins over in-flight advocate writes (PRD F8) |
| Post-engagement | On `cases.state='closed'`, consent auto-revokes and the advocate loses write access (retains read-only history) |
| Data minimization | No NID stored for clients; NID optional for the arrested person; only redacted text reaches the LLM |
| Retention | Per PRD section 10 (30-day raw AI input, 90-day case archive window, 5-year audit logs) |

### 9.5 Secrets Management

| Secret | Where it lives | Never in |
|---|---|---|
| `SUPABASE_ANON_KEY` | Flutter app bundle (public by design) | - |
| `SUPABASE_SERVICE_ROLE_KEY` | Edge Functions env, Worker env | Flutter app, git |
| `GROQ_API_KEY` | Worker secret | Flutter app, git |
| `FCM_SERVER_KEY` | Edge Functions secret | Flutter app, git |
| Android keystore | GitHub Secret (base64) | git, repo |
| `JWT` signing secret | Managed by Supabase | anywhere else |

`.env` is git-ignored; `.env.example` documents keys. CI fails on any committed secret matching common patterns.

### 9.6 Security Testing Checklist (release gate)

1. Client A cannot read Client B's case, hearings, documents, invoices (asserted per table).
2. Unverified advocate cannot see the SOS feed or accept an SOS.
3. Client cannot read `ai_summaries` where `state='draft'`.
4. Client cannot write `audit_logs` (API insert must fail).
5. Client cannot elevate: calling `admin_force_publish` returns an error.
6. Signed URL for a document stops working after 15 minutes.
7. PIN locks after 5 failures; unlock after the lock window.
8. Two concurrent `accept_sos` calls -> exactly one winner.
9. Rate limits trigger at the documented thresholds.
10. Worker rejects a request with a tampered/expired JWT.

## 10. Non-Functional Design

### 10.1 Performance Budgets (from PRD section 9)

| Metric | Target | Design decision that achieves it |
|---|---|---|
| APK size | < 50 MB | No bundled ML models; R8/proguard shrinking; deferred components for admin screens |
| Cold start | < 3 s on a 2 GB Android device | Lazy DI, Hive opens on first paint path, no network block on boot |
| First contentful paint (3G) | < 2 s | Cached-first rendering from Hive, then network refresh |
| PostgREST read p95 | < 500 ms | Indexes on all RLS predicates (section 5.5), selective `select=` projections |
| Advocate search p95 | < 100 ms | GIN indexes on `districts/courts/specializations`; ranked RPC |
| Realtime latency | < 1 s | Single channel per case; filtered subscriptions |
| AI triage | < 8 s p95 | Groq (~500 tok/s); KV response cache for repeat inputs; JSON mode |
| AI summary draft | < 10 s p95 | Short outputs (max 120 words), temperature 0.2 |
| Sync of a queued item | < 2 s per item on 3G | FIFO worker, no parallel storms, 100-item cap |

### 10.2 Caching Strategy

| Layer | What | TTL | Invalidation |
|---|---|---|---|
| Hive (client) | Cases, hearings, checklists, notifications, published summaries | Until replaced | Realtime update or delta pull |
| Cloudflare KV | AI responses keyed by `sha256(model + prompt_version + redacted input)` | 24 h | TTL only (deterministic prompts) |
| Worker JWKS | Supabase public keys | 1 h | TTL |
| PostgREST | HTTP cache headers on read-only views (`advocate_public`) | 60 s | TTL |
| Flutter memory | Provider-level memoization per screen | Session | Provider dispose |

### 10.3 Scalability Path

| Phase | Users | Bottleneck | Action |
|---|---|---|---|
| MVP | 0-500 | none | Free tiers (PRD section 9) |
| Growth | 500-5,000 | Supabase storage + Realtime concurrency | Supabase Pro (~$25/mo), Groq paid tier, add R2 for documents |
| Scale | 5,000-50,000 | Postgres connections, Realtime fan-out | Supavisor pooling, partition `audit_logs` by month, split Realtime channels per district |
| Enterprise | 50,000+ | Multi-region, compliance | Self-hosted Supabase, read replicas, CDN-cached advocate directory |

Design choices that delay the need to scale: cursor pagination everywhere, no N+1 reads from the client, aggregate dashboards computed by scheduled SQL into a summary table (not on-demand).

### 10.4 Failure-Degradation Matrix (design view of PRD section 14)

| Degraded component | Core flow (SOS -> case -> timeline) | AI features | UI signal |
|---|---|---|---|
| Groq/Groq quota | unaffected | template fallback | "AI is busy" note |
| llama.cpp down | unaffected | Groq or template fallback | health badge red in dev |
| Realtime down | works (delta pull on focus/resume) | works | "showing cached data" badge |
| FCM down | works | works | inbox still populates |
| Storage down | metadata works | works | upload retry button |
| Postgres down | **outage** | outage | full-screen retry state |

## 11. DevOps and Environments

### 11.1 Repository Layout (monorepo)

```
LegalLink/
+-- apps/legal_link/          Flutter app (web + android targets)
+-- edge/worker/              Cloudflare Worker (llm-gateway) + prompt files
+-- edge/functions/           Supabase Edge Functions (Deno/TS)
+-- db/migrations/            SQL migrations (supabase CLI)
+-- db/seed.sql               Checklist templates + demo data
+-- db/tests/rls_test.sql     RLS assertions run in CI
+-- ai/                       RAG build scripts + golden set
+-- docs/                     prd.md, trd.md, diagrams
+-- .github/workflows/        ci.yml, deploy-web.yml, release-android.yml
```

### 11.2 Environments

| Env | Supabase | Worker | AI_PROVIDER | Purpose |
|---|---|---|---|---|
| `local` | `supabase start` (Docker) | `wrangler dev` | `local` (llama.cpp) | Daily development, offline |
| `staging` | Separate free project | `wrangler deploy --env staging` | `groq` | PR previews, RLS tests, demo rehearsal |
| `prod` | Main free project | `wrangler deploy --env prod` | `groq` | Pilot users |

### 11.3 CI Pipeline (`.github/workflows/ci.yml`)

```
on: pull_request
jobs:
  analyze:   flutter analyze  + dart format --set-exit-if-changed
  test:      flutter test (unit + widget) with coverage gate 60%
  rls:       supabase start -> db push -> psql -f db/tests/rls_test.sql
  ai-golden: run 30 fixed inputs against the mock provider; assert JSON schema
             (CI stays provider-independent and free of API keys; the REAL
              dual-provider run on Groq + local Qwen is a Sprint 1 gate, see 16.2)
  sql-lint:  sqlfluff on db/migrations
  build:     flutter build web --release  +  flutter build apk --debug (artifact)
```

### 11.4 Deployment Workflows

| Workflow | Trigger | Steps |
|---|---|---|
| `deploy-web.yml` | push to `main` | build web -> `wrangler pages deploy` -> smoke test `/` and one PostgREST call |
| `release-android.yml` | tag `v*.*.*` | build signed APK (keystore from secrets) -> upload to GitHub Release -> attach changelog |
| `deploy-worker.yml` | changes in `edge/worker/**` on `main` | `wrangler deploy` -> `/v1/ai/health` check |
| `deploy-functions.yml` | changes in `edge/functions/**` on `main` | `supabase functions deploy` |

### 11.5 Database Change Process

1. Author writes `db/migrations/<timestamp>_<name>.sql`.
2. CI applies it to a throwaway local DB and runs the RLS suite.
3. Merge -> `supabase db push` to staging, then prod (manual approval gate).
4. Destructive changes only after one release of dual-compatibility (expand -> migrate -> contract).
5. Every migration that touches RLS must include a test update.

### 11.6 Rollback

- **Web:** redeploy the previous Cloudflare Pages deployment (instant, zero downtime).
- **Worker:** `wrangler rollback` to the previous version.
- **Android:** keep the previous APK release downloadable; the API stays backward-compatible for one release.
- **DB:** migrations are additive within a release; a code rollback never requires a schema rollback.
- **Data:** daily Supabase backup + `pg_dump` artifact in GitHub.

## 12. Observability

### 12.1 Logging

| Source | What is logged | Where | Retention |
|---|---|---|---|
| Client | Errors + sync conflicts + rate-limit hits (no PII) | Supabase table `client_events` (P1) / console in MVP | 30 days |
| Worker | request_id, uid, action, latency_ms, cache hit, fallback_used, provider | Cloudflare Logs (tail) + Supabase `ai_triage_sessions` counters | 7 days (CF), durable for AI rows |
| Edge Functions | invocation, duration, FCM result | Supabase Functions logs | 7 days |
| Database | slow queries (`pg_stat_statements`), RLS denials | Supabase dashboard | 7 days |
| Audit | every sensitive mutation | `audit_logs` (append-only) | 5 years |

**Never logged:** NID numbers, phone numbers in full, document contents, raw PIN, raw case notes before redaction.

### 12.2 Metrics and Alerts

| Metric | Threshold | Alert |
|---|---|---|
| Worker error rate | > 5% over 5 min | Email the team mailbox |
| Worker p95 latency | > 1 s over 15 min | Email |
| AI fallback rate | > 10% over 1 h | Email (provider issue) |
| FCM delivery failure | > 10% weekly | Investigation ticket |
| Supabase DB size | > 80% of free tier | Email + archival job check |
| Supabase Storage | > 80% of 1 GB | Email + R2 overflow decision |
| Realtime concurrent connections | > 80% of free tier | Email |
| RLS denial spike | > 50/min | Investigate (possible attack or broken policy) |
| SOS with no accept | > 30% in 24 h in a district | Product alert: supply problem |

### 12.3 Health Endpoints

| Endpoint | Returns |
|---|---|
| `GET /v1/ai/health` (Worker) | `{ provider, reachable, latency_ms, cache_hits }` |
| `GET /rest/v1/` (PostgREST) | OpenAPI root - used by the deploy smoke test |
| Client-built diagnostics screen (admin/dev only) | sync queue length, last sync ts, realtime channel state, AI provider |

### 12.4 On-Call (4-person team, MVP)

- One rotating "duty engineer" per sprint; the alert mailbox forwards to their phone.
- P0 (data leak, RLS bypass, data corruption): all four, immediately, incident note appended to `audit_logs`.
- P1 (AI down, push down): next business day.
- P2 (cosmetic, non-blocking): backlog.
- Post-incident: a one-page RCA in `docs/incidents/` with a linked PR.

## 13. Testing Architecture

| Level | Scope | Tool | Gate |
|---|---|---|---|
| Unit | domain entities, use cases, formatters, validators, conflict resolver | `flutter_test` + `mocktail` | Every PR; coverage >= 60% |
| Widget | SOS form, checklist, timeline, PIN publish, sync badge, empty states | `flutter_test` | Every PR |
| Integration (client) | auth -> SOS -> case -> checklist -> publish flow against local Supabase | `integration_test` | Nightly + pre-release |
| Database/RLS | per-table "cannot read others' rows" assertions; concurrent `accept_sos`; PIN lockout | `psql` + `pgTAP`-style SQL asserts | Every PR that touches `db/**` |
| API contract | PostgREST RPC shapes + Worker routes with a mock provider | `vitest` (Worker) | Every PR |
| AI golden set | 30 fixed Bangla inputs -> assert JSON schema + banned-phrase absence | Node script | Every PR (mock provider) that touches `edge/worker/prompts/**` or `ai/**`; **dual-provider run on Groq + local Qwen is a Sprint 1 gate (section 16.2)** |
| Accessibility | 48x48 dp targets, Bangla semantic labels, contrast tokens, text scaling 1.0-2.0, Tab traversal | `flutter_test` + `SemanticsTester` + manual audit | Pre-release (rules in section 8.8) |
| Manual pilot script | 20 steps (demo flow, offline flow, abuse limits) | Human checklist | Pre-release; re-run as gate D-1 before the faculty demo (section 16.3) |
| Load sanity | 50 concurrent Realtime subscribers, 100 sequential writes | `k6` | Pre-release |
| Manual pilot script | 20 steps (demo flow, offline flow, abuse limits) | Human checklist | Pre-release |

**Definition of Done (per feature):** unit + widget tests, RLS coverage if it touches data, Bangla strings in ARB (bn + en), empty/error/offline states designed, audit events emitted, and the PRD acceptance criteria demonstrated in staging.

**Test data:** `db/seed.sql` provides two clients (A, B), three advocates (one unverified), one admin, one case per client - exactly what the isolation tests need.

## 14. Tool Inventory (accounts and roles to provision)

| Tool | Purpose | Who needs it | Cost |
|---|---|---|---|
| GitHub org + repo | Source, CI, releases | All 4 | $0 |
| Supabase (prod + staging projects) | DB, Auth, Storage, Realtime, Functions | All 4 | $0 |
| Cloudflare account | Workers, Pages, KV, (R2 optional) | Backend + Frontend leads | $0 |
| Groq account | LLM API key | AI lead | $0 |
| Firebase project | FCM + Android app registration | Frontend lead | $0 |
| Android Studio / VS Code / IntelliJ | Flutter dev | All 4 | $0 |
| Flutter SDK + Android SDK | Build/run | All 4 | $0 |
| Supabase CLI + Docker Desktop | Local stack, migrations | Backend lead (+ AI lead) | $0 |
| Wrangler CLI | Worker dev/deploy | Backend lead | $0 |
| llama.cpp + Qwen 2.5-7B GGUF | Offline AI demo | AI lead | $0 |
| LM Studio / OpenWebUI (optional) | Prompt testing UI | AI lead | $0 |
| Postman / `.http` files | API smoke tests | All 4 | $0 |
| `sqlfluff`, `flutter_lints` | Static quality | All 4 | $0 |
| OpenCode + Mimo 2.5 | AI-assisted TDD development | All 4 | $0 |
| Canva / draw.io | Pitch deck, diagrams | Ops lead | $0 |
| Discord/WhatsApp group | Team comms | All 4 | $0 |

**Human resources (non-tool):** one practicing advocate as domain advisor (verification wording, disclaimers, pilot), one law student for legal-content verification (optional, RAG phase).

## 15. Local Development Setup

```bash
# 1. Flutter + Dart
flutter doctor          # expect Flutter + Android toolchain green
cd apps/legal_link
flutter pub get

# 2. Local backend
supabase start          # Postgres + Auth + Storage + Realtime in Docker
supabase db push        # apply db/migrations
psql "$LOCAL_DB_URL" -f db/seed.sql

# 3. Local AI (offline demo mode)
#    download Qwen2.5-7B-Instruct GGUF (Q4_K_M, ~4.5 GB)
llama-server -m models/qwen2.5-7b-instruct-q4_k_m.gguf --port 8080 -ngl 99

# 4. Worker
cd edge/worker
wrangler dev --env local          # serves http://localhost:8787

# 5. Run the app
cd apps/legal_link
flutter run -d chrome             # web
flutter run -d <android-device>   # android
```

`.env` (git-ignored) keys:
```
SUPABASE_URL=
SUPABASE_ANON_KEY=
AI_GATEWAY_URL=http://localhost:8787
AI_PROVIDER=local          # local | groq
AI_ENABLED=true
```

Smoke check after boot: log in as a seeded client with the local dev OTP, open the seeded case, confirm the timeline renders from Hive while the network is throttled.

## 16. Build Order (technical sequencing for the 8-week plan)

| Sprint | Technical deliverables | Readiness gate (must pass to exit the sprint) |
|---|---|---|
| 1 (W1-2) | Monorepo, local Supabase, migrations 001-016 (core tables + RLS, including `fcm_token`/`fcm_updated_at`), auth + onboarding, profiles/advocates, CI skeleton, `MinTapTarget` + Bangla font subset | **G-1.1 RLS suite green on day 1** and **G-1.2 AI golden set valid on both providers** (section 16.2) |
| 2 (W3-4) | SOS + `accept_sos` RPC + district Realtime, case creation, checklist templates + instantiation, `submit_triage` + Worker `/v1/ai/triage`, checklist UI states | Concurrent-accept test green; triage template-membership filter tested |
| 3 (W5-6) | Hearings + timeline + amendments, Worker `/v1/ai/summarize` + `publish_ai_summary` + PIN, invoices + payments + PDF route, Edge Functions (FCM, crons incl. `annual_reverify_reminder`) | Draft-invisibility RLS test green; PIN lockout test green |
| 4 (W7-8) | Offline sync engine + conflict UI, responsive web layout, section 8.8 accessibility pass, admin verification + audit views, Android release + Pages deploy | **G-4.1 20-step pilot script**, **G-4.2 hybrid AI switch**, **G-4.3 RLS live demo** (section 16.3) |

### 16.1 Readiness Gate Overview

Gates are pass/fail and block the next phase. A failing gate is treated as a defect, not a task: if RLS does not hold, no feature work starts.

| Gate | When | Blocks | Evidence to attach |
|---|---|---|---|
| **IM-1/2/3** | Before Sprint 1 | Sprint 1 kickoff | TRD sections updated (done here); migration + widget/test entries added in Sprint 1 |
| **G-1.1** RLS suite | Sprint 1, **day 1** | All feature work | CI log of `db/tests/rls_test.sql` + the 6 assertion outcomes |
| **G-1.2** AI golden set | Sprint 1, before features | AI feature work | `ai/golden/results/{local,groq}.json` committed |
| **G-4.1** Pilot script | Before demo | Faculty demo | Completed 20-step checklist, signed by two team members |
| **G-4.2** Hybrid AI switch | Before demo | Faculty demo | Screenshots/video of `local` and `groq` runs + `/v1/ai/health` |
| **G-4.3** RLS live demo | Before demo | Faculty demo | Four documented denial outcomes (section 16.3) |

### 16.2 Immediate (pre-Sprint-1) Work and Sprint-1 Gates

**IM-1 - `profiles.fcm_token` column.** DONE in this TRD: `fcm_token` + `fcm_updated_at` are defined in section 5.4, token cleanup on `UNREGISTERED`/`INVALID_ARGUMENT` is specified in section 6.6, and the registration call is in the section 6.3 catalog. Sprint 1 action: include both columns (with a comment on the multi-device limitation) in migration `001`, and add `device_tokens` to the P1 backlog.

**IM-2 - `annual_reverify_reminder()` cron function.** DONE in this TRD: full plpgsql body, lapse consequences, and cron registration are in section 5.7. Sprint 1 action: register the schedule in migration `016_cron.sql` and add a reminder-path assertion to `db/tests`.

**IM-3 - Accessibility subsection.** DONE in this TRD: section 8.8 lists 11 rules with a named verification method each. Sprint 1 action: add `MinTapTarget` to `shared/widgets`, bundle the Noto Sans Bengali subset, and wire the `SemanticsTester` + contrast + text-scale checks into the CI `test` job.

**G-1.1 - Run the RLS test suite on day 1 (the security foundation).** Apply the migrations to a clean local database and run the suite **before writing any feature code**.

```bash
supabase start
supabase db push                                   # migrations 001..016
psql "$LOCAL_DB_URL" -f db/seed.sql                # clients A/B, 3 advocates (1 unverified), admin
psql -v ON_ERROR_STOP=1 "$LOCAL_DB_URL" -f db/tests/rls_test.sql
```

Exit criteria (all six must hold, each asserted as a specific role via `set local role authenticated` + `request.jwt.claims`):

1. Client A reads **0 rows** of client B's `cases`, `hearings`, `documents`, `invoices`.
2. Unverified advocate sees **0 rows** of open `sos_requests` and `accept_sos` raises `not_verified_advocate`.
3. Client reads **0 rows** of `ai_summaries` where `state = 'draft'` (HITL is database-enforced).
4. An API-level `INSERT` into `audit_logs` **fails** (no insert policy exists).
5. A non-admin calling `admin_force_publish` **raises**.
6. Two concurrent `accept_sos` calls on the same SOS return **exactly one** non-null result.

Any failure blocks Sprint 1 feature work until fixed, because every later feature inherits this boundary.

**G-1.2 - Validate the AI golden set against BOTH providers before building AI features.** The CI job uses a mock provider (no keys, no cost); this gate is the real dual-provider run.

```bash
# 1) local provider (offline path used at the demo)
llama-server -m models/qwen2.5-7b-instruct-q4_k_m.gguf --port 8080 -ngl 99
cd ai/golden && AI_PROVIDER=local npm run golden      # 30 fixed Bangla inputs

# 2) cloud provider (production path)
export AI_PROVIDER=groq GROQ_API_KEY=... && npm run golden
```

Exit criteria:

| Check | Threshold |
|---|---|
| Schema-valid JSON responses | 30/30 on `local` **and** 30/30 on `groq` |
| Banned-phrase hits (advice/prediction wording) | 0 on both |
| Checklist items that are template members | 100% (the template-membership filter must drop anything else) |
| `case_type` agreement between the two providers | >= 90% of 30 inputs |
| `fallback_used` flags during a clean run | 0 |

Commit `ai/golden/results/local.json` and `groq.json`. If local Qwen fails the threshold, reduce max context, lower the output length, or fall back to Qwen 2.5-3B - the offline demo path must work, because that is what proves the hybrid architecture (PRD section 8.2).

### 16.3 Faculty Demo Gates

Rehearse the full flow at least twice before the real demo. Each item is pass/fail; two team members sign the checklist.

**G-4.1 - 20-step manual pilot script (PRD Section 20)**

| # | Step | Pass condition |
|---|---|---|
| 1 | Client registers with phone OTP | session created, role = client |
| 2 | RLS probe: client B opens client A's case URL | access error / zero rows - never data |
| 3 | Client posts an SOS with a Bangla voice description | row created, follows the SOS state machine |
| 4 | Verified advocate in that district gets push + Realtime alert | alert within 15 s |
| 5 | Two advocates tap Accept on the same SOS simultaneously | exactly one wins; the loser sees "already taken" |
| 6 | Case is created automatically on accept | case linked to the SOS, consent row created |
| 7 | AI triage + checklist appears as "Suggested" | items are `suggested_pending_advocate`, disclaimer visible |
| 8 | Client uploads an FIR photo | document `uploaded`, signed URL works, 15-min expiry set |
| 9 | Advocate approves/edits the checklist | client sees "Approved by your lawyer" |
| 10 | AI outage drill: stop llama.cpp, re-run triage | template output + "AI is busy" note; the flow is not blocked |
| 11 | Advocate logs a hearing | hearing stored with `published_at` null |
| 12 | Advocate publishes the hearing | client timeline shows it |
| 13 | Client taps "Request update" twice in a row | the second call is deduped (1 per 24 h) |
| 14 | Advocate generates an AI Bangla summary | draft only; the client cannot see it |
| 15 | Client attempts to read that draft directly via the API | 0 rows (HITL is database-enforced) |
| 16 | Advocate publishes the summary with the 4-digit PIN | client gets push, text appears on the phone |
| 17 | PIN lockout drill: 5 wrong PINs | locked for 30 min with attempts shown |
| 18 | Advocate creates an invoice (15% VAT) and renders the PDF | numbering `INV-{YEAR}-{SEQ}`, signed PDF URL |
| 19 | Offline drill: airplane mode -> browse case -> add a note -> reconnect | queued badge -> "All changes saved"; server row matches |
| 20 | Admin force-publish with a reason | published with `published_by='admin_override'` and an audit row |

**G-4.2 - Hybrid AI switch demo.** With the app running and a case open, switch `AI_PROVIDER` from `local` to `groq` (and back) and re-run triage and summary each time. Pass condition: identical JSON schema and identical checklist template membership on both providers, a different `model` value in each stored row, `/v1/ai/health` reporting the active provider, and the `fallback_used` flag visible from step 10. A video capture of both runs is the evidence.

**G-4.3 - RLS enforcement demo.** Log in as the seeded second client (client B) and attempt four reads live, in front of the panel:

| # | Attempt | Required outcome |
|---|---|---|
| 1 | Read client A's case row | 0 rows / access denied |
| 2 | Re-open a document signed URL after its 15-minute expiry | 403 expired |
| 3 | Read an `ai_summaries` row in `draft` state | 0 rows |
| 4 | Insert a row into `audit_logs` via the API | rejected (no insert policy) |

This is the most persuasive security demonstration for a legal-tech panel and the direct proof of PRD section 16 criterion 4.

**Demo-day freeze:** tag the release, keep the previous APK downloadable, re-run the RLS suite the morning of the demo, pre-warm the llama.cpp server so the offline demo does not stutter on first load, and keep a pre-recorded fallback video of G-4.2/G-4.3 in case of venue network failure.

## 17. Architecture Decision Records (ADRs)

| ADR | Decision | Alternatives rejected | Rationale |
|---|---|---|---|
| ADR-001 | Flutter for web + Android | React Native + React web; two native apps | One Dart codebase, real web build, shared domain logic (PRD F8) |
| ADR-002 | Supabase over Firebase | Firebase Firestore; custom Node/Postgres | RLS gives database-level zero-trust authorization, which the legal domain requires; SQL + pgvector for RAG |
| ADR-003 | RLS as the primary authorization layer | App-level checks; API gateway checks | Untrusted clients cannot bypass; testable in CI; survives new client surfaces |
| ADR-004 | Postgres RPC for atomic operations | Client-side multi-call orchestration | `accept_sos`, publish, and invoice numbering must be single-transaction |
| ADR-005 | Human-in-the-Loop publish model | Fully automated AI posting to clients | Legal liability (PRD 8.4); enforced by RLS so it cannot be bypassed |
| ADR-006 | Hybrid AI (Groq + local llama.cpp) behind one Worker | Groq only; local only | Cloud speed in production + a genuinely offline faculty demo; no vendor lock-in |
| ADR-007 | Cloudflare Worker as the AI gateway | Direct client-to-LLM calls; Supabase Edge Function only | PII redaction, KV caching, shared rate limiting; keeps the provider key off the client |
| ADR-008 | Hive for the client cache | SQLite (sqflite/drift) | Works on web without native code; adequate for our access patterns |
| ADR-009 | Riverpod for state | BLoC, Provider | Compile-time safety, testability, less boilerplate for a 4-person team |
| ADR-010 | ARB i18n files for Bangla | DB-driven translations | Bangla is the primary market; translations ship with the app, no network dependency |
| ADR-011 | 15-minute signed URLs for documents | Public bucket; long-lived URLs | Legal-ethics-grade privacy for FIRs and court orders |
| ADR-012 | Immutable published hearings (amend via new version) | In-place edits | Dispute-evidence integrity; gives clients a visible "rescheduled" trail |
| ADR-013 | Additive-only migrations per release | Destructive migrations with code rollback | Keeps rollback possible without a schema rollback |
| ADR-014 | No public win-rate ranking | Rating/win-rate marketplace | Defamation risk and unreliable outcome data (PRD F2) |
| ADR-015 | Soft delete + tombstones | Hard delete | Audit integrity and offline sync correctness |

## 18. Technical Risks and Debt Register

| # | Risk / debt | Impact | Mitigation / trigger to fix |
|---|---|---|---|
| 1 | Free-tier ceilings (Supabase storage, Realtime concurrency, Groq quota) | Feature degradation at pilot scale | Usage alerts at 80%; R2 overflow ready; paid tier at 500+ users |
| 2 | RLS policy complexity / recursive policy bugs | Security or availability incident | Helper functions + CI isolation suite on every `db/**` change |
| 3 | Manual Bar Council verification does not scale | Onboarding backlog | 48h SLA + queue dashboard; AI OCR verification planned (P2) |
| 4 | AI output quality for Bangla legal phrasing | Poor summaries reduce trust | Prompt versioning + golden set + advocate review loop (HITL is the safety net) |
| 5 | Offline conflict complexity | User confusion on conflicts | Explicit conflict UI + consent-wins rule; conflict counters in observability |
| 6 | `audit_logs` growth | Table bloat over years | Monthly partitioning at scale; aggregate views for the dashboard |
| 7 | Web build fidelity for Bangla fonts | Rendering issues on low-end browsers | Bundle a subset Bangla font; avoid system-font dependence |
| 8 | Real-world court data has no API | Data completeness depends on advocates | Voice-first entry + clerk mode (P2); OCR of court orders (P2) |
| 9 | Team of 4 with no dedicated QA | Defects reach pilot | Automated gates (RLS + golden set + widget tests) and a manual 20-step script |
| 10 | Local llama.cpp on 6 GB VRAM | Demo stutter | Qwen 2.5-7B Q4_K_M, limited context, `-ngl 99`; smaller 3B model as fallback |

## 19. Traceability: PRD Requirement -> Technical Artifact

| PRD requirement | Tables | APIs | Components |
|---|---|---|---|
| F1 Onboarding & OTP | `profiles` | `/auth/v1/otp`, `/rpc/complete_signup` | C1, C2, C6 |
| F2 Advocate profile & verification | `advocates`, `advocate_public` | `advocates` CRUD, `advocate_search`, admin PATCH | C4, C5, C9 |
| F3 Emergency SOS | `sos_requests`, `cases` | `sos_requests`, `rpc/accept_sos` | C4, C7, C9 |
| F4 Triage + checklist | `checklist_templates`, `checklist_items`, `ai_triage_sessions` | `/v1/ai/triage`, `rpc/submit_triage` | C3, C5, C11/C12 |
| F5 Case overview & timeline | `cases`, `hearings`, `consents` | `hearings` CRUD, Realtime `case:{id}` | C4, C7 |
| F6 AI summary (HITL) | `ai_summaries` | `/v1/ai/summarize`, `rpc/publish_ai_summary` | C3, C5, C9, C10 |
| F7 Invoice & billing | `invoices`, `invoice_items`, `payments` | `rpc/create_invoice`, `/v1/invoice/pdf` | C3, C4, C8 |
| F8 Cross-device sync | `cases`, `hearings`, `documents`, `offline_sync_queue` | Realtime WSS + delta pulls | C1, C2, C7 |
| PRD 9 Performance | indexes (5.5), Hive/KV caching | - | all |
| PRD 9 Security | RLS policies (5.6) | signed URLs, JWKS | C3, C5, C8 |
| PRD 9 Accessibility | `MinTapTarget`, Noto Sans Bengali subset, semantics/lint rules (8.8) | - | C1, C2 |
| PRD 10 Retention | cron functions | `expire_drafts`, `purge_triage_inputs` | C9 |
| PRD 13 Rate limits | rate-limit keys | `/v1/rate/check`, RPC guards | C3, C5 |
| PRD 14 Failure modes | fallbacks | template paths, retries | C1, C2, C3 |
| PRD F2 annual re-verification | `advocates.reverify_due_at` | `annual_reverify_reminder()` (5.7) | C9 |
| Push notifications | `profiles.fcm_token`, `notifications` | `dispatch-fcm` (6.6) | C9, C10 |
| Readiness gates (immediate / Sprint 1 / demo) | - | gate scripts (16.2, 16.3) | all |

## 20. Data Seeding & Cold Start Strategy (For Demo & Pilot)

To solve the "Cold Start Problem" (an empty app during the faculty demo and initial pilot), we will execute a one-time Data Seeding phase using local Python scraping scripts. This populates the app with accurate, public information without relying on live scraping for daily operations.

**20.1 Seeding Targets & Sources**

| Target Table | Data Source | Scraping Method | Database Action |
|---|---|---|---|
| `advocates` | Supreme Court / Bar Council public directories | BeautifulSoup (Python) | Bulk insert. Set `verification = 'pending'`. Visible in search, but cannot accept SOS until claimed/verified. |
| `hearings` | Public "Cause Lists" (Past 6 months) from court websites | PyPDF2 / BeautifulSoup | Bulk insert into `hearings` linked to seeded demo `cases`. Creates a rich, historical timeline for the demo. |
| `legal_knowledge_base` | `bdlaws.minlaw.gov.bd` (Core Acts) | LangChain WebBaseLoader | Chunk, embed (bge-m3), and insert into `pgvector` for the RAG chatbot. (See Section 7.4) |

**20.2 Execution Pipeline**

1. **Script Location:** `scripts/seed_scraper.py` (Run locally, not in production).
2. **Data Cleaning:** Normalize Bangla Unicode, strip HTML, map court names to standard districts.
3. **Bulk Insert:** Use Supabase `service_role` key to bypass RLS and insert thousands of rows in seconds.
4. **Demo Accounts:** Create 5 "Wizard of Oz" demo accounts (2 clients, 2 advocates, 1 admin) and link the seeded data to them so the faculty demo flow is perfectly scripted.

**20.3 Faculty Viva Defense**

If asked about data sourcing: *"Sir/Ma'am, because Bangladesh lacks a live court API, we cannot scrape real-time updates for active cases. However, to ensure the platform is useful from Day 1, we built a 'Data Seeding Pipeline' that scrapes public historical records and lawyer directories. This populates the app with accurate baseline data for the pilot, while all ongoing, live case updates are entered manually by the advocates via our voice-first dashboard to ensure 100% accuracy."*

## 21. Glossary (technical)

| Term | Meaning |
|---|---|
| PostgREST | Auto-generated REST API over Postgres objects |
| RLS | Row Level Security - per-row database authorization |
| RPC | Postgres function exposed as an API endpoint |
| HITL | Human-in-the-Loop |
| KV | Cloudflare key-value store used for caching and counters |
| KV cache key | `sha256(model + prompt_version + redacted input)` |
| Redaction | Removing PII before an LLM call |
| Template fallback | Rule-based output used when AI is unavailable |
| Golden set | Fixed AI inputs with expected schema, run in CI |
| Outbox | Device-side queue of not-yet-synced mutations |
| Tombstone | Soft-delete marker propagated during sync |
| Delta pull | Fetching only rows where `updated_at > last_sync_ts` |
| JWKS | Public keys used to verify Supabase JWTs at the edge |
| `AI_PROVIDER` | Env switch selecting `groq` (cloud) or `local` (llama.cpp) |

---
*Companion to `D:\LegalLink\prd.md` (v2.0). This TRD covers architecture (C4 L1-L3), stack with versions, full data design with RLS and RPCs, API surface (PostgREST, Worker, Realtime), AI subsystem with prompts/schemas/guardrails, Flutter client and offline sync design, accessibility implementation, security and threat model, NFRs with budgets, DevOps/CI-CD, observability, testing, tool inventory, setup, build order with pass/fail readiness gates (immediate, Sprint 1, faculty demo), 15 ADRs, risk register, and PRD-to-technical traceability.*

*v1.1 (revision) - added: `profiles.fcm_token` + `fcm_updated_at` with dispatcher token cleanup; `annual_reverify_reminder()` cron function with lapse consequences; Section 8.8 accessibility implementation with verification methods; Section 16.1-16.3 readiness gates (day-1 RLS suite with six exit criteria, dual-provider AI golden set validation, 20-step manual pilot script, hybrid AI switch demo, live RLS denial demo, demo-day freeze).*
