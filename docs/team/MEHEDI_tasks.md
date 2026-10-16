# ⚙️ Mehedi: AI/Integration & DevOps (Role C)
**Focus:** CI/CD pipeline, environment config, AI scaffolding, and infrastructure.
**Primary Stack:** Cloudflare Workers (TS), Hugging Face, GitHub Actions.

## 🟢 Sprint 1 (Week 1): Auth & Minimal Profiles
**Goal:** Set up the infrastructure so others can build without blockers.

### Tasks
1. **Local Auth Config:** Configure local Supabase Auth for Phone OTP (test OTP mode) and ensure the JWT includes the `role` claim in `app_metadata`.
2. **Arch-Lint:** Set up the `arch-lint` CI job to enforce the `presentation -> domain <- data` architecture.
3. **AI Stub:** Create the `AIService` stub in Flutter and the `ai/local_server/hf_server.py` smoke test script (just needs to boot and return a mock JSON).
4. **Pages Pipeline:** Set up the Cloudflare Pages preview pipeline for the Flutter Web build.

### 📦 What to Commit
- `edge/worker/` (Basic health check endpoint)
- `ai/local_server/hf_server.py`
- `.github/workflows/arch-lint.yml`

### ✍️ Commit Message Format
- `feat(infra): add AIService stub and local AI server`
- `ci: add arch-lint job to enforce clean architecture`
- `feat(infra): configure local Supabase Auth for test OTP`

---

## 🟡 Sprint 2 (Week 2): Document Verification + SOS Basics
**Goal:** Infrastructure for files and basic API limits.

### Tasks
1. **Storage Policies:** Configure Supabase Storage policies for the `sanad` and `documents` buckets (15-minute signed URLs, private buckets).
2. **Realtime Basics:** Scaffold the Realtime district channel basics (`sos:{district}`).
3. **Rate Limits:** Build the Worker `/v1/rate/check` endpoint to enforce the 3 SOS/24h limit.
4. **Deploy Pipeline:** Polish the `deploy-web.yml` and `deploy-worker.yml` GitHub Actions.

### 📦 What to Commit
- `edge/worker/src/routes/rate.ts`
- `db/migrations/` (Storage policies SQL)

### ✍️ Commit Message Format
- `feat(infra): add signed URL policies for document buckets`
- `feat(infra): scaffold rate limit endpoint and realtime channels`

---

## ✅ Definition of Done (DoD)
- [ ] `hf_server.py` boots locally on port 8080 and returns a valid JSON response.
- [ ] Cloudflare Pages successfully deploys a preview URL on PR creation.
- [ ] No API keys or secrets committed (use `.env.example`).
