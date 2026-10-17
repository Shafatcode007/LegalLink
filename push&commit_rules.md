# Push & Commit Rules — LegalLink Contributor Contract

**Status:** Binding governance document (permanent). Supersedes ad-hoc habits; complements `docs/agent_rules.md`.
**Audience:** Role A (Backend/DB), Role B (Client/UI), Role C (AI/Infra/Integration).
**Source of truth:** `docs/prd.md`, `docs/trd.md` (§8, §9, §11, §16, §17), `docs/database_schema.md`, `docs/sprint.md`, `docs/ui_ux.md`, `docs/agent_rules.md`.

The environment is **WSL2 Ubuntu + native Docker Engine**; the Supabase CLI is the **native Linux binary** (`~/.local/bin/supabase-linux`) — never the npm package. When invoking from Windows PowerShell, wrap shell commands in `wsl bash -lc "..."`.

---

## 1. Core Principles & Zero-Tolerance Guardrails

| # | Rule | Enforcement |
|---|---|---|
| 1 | **Zero secrets.** Never commit `.env`, `.env.local`, service-role keys, `HF_API_KEY`, `FCM_SERVER_KEY`, JWT signing secrets, or Android keystores. | Pre-commit secret scan; CI fails on common secret patterns (TRD §9.5). `SUPABASE_ANON_KEY` is public by design; everything else is not. |
| 2 | **No direct push to `main`.** All work lands through a role branch → PR → CI green → merge. | Branch protection on `main`; PR required. |
| 3 | **Contract-first coordination.** Monday contract freeze fixes all RPC signatures, Worker routes, JSON schemas, and realtime event names. No UI or AI code may change a backend contract unilaterally. | Contract changes announced at the Monday freeze or via an integration checkpoint before push. |
| 4 | **Migrations are additive per release.** No destructive schema change without one release of dual-compatibility (expand → migrate → contract). | TRD §11.5, ADR-013, `agent_rules.md` §2. |
| 5 | **Every RLS-touching migration ships a test update.** | TRD §11.5(5) — PRs without a `db/tests/rls_test.sql` delta are rejected. |
| 6 | **RLS is the only authorization layer.** No raw SQL that bypasses RLS; no `service_role` key in client code. | `agent_rules.md` §2; ADR-003. |
| 7 | **Zero client-side protected access.** The Flutter app never holds a service-role key; all Storage reads go through 15-minute signed URLs (ADR-011). | Code review + CI. |
| 8 | **Immutability.** Published summaries, hearings, invoices and audit logs are archival artefacts — never edited in place (ADR-012, ADR-015). | Trigger-enforced (`audit_immutable`, `hitl_gate`). |
| 9 | **Publish the contract before wiring DTOs.** When Role A adds/changes a table or RPC, the exact JSON request/response payload is published before Role B writes DTOs (§1.1). | Monday contract freeze; PR review. |
| 10 | **Gitignore generated code, commit lockfiles.** Build/tool output stays ignored; `pubspec.lock` and `package-lock.json` are committed for reproducible builds (§1.3). | `.gitignore` + CI. |

### 1.1 Schema → DTO contract publication

When Role A modifies or adds a table/RPC (e.g. `accept_sos`, `invoices`, `advocate_public`), Role A **must publish the exact JSON request/response payload** in the commit/PR description (or update the shared schema docs) **before Role B wires the feature**. The contract fixes:

- **field names** — `snake_case` on the wire; Role B maps to Dart `camelCase` consistently in every DTO.
- **nullability** — which fields are `nullable` (Dart `T?`).
- **types & timestamps** — ISO-8601 UTC for `timestamptz`.
- **error codes** and enum values (TRD §6.7).

Role B must not invent DTO fields. Serialization bugs (timestamp format, null vs non-null, naming) are caught by unit tests generated from this contract.

### 1.2 Realtime channel naming (immutable)

Realtime channel/topic names are fixed by TRD §6.5 and **no role may alter their format unilaterally** (a common integration failure is a client topic that does not match the database publication filter):

| Channel | Source (TRD §6.5) |
|---|---|
| `case:{case_id}` | `postgres_changes` on `cases`, `hearings`, `ai_summaries`, `checklist_items`, `documents` filtered by `case_id` |
| `sos:{district}` | INSERT + UPDATE on `sos_requests` filtered by `district` |
| `inbox:{user_id}` | INSERT on `notifications` filtered by `user_id` |
| `admin:{queue}` | INSERT on `advocates` (verification=pending), `audit_logs` (flagged), complaints |

A subscription key must be a **stable string** derived deterministically from its identifiers (a `List` identity key is forbidden — TRD §8.3), so equal inputs reuse exactly one channel.

### 1.3 Generated code & lockfile rules

- Keep build/tool output strictly gitignored: `.dart_tool/`, `build/`, `coverage/`, `.packages`, `.pub-cache/`, `.wrangler/`, `node_modules/`, `.supabase/`.
- Commit **`pubspec.lock`** and (once `edge/worker/` exists) **`package-lock.json`** for reproducible CI builds.
- Resolve lockfile conflicts by re-running `flutter pub get` / `npm install` — **never** hand-merge lockfiles or commit a platform-specific (WSL2 vs Windows vs macOS) resolution.

---

## 2. Commit Message Conventions

**Format:** `<type>(<scope>): <short description>` — imperative present tense, lower-case, no trailing period, ≤ 72 chars.

**Allowed types:** `feat`, `fix`, `test`, `refactor`, `chore`, `docs`, `ci`, `perf`.

**Cross-cutting scope:** `docs` for governance/docs, `chore` for tooling/housekeeping, `ci` for pipeline changes (available to all roles).

### 2.1 Scope by role

| Role | Mandatory scopes | Example commits |
|---|---|---|
| **A — Backend/DB** | `db`, `migration`, `rpc`, `rls`, `storage`, `seed` | `feat(db): add accept_sos RPC with row locking`<br>`test(rls): add race condition assertion for SOS accept`<br>`feat(storage): harden sanad bucket policy` |
| **B — Client/UI** | `ui`, `auth`, `admin`, `sos`, `timeline`, `theme`, `offline` | `feat(ui): add 600ms hold-to-confirm SOS button`<br>`refactor(admin): adopt clean architecture for verification flow`<br>`fix(offline): flush outbox on connectivity restore` |
| **C — AI/Integration** | `worker`, `ai`, `gateway`, `prompts`, `rag`, `ci` | `feat(worker): add PII redaction regex for BD phones and NIDs`<br>`test(ai): add 30-item golden set schema assertions`<br>`chore(prompts): version triage prompt to v4` |

### 2.2 Body & trailers

- Use the body to explain **why**, not what (the diff shows what).
- Reference ADRs and gates where relevant, e.g. `Refs: ADR-016`, `Sprint: S2`, `Gate: G-1.1`.
- One logical change per commit. Migration + its RLS test assertions may be **two** commits (`feat(db): …` then `test(rls): …`).

---

## 3. Role-Specific Push Order & Pre-Push Checklists

Every commit must be locally verified **before** `git push`. Run the full checklist for your role.

### 🟢 3.1 Role A — Backend & DB (Shafat)

1. **Timestamp:** new migration uses a unique 14-digit prefix — `YYYYMMDDHHMMSS_description.sql` (never reuse an existing version).
2. **Mirror:** the file exists **byte-identical** in both `db/migrations/` and `supabase/migrations/`.
3. **Sync validator:**
   ```bash
   ./scripts/verify_migration_sync.sh
   ```
4. **Iron Laws** (`docs/agent_rules.md` §5): `INSERT` policies on `storage.objects` use `WITH CHECK` (never `USING` alone); `SECURITY DEFINER` functions set `search_path = public, extensions` and `revoke execute … from public`.
5. **Drift guard (Run 1 + Run 2 must both be green):**
   ```bash
   supabase db reset --local --no-seed
   psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -f db/seed.sql
   psql -v ON_ERROR_STOP=1 "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -f db/tests/rls_test.sql   # Run 1
   psql -v ON_ERROR_STOP=1 "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -f db/tests/rls_test.sql   # Run 2 (idempotency / drift)
   ```
   Output must end with `*** ALL HITL RLS TESTS PASSED ***` on **both** runs.
6. **No bypass:** confirm no committed SQL bypasses RLS (no `service_role` shortcuts, no client-side raw SQL).
7. **Contract:** if the migration adds/changes a table or RPC, publish the exact JSON payload contract (see §1.1) in the commit/PR body **before** Role B wires DTOs.

### 🔵 3.2 Role B — Client & UI (Flutter)

1. **Clean Architecture boundaries** (TRD §8.1):
   - `domain/` — pure Dart: **no** imports of `presentation/`, `data/`, `flutter`, `supabase_flutter`, or `hive`. The pure `riverpod` package is allowed for provider tokens.
   - `data/` — DTOs, repository implementations, Supabase/Hive sources.
   - `presentation/` — Riverpod notifiers + widgets/screens; **never imports `data/`**.
2. **Composition root:** only `lib/app/di.dart` may import both `domain/` and `data/` (ADR-016). Concrete repository bindings live **only** here via `ProviderScope` overrides.
3. **Design tokens** (`docs/ui_ux.md` §1.1): no ad-hoc hex values — use the token palette. Forest is **verified-badge only**; **Burgundy is reserved for the SOS action, critical alert borders, and overdue outlines** — never decorative, never body emphasis.
4. **SOS interaction:** the SOS control is the 600 ms hold-to-confirm widget; one Burgundy CTA per SOS screen.
5. **Accessibility** (`docs/ui_ux.md`, TRD §8.8): all touch targets ≥ 48×48 dp; Bangla body ≥ 16 sp with 1.6 line-height; status conveyed by icon + text, never colour alone.
6. **Static analysis:**
   ```bash
   cd apps/legal_link
   flutter pub get
   flutter analyze          # must exit 0 errors AND 0 warnings
   dart format --set-exit-if-changed lib test
   ```
7. **Offline invariants** (TRD §8.4): `accept_sos` is **realtime-only — never enqueued in the outbox** (ADR-016).

### 🟣 3.3 Role C — AI & Integration (Worker & Cloudflare)

1. **PII redaction:** every Worker route in `edge/worker/` redacts names, NIDs, and BD phone numbers **before** any external model call.
2. **Prompt versioning:** prompts live at `edge/worker/prompts/{feature}_{version}.ts` (e.g. `triage_v3.ts`); prompt changes require a **new** version file and a golden-set run (TRD §7.3).
3. **Fallbacks:** every AI endpoint returns a rule-based `TemplateAIService` fallback on timeout/error (> 30 s) — the UI must never hang on a model.
4. **Response guards:** checklist items must exist in the admin template set; `disclaimer_bn` is always present; prohibited prediction/advice patterns trigger regenerate-once → template fallback + `flagged=true` (TRD §7.2).
5. **Validation:**
   ```bash
   cd edge/worker
   npm run lint || npx tsc --noEmit
   ```
6. **Golden set** (`ai/`): the 30 fixed inputs must still assert against the JSON schemas; CI stays provider-independent and free of API keys.

---

## 4. TDD Gates (all roles)

Business logic, bug fixes, and refactors follow **RED → GREEN → REFACTOR**:

1. **RED** — write the failing test/assertion first; run it and confirm it fails for the right reason.
2. **GREEN** — minimal implementation to pass.
3. **REFACTOR** — clean up (`/clean`): no debug prints, no dead code, files < 800 lines, functions < 50 lines.
4. Coverage gate: **≥ 60%** for the Flutter app (TRD §11.3); every table touched by RLS has an assertion.

Database work additionally **must** pass the drift guard (§3.1.5) before push.

---

## 5. Merge & Synchronization Protocol

| Step | Command / rule |
|---|---|
| **Branch** | `role-a/<feature>`, `role-b/<feature>`, `role-c/<feature>` |
| **Rebase before push** | `git fetch origin main && git rebase origin/main` — keeps history linear, no merge bubbles |
| **Never force-push** | `git push --force` / `--force-with-lease` is **prohibited** on `main` and any shared branch |
| **PR + CI** | Open a PR to `main`; required checks: `analyze`, `test`, `rls`, `ai-golden`, `sql-lint`, `arch-lint`, `build` (TRD §11.3) |
| **Merge** | Squash or rebase merge only after all checks are green and one reviewer approves |
| **Contract drift** | If an RPC signature / Worker route / schema changes, announce at the Monday freeze or raise an integration checkpoint **before** pushing |

**Weekly rhythm (TRD §11 / `docs/sprint.md`):** Mon triage + **contract freeze** → Tue (faculty sync; all three lanes build in parallel against contracts) → Wed **integrate checkpoint** (mocks → real behind flags) → Thu harden + rehearse → Fri demo + feedback.

---

## 6. Verification Quick Reference

| Check | Command |
|---|---|
| Migration dual-folder sync | `./scripts/verify_migration_sync.sh` |
| RLS drift guard (×2) | `psql -v ON_ERROR_STOP=1 "$LOCAL_DB_URL" -f db/tests/rls_test.sql` |
| Flutter static analysis | `cd apps/legal_link && flutter analyze` |
| Dart formatting | `dart format --set-exit-if-changed lib test` |
| Worker type/lint | `cd edge/worker && npm run lint || npx tsc --noEmit` |
| Repo state | `git status && git log -n 15 --oneline --decorate` |

---

## 7. Definition of Done (per change)

- [ ] Correct role branch; commit message follows §2 with a role scope.
- [ ] Tests written **first** (RED → GREEN) where logic changed; coverage gate met.
- [ ] Role checklist in §3 fully passed.
- [ ] No secrets, no RLS bypass, no direct push to `main`.
- [ ] RLS-touching change includes a `db/tests/rls_test.sql` update; drift guard green ×2.
- [ ] Contracts honored (or changed at the Monday freeze / integration checkpoint).
- [ ] New/changed tables & RPCs published a JSON payload contract **before** client DTOs were written (§1.1).
- [ ] Realtime channel names match TRD §6.5; no unilateral topic changes (§1.2).
- [ ] Generated artifacts gitignored; lockfiles committed and never hand-merged (§1.3).
- [ ] PR CI green; reviewed and merged without force-push.

---

*This document is the contract. Any change to it requires its own `docs:` PR reviewed by all three roles. When this document and a passing commit conflict, this document wins and the commit is corrected.*
