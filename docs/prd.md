# LegalLink - Product Requirements Document (PRD)

| Field | Value |
|---|---|
| **Product** | LegalLink - Bangladesh's first Emergency Legal Access & Case Transparency Platform |
| **Platforms** | Android app + Web app (single Flutter codebase) |
| **Version** | 2.0 (revised after critical-flaw review: state machines, HITL escape hatch, offline sync rules, failure modes, rate limits, verification SLA, accessibility, retention, KPIs, testing, deployment, monitoring) |
| **Status** | MVP requirements - approved for implementation |
| **Target market** | Bangladesh |
| **Cost constraint** | $0/month - free tiers only (Supabase, Cloudflare, Hugging Face free tier, local AI) |
| **Team** | 4 developers (Backend/DB, Frontend/UI, AI & Business Logic, Admin & Ops) |
| **Timeline** | 8 weeks to MVP |

## 1. Executive Summary

LegalLink connects people in Bangladesh who suddenly need legal help (arrest, bail, disputes) with verified advocates (lawyers), and keeps clients informed about their case with plain-Bangla AI updates.

Core value proposition:
1. **Emergency SOS** - find a verified bail lawyer near the relevant Thana/court in minutes, not days.
2. **Case transparency** - clients track hearings, dates, and plain-language updates instead of depending on middlemen (dalals).
3. **Pre-hire readiness** - AI case triage + smart document checklist stops wasted court trips.
4. **Trust** - admin-verified advocates (Bar Council credentials), moderated reviews, immutable audit logs.

## 2. Problem Statement

When someone in Bangladesh is arrested, relatives are stressed and usually find a lawyer through a contact or a tout. They cannot compare experience, specialization, or fees. After hiring, clients depend on the lawyer or clerk to tell them the next hearing date and what happened at the last hearing. Missing information causes confusion, wasted trips, and exploitation by middlemen (dalals).

## 3. Vision

Give every person fast, transparent access to suitable legal representation and clear visibility into their case.

## 4. Target Users & Roles

| Role | Description | Primary goals |
|---|---|---|
| **Client / Family / Victim** | Person whose family member was arrested or who needs legal help | Find a lawyer fast, prepare documents, track the case, understand updates |
| **Advocate** | Verified legal professional | Receive clients (incl. SOS), update case progress, bill transparently |
| **Admin / Moderator** | Platform operator | Verify advocates, moderate reviews/complaints, monitor AI safety, audit |

Optional role (post-MVP): Clerk (Muharrir) as a sub-role under Advocate, with voice-first data entry.

## 5. Faculty / Project Requirements (Mandatory)

1. **AI Component** - product must contain a genuine AI feature.
2. **Document Checklist after SOS** - the SOS flow must lead into a smart document checklist.
3. **Case Overview System** - case timeline + situation tracker.
4. **App + Web versions** - both Android and Web builds.
5. **Proper Integration** - mobile and web are one product (shared auth, shared data, real-time sync).

## 6. MVP Feature Requirements (8 Features)

### F1. Secure Onboarding & OTP Login (P0)

**User stories**
- As a client, I want to log in with my +880 phone number via SMS OTP so I don't need passwords.
- As an advocate, I want to register and log in with phone OTP so onboarding is fast.
- As a user, I want to select my language (Bangla/English) so I can read the app in my language.

**Acceptance criteria**
- Phone OTP login (Supabase Auth) works on both Web and Android.
- Role selection on first login (client / advocate / admin); role stored in profile and carried in the JWT.
- Advocate registration collects: full name, NID number, Bar Council enrollment number, Sanad (certificate) photo, courts, specializations, fee range, languages.
- Advocate sets a 4-digit summary-approval PIN during onboarding (hashed, never stored in plain text; changeable in profile; locked after 5 failed attempts).
- One account works on all devices (same session).
- If the SMS OTP does not arrive: resend after 30 s, max 3 attempts per 5 minutes, then show "try email OTP / contact support".

---

### F2. Advocate Profile, Specialization & Verification (P0)

**User stories**
- As a client, I want to see a verified advocate's years of practice, specializations, courts and fee range so I can compare before hiring.
- As an advocate, I want to manage my profile (specializations, courts, fees, languages, availability) so the right clients find me.
- As an admin, I want to approve or reject advocate verification so only real lawyers appear in search.

**Acceptance criteria**
- Profile fields: name, photo, NID, Bar Council number, Sanad, years of practice, specializations (criminal / bail / family / property / labor / women & child), courts/districts, languages, fee range, availability settings.
- **Verification procedure:**
  - Required documents: Sanad (Bar Council enrollment certificate) photo + NID photo + Bar Council enrollment number.
  - Admin manually cross-checks the enrollment number on the Bangladesh Bar Council public site (no public API exists for the MVP).
  - **SLA: verification decision within 48 hours** of submission; applicant is notified either way.
  - **Rejection flow:** rejection reason shown; advocate may re-apply after correcting (max 3 attempts, then admin chat).
  - **Annual re-verification reminder** for every verified advocate; unverified-in-90-days advocates are hidden from new SOS/search but keep existing cases.
- Verification state machine: `pending -> verified / rejected`.
- Verified badge displayed in search results and profiles.
- NO public "win-rate" ranking (defamation/legal risk). Ranking basis: verified experience, case-type match, court, fee fit, and professionalism/punctuality feedback only.

---

### F3. Emergency SOS - Arrest / Bail (P0)

**User stories**
- As a family member, I want to tap one button and describe the arrest so nearby bail lawyers are informed immediately.
- As an advocate, I want SOS alerts for my court/district with accept/reject so I can grow my caseload.
- As a client, I want to know within ~15 minutes whether a lawyer accepted so I can plan next steps.

**Acceptance criteria**
- SOS capture form: person's name, Thana/police station, district/court, charges (if known), arrest time, NID (if available), urgency, contact number.
- SOS broadcast in real time to verified advocates in that district/court (Supabase Realtime + FCM push).
- First accept locks the SOS: a DB transaction with row locking so two advocates cannot accept the same SOS.
- Client is notified instantly with the accepting advocate's details.
- Every SOS state change is written to the audit log.

**SOS -> Case -> Checklist state machine (race-condition rule):**
```
SOS: open --accept--> accepted --create--> case created
                                  |
                                  v
                ai_triage_session runs -> checklist items created
                each item status: suggested_pending_advocate
                                  |
        Advocate review (target < 2 h): edit + approve
                                  |
                                  v
                item status -> approved (client sees "Approved by your lawyer")
```
- Before advocate approval the client CAN see the checklist, clearly labeled **"Suggested - your lawyer will confirm shortly"** with a banner. The client may start gathering/uploading documents early (uploads stay in `needs_review`).
- If the advocate has not reviewed within 48 h: the checklist auto-converts to "general list" mode with the standard disclaimer; a reminder is sent to the advocate.
- Declined/cancelled/expired SOS (no accept in 24 h): client is notified, can edit and re-post (counts toward the rate limit, section 13).

---

### F4. AI Case Triage + Smart Document Checklist (P0 - Faculty Requirement)

**User stories**
- As a client, I want the app to tell me which documents to prepare for my case type so I stop wasting court trips.
- As a client, I want to describe my situation in plain Bangla and get a clear "situation overview" before I even hire a lawyer.
- As an advocate, I want to review and approve the AI-generated checklist so the client prepares exactly what I need.

**Acceptance criteria**
- Intake: case-type selection + 3-6 contextual questions (arrested? FIR copy available? medical papers? property documents? witnesses?).
- Rule-based foundation: admin-managed checklist templates per case type (criminal/FIR, bail, family, property/land, women & child). Each item: document name, importance, purpose.
- AI personalization: the LLM receives the approved template + intake answers and outputs strict JSON with the recommended items, urgency notes and next steps. AI only *customizes* the template - it never invents a free-form list (hallucination control).
- **Checklist item state machine:**
  `suggested_pending_advocate -> approved / rejected -> (upload) uploaded -> needs_review -> approved / rejected`
- Lawyer approval flow as defined in F3; without an assigned advocate the app shows the general list with a warning: "This is a general document list. Please confirm with a verified lawyer."
- Document upload per checklist item (photo/PDF) with resumable upload and progress; a failed/corrupt upload is retryable and never leaves a half-file in the vault.
- Reminders: push notification when a required document is still missing before the next hearing.
- **AI safety (mandatory):** disclaimer on every output ("general information, not legal advice"); PII redacted before the LLM call; output stored with model name + prompt version.

---

### F5. Case Overview & Timeline - Situation Tracker (P0 - Faculty Requirement)

**User stories**
- As a client, I want to see my case timeline with hearing dates and what happened at each hearing, so I always know the current status.
- As a client, I want a reminder before my next hearing date so I never miss it.
- As an advocate, I want to log hearing outcomes and next dates in under a minute, so updating is effortless.

**Acceptance criteria**
- Case record: case number, court, case type, parties, assigned advocate, status (`created -> active -> closed -> archived`).
- Hearings: date, court, outcome/notes, next hearing date - entered by the advocate (text or voice-to-text dictation).
- Client timeline view (chronological, plain language) shows **only published** updates.
- Push + in-app reminders for upcoming hearings (FCM) with configurable lead time.
- Dashboard "situation" banner: latest outcome + next hearing at a glance.
- All updates real-time sync to the client's devices (F8).
- **Edge cases (required):**
  - *No hearings yet:* timeline shows an empty state: "Your case has started. Your first hearing will appear here when your advocate schedules it."
  - *Editing after publication:* a published hearing record is immutable; the advocate creates a **new version** with an "Amended" tag and link to the previous one. Clients always see the latest version.
  - *Next-date changes:* every change to a future hearing date is a logged timeline event ("Hearing rescheduled from X to Y"), so old dates never silently disappear.
  - *Closed cases:* remain visible to both parties, read-only, and move to an archive section after 90 days.

---

### F6. AI Case Summary in Bangla - Human-in-the-Loop (P0 - Faculty Requirement)

**User stories**
- As an advocate, I want to dictate raw hearing notes and get a clean Bangla summary drafted for my client, so I don't spend 20 minutes writing.
- As a client, I want a plain-Bangla summary of what happened at the hearing, so I understand without legal jargon.
- As an admin, I want to review flagged AI outputs so unsafe content is caught.

**Acceptance criteria (HITL - non-negotiable)**
- Advocate enters raw hearing notes (text or voice -> text).
- AI drafts a plain-Bangla summary: events + next hearing date **only** - never legal advice, never outcome prediction.
- Summary is stored with status `draft` - invisible to the client (enforced by RLS, not just UI).
- The advocate can edit the draft, then signs off with a 4-digit PIN (hashed) to publish.
- On publish: status -> `published`; real-time broadcast; client receives a push notification and sees the summary.
- Every summary is logged: model used, prompt version, tokens used, draft text, final text, approver ID.
- Admin AI-safety dashboard can flag/inspect any summary.
- **The AI never communicates directly with the client.**

**HITL escape hatch (required - no orphaned drafts):**
- **Draft expiry:** a draft not published within **7 days** is auto-archived with a notification to the advocate; the client sees "your lawyer has not posted an update yet".
- **Client reminder:** a "Request update" button on the case screen pings the advocate (max 1 per 24 h per client per case).
- **Advocate unavailability:** if the assigned advocate has no activity for 14 days, the client is offered "contact support / request a new advocate" (case transfer keeps full history; transfer is logged).
- **Admin override:** in genuine emergencies an admin may force-publish a draft, with a mandatory reason field; this action is permanently audit-logged and the client sees "published by platform staff on your lawyer's file".
- **PIN security:** PIN set at onboarding, changeable in profile; 5 failed attempts -> 30-minute lockout; 3 lockouts -> admin-assisted reset.

---

### F7. Advocate Invoice & Billing (P0)

**User stories**
- As an advocate, I want to create itemized invoices (professional fee, court fees, stamp duty, other charges + 15% VAT) so billing is transparent and professional.
- As a client, I want to see itemized invoices with payment status so I know what I paid and what is pending.
- As an advocate, I want to mark invoices as paid when I receive a bKash/Nagad transfer, so I can track collections.

**Acceptance criteria**
- Invoice with line items (description + amount), subtotal, 15% VAT, total.
- **Numbering:** `INV-{YEAR}-{SEQUENCE}` (e.g. INV-2026-0042), sequence resets every 1 January, unique per advocate, never reused (a voided invoice keeps its number with status `void`).
- **Currency formatting:** BDT symbol, thousands separators, 2 decimal places; server-side formatting rules (not device-locale-dependent).
- **PDF generation: server-side** (Cloudflare Worker renders a signed, shareable PDF URL with a 15-minute expiry). The client can also save a view-only copy inside the app.
- Status machine: `draft -> sent -> partially_paid -> paid / overdue / void`.
- **Partial payments:** each payment entry records amount, date, method (bKash/Nagad/Cash/bank) and transaction ID; an invoice stays `partially_paid` until the balance is zero.
- **Overdue handling:** automated reminders at **3, 7 and 14 days** overdue; after 30 days the invoice is flagged for the advocate (no automatic penalties - that is a legal decision outside the app).
- Invoices are linked to a case; a client can view only their own invoices; every status change is audit-logged.
- Credit notes / refunds: post-MVP (P2) - until then handled by a `void` + new invoice with a note.

---

### F8. Cross-Device Sync - Chamber + Court (P0 - Faculty Requirement)

**User stories**
- As an advocate, I want to log in on my chamber PC (web) and my phone (Android), so I update a case in court and see it in the chamber.
- As a client, I want the app and the web version to always show the same data.
- As an advocate, I want the app to keep working in court with poor internet and sync when I'm back online.

**Acceptance criteria**
- Single Flutter codebase: one account, one session across Web + Android.
- Supabase Realtime: changes propagate to all logged-in devices with < 1 s latency (optimistic local update first).
- Optimistic updates: local Hive cache updates instantly, then syncs to Supabase.
- **Offline sync rules (explicit):**
  - *Writes (text/fields):* queued in `offline_sync_queue` with timestamp + actor; replayed in order on reconnect. Normal fields: last-write-wins by `updated_at`. Critical fields (consent, payment, PIN-protected publish): version-based optimistic locking - a stale write is **rejected and shown as a conflict** for the user to resolve manually.
  - *Files:* an offline capture stores a local reference + metadata; the byte upload happens when online. Until upload completes the record shows "uploading - visible on this device only". A mid-upload interruption resumes from the last chunk (resumable upload), never leaving a corrupt file.
  - *Deletes:* tombstone pattern - the delete is queued and, on sync, the row is soft-deleted (`deleted_at`) after a server-side re-check of permissions. If the row was protected/changed server-side, the user sees a conflict explanation.
  - *JSONB fields:* last-write-wins with **full replacement** of the JSON value (no deep merge), safe because all JSONB fields are AI outputs or form payloads regenerated as a whole.
  - *Queue limits:* max **100 queued operations** per device; at 50 the UI shows "low connectivity - changes will sync later"; at 100 new writes are blocked with a clear message.
  - *Consent conflict rule:* a client's consent revocation **always wins** over any in-flight advocate write - the write fails and is reported.
  - *Visibility:* a persistent "Syncing... / All changes saved / N changes waiting" indicator on every synced screen.
- Same RLS policies, same file access (signed URLs), same notification triggers on both platforms.
- Responsive UI: mobile layout (< 600 px, bottom nav) vs web layout (sidebar).
- **Critical-path invariant:** two advocates can never accept the same SOS (DB transaction + row lock).

## 7. Secondary Features (Post-MVP Backlog)

| # | Feature | Priority |
|---|---|---|
| 9 | Legal Rights Chatbot (RAG over BD laws; general info only, with source citation + disclaimer) | P1 |
| 10 | AI Advocate Recommendation (ranked by case-type match, experience, court, fee fit) | P1 |
| 11 | Role-specific Dashboards (client / advocate / admin) | P1 |
| 12 | Consultation Booking & fee transparency | P1 |
| 13 | Client Reviews & advocate reputation (moderated; professionalism/punctuality only) | P1 |
| 14 | Complaints & Dispute Resolution (client -> admin) | P1 |
| 15 | Real-time Admin Analytics (SOS response time, case volume, AI flags) | P1 |
| 16 | Legal Aid Directory (free/low-cost help for those who can't afford fees) | P2 |
| 17 | Clerk (Muharrir) sub-role with voice-first data entry | P2 |
| 18 | Digital Vakalatnama / deed generator | P2 |
| 19 | AI document vision (Sanad OCR verification, court-order PDF OCR) | P2 |
| 20 | Credit notes / refund flow (invoicing) | P2 |

## 8. AI Component Requirements

### 8.1 AI Features
| # | Feature | Scope |
|---|---|---|
| A | Case Triage + Document Checklist personalization | **MVP (F4)** |
| B | Case Update Summarizer with Human-in-the-Loop | **MVP (F6)** |
| C | Legal Rights Chatbot with RAG | P1 (Feature 9) |

### 8.2 Hybrid AI Architecture (Required)
- One `AIService` interface inside the Flutter app; the backend is chosen by `.env` (`AI_PROVIDER`).
- `AI_PROVIDER=production` -> **Hugging Face Serverless Inference API (e.g., Qwen 2.5-7B)**, OpenAI-compatible endpoint, free tier.
- `AI_PROVIDER=local` -> **Hugging Face transformers local server** running **Qwen 2.5-3B (or custom fine-tuned model)** on `localhost:8080` (dev machine: ASUS TUF A15, RTX 4050 6GB VRAM).
- Same prompts and same JSON schemas on both backends - switching is a URL change; no app code changes.
- All LLM calls pass through a **Cloudflare Worker** that performs **PII redaction** (names, NID numbers) before the text reaches any model.
- Extraction/triage calls use strict JSON schema output (`response_format: json_object`) and temperature <= 0.2.
- **AI failure fallback:** if the LLM call fails or times out (> 30 s), the user is shown the rule-based template output (no AI) with a note; the request is retried once in the background. AI features must never hard-block the core flow.

### 8.3 RAG Knowledge Base (Chatbot, P1)
- Sources: `sakhadib/Bangladesh-Legal-Acts-Dataset` from Hugging Face (filtered to 15-20 core acts for MVP).
- Cleaning: strip HTML, fix Bangla Unicode, anonymize names.
- Chunking: 300-500 word sections -> target 2,000-5,000 searchable chunks.
- Embeddings: `BAAI/bge-m3` (local, free, excellent Bangla support) -> Supabase **pgvector** table `legal_knowledge_base`.
- Query: embed question -> top 3-5 similar chunks -> answer with **source citation** (e.g. "CrPC Section 496") + disclaimer. If no relevant chunk is found -> respond "Consult an advocate".

### 8.4 AI Safety Golden Rules
1. **No legal advice, ever.** AI output is general information only; every screen carries a disclaimer; users are always directed to a verified advocate.
2. **Human-in-the-Loop.** Summaries remain `draft` until the advocate's PIN approval; clients never see drafts.
3. **RAG grounding.** Chatbot answers only from retrieved BD-law chunks; otherwise it defers to a lawyer.
4. **PII protection.** Redaction before LLM calls; model providers are used in a no-training configuration.
5. **Full audit.** Every AI output is logged (model, prompt version, input hash, output, reviewer/flag).

## 9. Non-Functional Requirements

| Area | Requirement |
|---|---|
| **Cost** | $0/month for MVP: Supabase free tier (Postgres, Auth, Realtime, 1 GB Storage, pgvector), Cloudflare Workers/Pages free tier, Hugging Face free tier, local AI. |
| **Performance** | Must run on low-end Android (2 GB RAM). Targets: APK < 50 MB; cold start < 3 s; page load < 2 s on 3G; API p95 < 500 ms; advocate-search queries < 100 ms; support 500 simultaneous active sessions on free tiers. Heavy AI NEVER runs in Flutter memory - offloaded to the Cloudflare Worker (HF Serverless) or the local HF transformers server. |
| **Offline** | Core read flows (case timeline, checklists, documents) work offline via Hive cache; mutations queue in `offline_sync_queue` (rules in F8). |
| **Security (5 layers)** | 1) TLS in transit; 2) Phone OTP + JWT (15-min access / 7-day refresh, role claim); 3) RLS on **every** table (client sees only own cases, advocate only assigned, admin sees all but every admin action is logged); 4) AES-256 at rest + 15-minute expiring signed URLs for sensitive documents; 5) immutable audit trail for every sensitive action. |
| **Privacy** | Explicit consent record (client -> advocate, scoped, revocable) before case data is shared; access revoked when the engagement ends; case data treated as highly sensitive. |
| **Languages** | Bangla-first UI, English toggle; AI summaries in plain Bangla with legal terms kept in brackets. |
| **Accessibility** | WCAG 2.1 AA target. Every critical action has icon + text (no icon-only buttons); voice input available for all text entry; minimum 48x48 dp touch targets; high-contrast mode; Bangla font fallback for old devices; status shown by text/badge, never color alone; full keyboard navigation on web; screen-reader labels on all interactive elements. |
| **Compliance** | No public win-rate rankings; moderated reviews; disclaimers on every AI screen; Bar Council verification for advocates; aligned with the Digital Act / DPA 2023 context on data handling (see retention, section 10). |
| **Scalability** | 0-500 users on free tiers without redesign; documented path to paid tiers at 500-5,000 users (~$75/mo) and 5,000-50,000 (~$500/mo). |

## 10. Data Requirements (Core Tables - MVP)

| # | Table | Purpose / key fields |
|---|---|---|
| 1 | `profiles` | Extends `auth.users`: role, language, phone |
| 2 | `advocates` | NID, Bar Council number, Sanad URL, specializations, courts, fee range, verification status + dates |
| 3 | `sos_requests` | Status `open -> accepted / declined / cancelled / expired`, district, court, thana |
| 4 | `cases` | Type, court, status, parties, assigned advocate |
| 5 | `consents` | Client -> advocate, scope, granted/revoked timestamps (critical for legal compliance) |
| 6 | `hearings` | Date, court, outcome notes, next date, entered_by, version/amended flag |
| 7 | `ai_summaries` | Status `draft -> published / archived`, model, prompt version, tokens, draft/final text, approver, published_by (advocate or admin override) |
| 8 | `invoices` | Number (INV-YEAR-SEQ), totals, VAT (15%), status machine, payment refs |
| 9 | `invoice_items` | Line items (description, amount) |
| 10 | `documents` | Signed storage URLs, case link, status, local-reference for offline uploads |
| 11 | `checklist_templates` | Admin-managed, per case type |
| 12 | `checklist_items` | Per-case instance, status `suggested_pending_advocate -> approved/rejected -> uploaded -> needs_review -> approved/rejected` |
| 13 | `ai_triage_sessions` | Input hash, output JSON, model, prompt version |
| 14 | `audit_logs` | **Immutable, append-only** (user, action, timestamp, IP, device) |

Extension tables (P1+): `reviews`, `complaints`, `consultation_bookings`, `legal_knowledge_base` (pgvector), `notifications`, `offline_sync_queue` (device, op, payload, created_at, synced_at).

**RLS rules (enforced at the database, zero-trust):**
- Client: read only rows where `client_id = auth.uid()` AND status is published/approved.
- Advocate: read/write only cases assigned to them.
- Admin: read all; every admin write is mirrored to `audit_logs`.

**Data retention policy (required):**
- Closed cases: read-only for 90 days, then archived (kept, hidden from default views).
- Documents: advocate may request deletion of a document at case closure; deletion is a soft delete + storage purge after 30 days, logged.
- AI triage sessions: raw input retained 30 days, then the raw text is dropped (output JSON + hash kept).
- `ai_summaries`: retained for the life of the case (dispute evidence).
- **User deletion right:** a client can request account deletion; case data tied to active engagements is not destroyed but access is sealed; admin logs the request.
- `audit_logs`: retained **5 years** (legal-hold), never deleted.

## 11. Technology Stack (Fixed)

| Layer | Technology | Reason |
|---|---|---|
| App (Web + Android) | **Flutter + Dart** | One codebase for both platforms |
| State management | **Riverpod** | Compile-time safety, testability |
| Local cache | **Hive** | Fast, no native code, works on web |
| Backend | **Supabase** (Postgres, Auth, Realtime, Storage, pgvector, RLS) | Zero cost; RLS = zero-trust authorization |
| Edge / AI gateway | **Cloudflare Workers** (free tier) | PII redaction, AI caching, rate limits, invoice PDF rendering |
| AI (production) | **Hugging Face Serverless API - Qwen 2.5-7B** (OpenAI-compatible) | Free tier, ~500 tok/s |
| AI (local demo) | **Hugging Face transformers server + Qwen 2.5-3B (or fine-tune)** on RTX 4050 | Offline faculty demo, no vendor lock-in |
| Embeddings | **bge-m3** (local) | Free, excellent Bangla |
| Notifications | **Firebase Cloud Messaging** (free) | Android push; web in-app + toast |
| CI/CD | **GitHub Actions** -> Cloudflare Pages (web) + signed APK (Android) | Free, reproducible releases |
| Payments (MVP) | **Manual bKash/Nagad** verification | Zero upfront gateway cost |

**Localization architecture:**
- Translations in Flutter ARB i18n files (assets), not in the DB.
- `bn` is primary, `en` is fallback; any missing key falls back to English with a dev warning.
- Dates/numbers formatted with `intl` in BDT/Bangladesh locale (e.g. DD/MM/YYYY, BDT currency).
- AI-generated text is not run through i18n (it is generated directly in Bangla).

## 12. Mobile <-> Web Integration (Required Behaviors)

- Same authentication session, same RLS policies, same signed file URLs, same notification triggers on both platforms.
- Supabase Realtime WebSocket: any change propagates to all devices in < 1 s (optimistic local update first).
- Conflict resolution: last-write-wins (`updated_at`) for normal fields; version-based optimistic locking for consent/payment fields; offline queue replay on reconnect (full rules in F8).
- **Critical-path invariant:** two advocates can never accept the same SOS (DB transaction + row lock).

## 13. Rate Limiting & Abuse Prevention (Enforced in Cloudflare Worker + DB checks)

| Action | Limit | On breach |
|---|---|---|
| SOS posted by a client | 3 per 24 h | Block with "limit reached, try again in X h" |
| Active (unresolved) SOS per advocate | 5 concurrent | New alerts queued, not shown, until one is handled |
| AI triage requests per client | 10 per 24 h | Block further AI calls, template-only output |
| Summary drafts per case | 20 per 24 h | Block, notify advocate |
| PIN attempts | 5 per 30 min | 30-min lockout; 3 lockouts -> admin reset |
| Reviews | 1 per case, 7-day global cooldown after case closure | Block submission |
| Complaints | 5 per user per 30 days | Block, escalate to admin queue |
| OTP requests | 3 per 5 min per phone | 15-min cooldown + captcha on web |
| File uploads | 50 per case, 20 MB per file | Block with explanation |
| General API | 300 req/min per JWT, 1000 req/min per IP | 429 + exponential backoff |

All abuse events are logged in `audit_logs` with the offending ID for admin review.

## 14. Failure Modes & Fallbacks

| Failure | User sees | System behavior |
|---|---|---|
| Hugging Face Serverless down / rate-limited | "AI is busy - showing standard list/summary" | Retry once in 60 s; fall back to rule-based template (checklist) or plain formatted text (summary draft); core flows never blocked |
| Local HF transformers server unavailable | Same as above | Router detects no `localhost:8080` and reports AI-off mode; app degrades gracefully |
| LLM output invalid JSON / fails schema | Nothing wrong visible | Discard, retry once with stricter prompt; then template fallback + log |
| FCM push fails | Data is still in the app | Push is best-effort; in-app timeline is the source of truth; delivery failure logged, retried 3x |
| Supabase Realtime disconnects | "You are offline - showing cached data" badge | Reconnect with exponential backoff; on reconnect, full delta fetch of subscribed tables |
| OTP SMS not delivered | "SMS not arrived? Resend in 30 s / try email OTP" | Resend after 30 s, 3 attempts, then email OTP + support contact |
| File upload fails mid-way | "Upload incomplete - retry" | Resumable upload from last chunk; failed attempt never stored as a document |
| Payment verification disputed | Invoice shows "verification pending" | Invoice stays `sent`; advocate/admin can attach the transaction proof; disputed state logged |
| DB write rejected (RLS/lock) | Clear error, no silent failure | Optimistic UI rolls back with a message naming the cause |
| Admin verification queue backlog | Advocate sees "under review (SLA 48 h)" | SLA breach flags the queue for admin dashboard |

## 15. KPIs & Success Metrics (MVP, first 4 weeks after pilot launch)

| KPI | Target | Why |
|---|---|---|
| SOS -> first advocate acceptance time | p50 < 15 min in pilot districts | Core value proposition |
| SOSs accepted at all | > 60% | Adoption signal |
| Checklist completion (docs uploaded / required) | > 70% per case | "no wasted court trip" impact |
| Draft summary published within 7 days | > 90% | HITL escape hatch works |
| Client retention (opened app week 2+) | > 30% | Habit/usage |
| Advocate weekly active | > 50% of verified advocates | Two-sided marketplace health |
| Client satisfaction (1-5 after case milestone) | > 4.2 | Trust |
| AI outputs flagged as unsafe by admin | < 2% | AI safety |
| Critical (P0) bugs in pilot | 0 | Stability |

## 16. Success Criteria (Demo Day)

1. **Complete live flow:** SOS -> advocate accepts -> case created -> AI checklist generated ("Suggested") -> advocate approves checklist -> hearing logged -> AI Bangla summary drafted -> advocate signs with PIN -> client sees it on phone while the advocate works from the web.
2. **Offline demo:** airplane-mode on the phone, browse case, log an update, reconnect, watch it sync.
3. **Hybrid AI demo:** run `AI_PROVIDER=local` (Qwen 2.5-3B via hf_server.py, no internet) and `AI_PROVIDER=production` (Hugging Face Serverless) with the same code; then demo the AI-down fallback (template output).
4. **Security proof:** demonstrate an RLS policy blocking one client from reading another client's case.
5. **Abuse proof:** show the SOS rate limit and PIN lockout in action.
6. All 8 MVP features work end-to-end on **both** Web and Android.

## 17. Key Risks & Mitigations

| Risk | Mitigation |
|---|---|
| AI hallucination on legal content | HITL sign-off, rule-based checklist foundation, RAG grounding, strict JSON schemas, temperature <= 0.2, mandatory disclaimers |
| Liability (app "advises" wrongly) | AI never talks to clients; general-info framing only; advocate approval for every published summary |
| Advocate adoption (the #1 fatal flaw - this is a trust problem, not a tech one) | 7-day "Wizard of Oz" validation before building; advocate advisory meeting; 5-10 pilot advocates; clerk-first, voice-entry UX to save advocates time |
| Fake advocates / fake reviews | Admin verification against Bar Council number + Sanad (48 h SLA, annual re-verification); review moderation + rate limits |
| Dalal (tout) backlash | No public win-rate ranking; discreet professionalism/punctuality signals only |
| Data extortion / ransomware | RLS, signed URLs, minimal PII in LLM calls, immutable audit logs, encrypted storage |
| Scope creep | Only 8 features in MVP; everything else parked in section 7 backlog |
| Low-end hardware (2 GB RAM phones) | Lightweight Flutter app, all AI off-device, aggressive caching |
| Free-tier limits (Supabase/Cloudflare/Hugging Face) | Rate limits (section 13), AI caching in Workers, usage monitoring; scale plan documented |

## 18. Out of Scope (MVP)

- Live integration with official court systems for real-time updates (no public BD court API exists - ongoing data is entered by the lawyer/clerk). *Note: One-time historical data seeding via scraping is IN scope for the MVP demo (see TRD Section 20).*
- Automatic payment gateway integration (bKash/Nagad auto-verification is post-MVP).
- Separate clerk login (post-MVP sub-role).
- Win-rate rankings or rating games.
- Credit notes / refunds (void + new invoice until P2).
- Model fine-tuning (optional faculty bonus only; if attempted, use Google Colab T4 - the RTX 4050's 6 GB VRAM is insufficient).
- Multi-country support; languages other than Bangla + English.

## 19. Deployment & Release Strategy

- **Web:** Cloudflare Pages, deployed on every merge to `main`; a `staging` deployment on every PR for review.
- **Android:** signed APK built by GitHub Actions on version tags; released as a GitHub Release with a direct download link for the pilot; Play Console (internal testing) in month 2.
- **Environment config:** `dev / staging / prod` via Supabase project + `.env`; AI_PROVIDER per environment.
- **Rollback:** every release is tagged and reproducible; DB migrations are backward-compatible within one release (expand -> migrate -> contract pattern); a bad release is rolled back by redeploying the previous tag.
- **Release cadence (8 weeks):** internal alpha end of Sprint 2, Wizard-of-Oz pilot end of Sprint 3, faculty-ready build end of Sprint 4.

## 20. Testing Strategy

- **Unit (every PR):** Dart unit tests for domain entities and use cases (TDD: RED -> GREEN -> REFACTOR).
- **Widget tests:** critical screens (SOS form, checklist, timeline, PIN publish) on both form factors.
- **Integration:** Supabase local (Docker) + RLS policy tests - a dedicated suite asserts every "client A cannot read client B" boundary.
- **AI golden set:** 30 fixed Bangla inputs with expected JSON schemas; run on Hugging Face Serverless and the local HF transformers server in a manual CI check; block merge on schema failure.
- **Manual checklist:** 20-item pilot test script covering the demo-day flow, offline flow, and abuse limits.
- **Load sanity:** 50 concurrent realtime subscribers on a case channel without dropped events (free-tier smoke test).

## 21. Monitoring & Alerting

- **Supabase dashboard:** DB size, active connections, slow queries - weekly manual review (MVP), alerts on free-tier usage at 80%.
- **Cloudflare Workers analytics:** error rate > 5% or p95 > 1 s -> email alert to the 4-person team (single mailbox, on-call rotation by sprint).
- **FCM delivery:** weekly delivery-rate check; > 10% failure -> investigate.
- **AI monitoring:** daily count of schema-failures / fallbacks from `ai_triage_sessions` + `ai_summaries`; > 2% unsafe flags -> emergency review.
- **Escalation:** any P0 (data leak, RLS bypass, payment corruption) -> all four developers, phone tree, incident note in the audit log.

## 22. Open Questions (to resolve with the pilot advocate)

1. Is 48 h a realistic verification SLA for a 4-person team with manual Bar Council checks?
2. Exact wording of disclaimers (Bangla) - to be reviewed by a practicing advocate + faculty.
3. Pilot districts/courts and which 5-10 advocates join the Wizard-of-Oz test.
4. Should the client "Request update" reminder also fire for stuck SOSes (not just summaries)?
5. Fee-range display: bands (e.g. "<5k / 5-15k / 15k+") vs exact numbers - Bar Council ethics check needed.

## 23. Glossary

| Term | Meaning |
|---|---|
| Advocate | Lawyer in Bangladesh (Bar Council enrolled) |
| Sanad | Bar Council enrollment certificate |
| Thana | Police station |
| Dalal | Court middleman / tout |
| FIR | First Information Report |
| Vakalatnama | Engagement/authorization letter for an advocate |
| Muharrir | Advocate's clerk |
| HITL | Human-in-the-Loop (AI drafts, human approves) |
| RLS | Row-Level Security (Postgres/Supabase) |
| RAG | Retrieval-Augmented Generation |
| Tombstone | A queued delete that soft-deletes a row on sync |
| DPA 2023 | Bangladesh's proposed Data Protection Act (context for retention policy) |

---
*Source: consolidated from the full LegalLink project history - feature story map (16 -> 24 features), faculty-requirement mapping (8-feature MVP), feasibility study, hybrid AI architecture decisions, the final technical blueprint (20-table schema, data flows, 5-layer security model) - and revised v2.0 against the critical-flaw PRD review: explicit state machines (SOS->Case->Checklist), HITL escape hatch (draft expiry, client reminder, admin override, PIN policy), offline sync rules (files, deletes, JSONB, queue limits), failure modes, rate limits, verification SLA, invoice numbering/formatting, accessibility, data retention, KPIs, testing, deployment, and monitoring.*
