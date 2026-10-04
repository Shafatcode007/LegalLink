# LegalLink (আইন সহায়)

**Bangladesh's first Emergency Legal Access & Case Transparency Platform.**

| Document | Purpose |
|---|---|
| [`docs/prd.md`](docs/prd.md) | Product requirements - personas, the 8 MVP features, acceptance criteria |
| [`docs/trd.md`](docs/trd.md) | Technical design - architecture, tech stack, data design, APIs, CI |
| [`docs/database_schema.md`](docs/database_schema.md) | Table-by-table schema reference and review notes |
| [`docs/ui_ux.md`](docs/ui_ux.md) | UI/UX specification and design system |
| [`Design/`](Design/) | UI mockups (`.png` + source `.code.html`) for web and mobile |

---

## 1. Executive Summary

**The problem.** When someone is arrested in Bangladesh, the family is stressed and usually finds a lawyer through a contact or a *dalal* (tout). They cannot compare experience, specialization, or fees. After hiring, clients depend entirely on the lawyer or clerk to relay the next hearing date and what happened at the last one. Missing information causes confusion, wasted court trips, and exploitation by middlemen.

**The solution.** LegalLink connects people who suddenly need legal help with **verified** advocates, and keeps clients informed in plain Bangla:

1. **Emergency SOS** - find a verified bail lawyer near the relevant Thana/court in minutes, not days.
2. **Case transparency** - track hearings, dates, and plain-language updates instead of depending on dalals.
3. **Pre-hire readiness** - AI case triage plus a smart document checklist stops wasted court trips.
4. **Trust** - admin-verified advocates (Bar Council credentials), moderated reviews, immutable audit logs.

**The constraint that shaped every decision.** The entire stack runs at **$0/month** on free tiers (Supabase, Cloudflare, Groq, GitHub Actions) with local AI tooling, until the pilot proves retention (PRD §15).

---

## 2. Key Features (MVP)

| # | Feature | Description |
|---|---|---|
| **F1** | Secure Onboarding & OTP Login | Phone OTP (`+880`) via Supabase Auth on Web and Android, role selection (client/advocate/admin) carried in the JWT, and Bangla/English language choice. |
| **F2** | Advocate Profile, Specialization & Verification | Public profile (NID, Bar Council number, Sanad, years of practice, specializations, courts/districts, languages, fee range) with an admin verification state machine and annual re-verification. |
| **F3** | Emergency SOS - Arrest / Bail | One-tap SOS broadcast in real time to verified advocates in that district/court; the **first accept locks the SOS** via a DB transaction with row locking. |
| **F4** | AI Case Triage + Smart Document Checklist | Plain-Bangla situation overview plus an AI-suggested document checklist the advocate reviews and approves before it is treated as final. |
| **F5** | Case Overview & Timeline - Situation Tracker | A case timeline and situation tracker so the client sees hearings, dates, and status at a glance. |
| **F6** | AI Case Summary in Bangla - Human-in-the-Loop | AI drafts a plain-Bangla summary of events and next hearing date; the advocate edits and signs off with a 4-digit PIN before the client ever sees it. |
---

## 3. Architecture & Tech Stack

One codebase, two form factors. Flutter for Web and Android, Supabase Postgres as the single source of truth, and Cloudflare Workers as the AI gateway. No LLM inference ever runs inside the mobile app.

| Tier | Technology | Role |
|---|---|---|
| **Client** | Flutter 3.x / Dart 3.x | One codebase for Web + Android; responsive via `LayoutBuilder`, not separate apps |
| | `flutter_riverpod` 2.x | Compile-time safe state management, no `BuildContext` coupling |
| | `go_router` 14.x | Declarative routes with auth/role redirect guards |
| | `hive` + `hive_flutter` 2.x | Local cache and offline queue - **never authoritative** |
| | `supabase_flutter` 2.x | Auth, PostgREST, Realtime, Storage in one SDK |
| **Backend** | Supabase Postgres | Single source of truth; RLS, triggers, `pgvector`, `pgcrypto`, `pg_trgm` |
| | Supabase Auth | Phone OTP (`+880`), JWT (15-min access / 7-day refresh), `role` claim in `app_metadata` |
| | PostgREST + RPC | Auto REST over tables/views; RPC for atomic operations |
| | Supabase Realtime | Postgres changes over WSS; a channel per case / per district |
| | Supabase Storage | Buckets: `documents` (private), `avatars`, `sanad` |
| **Edge / AI** | Cloudflare Workers | `llm-gateway` route namespace `/v1/*`; PII redaction before any LLM call |
| | Cloudflare KV | Caches deterministic AI responses by input hash, TTL 24h |
| | Cloudflare Pages | Flutter Web build output, auto SSL, global CDN |
| **AI Models** | Groq API - `llama-3.x` | Production LLM. OpenAI-compatible `/chat/completions`, JSON mode |
| | llama.cpp + Qwen 2.5-7B GGUF (Q4_K_M) | Local/offline LLM at `localhost:8080`, OpenAI-compatible |
| | `BAAI/bge-m3` via Python/ONNX | Embeddings for RAG (build time), `vector(1024)` in `pgvector` |

### Environments

| Env | Supabase | Worker | `AI_PROVIDER` | Purpose |
|---|---|---|---|---|
| `local` | `supabase start` (Docker) | `wrangler dev` | `local` (llama.cpp) | Daily development, fully offline |
| `staging` | Separate free project | `wrangler deploy --env staging` | `groq` | PR previews, RLS tests, demo rehearsal |
| `prod` | Main free project | `wrangler deploy --env prod` | `groq` | Pilot users |

---

## 4. AI Subsystem & Security

### Hybrid AI - one interface, switchable backend

All AI access goes through a single `AIService` interface. The `AI_PROVIDER` environment variable selects the backend:

- `AI_PROVIDER=groq` → `https://api.groq.com/openai/v1/chat/completions`
- `AI_PROVIDER=local` → `http://localhost:8080/v1/chat/completions`

Both are OpenAI-compatible, so **prompts, JSON schemas, and app code do not change** when switching. This is what makes the offline demo possible: with `AI_PROVIDER=local` the entire demo runs against llama.cpp on a laptop. Every AI feature also has a rule-based fallback path, because **AI must never block the core flow** - if the LLM is down, SOS, tracking, and billing still work.

### Human-in-the-Loop (HITL)

**The AI never communicates directly with the client.** For F6:

---

## 5. Repository Structure (Monorepo)

Planned layout per TRD §11.1. Only `docs/` and `Design/` exist today; the remaining directories are built out as the team starts each tier.

```text
LegalLink/
├── apps/legal_link/          # Flutter app (web + android targets)
├── edge/worker/              # Cloudflare Worker (llm-gateway) + prompt files
├── edge/functions/           # Supabase Edge Functions (Deno/TS)
├── db/migrations/            # SQL migrations (supabase CLI)
├── db/seed.sql               # Checklist templates + demo data
├── db/tests/rls_test.sql     # RLS assertions run in CI
├── ai/                       # RAG build scripts + golden set
├── docs/                     # prd.md, trd.md, diagrams
├── Design/                   # UI/UX mockups and design assets
└── .github/workflows/        # ci.yml, deploy-web.yml, release-android.yml
```

---

## 6. Data Seeding & Cold Start

Because Bangladesh has no public court API, the app is populated for the demo and pilot by a **one-time Data Seeding phase** that scrapes public historical records and lawyer directories. This is not live scraping - ongoing case updates are entered manually by advocates.

| Target table | Source | Method |
|---|---|---|
| `advocates` | Supreme Court / Bar Council public directories | BeautifulSoup |
| `hearings` | Public Cause Lists (past 6 months) | PyPDF2 / BeautifulSoup |
| `legal_knowledge_base` | `bdlaws.minlaw.gov.bd` (Core Acts) | LangChain WebBaseLoader → chunk → embed (bge-m3) → `pgvector` |

Seeded advocates are inserted as `verification = 'pending'` - visible in search, but unable to accept an SOS until claimed and verified. Five "Wizard of Oz" demo accounts (2 clients, 2 advocates, 1 admin) anchor the scripted demo flow. Full rationale, including the viva talking points, is in TRD §20.

---

## 7. Contributing

This is an academic project. Contributions are from the 4-person team plus faculty reviewers.

- **Read first:** `docs/prd.md` (what we build) and `docs/trd.md` (how we build it). Most design questions are already answered there - please check before opening an issue.
- **Migrations:** `expand → migrate → contract`. Never edit an already-applied migration.
- **Before pushing:** `flutter analyze`, `dart format`, and `sqlfluff` must be clean. CI runs analyze, tests (60% coverage gate), the RLS assertion suite, and the 30-input golden AI set.
- **Never commit secrets.** `.env`, service-role keys, and the Groq/FCM keys live in GitHub Secrets / Supabase Vault. `.gitignore` already covers `.env`, `*.gguf`, `*.onnx`, and `*.bin`.
- **RLS changes are security changes.** Any new table needs its policies and assertions in `db/tests/rls_test.sql` in the same PR.

---

## 8. License

**Proprietary.** All rights reserved. This repository is an academic project and is not licensed for redistribution or commercial use.

---

<div align="center">

**LegalLink (আইন সহায়)** - built for the people of Bangladesh.

[Report an issue](https://github.com/Shafatcode007/LegalLink/issues) · [View source](https://github.com/Shafatcode007/LegalLink)

</div>
1. The advocate enters raw hearing notes (text or Bangla voice dictation).
2. The AI drafts a plain-Bangla summary covering **events and the next hearing date only** - never legal advice, never an outcome prediction.
3. The draft is stored with status `draft` and is **invisible to the client, enforced by database RLS, not by hiding a UI element**.
4. The advocate may edit the draft, then signs off with their **4-digit PIN** (stored hashed, never in plain text).
5. On publish: status → `published`, a real-time broadcast fires, and the client receives a push notification.

Escape hatches prevent orphaned drafts: an unpublished draft auto-archives after **7 days**, and the client sees "your lawyer has not posted an update yet". Every summary is logged with the model used, prompt version, tokens used, draft text, final text, and approver ID.

### Zero-Trust Security

Authorization lives in **Postgres Row-Level Security**, not in the UI. The client is never trusted, and there is no "security by UI hiding" - a caller who hits the API directly is subject to exactly the same policies. Supporting principles:

- **P1** Zero-trust authorization at the database - all access control lives in RLS.
- **P2** Single source of truth - Hive is a cache and offline queue, never authoritative.
- **P9** Auditability by default - every sensitive mutation writes an append-only `audit_logs` row.
- **P8** Fail loud, fail safe - RLS rejections and quota breaches surface to the user; no silent data loss.
| **F7** | Advocate Invoice & Billing | Itemised invoices and PDF generation with transparent totals, so fees are visible to the client. |
| **F8** | Cross-Device Sync - Chamber + Court | One product, two form factors: a case updated in the chamber is visible in court in real time (shared auth, shared data, Realtime). |

Four of these - **F4, F5, F6, F8** - are marked as mandatory faculty requirements (PRD §5), alongside the AI component, the post-SOS document checklist, the case overview system, and combined App + Web builds.

> **On rankings:** there is deliberately **no public win-rate ranking** (defamation/legal risk). Ranking uses verified experience, case-type match, court, fee fit, and professionalism/punctuality feedback only.