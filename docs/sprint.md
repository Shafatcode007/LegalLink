# LegalLink — 6-Week Sprint Plan (Agentic + Prototype Methodology)

**Date:** October 9, 2026 · **Revised:** W1 scope trimmed, offline spread W4–W6, Tuesday updates added
**Baseline:** Phase 2 DB gate **COMPLETE** — 18-migration chain, seed, `db/tests/rls_test.sql` 15/15 green (2× runs, no drift).
**Cadence:** 6 sprints × 1 week · **Tuesday faculty sync (15 min)** · **Friday demo (15 min)**.
**Source docs:** `docs/prd.md` (§5 faculty reqs, §16 demo criteria), `docs/trd.md` (§8, §16 gates), `docs/ui_ux.md`, `docs/database_schema.md`, `Design/`.

---

## 1. Development Methodology — Agentic Prototyping

### 1.1 Prototype-driven (features change continuously)
- Every week ships a **working vertical prototype** (UI + backend + AI end-to-end). Rough edges OK; dead ends expected.
- **Friday demo = prototype review**, not acceptance. Faculty feedback re-scopes Monday.
- **Two-stage maturity:** build fast W1–W5; harden only what survived feedback in W6.
- **Feature flags / demo switches:** in-flight changes never break Friday's demo path.

### 1.2 Agentic (AI-agent-assisted development)
Each developer orchestrates parallel AI agents; humans architect, review, verify:

| Agent role | Used for |
|---|---|
| `planner` / `architect` | Sprint slicing, RPC/UI design before code |
| `tdd-guide` | RED→GREEN→REFACTOR on business logic |
| `code-reviewer` / `security-reviewer` | Every PR — RLS, auth, input validation |
| `build-error-resolver` | CI/compile failures |
| `explore` | Fast codebase discovery |

**Human non-negotiables:** RLS policy design, demo rehearsal, faculty feedback interpretation, Friday demo.

### 1.3 Change protocol (continuous feature change)
- **Anchors (fixed):** 5 faculty requirements (PRD §5), 8 MVP features (F1–F8), gates `G-1.1`/`G-1.2`/`G-4.1–4.3`, RLS-green, both form factors.
- **Negotiable:** UX flows, feature details, priorities, nice-to-haves.
- **Change budget:** Monday triage — max **2 changes in / 1 item out** per week. New ideas → rolling backlog (§7).

### 1.4 Parallel track development (frontend · backend · AI — simultaneously, never sequentially)
All three layers are built **concurrently in every sprint** — no role waits idle for another. The enabler is **contract-first**:

1. **Monday contract freeze (15–30 min, all 3 devs):** agree the week's interfaces before any code:
   - **A** publishes RPC signatures (name, params, return type, error codes)
   - **C** publishes Worker routes + JSON schemas + realtime event names
   - **B** receives both and maps screens to them
2. **Tue–Thu, three lanes run in parallel:**
   - **Backend lane (A):** migrations, RPCs, RLS — verified by the drift-guard suite
   - **Frontend lane (B):** screens and flows wired to **mocks/stubs matching the contract** (e.g., W3's hardcoded checklist is exactly this pattern) — zero idle waiting
   - **AI/Infra lane (C):** Worker endpoints, prompts, golden set, realtime plumbing — callable via contract even while the UI is still rough
3. **Wednesday integrate checkpoint:** swap mocks → real RPCs/endpoints behind flags; anything that can't integrate yet stays flagged, demo path stays on the stable side.

**Rule:** a screen never blocks on a live backend/AI response to be *built* — it blocks only at the Wednesday swap. This is why the W3 stub → W4 real-AI swap is safe: both sides honored the same schema from Monday.

---

## 2. Team & Roles (3 active developers, ~20–30 h/person/week)

| Role | Owns | Primary stack |
|---|---|---|
| **A — Backend/DB** | Migrations, RPCs, RLS, storage, audit | Supabase (Postgres/SQL) |
| **B — Client/UI** | Flutter app (Web + Android), screens, offline UI | Flutter/Riverpod, Hive |
| **C — AI/Integration** | Cloudflare Worker, prompts, providers, realtime, CI/CD | Workers (TS), Hugging Face, GitHub Actions |

**Weekly rhythm (parallel lanes):** Mon (triage + **contract freeze** — RPC/schemas/events agreed) → **Tue (faculty sync; all 3 lanes building simultaneously against contracts)** → Wed (**integrate checkpoint**: mocks → real behind flags) → Thu (harden, tests, rehearse) → **Fri (demo + feedback)**. Unfinished Friday noon → rolling backlog, never silent carry. Backend, frontend, and AI progress are reported as three lanes in every Tuesday update.

---

## 3. Sprint Summary

| # | Week | **Tuesday update focus** | **Friday demo (working end-to-end)** | **Cut line if behind** |
|---|---|---|---|---|
| S1 | W1 | Auth flow + profile creation | OTP login → minimal profile → admin approve → badge. **No document uploads yet** | Drop re-apply/rejection-reason UI |
| S2 | W2 | Document verification + SOS basics | Advocate **uploads Sanad** → admin verifies (signed URLs) → **SOS button works (single accept, no race)** | Drop concurrent race; keep single-accept |
| S3 | W3 | SOS race + AI triage **stub** | 2 advocates race accept → 1 wins, case created · AI checklist shows (**hardcoded template, no real AI yet**) | Drop stub polish; keep template fallback path |
| S4 | W4 | **Real AI integration** + timeline + offline read spike | AI generates **real** Bangla checklist → hearing logged → phone timeline updates live | Drop offline spike (absorbed by W5 outbox) |
| S5 | W5 | HITL publish + billing (HTML invoice) + offline **write** on one screen | AI draft → PIN publish → client sees it · invoice renders (**HTML**) · **offline edit on hearing-log screen works (outbox)** | Drop invoice entirely to HTML-only single line; keep offline outbox |
| S6 | W6 | Offline product-wide + hardening + gates | Full flow works **offline** + conflict sheet · all gates green · Web + APK | Drop load testing; keep core sync + both form factors |

⭐ Faculty requirements land: AI real in **W4**, checklist-after-SOS chain **W3→W4**, timeline **W4**, App+Web **every week**, cross-device/integration **W2/W4/W6**, offline **W6**.

---

## 4. Detailed Sprint Plans

### S1 · W1 — Auth & Minimal Profiles (F1 start + F2 start) — ~20–30 h/person

**Goal:** Empty repo → OTP login on both form factors → minimal profile → admin approve → badge. **Document uploads explicitly deferred to W2.**

| Owner | Deliverables (hours) |
|---|---|
| A (~20 h) | Monorepo layout (TRD §11.1); CI skeleton (`analyze` + `rls` job on `db/tests/rls_test.sql`); auth/role guards; `submit_verification` / `admin_decide` RPCs — **approve/reject only, no re-apply cap** |
| B (~25 h) | Flutter project (web + android), `go_router` auth shell, design tokens (`ui_ux.md` §1.1–1.3), Bangla font subset, phone→OTP screens; **minimal profile form (name, phone, role only)**; admin queue UI (list + approve/reject buttons); `VerifiedBadge` |
| C (~15 h) | Phone-OTP local config (test OTP) + JWT `role` claim; `arch-lint` CI job; `AIService` stub + `hf_server.py` smoke; Pages preview pipeline |

**Tuesday update goal:** *"Auth flow 60% done. OTP works on Web, Android in progress. Friday target: full OTP + profile creation."*
**Friday demo:** Register `+880` → OTP → create minimal profile → admin approves → verified badge. **No document uploads.**
**Exit gate:** `G-1.1` RLS green in CI; both targets boot; PII absent from public search.

---

### S2 · W2 — Document Verification + SOS Basics (F2 + F3 start) — ~20–30 h/person

**Goal:** Full verification with Sanad/NID uploads; SOS button works end-to-end with **single accept** (race deferred to W3).

| Owner | Deliverables (hours) |
|---|---|
| A (~20 h) | Document-upload RPCs + storage paths; `accept_sos` **single-accept** logic (row locking, `sos_already_taken`); **re-apply cap (3)** (moved from W1) |
| B (~25 h) | Advocate registration form (NID, Bar Council no., Sanad photo, courts, specializations, fees — moved from W1); **upload UI**; admin queue shows documents; SOS screen (giant button, `ui_ux.md` §3.3) + advocate inbox Accept/Decline |
| C (~15 h) | Sanad/NID uploads with **15-min signed URLs** (policies exist in 009); realtime district channel basics; `/v1/rate/check` scaffold |

**Tuesday update goal:** *"Document upload UI done. Admin queue wired with signed URLs. Friday target: advocate uploads Sanad, admin approves; SOS button triggers broadcast."*
**Friday demo:** Advocate uploads Sanad → admin approves with document visible → badge; **SOS tapped → advocate receives alert → single accept creates case** (no race yet).
**Exit gate:** Signed URLs expire in 15 min; RLS suite green.

---

### S3 · W3 — SOS Race + AI Checklist Stub (F3 + F4 scaffold) — ~20–30 h/person

**Goal:** The signature race demo; AI checklist **stubbed with hardcoded template** so UI/states are fully built before real AI lands W4.

| Owner | Deliverables (hours) |
|---|---|
| A (~25 h) | Race-condition hardening: concurrent `accept_sos` test script (two simultaneous accepts, one wins); SOS rate limit + `expire_sos` cron wiring |
| B (~20 h) | Checklist UI states `suggested_pending_advocate → approved`, "Suggested" vs "Approved by your lawyer" distinction, disclaimer banner; triage Q&A form (Bangla) wired to **stub** (returns template items) |
| C (~15 h) | Realtime channel stability; widget test: **exactly one** channel per district set; Worker `/v1/ai/triage` **scaffold** (route + JSON schema + fallback plumbing, provider response mocked) |

**Tuesday update goal:** *"Race condition test passing locally. Realtime channel stable. AI endpoint scaffolded with stub. Friday target: 2 advocates race live; hardcoded checklist shows."*
**Friday demo:** Two advocates race Accept → **one wins, case on both screens** → open case → **AI checklist appears (stubbed/template)** with correct states.
**Exit gate:** Concurrent-accept script green; `rate_limited` with `reset_at`; RLS green.

---

### S4 · W4 — Real AI + Timeline + Offline Read Spike (F4 ⭐ + F5 ⭐) — ~20–30 h/person

**Goal:** Swap stub → **real AI** (golden set gate), ship the live timeline, and spike offline on one read screen.

| Owner | Deliverables (hours) |
|---|---|
| A (~20 h) | Hearing/amendment RPCs + `request_update` dedupe; case overview behind `has_case_access`; audit rows; `submit_triage` + `ai_triage_sessions` wiring; **template-membership filter** |
| B (~25 h) | Case detail + timeline (mobile §3.5 + responsive web), hearing-log form, client read-only view, empty/loading states; **accessibility baseline** (48 dp, Bangla semantics); **offline spike: case-detail read from Hive cache** |
| C (~20 h) | Real `/v1/ai/triage`: JWT → rate limit → PII redaction → HF → schema validate → fallback; `AI_PROVIDER` switch; **golden set v1 (30 inputs, local + HF) → `G-1.2` evidence**; case Realtime delta channel |

**Tuesday update goal:** *"Real AI triage endpoint responding. Checklist schema validated. Timeline screens 70%. Friday target: real AI checklist + hearing logged → phone updates."*
**Friday demo:** Bangla situation → **real AI checklist** (both providers + kill-AI fallback drill) → advocate logs hearing on web → **client phone timeline updates live**.
**Exit gate:** `G-1.2` 30/30 schema-valid both providers, 0 banned phrases; F-6 cross-client assertions live.

---

### S5 · W5 — HITL Publish + Billing (HTML) + Offline Write Spike (F6 ⭐ + F7) — ~20–30 h/person

**Goal:** HITL trust proof; billing as **HTML invoice** (PDF deferred); offline **write** on the hearing-log screen via outbox.

| Owner | Deliverables (hours) |
|---|---|
| A (~20 h) | `expire_drafts` cron wiring; notification dedupe; **draft-invisibility RLS assertion**; invoice RPC wiring (`next_invoice_no`, record payment) + party-only RLS; **server-side updated_at merge rules** prep |
| B (~25 h) | "Legal Notice" card (`ui_ux.md` §3.6), editor + **PIN pad**, lockout UI, client published view; invoice list/detail + record-payment (→ **HTML invoice view, not PDF**); **offline write: hearing-log form queues to outbox + `SyncBadge`** |
| C (~20 h) | `/v1/ai/summarize`: JSON mode, temp ≤ 0.2, ≤120 words, PII redaction, KV cache; **golden set v2**; outbox FIFO worker prototype (100-item cap; **SOS accept never queued**) |

**Tuesday update goal:** *"PIN publish works end-to-end. Outbox queue flushing on hearing-log screen. Friday target: draft → PIN → client sees; offline edit syncs on reconnect."*
**Friday demo:** Notes → AI draft (**invisible to client — direct API proof**) → PIN sign → client card → wrong PIN 5× → lockout countdown → invoice renders (**HTML**) → **airplane mode: edit hearing note on phone → reconnect → lands server-side**.
**Exit gate:** Draft-invisibility + PIN-lockout tests green; hybrid switch identical schema.
**Cut line:** invoice → single total line; offline → queue without conflict sheet (that's W6).

---

### S6 · W6 — Offline Product-Wide + Release + All Gates (F8 ⭐ + release) — ~20–30 h/person

**Goal:** Offline everywhere + conflict handling; harden surviving features; hit every gate.

| Owner | Deliverables (hours) |
|---|---|
| A (~20 h) | Write-merge rules final (`updated_at` tombstones, TRD §8.4); `sqlfluff` clean; **RLS denial matrix script** (G-4.3); admin audit views final |
| B (~30 h) | Offline product-wide: Hive core reads, outbox across screens, **conflict sheet** (`ui_ux.md` §4.3); responsive polish; text scaling 1.0–2.0; **signed APK** |
| C (~20 h) | Outbox FIFO worker final + Realtime reconnect/backoff; **`G-4.2` hybrid-AI evidence video**; golden-set commits; **20-step pilot script** + screenshots; **Pages prod deploy** |

**Tuesday update goal:** *"Offline sync working product-wide. Conflict detection implemented. Friday target: full flow offline + 20-step demo rehearsal."*
**Friday demo (final scope confirmation):** Full PRD §16 sequence — SOS → accept → case → AI checklist → hearing → AI summary → PIN publish → client sees it (phone) while advocate works (web) → invoice → **airplane-mode edit → reconnect → syncs + conflict sheet** → **RLS denial proof** → **rate limit + PIN lockout proof** → **hybrid AI switch + AI-down fallback**. On **Web (Pages) + Android APK**.
**Exit gates:** `G-4.1` 20-step signed off; `G-4.2` + `G-4.3` evidence captured; RLS + golden set green on `main`.
**Cut line (order):** conflict sheet → banner; load sanity → skipped. **Never cut:** outbox queue, RLS proofs, either form factor.

---

## 4.5 Tuesday Update Goals (example phrasing per week)

| Week | Example Tuesday line |
|---|---|
| W1-Tue | *"Auth flow 60% done. OTP works on Web, Android in progress. Friday target: full OTP + profile creation."* |
| W2-Tue | *"Document upload UI done. Admin queue wired. Friday target: advocate uploads Sanad, admin approves; SOS button works."* |
| W3-Tue | *"Race condition test passing. Realtime channel stable. AI stub returning template checklist. Friday target: 2 advocates race, 1 wins live."* |
| W4-Tue | *"Real AI endpoint responding on both providers. Timeline screens 70%. Friday target: real AI checklist + live timeline."* |
| W5-Tue | *"PIN publish works. Outbox flushing on hearing-log screen. Friday target: draft → PIN → client sees; offline edit syncs."* |
| W6-Tue | *"Offline sync working product-wide. Conflict detection implemented. Friday target: full flow offline + 20-step rehearsal."* |

---

## 5. Faculty Requirement → Prototype Traceability

| PRD §5 mandatory requirement | Lands in | Proven live at |
|---|---|---|
| 1. AI component | W3 stub → **W4 real** (triage), W5 (summary) | W4 demo + fallback drill |
| 2. Document checklist after SOS | W2 (SOS) → W3/W4 (checklist) | W3 stub demo, W4 real demo |
| 3. Case overview / timeline | W4 | W4 Friday demo |
| 4. App + Web builds | W1 → W6 (APK + Pages) | Every Friday; finalized W6 |
| 5. Integration (shared auth/data/realtime) | W2, W4, W6 | W4 + W6 demos |

PRD §16 demo-day criteria 1–6 map to: W5 (1), W6 (2), W4 (3), W6 (4), W5+W6 (5), W6 (6).

---

## 6. Standing Rules (every sprint)

### Tuesday Update Protocol (15-min faculty sync)
Every Tuesday:
1. **Shipped (since last Friday):** what's working in the prototype
2. **In Progress (Tue–Thu) — reported as 3 parallel lanes:** backend (A) / frontend (B) / AI-infra (C), one line each
3. **Blocked:** any technical/dependency blockers (esp. contract mismatches between lanes)
4. **Friday Demo Preview:** what will be shown Friday
5. **Feedback Integration:** how Friday's feedback was applied

Format: 5-minute presentation + 10-minute Q&A.
Deliverable: 1-page markdown summary posted to repo (`docs/updates/WN-tue.md`) by Tuesday 6pm.

### Definition of Done (per sprint deliverable)
- ✅ Code merged to `main` (not just an open PR)
- ✅ CI green (RLS + lint + build)
- ✅ Demo path rehearsed on **both Web + Android** by Thursday 6pm
- ✅ No `TODO`/`FIXME` in the demo path
- ✅ Agent-generated code has human sign-off on RLS/auth changes
- ✅ Tuesday update delivered to faculty

### Engineering rules
1. **RLS suite stays green** — `db/tests/rls_test.sql` in CI on every `db/**` PR; red blocks merge.
2. **No new table without RLS policies + an assertion** in the same PR (README §7).
3. **AI never blocks core flow** — fallback ships same week as the AI screen (PRD P5).
4. **Bangla strings in ARB** (bn + en); `flutter analyze` + `dart format` clean.
5. **Friday demo uses seeded data** (`db/seed.sql`) + at most one fresh registration; rehearsed Thursday.
6. **Change budget enforced** — max 2 in / 1 out per Monday; demo path protected by flags.
7. **Dual-folder sync** — every `db/migrations/` edit is copied to `supabase/migrations/` (Iron Laws).

---

## 7. Rolling Backlog (continuous feature change)

_Triaged every Monday under the change budget._

| Logged | Source | Item | Status |
|---|---|---|---|
| — | — | _(empty)_ | — |

**Carried list:** _(empty — updated each Monday)_

---

## 8. Buffer & Risk Register

| Risk | Week | Mitigation |
|---|---|---|
| W1 still dense despite trim | W1 | Cut line: rejection-reason UI; minimal profile form only |
| Stub→real AI transition breaks checklist UI | W3→W4 | Stub uses the **same JSON schema** as the real endpoint; golden set validates the swap |
| Lane drift — frontend builds against a contract the backend/AI never implements | all | Monday contract freeze; Wednesday integrate checkpoint catches mismatches by Wed, not Friday |
| Feature churn destabilizes demos | all | Anchors vs negotiable (§1.3); flags; Friday on stable path |
| Agent-code drift / subtle bugs | all | TDD + reviewer agents + human RLS sign-off; RLS suite as safety net |
| Realtime race flakiness on demo Wi-Fi | W3/W6 | Rehearse twice; fallback video (TRD demo-day freeze) |
| Golden set misses 30/30 | W4 | Shorter output / Qwen 2.5-3B fallback (TRD §16.2) |
| HITL week overloaded (billing + offline write) | W5 | Billing is HTML-only single screen; outbox on ONE screen only |
| Offline overrun in final week | W6 | Incremental W4 read spike → W5 write spike → W6 wide; pre-approved cuts; never cut sync/form factors |
| Free-tier quota in demo week | W6 | KV caching; usage alerts at 80%; local AI pre-warmed |
