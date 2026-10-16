# ️ Shafat: Backend & Database Lead (Role A)
**Focus:** Database schema, RLS security, atomic RPCs, and CI skeleton for DB.
**Primary Stack:** Supabase (Postgres/SQL), Deno Edge Functions.

## 🟢 Sprint 1 (Week 1): Auth & Minimal Profiles
**Goal:** Secure the foundation. No document uploads yet.

### Tasks
1. **Monorepo Layout:** Finalize `db/migrations/` and `supabase/migrations/` dual-folder sync.
2. **CI Skeleton:** Create `.github/workflows/ci.yml` with the `rls` job that runs `db/tests/rls_test.sql`.
3. **Auth/Role Guards:** Ensure `complete_signup` RPC prevents clients from assigning themselves `role = 'admin'`.
4. **RPCs:** Write `submit_verification` and `admin_decide` RPCs (approve/reject only, no re-apply cap yet).

### 📦 What to Commit
- `db/migrations/20261013000001_rpc_verification.sql`
- `db/tests/rls_test.sql` (Add assertions for the new RPCs)
- `.github/workflows/ci.yml`

### ✍️ Commit Message Format
- `feat(db): add submit_verification and admin_decide RPCs`
- `test(db): add RLS assertions for verification flow`
- `ci: add RLS test suite to GitHub Actions`

---

## 🟡 Sprint 2 (Week 2): Document Verification + SOS Basics
**Goal:** Secure file uploads and the critical SOS row-locking logic.

### Tasks
1. **Document Uploads:** Write RPCs/storage path logic for Sanad/NID uploads.
2. **SOS Logic:** Write `accept_sos` with strict Postgres row locking (`UPDATE ... WHERE status = 'open'`).
3. **Invariants:** Implement the `sos_already_taken` invariant (returning `NULL` to the loser of the race).
4. **Re-apply Cap:** Implement the 3-attempt re-apply cap logic in `admin_decide`.

### 📦 What to Commit
- `db/migrations/20261020000001_rpc_sos_and_uploads.sql`
- `db/tests/rls_test.sql` (Add concurrent accept test)

### ✍️ Commit Message Format
- `feat(db): add accept_sos RPC with row locking`
- `feat(db): add document upload RPCs and storage paths`

---

## ✅ Definition of Done (DoD)
- [ ] Every migration in `db/migrations/` is copied to `supabase/migrations/`.
- [ ] `db/tests/rls_test.sql` runs green locally (`psql -f db/tests/rls_test.sql`).
- [ ] No raw secrets committed.
