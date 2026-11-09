# Android verification 2 November 2026

The checkout was synchronized with `origin/main` at `24d09d2` on the separate `role-b/android-verification` branch. The completed Sprint 1 branch and the user's existing `AGENTS.md` edit were preserved. Unmerged teammate branches were fetched for visibility but were not combined into the application.

## Fixes found during verification

- OTP requests normalized Bangladesh phone numbers, but OTP verification used the original input. The phone screen supplies ten digits, so the two calls could target different numbers. Verification now uses the same E.164 normalization. Four regression cases cover ten-digit, leading-zero, country-code and already-normalized inputs. The tests reproduced three failures before the fix. The real local integration test now signs in using the phone screen's ten-digit format.
- The authentication repository no longer prints the requested phone number to debug logs.
- Android Gradle builds now use a 2 GB heap and two workers, leaving memory for Android Studio and an emulator on a 16 GB computer. Previously the project allowed an 8 GB heap plus 4 GB of metaspace.

## Automated verification

| Check | Result |
| --- | --- |
| Flutter toolchain | Flutter 3.47.7, Dart 3.13.5 |
| Full native WSL Flutter suite | 112 passed; two opt-in local integration tests skipped in the default suite |
| Line coverage | 69.37%, above the 60% contributor gate |
| Real local integration | Both tests passed, including ten-digit OTP login, registration, three private uploads, re-application and SOS create/read/cancel |
| Analysis | No issues |
| Formatting | 129 Dart files checked without changes |
| Changed source size gate | Passed |
| Native WSL Android debug build | Passed, including the live local-backend configuration |
| Windows Android debug build | Passed with the reduced Gradle memory settings |
| Android Studio Run action | Passed on the selected emulator; Flutter run console and hot-reload connection are available |
| Diff whitespace check | Passed |

## Android runtime observations

The app runs on the existing Medium Phone API 37 emulator, Android 17. The emulator uses WHPX, software graphics, two CPU cores and a 1536 MB memory override for this session. No emulator data was wiped.

Observed directly on Android:

- Bangla phone and OTP screens render; an empty/invalid phone is rejected.
- An incorrect OTP shows the localized error. The correct local test OTP signs in to the real backend and opens Home in the account's English language.
- A restored session returns to Home; signing out returns to the phone screen.
- A short SOS tap does not confirm. A hold opens the capture sheet.
- The contact phone is prefilled. Sending the filled form creates a real local request and displays its waiting state.
- Reopening SOS restores that open request. Cancellation requires confirmation and displays the cancelled state. A database read independently confirmed `cancelled`.
- Advocate login opens the advocate Home and registration form. Android's native file picker rejects an invalid image and uploads a valid synthetic test image successfully. The form shows the selected filename and `Upload complete.` No real identity document was used.

## Local Android Studio setup

Flutter and Dart plugins were installed in the existing Android Studio installation. The app project is `C:\Users\akibh\LegalLink\apps\legal_link`; the selected device is Medium Phone API 37.0. A local, ignored **Local Android Check** run configuration reads `.dart_tool/android-verification/public.json`. That file contains only public local project settings and is not committed.

The IDE's Run action launched this configuration on the emulator, using the Windows Flutter installation. The emulator and IDE session are left open for inspection. Screenshots of Home, registration, upload and SOS states are kept locally under `.dart_tool/android-verification/evidence/`; they are generated evidence and are not committed.

The app uses a separate local Supabase project named `legallink-android-check`, with API port 54331. It was built from current repository migrations without resetting the original local database. The emulator reaches it through:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" -s emulator-5554 reverse tcp:54331 tcp:54331
```

Test client: `1700000003`. Test advocate: `1700000099`. Fixed local OTP: `123456`. These accounts do not send real SMS. The local advocate PIN fixture is `4826`.

Keep the local backend running while using this configuration. After an emulator restart, repeat the reverse-port command. The default `main.dart` configuration still uses the explicitly labeled demo adapters unless live mode is enabled.

## Verification limits

This checks the Role B1 auth, onboarding and client SOS flows and the current app's automated tests. It does not certify every future product screen or another role's unfinished features. Real SMS delivery, push notifications, production connectivity, physical hardware and a signed release remain separate release checks. The current file-picker plugin builds successfully but emits Flutter's future Kotlin migration warning.
