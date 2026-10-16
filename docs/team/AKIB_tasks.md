# 🎨 Akib: Client UI - Auth & Onboarding (Role B1)
**Focus:** The user's first experience. Building against mock data first, then swapping to real backend.
**Primary Stack:** Flutter/Riverpod, GoRouter, Hive.

## 🟢 Sprint 1 (Week 1): Auth & Minimal Profiles
**Goal:** Get the user logged in and into the app.

### Tasks
1. **Flutter Init:** Initialize the Flutter monorepo (`apps/legal_link`) with Web + Android targets.
2. **Routing:** Implement the `go_router` auth shell with auth guards (redirect to `/login` if no session).
3. **Design Tokens:** Apply Parchment/Oxford/Brass colors and bundle the Noto Sans Bengali font subset (`ui_ux.md` §1.1–1.3).
4. **Screens:** Build the Phone Number input (+880 prefix), 6-digit OTP screen, and Role Selection screen.
5. **Profile:** Build the "Minimal Profile" form (Name, Phone, Language only) wired to a **Mock Repository**.

### 📦 What to Commit
- `apps/legal_link/lib/features/auth/` (All auth screens and providers)
- `apps/legal_link/lib/app/theme.dart` (Design tokens)
- `apps/legal_link/lib/app/router.dart`

### ✍️ Commit Message Format
- `feat(ui): initialize Flutter app and GoRouter auth shell`
- `feat(ui): add OTP and minimal profile screens`
- `style(ui): apply design tokens and bundle Bangla font`

---

## 🟡 Sprint 2 (Week 2): Document Verification + SOS Basics
**Goal:** The heavy UI lifting for the advocate and the emergency button.

### Tasks
1. **Advocate Form:** Build the full Advocate Registration form (NID, Bar Council no., Sanad photo, courts, specializations, fees).
2. **Upload UI:** Build the file upload UI with progress bars and error states (`ui_ux.md` §4.2).
3. **SOS Screen:** Build the giant Burgundy SOS button with the 600ms hold-to-confirm mechanic (`ui_ux.md` §3.3).

### 📦 What to Commit
- `apps/legal_link/lib/features/onboarding/`
- `apps/legal_link/lib/features/sos/` (SOS screen and hold-to-confirm logic)

### ✍️ Commit Message Format
- `feat(ui): add full advocate registration form`
- `feat(ui): add SOS button with hold-to-confirm mechanic`

---

## ✅ Definition of Done (DoD)
- [ ] `flutter analyze` and `dart format` are clean.
- [ ] All Bangla strings are in ARB files (`lib/l10n/`), never hardcoded.
- [ ] Every button is ≥ 48x48 dp (WCAG compliance).
- [ ] Wednesday: Mock repositories are swapped for real Supabase calls.
