# LegalLink — API Contracts

**Version:** 1.0  
**Date:** October 2026  
**Source:** `docs/trd.md` §6; `docs/prd.md` §13; `docs/database_schema.md` §4  
**Stack:** Supabase PostgREST · Cloudflare Workers (Hono + Zod) · Flutter `supabase_flutter` · Flutter `http`/`dio`  
**Determinism:** All URLs, headers, status codes, JSON schemas, error codes, and rate limits are exact; no probabilistic language.

---

## 1. Conventions — exact

| Item | Rule |
|------|------|
| Base URL (Data) | `https://<project>.supabase.co/rest/v1` |
| Base URL (Auth) | `https://<project>.supabase.co/auth/v1` |
| Base URL (Realtime) | `wss://<project>.supabase.co/realtime/v1` |
| Base URL (Worker) | `https://api.legallink.bd/v1` (Cloudflare Worker) |
| Auth header | `Authorization: Bearer <jwt>` on every call |
| Content type | `application/json` (Worker accepts `multipart/form-data` for PDF/upload helpers) |
| JSON keys | `snake_case` matching DB columns — no translation layer |
| Timestamps | ISO-8601 UTC (`2026-03-12T09:15:00Z`). UI converts to Asia/Dhaka |
| Money | Serialized as string with 2 decimals (`"15000.00"`) — no floats |
| Pagination | PostgREST `Range` header + `Prefer: count=exact`; default page 20, max 100. Worker uses `limit`/`cursor` |
| Idempotency | Mutating Worker calls accept `Idempotency-Key` header |
| Error envelope | `{"error": {"code": "...", "message": "...", "message_bn": "...", "retryable": bool, "request_id": "..."}}` |

---

## 2. Authentication API (Supabase Auth) — exact

| Operation | Method | Endpoint | Request Body | Response | Notes |
|-----------|--------|----------|--------------|----------|-------|
| Request OTP | POST | `/auth/v1/otp` | `{"phone": "+8801XXXXXXXXX"}` | `{}` | Rate limit 3 / 5 min / phone. Supports email OTP fallback |
| Verify OTP | POST | `/auth/v1/verify` | `{"phone": "...", "token": "123456", "type": "sms"}` | `{access_token, refresh_token, user}` | Returns JWT (15 min access / 7 day refresh) |
| Refresh session | POST | `/auth/v1/token?grant_type=refresh_token` | `{"refresh_token": "..."}` | `{access_token, refresh_token}` | Silent refresh handled by `supabase_flutter` |
| Sign out | POST | `/auth/v1/logout` | — | `{}` | Revokes refresh token |
| Current user | GET | `/auth/v1/user` | — | `{id, role, app_metadata, ...}` | Used on boot to hydrate role |

**JWT payload (decoded) — exact:**
```json
{
  "sub": "b1c2...uuid",
  "role": "authenticated",
  "app_metadata": {"role": "advocate"},
  "exp": 1770000000,
  "iat": 1769999100
}
```

**Role claim:** After first successful verify, app calls `POST /rest/v1/rpc/complete_signup` with `{p_role, p_full_name, p_language}` which writes `profiles` and copies `role` into `app_metadata` so RLS helpers and JWT agree.

---

## 3. Data API — Endpoint Catalog (PostgREST) — exact

Calls expressed as resource + filter; map 1:1 to `supabase_flutter` queries.

### 3.1 F1 Onboarding

| Purpose | Method | Endpoint | Request Body | Notes |
|---------|--------|----------|--------------|-------|
| Create / refresh profile | POST | `/rest/v1/rpc/complete_signup` | `{"p_role": "client", "p_full_name": "...", "p_language": "bn"}` | Only insert path into `profiles` |
| Read own profile | GET | `/rest/v1/profiles?select=*&id=eq.{uid}` | — | — |
| Update language | PATCH | `/rest/v1/profiles?id=eq.{uid}` | `{"language": "bn"}` | — |

### 3.2 F2 Advocate Profile & Verification

| Purpose | Method | Endpoint | Request Body | Notes |
|---------|--------|----------|--------------|-------|
| Create advocate profile | POST | `/rest/v1/advocates` | `{"profile_id": "...", "bar_council_no": "...", ...}` | — |
| Upload Sanad | POST | `/storage/v1/object/sanad/{uid}/sanad.jpg` | binary file | Then `PATCH /advocates` with `sanad_url` |
| Read own verification state | GET | `/rest/v1/advocates?select=verification,rejection_reason,attempts&profile_id=eq.{uid}` | — | — |
| Public verified list | GET | `/rest/v1/advocate_public?select=*&limit=20` | — | View only; excludes phone/nid/pin_hash |
| Search advocates | POST | `/rest/v1/rpc/advocate_search` | `{"p_type": "...", "p_district": "...", ...}` | Ranked over verified projection |
| Admin: verification queue | GET | `/rest/v1/advocates?verification=eq.pending&order=created_at.asc` | — | Admin only |
| Admin: approve | PATCH | `/rest/v1/advocates?profile_id=eq.{uid}` | `{"verification": "verified", "verified_at": "now()"}` | Admin only |
| Admin: reject | PATCH | `/rest/v1/advocates?profile_id=eq.{uid}` | `{"verification": "rejected", "rejection_reason": "..."}` | Admin only |

### 3.3 F3 SOS

| Purpose | Method | Endpoint | Request Body | Notes |
|---------|--------|----------|--------------|-------|
| Post SOS | POST | `/rest/v1/sos_requests` | `{"person_name": "...", "thana": "...", "district": "...", "court": "...", "charges": "...", "contact_phone": "...", "urgency": "..."}` | Client only |
| Open SOS feed (advocate) | GET | `/rest/v1/sos_requests?status=eq.open&district=in.(...Dhaka...*)&order=created_at.desc` | — | Verified advocates in district |
| Accept SOS (atomic) | POST | `/rest/v1/rpc/accept_sos` | `{"p_sos_id": "uuid"}` | Returns `null` if race lost |
| Cancel SOS | PATCH | `/rest/v1/sos_requests?id=eq.{id}&status=eq.open` | `{"status": "cancelled"}` | Client only |
| My SOS history | GET | `/rest/v1/sos_requests?client_id=eq.{uid}&order=created_at.desc` | — | — |

### 3.4 F4 Triage + Checklist

| Purpose | Method | Endpoint | Request Body | Notes |
|---------|--------|----------|--------------|-------|
| Run AI triage | POST | `/rest/v1/rpc/submit_triage` | `{"p_input": {...answers}}` | Enforces 10/24h rate limit |
| Read checklist | GET | `/rest/v1/checklist_items?case_id=eq.{id}&order=importance.desc` | — | — |
| Advocate approve item | PATCH | `/rest/v1/checklist_items?id=eq.{id}` | `{"status": "approved", "approved_at": "now()"}` | Advocate own case |
| Advocate reject item | PATCH | `/rest/v1/checklist_items?id=eq.{id}` | `{"status": "rejected", "reject_reason": "..."}` | Advocate own case |
| Client mark uploaded | PATCH | `/rest/v1/checklist_items?id=eq.{id}` | `{"status": "uploaded"}` | Client upload transition only |
| Templates (admin) | GET | `/rest/v1/checklist_templates?active=is.true&order=sort_order` | — | Admin managed |

### 3.5 F5 Case Timeline

| Purpose | Method | Endpoint | Request Body | Notes |
|---------|--------|----------|--------------|-------|
| Create case manually | POST | `/rest/v1/cases` | `{"case_type": "bail", "client_id": "...", ...}` | — |
| My cases (client) | GET | `/rest/v1/cases?client_id=eq.{uid}&state=in.(created,active)` | — | — |
| My cases (advocate) | GET | `/rest/v1/cases?advocate_id=eq.{uid}&order=updated_at.desc` | — | — |
| Case detail | GET | `/rest/v1/cases?select=*,hearings(*),checklist_items(*),ai_summaries(*)&id=eq.{id}` | — | — |
| Add hearing | POST | `/rest/v1/hearings` | `{"case_id": "...", "hearing_date": "...", "court": "...", "outcome_notes": "...", "published_at": null}` | Advocate writes own case |
| Publish hearing to client | PATCH | `/rest/v1/hearings?id=eq.{id}` | `{"published_at": "now()"}` | Advocate own case |
| Amend published hearing | POST | `/rest/v1/hearings` | `{"case_id": "...", "supersedes_id": "...", "is_amended": true, ...}` | Never UPDATE published row |
| Timeline feed | GET | `/rest/v1/hearings?case_id=eq.{id}&published_at=not.is.null&order=hearing_date.desc` | — | Client sees published only |
| Sign consent | POST | `/rest/v1/consents` | `{"case_id": "...", "advocate_id": "...", "scope": ["case_data"]}` | Client grant |
| Revoke consent | PATCH | `/rest/v1/consents?id=eq.{id}` | `{"revoked_at": "now()", "version": <current+1>}` | Client revoke |

### 3.6 F6 AI Summary (HITL)

| Purpose | Method | Endpoint | Request Body | Notes |
|---------|--------|----------|--------------|-------|
| Generate draft | POST | `/v1/ai/summarize` (Worker) | `{"raw_notes": "...", "case_type": "bail", "language": "bn"}` | Returns `{draft_bn, model, prompt_version, tokens}` |
| Persist draft | POST | `/rest/v1/ai_summaries` | `{"case_id": "...", "hearing_id": "...", "raw_input": "...", "draft_bn": "...", "state": "draft"}` | Advocate scoped RLS |
| Read my drafts (advocate) | GET | `/rest/v1/ai_summaries?case_id=eq.{id}&state=eq.draft` | — | — |
| Publish with PIN | POST | `/rest/v1/rpc/publish_ai_summary` | `{"p_summary_id": "...", "p_pin": "1234", "p_final_bn": "..."}` | PIN-gated |
| Client reads published | GET | `/rest/v1/ai_summaries?case_id=eq.{id}&state=eq.published` | — | RLS enforces filter anyway |
| Client requests update | POST | `/rest/v1/rpc/request_update` | `{"p_case_id": "..."}` | Deduped 1 / 24 h |
| Admin force-publish | POST | `/rest/v1/rpc/admin_force_publish` | `{"p_summary_id": "...", "p_reason": "..."}` | Admin only |

### 3.7 F7 Invoices

| Purpose | Method | Endpoint | Request Body | Notes |
|---------|--------|----------|--------------|-------|
| Create invoice | POST | `/rest/v1/rpc/create_invoice` | `{"p_case_id": "...", "p_items": [{"description": "...", "amount_bdt": "15000.00"}], "p_due_date": "..."}` | — |
| List invoices | GET | `/rest/v1/invoices?select=*,invoice_items(*)&case_id=eq.{id}&order=created_at.desc` | — | — |
| Record payment | POST | `/rest/v1/payments` | `{"invoice_id": "...", "amount_bdt": "5000.00", "method": "bkash", "txn_id": "..."}` | — |
| Send invoice | PATCH | `/rest/v1/invoices?id=eq.{id}` | `{"state": "sent"}` | — |
| Render PDF | POST | `/v1/invoice/pdf` | `{"invoice_id": "uuid"}` | Returns `{url, expires_in}` |

### 3.8 F8 Sync Support

| Purpose | Method | Endpoint | Notes |
|---------|--------|----------|-------|
| Delta pull on reconnect | GET | `/rest/v1/{table}?updated_at=gt.{last_sync_ts}` | Per subscribed table |
| Push queued op | POST/PATCH/DELETE | `/rest/v1/{table}` | Per op in FIFO order from outbox |
| Report queue telemetry | POST | `/rest/v1/offline_sync_queue` | Batch telemetry |

### 3.9 Notifications

| Purpose | Method | Endpoint | Request Body | Notes |
|---------|--------|----------|--------------|-------|
| In-app inbox | GET | `/rest/v1/notifications?user_id=eq.{uid}&order=created_at.desc&limit=50` | — | — |
| Mark read | PATCH | `/rest/v1/notifications?id=eq.{id}` | `{"read_at": "now()"}` | — |
| Register FCM token | PATCH | `/rest/v1/profiles?id=eq.{uid}` | `{"fcm_token": "...", "fcm_updated_at": "now()"}` | On app start + token refresh |

---

## 4. Cloudflare Worker API (`POST /v1/*`) — exact

Every route: JWT required → verify with Supabase JWKS → rate limit (KV) → PII redact → act → log.

### 4.1 Route Catalog — exact

| Route | Method | Request Body | Response | Notes |
|-------|--------|--------------|----------|-------|
| `/v1/ai/triage` | POST | `{"answers": {...}, "case_type": "bail"}` | `{case_type, urgency, overview_bn, actions_bn[], checklist[], disclaimer_bn, model, prompt_version, cached}` | Rule-based template merged with AI suggestions; template-only on AI failure |
| `/v1/ai/summarize` | POST | `{"raw_notes": "...", "case_type": "bail", "language": "bn"}` | `{draft_bn, model, prompt_version, tokens, fallback_used}` | JSON mode, temperature 0.2, 30 s timeout |
| `/v1/ai/chat` | POST | `{"question_bn": "..."}` | `{answer_bn, sources[], disclaimer_bn}` | RAG; no chunk found → `answer_bn` = "consult an advocate" |
| `/v1/ai/health` | GET | — | `{provider: "huggingface\|local", reachable: bool, latency_ms}` | App health badge |
| `/v1/invoice/pdf` | POST | `{"invoice_id": "uuid"}` | `{url, expires_in}` | Reads invoice via service role after verifying caller is a party |
| `/v1/rate/check` | POST | `{"action": "sos\|triage\|pin\|..."}` | `{allowed, remaining, reset_at}` | Shared limiter used by app for pre-flight UX |

### 4.2 Worker Pipeline — exact sequence

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

### 4.3 Triage Output Schema — exact JSON (`response_format: json_object`)

```json
{
  "case_type": "bail",
  "urgency": "high",
  "overview_bn": "গ্রেপ্তারের পর জামিনের জন্য আবেদন করতে হবে...",
  "actions_bn": ["থানা থেকে এফআইআর কপি নিন", "..."],
  "checklist": [
    {"template_id": "uuid-or-null", "item_name_bn": "এফআইআর কপি", "importance": "high", "reason_bn": "মামলার মূল দলিল"}
  ],
  "questions_to_ask_lawyer_bn": ["..."],
  "disclaimer_bn": "এটি সাধারণ তথ্য, আইনি পরামর্শ নয়।"
}
```

**Worker-enforced rules on response — exact:**
1. Every `checklist[].item_name_bn` must exist in the admin template set for that case type (or be explicitly marked `ai_extra: true`). Anything else is dropped — the AI cannot invent a document list.
2. `importance` must be one of `high\|medium\|low`.
3. `disclaimer_bn` must be present, non-empty; if missing the Worker injects the canonical string.
4. Max 15 checklist items, max 5 actions.

### 4.4 Summary Output Schema — exact JSON

```json
{
  "summary_bn": "১২ মার্চের শুনানিতে জামিনের আবেদন ... পরে তারিখ ২০ মার্চ।",
  "next_hearing_date": "2026-03-20",
  "events": ["জামিন আবেদন দাখিল", "বিপক্ষ সময় চেয়েছে"],
  "disclaimer_bn": "এটি আপনার আইনজীবীর অনুমোদন সাপেক্ষ।"
}
```

**Prohibited patterns** (blocked by post-filter): any prediction wording (`জামিন পাবেন`, `হেরে যাবেন`), any explicit advice (`আপনার করা উচিত` outside procedural steps), any monetary guarantee. On match → draft regenerated once; on second match → template fallback + `flagged=true` for admin review.

---

## 5. Rate Limits — exact (PRD §13)

| Action | Key | Window | Limit | Enforced At |
|--------|-----|--------|-------|-------------|
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

---

## 6. Error Payloads — exact

### 6.1 Worker Error Envelope

```json
{
  "error": {
    "code": "AI_UNAVAILABLE",
    "message": "AI is busy",
    "message_bn": "AI এখন ব্যস্ত",
    "retryable": true,
    "request_id": "..."
  }
}
```

### 6.2 PostgREST / RPC Errors — exact mapping in client to Bangla

| Code | Source | Client Behavior |
|------|--------|-----------------|
| `not_verified_advocate` | `accept_sos` | "Your account is not verified yet." |
| `sos_already_taken` (null result) | `accept_sos` | "Another advocate already accepted this SOS." |
| `rate_limited` | Worker / RPC | Show remaining time from `reset_at` |
| `invalid_pin` (NULL return) | `publish_ai_summary` | Wrong PIN: RPC returns NULL and counter commits; show attempts-left read from advocate's own row; lock after 5 |
| `pin_locked` | `publish_ai_summary` | Show lock expiry time |
| `draft_expired` | `publish_ai_summary` | "This draft expired. Generate a new summary." |
| `conflict_stale_version` | consent / invoice / publish writes | Show conflict sheet → "reload and reapply" |
| `rls_denied` (42501) | any | Never silent: show "you do not have access" + log |
| `quota_exceeded` | Worker | Fall back to template output where applicable |

---

## 7. API Security Checklist — exact

- JWT verified on every Worker route via cached JWKS (no shared secrets in the client).
- Service-role key exists **only** in Edge Functions and Worker environment — never in Flutter app.
- CORS: Worker allows only `https://legallink.bd` and `localhost:*` origins.
- All Storage reads go through 15-minute signed URLs.
- All writes go through RLS or security-definer RPCs that re-check the caller.
- `audit_logs` is not writable through the API at all (no INSERT policy).
