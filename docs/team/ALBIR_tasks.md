# 🛡️ Albir: Client UI - Admin & Shared Components (Role B2)
**Focus:** The admin workflow, shared UI components, and complex UI states.
**Primary Stack:** Flutter/Riverpod, GoRouter, Hive.

## 🟢 Sprint 1 (Week 1): Auth & Minimal Profiles
**Goal:** Build the shared library and the admin verification queue.

### Tasks
1. **Shared UI Library:** Build `VerifiedBadge` (Forest green, seal-check glyph, "যাচাইকৃত"), `MinTapTarget` wrapper, and custom Buttons (Ribbon, Primary, Secondary).
2. **Admin Queue UI:** Build the Admin Verification Queue (List of pending advocates with "Approve" / "Reject" buttons) using **mock data**.
3. **Advocate Profile:** Build the Advocate Profile View screen (showing name, bar council no, and the verified badge).

### 📦 What to Commit
- `apps/legal_link/lib/shared/widgets/` (VerifiedBadge, Buttons, MinTapTarget)
- `apps/legal_link/lib/features/admin/` (Admin queue UI)

### ✍️ Commit Message Format
- `feat(ui): add VerifiedBadge and shared button components`
- `feat(ui): add admin verification queue UI (mock data)`

---

## 🟡 Sprint 2 (Week 2): Document Verification + SOS Basics
**Goal:** Complex UI states and integrating real-time alerts.

### Tasks
1. **Admin Document Review:** Update the Admin Verification Queue to display uploaded document previews via secure, temporary signed URLs.
2. **Single Accept Flow UI:** When an advocate taps Accept, the UI must instantly lock and show "Case Created".
3. **Losing Advocate UI:** Handle the UI state for a "Losing Advocate" (showing "This SOS is already taken" when the backend returns `null`).
4. **Sync Badge:** Implement the `SyncBadge` and offline/queued UI states for the SOS form.

### 📦 What to Commit
- `apps/legal_link/lib/features/admin/` (Wired to real backend)
- `apps/legal_link/lib/features/sos/` (Advocate inbox and accept/decline UI)

### ✍️ Commit Message Format
- `feat(ui): wire admin queue to real backend with signed URLs`
- `feat(ui): add advocate inbox and single-accept flow UI`

---

## ✅ Definition of Done (DoD)
- [ ] `flutter analyze` and `dart format` are clean.
- [ ] No generic circular spinners; use the specific loading metaphors from `ui_ux.md` §4.2.
- [ ] Wednesday: Mock repositories are swapped for real Supabase calls.
