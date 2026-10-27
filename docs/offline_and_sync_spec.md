# LegalLink — Offline & Sync Specification

**Version:** 1.0  
**Date:** October 2026  
**Source:** `docs/trd.md` §8.4, `docs/prd.md` §F8, `docs/architecture_blueprint.md` §6  
**Stack:** Flutter · Riverpod · Hive · Supabase Postgres + Realtime  
**Determinism:** All schemas, limits, timeouts, and UI states are exact; no probabilistic language.

---

## 1. Principles — exact

| # | Principle | Rule |
|---|-----------|------|
| P1 | **Single source of truth** | Supabase Postgres is authoritative. Hive is cache + offline queue only, never authoritative |
| P2 | **Optimistic local update first** | UI updates instantly from Hive, then syncs to Supabase in background |
| P3 | **Writes queue in outbox FIFO** | Replayed in order on reconnect |
| P4 | **SOS accept is realtime-only** | Never enqueued in outbox; `accept_sos` calls RPC live |
| P5 | **Fail loud, fail safe** | Conflicts, RLS rejections, quota breaches surface to user; never silent data loss |

---

## 2. Local Storage (Hive) — exact

### 2.1 Boxes

| Box | Purpose | TTL / Eviction |
|-----|---------|----------------|
| `auth_box` | Auth session, phone, role, language, profile-completed flag | Until sign-out |
| `outbox` | Pending mutation queue (FIFO) | Until synced |
| `cache_box` | Cached cases, hearings, checklists, documents, summaries, notifications | Until replaced by realtime update or delta pull |

### 2.2 Outbox Record Schema (Hive box `outbox`) — exact JSON

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

---

## 3. Sync Worker — exact

### 3.1 Execution Model

```
UI action
  → Hive write (optimistic)
  → Outbox enqueue
  → Sync worker (FIFO, connectivity-triggered)
    → normal field: last-write-wins (updated_at)
    → critical: version check → conflict state
    → delete: tombstone → soft delete server
    → file: resume chunk upload
```

### 3.2 Queue Limits — exact

| Threshold | UI Signal | Behavior |
|-----------|-----------|----------|
| 0–49 ops | `Synced` chip (stone) | Normal sync |
| 50 ops | Brass-wash inline banner: "সংযোগ দুর্বল — পরিবর্তনগুলো পরে সিংক হবে।" | Changes queue; sync when online |
| 100 ops | Burgundy-wash banner: "অপেক্ষারতার সীমা পূর্ণ। সংযোগ ফিরে আসলে আবার চেষ্টা করুন।" | New writes blocked |

### 3.3 Retry Policy — exact

| Attempt | Backoff | Max Attempts |
|---------|---------|--------------|
| 1 | 2 s | 5 |
| 2 | 8 s | |
| 3 | 32 s | |
| 4–5 | exponential | |

After 5 failed attempts → record marked `failed` with user-visible retry button.

### 3.4 FIFO Ordering — exact

- Sort by `client_ts` ascending.
- Dependencies respected by target order (case before hearing before checklist item).
- Per-entity ordering preserved.

---

## 4. Merge Rules — exact

| Field Type | Merge Rule | Implementation |
|------------|------------|----------------|
| Normal text / numeric | Last-write-wins by `updated_at` | Client sends `updated_at`; server applies if newer |
| Critical (consent, payment, PIN publish) | Version-based optimistic locking | Stale write rejected → conflict sheet |
| JSONB | Full replacement (no deep merge) | All JSONB fields are AI outputs or form payloads regenerated as whole |
| Deletes | Tombstone → soft delete (`deleted_at`) | After server-side re-check of permissions |

---

## 5. Conflict Resolution — exact

### 5.1 Conflict Detection

- Server write returns `conflict_stale_version` when base version mismatches current server version.
- Item marked `conflict` in outbox.
- UI shows both versions side by side.

### 5.2 UI Conflict Resolution Sheet — exact

| Element | Specification |
|---------|---------------|
| Title | `পরিবর্তনের সংঘর্ষ (Conflict)` |
| Body | Plain Bangla explanation of which side is newer |
| Button 1 | `আমার সংস্করণ রাখুন (Keep mine)` |
| Button 2 | `তাদের সংস্করণ নিন (Use theirs)` |
| Behavior | Never silent overwrite; consent revocation always wins over in-flight advocate write |

### 5.3 Special Conflict Rules — exact

- **Consent revocation wins:** On receiving a revocation, drop queued advocate writes for that case.
- **File uploads:** Row written with `local_ref` immediately; bytes uploaded on connectivity; then `storage_path` + status update.
- **Mid-upload interruption:** Resumable upload from last chunk; never leaves corrupt file.

---

## 6. UI Sync Indicator — exact

Persistent chip, bottom-left above navigation:

| State | Visual | Text |
|-------|--------|------|
| Offline | Stone, dashed border, `⛌` glyph | `অফলাইন (N pending)` |
| Syncing | Brass arc, animated, `◐` | `সিংক হচ্ছে… (Syncing)` |
| Synced | Stone, fades after 3 s | `সব সংরক্ষিত (All changes saved)` |

Announced via polite live region (`aria-live="polite"`).

---

## 7. Realtime + Delta Pull — exact

| Event | Action |
|-------|--------|
| Screen mount | Subscribe to Realtime channel (`case:{id}`, `sos:{district}`, `inbox:{user_id}`, `admin:{queue}`) |
| Screen unmount | Unsubscribe |
| App resume | Re-subscribe + delta fetch (`updated_at > last_sync_ts`) |
| Auth change | Unsubscribe all, clear Hive token-sensitive caches |

### 7.1 Realtime Channels — exact

| Channel | Source Filter |
|---------|---------------|
| `case:{case_id}` | `postgres_changes` on `cases`, `hearings`, `ai_summaries`, `checklist_items`, `documents` filtered by `case_id` |
| `sos:{district}` | INSERT + UPDATE on `sos_requests` filtered by `district` |
| `inbox:{user_id}` | INSERT on `notifications` filtered by `user_id` |
| `admin:{queue}` | INSERT on `advocates` (verification=pending), `audit_logs` (flagged), complaints |

**Rule:** Subscription key must be a stable string derived deterministically from identifiers (sorted districts joined). `List` identity keys are forbidden.

---

## 8. Offline Read Flows — exact

| Flow | Behavior |
|------|----------|
| Timeline | Renders from Hive cache with `শেষ আপডেট 2 মিনিট আগে (Last updated 2 min ago)` in `stone-text` |
| Checklists | Renders from Hive cache |
| Invoices | Renders from Hive cache |
| Documents | Renders from Hive cache |
| Writes | Queue silently, show `N পরিবর্তন অপেক্ষায় (N changes waiting)` |

### 8.1 Per-Item Pending Marker — exact

- Any locally created item shows dashed-stone `অপেক্ষায় (Queued)` chip.
- Files show `আপলোড হচ্ছে — শুধু এই ডিভাইসে (Uploading — this device only)`.

---

## 9. Offline SOS — exact

- Never silently dropped.
- Queued with clear `queued` banner.
- Explicit nudge to call 109.
- UI never claims a broadcast that has not left the device.

---

## 10. Synchronization Checklist — exact implementation

- [ ] All colours from §1.1 token set in sync UI (brass-wash banner, burgundy-wash banner, stone dashed border)
- [ ] `MinTapTarget` ≥ 48×48 dp on sync buttons
- [ ] Bangla strings in ARB files (`lib/l10n/`), never hardcoded
- [ ] `accept_sos` realtime-only; never enqueued in outbox (ADR-016)
- [ ] Outbox cap enforced at 100; warning at 50
- [ ] Conflict sheet renders both versions with explicit user choice
- [ ] Consent revocation drops queued advocate writes
- [ ] File uploads resume from last chunk
- [ ] Delta pull uses `updated_at > last_sync_ts`
- [ ] Channel names match TRD §6.5 exactly
- [ ] No generic circular spinners; use brass arc / loading metaphors per `ui_ux.md` §4.2
