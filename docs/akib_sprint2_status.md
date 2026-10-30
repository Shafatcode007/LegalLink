# Akib — Sprint 2 implementation and handoff

Initial Sprint 2 work merged in PR #17 from `role-b/sprint2-auth-onboarding`. The backend-contract follow-up is on `role-b/verification-contract-sync`, based on the newer `main`. The completed `role-b/auth-onboarding` branch is unchanged. The pre-existing local `AGENTS.md` edit is preserved and excluded from feature commits.

## Completed Flutter work

- Advocate registration: NID, Bar Council number, courts, districts, specializations, fee range, languages, years of practice, SOS availability, masked 4-digit PIN and confirmation, Sanad/NID photos and optional profile photo.
- Live registration calls the current `submit_verification` RPC with the authenticated profile ID, NID number and both credential paths. PIN hashing stays on the server. Re-applications preserve the existing PIN. Both backend attempt-limit error names map to the localized attempt-limit state.
- Real private credential uploads use Supabase TUS: 20 MB validation, bounded reads, image decoding checks, server-acknowledged progress, interrupted-upload resume, retry, replacement and authenticated object paths. Completed Sanad/NID uploads are linked by the verification RPC itself; the removed `update_advocate_documents` RPC is never called. No signed URLs or raw PINs are persisted on the device.
- Client SOS has one persistent shell control, a 600 ms safety delay, early-release/drag/background cancellation, keyboard hold, explicit screen-reader confirmation, focus indication and reduced-motion behavior.
- Live SOS creates an authenticated server request, retains its UUID across retries, recovers a saved request after a lost response, restores an existing open request, follows server status through the prescribed district topic plus polling, and cancels with owner/open-state filters. It never fabricates advocate delivery counts or acceptance.
- Phone OTP, existing-account login, profile creation, JWT refresh, restored sessions and sign-out use Supabase when enabled. `complete_signup` receives only role, full name and language. Admin self-signup is absent. Transport errors are localized separately from incorrect OTP codes.
- Bangla/English ARB strings and bundled Bengali font weights are retained. The reworked source uses the existing design palette, 48 dp controls, pure-Dart domain providers and composition-root bindings.

## Validation

| Gate | Result |
| --- | --- |
| Native WSL toolchain | Flutter 3.47.7 / Dart 3.13.5; native Supabase CLI 2.120.0; native Docker and Android SDK |
| Flutter coverage suite | 90 tests passed; 2 local-only integration tests intentionally skipped in the default suite |
| Coverage | 75.29%, above the required 60% |
| Local Supabase integration | Both fixed-OTP flows passed on an isolated stack built from current main: registration/re-application, three uploads and SOS create/read/cancel |
| PIN storage assertion | Database assertion confirmed the original bcrypt PIN still matched after re-application, without exposing the hash |
| RLS drift guard | Existing suite passed twice; transactions rolled back cleanly |
| Migration sync | Passed; no migration/RPC/policy source was changed |
| Architecture | Existing arch-lint passed |
| Source sizes | All changed Dart source files <800 lines; named functions/methods <50 lines |
| Analysis / whole-app formatting | Clean native WSL analysis; 110 Dart files checked with no formatting changes |
| Web release build | Passed in native WSL |
| Android debug APK | Passed in native WSL |

New behavioral changes were verified with failing tests before implementation, including live RPC payloads, upload resume, persistent SOS, retry recovery, active-request restoration and OTP network errors. The initial prototype predated this rework; its history is not presented as having followed test-first development.

The contract follow-up first reproduced missing profile/document parameters, reliance on the removed document RPC, and the unrecognized `re_apply_cap_exceeded` error. Its regression tests now pass. Fresh-stack integration also checks that re-applying preserves both document paths and does not increment the backend rejection counter.

The follow-up used a separate disposable Supabase project on API port 54331. The database confirmed that `update_advocate_documents` was absent. That test project was stopped and discarded after verification; the existing demo database was not reset or modified.

## Run against the local stack

Use the repository's native Supabase CLI and Docker setup. Test numbers from `supabase/config.toml` use OTP `123456` and do not send an SMS.

After starting Supabase, prepare an ignored file containing public local settings only:

```bash
python3 apps/legal_link/tool/prepare_local_test.py "$HOME/.local/bin/supabase-linux"
cd apps/legal_link
flutter run -d web-server --web-port=8080 --dart-define-from-file=.dart_tool/local-public.json
```

Run the opt-in integration tests separately. These mutate the fixed local demo accounts and consume verification attempts; repeat from a freshly reset local test stack when those quotas are exhausted.

```bash
flutter test --dart-define-from-file=.dart_tool/local-public.json test/integration/local_supabase_test.dart
```

The native Linux Flutter SDK installed for this task is under `$HOME/.cache/legal-link/flutter`; put its `bin` directory on the WSL PATH before running the commands above. Docker access may require an elevated WSL session. The helper exports no service-role key or signing secret.

For an Android emulator, use the host API address `http://10.0.2.2:54321` instead of the emulator's own loopback. Local HTTP is enabled only in the debug manifest. Production projects should use their HTTPS URL and public key.

Without `USE_SUPABASE=true` (or the compatible `USE_SUPABASE_AUTH=true` flag), the app deliberately uses labeled local demos. Enabling live mode switches auth, registration, uploads and client SOS together; failures do not fall back to demo success.

## Release and ownership notes

- No backend RPCs, RLS policies, atomic-accept implementation, Admin UI or Worker deployment logic were changed.
- Existing PINs cannot be changed through registration; a PIN-change lifecycle requires an owner-provided endpoint. The form keeps existing PINs on re-application.
- Hosted SMS and a physical-device/emulator runtime check require release-environment access; local fixed-OTP tests do not prove real SMS delivery.
- New Flutter CI gates cover analysis, formatting, source sizes, coverage and both build targets. The existing migration and architecture workflows remain in place.
- PR review, one approving reviewer and green CI are required before a squash/rebase merge. No direct push to `main` or force-push is permitted.

Exact payloads and storage/realtime conventions are recorded in `docs/role_b_sprint2_contracts.md`.
