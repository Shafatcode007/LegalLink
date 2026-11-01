# LegalLink — Remaining Task Report: Sprint 1 & Sprint 2

**Audit Date:** October 2026  
**Repository:** `D:\LegalLink` (GitHub: `Shafatcode007/LegalLink`)  
**Audited Branch:** `main` (HEAD: `f5fc98d fix(role-a): Sprint 2 completion (#21)`)  
**Source Docs:** `docs/sprint.md`, `docs/database_schema_and_rls.md`, `SHAFAT_tasks.md`, `AKIB_tasks.md`, `ALBIR_tasks.md`, `MEHEDI_tasks.md`

---

## 1. Executive Status Summary

| Role | Owner | Sprint 1 Done | Sprint 1 Remaining | Sprint 2 Done | Sprint 2 Remaining | Blockers |
|------|-------|--------------|-------------------|--------------|-------------------|----------|
| A — Backend & DB | Shafat | 1/1 | 0 | 7/7 | 0 | None |
| B1 — Client UI Auth & Onboarding | Akib | 5/5 | 0 | 3/3 | 0 | Low: Mock→real wiring |
| B2 — Client UI Admin & Shared | Albir | 3/3 | 0 | 4/4 | 0 | Medium: Silent mock fallback |
| C — AI/Integration & DevOps | Mehedi | 0/4 | 4 | 4/4 | 0 | High: 4 Sprint 1 infra items |
| D — Realtime SOS & Admin HITL | — | 0/0 | 0 | 3/6 | 3 | Missing: dispute views, HITL UI, realtime |

**All Role A Sprint 2 fixes are merged to `main` via PR #21 (squash commit `f5fc98d`).**

PR URL: `https://github.com/Shafatcode007/LegalLink/pull/21`

---

## 2. Role A — Backend & Database Lead (Shafat)

### Sprint 1 — All Complete

| Task ID | Task | Status | Evidence on `main` |
|---------|------|--------|-------------------|
| S1-R1 | RLS test assertions D-1 to D-14 | ✅ Done | `db/tests/rls_test.sql` (547 lines, D-1 through D-17 all present) |

### Sprint 2 — All Complete

| Task ID | Task | Status | Evidence on `main` |
|---------|------|--------|-------------------|
| S2-R1 | `submit_document` RPC + private buckets | ✅ Done | `db/migrations/20261020000001_rpc_sos_and_uploads.sql:35-70` |
| S2-R2 | `accept_sos` row locking | ✅ Done | `db/migrations/20261020000001:78-118`; `20261022000001:69-95` |
| S2-R3 | `sos_already_taken` invariant | ✅ Done | `db/migrations/20261020000001:99-101`; D-16 test |
| S2-R4 | 3-attempt re-apply cap in `admin_decide` | ✅ Done | `p_decision text`, `re_apply_cap_exceeded` pre-check, rejected-only increment |
| S2-R5 | Full RLS test coverage D-1 to D-17 | ✅ Done | `db/tests/rls_test.sql` (all 17 assertions) |
| S2-R6 | Storage INSERT WITH CHECK policies | ✅ Done | `db/migrations/20261020000001:130-165`; `20261001000009:48-52` |

### Role A — P0/P1 Tasks Completed

| Priority | Item | Action Taken | Evidence |
|----------|------|--------------|----------|
| P0 | Merge Sprint 2 to `main` | PR #21 squash-merged as commit `f5fc98d` | `git log main --oneline -1` shows `f5fc98d` |
| P0 | Fix `admin_decide` pre-check cap | `re_apply_cap_exceeded` raised when `attempts >= 3` | `db/migrations/20261023000001:132-139` |
| P0 | Fix `admin_decide` attempts increment | `attempts = case when v_decision = 'rejected' then attempts + 1 else attempts end` | `db/migrations/20261023000001:163` |
| P0 | Fix `admin_decide` type contract | `p_decision text` with internal cast `p_decision::verification_state` | `db/migrations/20261023000001:120,146` |
| P1 | Fix `submit_verification` signature | `p_profile_id uuid` first param; `p_sanad_url`, `p_nid_url` added | `db/migrations/20261023000002:29-40` |

### Verification Artifacts (Merged to `main`)

| Check | Result |
|-------|--------|
| Dual-folder SHA256 parity (26 files) | ✅ All identical |
| Conflict markers in `rls_test.sql` + migrations | ✅ None found |
| Docker drift-guard Pass 1 | ✅ `*** ALL HITL RLS TESTS PASSED ***` |
| Docker drift-guard Pass 2 | ✅ `*** ALL HITL RLS TESTS PASSED ***` |
| `admin_decide` pre-check cap | ✅ Present (`re_apply_cap_exceeded`) |
| `admin_decide` `p_decision text` type | ✅ Present with internal cast |
| `admin_decide` rejected-only increment | ✅ `case when rejected then +1 else end` |
| `submit_verification` contract params | ✅ `p_profile_id`, `p_sanad_url`, `p_nid_url` present |

---

## 3. Role B1 — Client UI: Auth & Onboarding (Akib)

### Sprint 1 — All Complete

| Task | Status | Evidence |
|------|--------|----------|
| Flutter Init (web + android) | ✅ Done | `apps/legal_link/` initialized |
| GoRouter auth shell with guards | ✅ Done | `apps/legal_link/lib/app/router.dart` |
| Design tokens + Bengali font | ✅ Done | `apps/legal_link/lib/app/theme.dart`; `assets/fonts/noto_sans_bengali/` |
| Phone → OTP → Role Selection screens | ✅ Done | `apps/legal_link/lib/features/auth/presentation/screens/` |
| Minimal Profile form | ✅ Done | `apps/legal_link/lib/features/onboarding/presentation/screens/minimal_profile_screen.dart` |

### Sprint 2 — All Complete

| Task | Status | Evidence |
|------|--------|----------|
| Advocate Registration form (NID, Bar Council, Sanad photo, courts, districts, specializations, fees) | ✅ Done | `apps/legal_link/lib/features/onboarding/presentation/screens/advocate_registration_screen.dart:1-452` |
| File upload UI (progress bars, error states) | ✅ Done | `apps/legal_link/lib/features/onboarding/data/supabase_credential_upload_repository.dart` |
| SOS 600ms hold-to-confirm button | ✅ Done | `apps/legal_link/lib/features/sos/presentation/widgets/hold_to_confirm_sos_button.dart:18` (holdDuration = 600ms) |

### Role B1 — Remaining Tasks

| Priority | Item | Notes |
|----------|------|-------|
| Low | Swap mock repositories for real Supabase calls | Mock repos exist as fallback; live mode wired via `AppConfig.useSupabaseAuth` flag |

---

## 4. Role B2 — Client UI: Admin & Shared Components (Albir)

### Sprint 1 — All Complete

| Task | Status | Evidence |
|------|--------|----------|
| Shared UI Library (VerifiedBadge, MinTapTarget, Buttons) | ✅ Done | `apps/legal_link/lib/shared/widgets/` |
| Admin Queue UI (mock data) | ✅ Done | `apps/legal_link/lib/features/admin/` |
| Advocate Profile View | ✅ Done | `apps/legal_link/lib/features/admin/presentation/screens/advocate_profile_view_screen.dart` |

### Sprint 2 — All Complete

| Task | Status | Evidence |
|------|--------|----------|
| Admin Document Review + signed URLs (15-min/900s) | ✅ Done | `apps/legal_link/lib/features/admin/data/sources/supabase_admin_data_source.dart:115-144` |
| Single Accept Flow UI (instant lock + "Case Created") | ✅ Done | `apps/legal_link/lib/features/sos/presentation/notifiers/sos_inbox_notifier.dart:108-160` |
| Losing Advocate UI ("This SOS is already taken") | ✅ Done | `apps/legal_link/lib/features/sos/presentation/widgets/sos_alert_card.dart:405-519` |
| SyncBadge + offline/queued states | ✅ Done | `apps/legal_link/lib/shared/widgets/sync_badge.dart` |

### Role B2 — Remaining Tasks

| Priority | Item | Notes |
|----------|------|-------|
| Medium | Eliminate silent mock fallback in admin data source | `SupabaseAdminDataSource.fetchAdvocates()` returns mock data on any error — masks backend/RLS failures |

---

## 5. Role C — AI/Integration & DevOps (Mehedi)

### Sprint 1 — Remaining Tasks (4 items)

| Task | Status | Gap |
|------|--------|-----|
| Local Auth Config: JWT `role` claim in `app_metadata` | ❌ Not Verified | Phone OTP test mode configured; JWT role claim not yet verified |
| Arch-Lint CI job enforcing `presentation -> domain <- data` | ❌ Not Enforcing | `.github/workflows/arch-lint.yml` exists; not yet enforcing in CI |
| AI Stub: `hf_server.py` boots and returns valid JSON | ❌ Not Verified | `ai/local_server/hf_server.py` exists (151 lines); not verified on port 8080 |
| Pages Pipeline: Flutter Web preview deploys on PR | ❌ Not Deploying | Pipeline created; Flutter Web preview URL not yet deploying on PR |

### Sprint 2 — All Complete

| Task | Status | Evidence |
|------|--------|----------|
| Storage Policies (sanad/documents, 15-min signed URLs) | ✅ Done | `db/migrations/20261001000009:36-64`; `20261020000001:130-165` |
| Realtime Basics (`sos:{district}` channel) | ✅ Done | `apps/legal_link/lib/features/sos/data/supabase_client_sos_repository.dart:137` |
| Rate Limits: Worker `/v1/rate/check` | ✅ Done | `edge/worker/src/routes/rate.ts:14`; `services/rate_limiter.ts:11-15` |
| Deploy Pipeline (`deploy-web.yml`, `deploy-worker.yml`) | ✅ Done | `.github/workflows/deploy-web.yml`; `.github/workflows/deploy-worker.yml` |

---

## 6. Role D — Realtime SOS Dispatch & Admin HITL Dashboard

### Sprint 2 — Remaining Tasks (3 items, missing from codebase)

| Task | Status | Gap Description |
|------|--------|-----------------|
| Admin dispute/review views | ❌ Missing | No dispute management screen or component found in `features/admin/` |
| Admin HITL PIN-publish screens | ❌ Missing | `publish_ai_summary` and `admin_force_publish` RPCs exist in schema but no admin UI screens |
| Realtime subscription in admin queue | ❌ Missing | Admin queue uses poll-only (`load()`/`refresh()`); no Supabase realtime subscription |

### Role D — Completed Items

| Item | Status | Evidence |
|------|--------|----------|
| Advocate SOS notification delivery | ✅ Done | Realtime `sos:{district}` + polling fallback |
| Concurrency feedback (losing advocate) | ✅ Done | "This SOS is already taken" UI state |
| Admin verification decision (approve/reject) | ✅ Done | `admin_verification_provider.dart:91-124` calls `admin_decide` RPC |

---

## 7. Iron Laws Compliance (Current `main` State)

| Law | Requirement | Assessment |
|-----|-------------|------------|
| #1 | Strict Schema Typing & Constraints | ❌ FAIL on `main` — `admin_decide.p_decision` is `verification_state` (contract says `text`) |
| #2 | RLS Enabled on All User Tables | ✅ PASS — All 16 tables have RLS |
| #3 | Security Definer & Search Path | ✅ PASS — All RPCs have `security definer set search_path = public` |
| #4 | Audit Logging on Privileged Actions | ✅ PASS — All mutating RPCs insert into `audit_logs` |
| #5 | Storage INSERT Policies WITH CHECK | ✅ PASS — All storage INSERT policies use `WITH CHECK` |
| #6 | Concurrency / Atomic Operations | ✅ PASS — `accept_sos` uses `UPDATE ... WHERE status = 'open'` |
| #7 | Dual-Folder Migration Parity | ✅ PASS — All 26 migrations byte-identical SHA256 |

**Note:** Law #1 fails on `main` due to the `admin_decide` type mismatch. The fix branch `role-a/sprint2-completion` resolves this by using `p_decision text` with internal cast to `verification_state`.

---

## 8. Prioritized Remediation List (Deterministic by Role)

### P0 — Blockers (before Sprint 2 close)

| # | Role | Item | Action |
|---|------|------|--------|
| P0-1 | A | Merge Sprint 2 to `main` | Create PR: `role-a/sprint2-completion` → `main` |
| P0-2 | A | `admin_decide` pre-check cap guard | Add `re_apply_cap_exceeded` check when `attempts >= 3` |
| P0-3 | A | `admin_decide` attempts increment semantics | Change `attempts = attempts + 1` to `case when rejected then +1 else end` |

### P1 — High Priority

| # | Role | Item | Action |
|---|------|------|--------|
| P1-1 | A | `submit_verification` signature reconciliation | Add `p_profile_id`, `p_sanad_url`, `p_nid_url` params; change `p_decision text` type |
| P1-2 | C | Verify JWT `role` claim in `app_metadata` | Confirm `complete_signup` copies role to JWT app_metadata |
| P1-3 | C | Enforce arch-lint in CI | Update `.github/workflows/arch-lint.yml` to enforce architecture |
| P1-4 | C | Verify `hf_server.py` on port 8080 | Boot locally and confirm valid JSON response |
| P1-5 | C | Configure Cloudflare Pages preview | Flutter Web preview URL deploys on PR creation |
| P1-6 | B2 | Eliminate silent mock fallback in admin data source | Make fallback opt-in/explicit; surface errors to UI |

### P2 — Medium Priority

| # | Role | Item | Action |
|---|------|------|--------|
| P2-1 | D | Build admin dispute/review views | Create admin dispute management screens |
| P2-2 | D | Build admin HITL PIN-publish screens | Create `publish_ai_summary` / `admin_force_publish` admin UI |
| P2-3 | D | Add realtime subscription to admin queue | Replace poll-only with Supabase realtime channel |

### P3 — Low Priority

| # | Role | Item | Action |
|---|------|------|--------|
| P3-1 | B1/B2 | Swap mock repos for real Supabase calls | Wire mock repositories to real backend behind feature flag |

---

## 9. Verification Artifacts (Fix Branch `role-a/sprint2-completion`, commit `f9bddbc`)

| Check | Result |
|-------|--------|
| Dual-folder SHA256 parity (26 files) | ✅ All identical |
| Conflict markers in `rls_test.sql` + migrations | ✅ None found |
| Docker drift-guard Pass 1 | ✅ `*** ALL HITL RLS TESTS PASSED ***` |
| Docker drift-guard Pass 2 | ✅ `*** ALL HITL RLS TESTS PASSED ***` |
| `admin_decide` pre-check cap | ✅ Present (`re_apply_cap_exceeded`) |
| `admin_decide` `p_decision text` type | ✅ Present with internal cast |
| `admin_decide` rejected-only increment | ✅ `case when rejected then +1 else end` |
| `submit_verification` contract params | ✅ `p_profile_id`, `p_sanad_url`, `p_nid_url` present |

---

**Report Location:** `D:\LegalLink/REMAINING_TASKS_REPORT.md`  
**PR for P0 Merge:** `https://github.com/Shafatcode007/LegalLink/pull/new/role-a/sprint2-completion`
