# LegalLink — Architecture Blueprint

**Version:** 1.1  
**Date:** October 2026  
**Status:** Approved for implementation  
**Source:** `docs/trd.md` §3, §4, §5, §6, §7, §8, §11; `docs/prd.md` §11  
**Methodology:** 6-week agentic prototyping sprint (`docs/sprint.md`)  
**Determinism:** All paths, signatures, types, and values below are exact; no optional or probabilistic language.

---

## 1. System Context (C4 Level 1)

```
+-------------------------------------------+
|   Bangladesh Legal Ecosystem              |
|   Advocates · Clients · Admins · Bar      |
|   Council · Police (Thana) · Courts       |
+---------------+---------------------------+
                | uses (Bangla-first UI)
                v
+------------------------+------------------+
| LegalLink Frontend     | LegalLink Backend |
| Flutter Web + Android  | Supabase + Worker |
| Riverpod / Hive / GoRouter | Postgres + RLS / RPC |
+------------------------+------------------+
                | HTTPS (JWT) + WSS (Realtime)
                v
+---------------------------+
| Cloudflare Worker Edge    |
| /v1/ai/triage             |
| /v1/ai/summarize          |
| /v1/rate/check            |
| /v1/invoice/pdf           |
+---------------------------+
                | OpenAI-compatible passthrough
                v
+----------------------------------+
| Hugging Face Serverless (cloud)  |
| Hugging Face Transformers (local)|
+----------------------------------+
```

---

## 2. Container Tier Responsibilities

| ID | Container | Trust | Primary Responsibility | Failure Impact |
|----|-----------|-------|------------------------|----------------|
| C1 | Flutter Web | Untrusted | Responsive UI, Hive cache, sync engine | Degraded UI only |
| C2 | Flutter Android | Untrusted | Same as C1 + camera, voice, FCM push | Degraded UI only |
| C3 | Cloudflare Worker | Semi-trusted (no JWT secret) | PII redaction, rate limits, AI cache, invoice PDF | AI features degrade; core flows unaffected |
| C4 | PostgREST (Supabase) | Trusted | Auto-generated REST over tables/views/RPC | Total outage of data access |
| C5 | Postgres + RLS + pgvector | Trusted — security boundary | Data, constraints, RLS, triggers, pgvector | Total outage; highest criticality |
| C6 | Supabase Auth | Trusted | Phone OTP issuance, JWT minting, refresh | Login outage; queued sessions survive 7-day refresh |
| C7 | Supabase Realtime | Trusted | Postgres change broadcast over WSS | Stale UI until delta refetch |
| C8 | Supabase Storage | Trusted | Document blobs, 15-minute signed URLs | Upload/view outage; cached metadata remains |
| C9 | Edge Functions (Deno/TS) | Trusted | Multi-step atomic ops, cron jobs | Specific operations fail; DB stays consistent |
| C10 | Firebase Cloud Messaging | External, best-effort | Push delivery | Silent; in-app timeline is source of truth |
| C11 | Hugging Face Serverless | External (no PII sent) | Production LLM inference | Fallback to rule-based template output |
| C12 | HF Transformers Server | Local (dev/demo) | Offline LLM for faculty demo | Fallback to HF Serverless if online |

---

## 3. Frontend Architecture (C1 / C2)

### 3.1 Stack (exact versions)

| Concern | Choice | Version | Purpose |
|---------|--------|---------|---------|
| Language | Dart | 3.x (bundled with Flutter) | Type-safe, null-safe, single language |
| Framework | Flutter | 3.47.6 stable | Single codebase for Web + Android |
| State Management | flutter_riverpod | 2.x | Compile-time safe, testable |
| Routing | go_router | 14.x | Auth/role redirect guards |
| Local Cache | hive + hive_flutter | 2.x | Offline-first storage, outbox queue |
| Backend SDK | supabase_flutter | 2.x | Auth, PostgREST, Realtime, Storage |
| HTTP | dio | 5.x | Calls to Cloudflare Worker |
| Localization | flutter_localizations + intl | SDK | ARB files (bn primary / en fallback) |
| Secure Storage | flutter_secure_storage | 9.x | Session token + PIN salt on Android |
| Notifications | firebase_messaging + flutter_local_notifications | 14.x / 17.x | FCM push + local reminders |
| Voice Input | speech_to_text | 6.x | Bangla dictation for advocates |
| PDF Viewing | flutter_pdfview / pdfx | latest | View advocate-issued invoice PDFs |
| Lint | flutter_lints + custom analysis_options.yaml | latest | Enforce `presentation -> domain <- data` |

### 3.2 Layered Dependency Rule (exact)

```
presentation -> domain <- data
```

- `lib/features/<feature>/domain/` — pure Dart entities, use cases, repository interfaces. May not import `flutter`, `supabase_flutter`, `hive`, `data/`, or `presentation/`.
- `lib/features/<feature>/data/` — DTOs, repository implementations, data sources. Depends on `domain`.
- `lib/features/<feature>/presentation/` — Riverpod providers/notifiers, pages, widgets. Depends on `domain` only (never `data` directly).
- Single exemption: `lib/app/di.dart` is the composition root and may bridge `presentation/` and `data/`.

### 3.3 Route Map (GoRouter) — exact

| Route | Screen | Auth Required | Role |
|-------|--------|---------------|------|
| `/login` | PhoneScreen | No | Public |
| `/otp` | OtpScreen | No | Public |
| `/role` | RoleSelectionScreen | Yes (OTP verified) | Any |
| `/profile` | MinimalProfileScreen | Yes (role confirmed) | Any |
| `/home` | HomeScreen | Yes (profile complete) | Any |

**Orphaned screens (exist in code but NOT registered in router):**
- `SosBroadcastFormScreen`
- `AdvocateSosInboxScreen`
- `AdminVerificationQueueScreen`
- `AdvocateProfileViewScreen`

---

## 4. Backend Architecture (C4 / C5 / C6 / C7 / C8 / C9)

### 4.1 Supabase Postgres Core (exact tables)

| Component | Purpose |
|-----------|---------|
| `profiles` | Extends `auth.users`; role, phone, language, FCM token |
| `advocates` | 1:1 extension of profiles; bar council no, Sanad/NID URLs, verification state, PIN hash |
| `sos_requests` | Emergency intake; `open -> accepted / declined / cancelled / expired`; district-based routing |
| `cases` | Case lifecycle; 1:0..1 with `sos_requests` via `sos_id` unique FK |
| `hearings` | Immutable amendment chain; `published_at` gates client visibility |
| `ai_summaries` | HITL state machine; `draft -> published / archived`; PIN-gated publish |
| `invoices` + `invoice_items` | Billing; `INV-{YEAR}-{SEQ}` numbering; 15% VAT; state machine |
| `payments` | Partial payments; bKash/Nagad/Cash/bank; manual verification |
| `documents` | Vault with soft delete (`deleted_at`); signed URLs |
| `checklist_templates` + `checklist_items` | Admin-authored templates; per-case instance state machine |
| `ai_triage_sessions` | Audit + telemetry for AI triage runs |
| `audit_logs` | Append-only; no UPDATE/DELETE policy |
| `notifications` | Per-user push/in-app; dedupe key |
| `legal_knowledge_base` | pgvector RAG corpus (P1) |
| `offline_sync_queue` | Server mirror for telemetry (not write path) |

### 4.2 Row Level Security (RLS) — exact

RLS enabled on **every** table. `auth.uid()` is the only identity source.

| Table | Select Policy | Insert Policy | Update Policy | Delete Policy |
|-------|---------------|---------------|---------------|---------------|
| `profiles` | `id = auth.uid() OR is_admin()` | None (via `complete_signup` RPC only) | `id = auth.uid()` | None |
| `advocates` | `profile_id = auth.uid() OR is_admin()` | None | `profile_id = auth.uid() OR is_admin()` | None |
| `sos_requests` | `client_id = auth.uid() OR advocate_id = auth.uid() OR is_admin()` | `client_id = auth.uid()` | `client_id = auth.uid() AND status='open'` | None |
| `cases` | `client_id = auth.uid() OR advocate_id = auth.uid() OR is_admin()` | `client_id = auth.uid()` | `advocate_id = auth.uid() OR is_admin()` | None |
| `hearings` | `published_at IS NOT NULL AND client is party` | Advocate writes own case | Advocate own case | None |
| `ai_summaries` | `state='published' AND client is party` | None | Advocate own case | None |
| `invoices` | `advocate_id = auth.uid() OR client_id = auth.uid() OR is_admin()` | Advocate own | Advocate own | None |
| `invoice_items` | Party of invoice | None (`with check (true)` — known gap) | Party of invoice | Cascade via invoices |
| `consents` | `client_id = auth.uid()` | `client_id = auth.uid()` | `client_id = auth.uid()` | None |
| `documents` | Case parties + `deleted_at IS NULL` | `uploaded_by = auth.uid()` | `uploaded_by = auth.uid()` | None |
| `checklist_items` | Client own case | None | Advocate own case; client upload transition | None |
| `audit_logs` | `is_admin()` | None | None | None |
| `notifications` | `user_id = auth.uid()` | `user_id = auth.uid()` | `user_id = auth.uid()` | None |

### 4.3 Helper Functions (security definer) — exact

| Function | SQL | Purpose |
|----------|-----|---------|
| `is_admin()` | `language sql stable security definer set search_path = public as $$ select exists (select 1 from profiles where id = auth.uid() and role = 'admin'); $$;` | Returns true if `profiles.role = 'admin'` |
| `is_verified_advocate()` | `language sql stable security definer set search_path = public as $$ select exists (select 1 from advocates where profile_id = auth.uid() and verification = 'verified'); $$;` | Returns true if advocate `verification = 'verified'` |
| `has_case_access(p_case_id uuid)` | `language sql stable security definer set search_path = public as $$ select exists (select 1 from cases c where c.id = p_case_id and (c.client_id = auth.uid() or c.advocate_id = auth.uid())) or is_admin(); $$;` | Returns true if caller is case party or admin |
| `set_updated_at()` | `language plpgsql as $$ begin new.updated_at := now(); return new; end; $$;` | Trigger maintains `updated_at` on every mutable table |

### 4.4 Atomic RPCs — exact signatures

| RPC | Signature | Purpose |
|-----|-----------|---------|
| `complete_signup` | `(p_role user_role, p_full_name text, p_language text)` | Only insert path into `profiles`; copies role into JWT `app_metadata` |
| `submit_verification` | — | Advocate verification submission |
| `admin_decide` | `(p_advocate_id uuid, p_decision text, p_rejection_reason text)` | Approve/reject advocate; audit trail |
| `accept_sos` | `(p_sos_id uuid) returns sos_requests` | Row-locked single accept; returns `NULL` if race lost |
| `create_case_from_sos` | `(p_sos_id uuid) returns uuid` | Creates case row + clones checklist templates |
| `submit_triage` | `(p_input jsonb) returns ai_triage_sessions` | Records triage session; enforces 10/24h rate limit |
| `publish_ai_summary` | `(p_summary_id uuid, p_pin text, p_final_bn text) returns ai_summaries` | PIN-gated publish; draft->published |
| `admin_force_publish` | `(p_summary_id uuid, p_reason text)` | Admin override publish; requires non-empty reason |
| `next_invoice_no` | `(p_advocate uuid) returns text` | `INV-{YEAR}-{SEQ}` per advocate, reset Jan 1 |
| `advocate_search` | `(p_type text, p_district text, p_court text, p_max_fee numeric, p_lang text)` | Ranked search over verified advocates |
| `request_update` | `(p_case_id uuid)` | Client requests advocate update; deduped 1/24h |
| `expire_drafts` | — | Cron: drafts older than 7 days -> archived |
| `expire_sos` | — | Cron: open SOS older than 24h -> expired |

---

## 5. AI / Integration Tier (C3 / C11 / C12)

### 5.1 Cloudflare Worker (llm-gateway) — exact routes

| Route | Method | Purpose |
|-------|--------|---------|
| `/v1/ai/triage` | POST | Case-type triage + checklist personalization |
| `/v1/ai/summarize` | POST | Plain-Bangla case summary draft |
| `/v1/ai/chat` | POST | P1 RAG chatbot over Bangladesh legal acts |
| `/v1/ai/health` | GET | Provider reachability (`local` \| `huggingface`) |
| `/v1/invoice/pdf` | POST | Server-side rendered signed invoice PDF URL (15-min expiry) |
| `/v1/rate/check` | POST | Rate-limit pre-flight (`sos`, `triage`, `pin`, etc.) |

### 5.2 Worker Pipeline (exact sequence)

```
request
  -> [1] JWT verify (JWKS cached 1 h)
  -> [2] rate limit key = uid:action (KV counter, sliding window)
  -> [3] body schema validate (Zod)
  -> [4] PII redaction:
         NID: /\b\d{10,17}\b/ -> [NID]
         BD phone: /\+?8801\d{9}/ -> [PHONE]
         names: from payload name list
         -> keep local map to re-hydrate placeholders in response
  -> [5] KV cache lookup (sha256 of model+prompt_version+redacted input; TTL 24 h)
  -> [6] provider call:
         AI_PROVIDER=huggingface -> router.huggingface.co/v1/chat/completions
         AI_PROVIDER=local      -> http://localhost:8080/v1/chat/completions
  -> [7] JSON schema validation of model output
  -> [8] re-hydrate placeholders
  -> response + logging to Supabase (service role)
```

### 5.3 Model Contracts — exact

| Feature | Model (cloud) | Model (local) | Temp | Output |
|---------|---------------|---------------|------|--------|
| Triage | Qwen 2.5-7B | Qwen 2.5-3B | ≤ 0.2 | Strict JSON (`response_format: json_object`) |
| Summarize | Qwen 2.5-7B | Qwen 2.5-3B | ≤ 0.2 | Strict JSON (`response_format: json_object`) |
| Chat (P1) | Qwen 2.5-7B | Qwen 2.5-3B | ≤ 0.3 | JSON with sources + disclaimer |

### 5.4 AI Guardrails — exact

- No legal advice ever; mandatory disclaimer on every AI surface.
- HITL: summaries remain `draft` until advocate PIN publish; clients cannot read drafts (RLS enforced).
- PII redacted before LLM calls; input hash stored, not raw.
- Fallback: `TemplateAIService` rule-based output when LLM fails/times out (>30 s).
- KV cache: deterministic responses keyed by input hash; 24 h TTL.

---

## 6. Synchronization Layer (Offline-First) — exact

### 6.1 Principles

| # | Principle | Rule |
|---|-----------|------|
| P1 | **Single source of truth** | Supabase Postgres is authoritative. Hive is cache + offline queue only, never authoritative |
| P2 | **Optimistic local update first** | UI updates instantly from Hive, then syncs to Supabase in background |
| P3 | **Writes queue in outbox FIFO** | Replayed in order on reconnect |
| P4 | **SOS accept is realtime-only** | Never enqueued in outbox; `accept_sos` calls RPC live |
| P5 | **Fail loud, fail safe** | Conflicts, RLS rejections, quota breaches surface to user; never silent data loss |

### 6.2 Outbox Record Schema (Hive box `outbox`) — exact JSON

```json
{
  "id": "uuid",
  "op": "insert|update|delete",
  "target": "table_name",
  "payload": { ... },
  "client_ts": "2026-10-27T09:15:00Z",
  "base_version": 3,
  "attempts": 0,
  "status": "pending"
}
```

| Field | Type | Purpose |
|-------|------|---------|
| `id` | String | Unique outbox record id |
| `op` | String | `insert`, `update`, or `delete` |
| `target` | String | Target table name |
| `payload` | Map | Row data to write |
| `client_ts` | String | ISO-8601 client timestamp |
| `base_version` | int | Version at time of queue (for optimistic locking) |
| `attempts` | int | Sync attempt counter (max 5) |
| `status` | String | `pending`, `synced`, `failed`, `conflict` |

### 6.3 Queue Limits — exact

| Threshold | UI Signal | Behavior |
|-----------|-----------|----------|
| 0–49 ops | `Synced` chip (stone) | Normal sync |
| 50 ops | Brass-wash inline banner: "সংযোগ দুর্বল — পরিবর্তনগুলো পরে সিংক হবে।" | Changes queue; sync when online |
| 100 ops | Burgundy-wash banner: "অপেক্ষারতার সীমা পূর্ণ। সংযোগ ফিরে আসলে আবার চেষ্টা করুন।" | New writes blocked |

### 6.4 Retry Policy — exact

| Attempt | Backoff | Max Attempts |
|---------|---------|--------------|
| 1 | 2 s | 5 |
| 2 | 8 s | |
| 3 | 32 s | |
| 4–5 | exponential | |

After 5 failed attempts → record marked `failed` with user-visible retry button.

### 6.5 Merge Rules — exact

| Field Type | Merge Rule |
|------------|------------|
| Normal text / numeric | Last-write-wins by `updated_at` |
| Critical (consent, payment, PIN publish) | Version-based optimistic locking; stale write rejected -> conflict sheet |
| JSONB | Full replacement (no deep merge) |
| Deletes | Tombstone -> soft delete (`deleted_at`) after server-side permission re-check |

### 6.6 UI Conflict Resolution Sheet — exact

| Element | Specification |
|---------|---------------|
| Title | `পরিবর্তনের সংঘর্ষ (Conflict)` |
| Body | Plain Bangla explanation of which side is newer |
| Button 1 | `আমার সংস্করণ রাখুন (Keep mine)` |
| Button 2 | `তাদের সংস্করণ নিন (Use theirs)` |
| Behavior | Never silent overwrite; consent revocation always wins over in-flight advocate write |

### 6.7 Realtime Channels — exact

| Channel | Source Filter |
|---------|---------------|
| `case:{case_id}` | `postgres_changes` on `cases`, `hearings`, `ai_summaries`, `checklist_items`, `documents` filtered by `case_id` |
| `sos:{district}` | INSERT + UPDATE on `sos_requests` filtered by `district` |
| `inbox:{user_id}` | INSERT on `notifications` filtered by `user_id` |
| `admin:{queue}` | INSERT on `advocates` (verification=pending), `audit_logs` (flagged), complaints |

**Rule:** Subscription key must be a stable string derived deterministically from identifiers (sorted districts joined). `List` identity keys are forbidden.

---

## 7. Security Layers — exact

| Layer | Implementation |
|-------|----------------|
| L1 Transport | TLS 1.3 everywhere; WSS for Realtime; HSTS on Pages |
| L2 Authentication | Supabase phone OTP; JWT 15-min access / 7-day refresh; `role` in `app_metadata` |
| L3 Authorization | RLS on all tables + security-definer RPCs + storage policies |
| L4 Encryption | AES-256 at rest (Supabase); pgcrypto for PIN hashing; 15-min signed URLs |
| L5 Audit | Append-only `audit_logs`; no INSERT/UPDATE/DELETE API policy |

---

## 8. Non-Functional Budgets — exact

| Metric | Target |
|--------|--------|
| APK size | < 50 MB |
| Cold start | < 3 s on 2 GB Android |
| FCP (3G) | < 2 s |
| PostgREST read p95 | < 500 ms |
| Advocate search p95 | < 100 ms |
| Realtime latency | < 1 s |
| AI triage p95 | < 8 s |
| Sync per queued item | < 2 s on 3G |
