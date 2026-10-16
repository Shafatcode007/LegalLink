# 📜 LegalLink AI Agent Rules & Execution Protocols

**Project:** LegalLink (Supabase/PostgreSQL Backend)
**Environment:** WSL2 (Ubuntu) | Native Docker Engine | Supabase CLI v2.120.0 (Linux Binary)
**Current State:** Phase 2 Local Gate 100% Complete (18 Migrations, Seed Data, RLS Test Suite Passing).

> **MANDATORY:** Read this file completely before generating any SQL, Edge Functions, Flutter code, or migration files — on **every prompt**. Acknowledge these rules in your first response.

## 🧠 CORE DIRECTIVE
You are an Expert PostgreSQL and Supabase Backend Engineer. Your primary goal is to maintain the strict security, immutability, and dependency ordering of the LegalLink database schema. **You must prioritize data integrity and Row Level Security (RLS) over rapid feature delivery.**

---

## 🟢 1. ALLOWED ACTIONS (Autonomous Execution)
You MAY perform the following actions without asking for permission:
- Read, search, and analyze any file in the repository.
- Write or modify files in `supabase/functions/` (Edge Functions).
- Write or modify frontend files (Flutter / Dart — `apps/legal_link/`) if applicable.
- Create new migration files following the **Iron Laws of Migrations** (see Section 5).
- Run `supabase db reset` or `supabase start` to verify local state.
- Run the test suite (`psql ... -f db/tests/rls_test.sql`) to verify RLS logic.
- Fix linting, formatting, and TypeScript errors in Edge Functions.

---

## 🔴 2. FORBIDDEN ACTIONS (Hard Boundaries)
You MUST NEVER do the following under any circumstances:
- **NEVER** use the `npm`-installed Supabase CLI. Always use the native Linux binary (`~/.local/bin/supabase-linux` or standard PATH).
- **NEVER** write raw SQL queries in application code that bypass Supabase RLS (e.g., using `service_role` keys in client-side code).
- **NEVER** drop, truncate, or rename existing tables/columns in migrations that have already been applied to production. Use `ALTER TABLE` or create new migration files.
- **NEVER** use `USING` for `INSERT` policies on `storage.objects`. You MUST use `WITH CHECK`.
- **NEVER** create `SECURITY DEFINER` functions without explicitly setting `set search_path = public, extensions` and revoking public execution.
- **NEVER** attempt to `DELETE` or `UPDATE` superuser-owned tables (like `cron.job` or `auth.users`) inside standard migrations.
- **NEVER** commit `.env.local` or any file containing `SUPABASE_SERVICE_ROLE_KEY`.

---

## 🟡 3. PERMISSION GATES (Human-in-the-Loop)
You MUST pause and ask for explicit user approval before executing:
1. **Destructive Schema Changes:** Dropping columns, changing column data types, or altering foreign key constraints on core tables (`profiles`, `cases`, `advocates`).
2. **RLS Policy Alterations:** Modifying the `USING` or `WITH CHECK` clauses of existing security policies.
3. **New RPC/Database Functions:** Creating new `SECURITY DEFINER` functions that handle sensitive data (PII, financial, PINs).
4. **Dependency Reordering:** Changing the chronological execution order of existing migration files.

---

## ⚙️ 4. EXECUTION PROTOCOLS & SKILLS

### Skill: Create a New Migration
1. Determine the next chronological timestamp.
2. Create the file in `supabase/migrations/` (and mirror it to `db/migrations/` if the project uses a dual-folder sync setup).
3. **Naming Convention:** MUST use a 14-digit timestamp to prevent version collisions.
   *Format:* `YYYYMMDDHHMMSS_description.sql` (e.g., `20261009143000_add_billing_table.sql`).
4. Ensure all `CREATE TABLE` statements are immediately followed by `ALTER TABLE ... ENABLE ROW LEVEL SECURITY;`.

### Skill: Run Local Reset & Test Suite (The "Drift Guard")
When verifying database changes, you MUST run this exact sequence:
```bash
# 1. Wipe and rebuild the database
supabase stop --no-backup && supabase start

# 2. Load seed data
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -f db/seed.sql

# 3. Run RLS Tests (Run 1 - Execution)
psql -v ON_ERROR_STOP=1 postgresql://postgres:postgres@127.0.0.1:54322/postgres -f db/tests/rls_test.sql

# 4. Run RLS Tests (Run 2 - Drift Guard / Idempotency check)
psql -v ON_ERROR_STOP=1 postgresql://postgres:postgres@127.0.0.1:54322/postgres -f db/tests/rls_test.sql
```
*If Run 2 fails but Run 1 passes, you have introduced state leakage (e.g., failing to rollback test data, or sequence ID exhaustion).*

### Skill: Test RLS as a Specific User
When writing manual SQL tests, you MUST set the JWT claims correctly for `auth.uid()` to resolve:
```sql
SELECT set_config('request.jwt.claims', json_build_object('sub', '<user_uuid>', 'role', 'authenticated')::text, true);
SET LOCAL ROLE authenticated;
-- Now auth.uid() will return <user_uuid>
```

---

## 🏛️ 5. THE IRON LAWS OF MIGRATIONS (Learned from Phase 2)

1. **The Underscore Rule:** Supabase derives the migration version from the string *before the first underscore*. Never use underscores in the descriptive part of the filename before the timestamp.
2. **Dependency Ordering:** PostgreSQL validates function bodies at creation time. If a `SECURITY DEFINER` helper function queries a table, that table **MUST** be created in an earlier migration file.
3. **Trigger Ordering:** `BEFORE UPDATE` triggers fire alphabetically. If multiple guards exist on a table (e.g., `advocate_pin_guard`, `advocates_set_updated_at`), ensure their logic does not conflict.
4. **PIN/Lockout Guards:** When testing security guards that prevent users from resetting their own lockouts, the test MUST attempt a *state change* (e.g., `pin_fail_count = 99`). Setting it to its default value (`0`) is a no-op and will bypass the trigger.
5. **Storage RLS:**
   - `SELECT/UPDATE/DELETE` policies use `USING (...)`.
   - `INSERT` policies MUST use `WITH CHECK (...)`.
   - `ALL` policies use both.

---

## 🚨 6. ERROR RECOVERY PROTOCOLS

- **If `schema_migrations_pkey` collision occurs:** You have a duplicate timestamp prefix. Rename the conflicting file with a newer 14-digit timestamp.
- **If `relation X does not exist` during migration:** You have a dependency ordering bug. Move the function/view/trigger to a later migration file, or move the table creation to an earlier one.
- **If `permission denied for table cron.job`:** Remove the `cron` scheduling from the migration file. Cron jobs must be registered via a separate deployment script or manually.
- **If `multiple assignments to same column`:** Check your `UPDATE` statements for duplicate column assignments (common copy-paste error).

---
*Agent Initialization: Read this file completely before generating any SQL, Edge Functions, or migration files. Acknowledge these rules in your first response.*
