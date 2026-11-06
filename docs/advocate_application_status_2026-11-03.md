# Advocate registration status and Home navigation — 3 November 2026

Advocates can now return to Home after submitting registration and see their saved application status instead of reopening an empty registration form.

## Completed changes

- A pinned **Back to Home** button remains reachable on the registration form, completion screen, status-load error, and approved/attempt-limit states.
- Advocate Home displays **Registration not submitted**, **Waiting for review**, **Changes required**, or **Verified advocate**. Review feedback is shown when supplied by the backend.
- Pending/rejected applications offer **Edit and resubmit** while the existing backend attempt limit permits it. Verified applications do not offer resubmission; submission also checks the latest saved status before calling the existing RPC.
- Re-applications restore professional details and existing Sanad/NID document references. They retain the existing approval PIN without reading PIN security fields or asking the advocate to enter the PIN again.
- Status refreshes on demand, on app resume, and every 30 seconds while the application is unverified. Read failures offer retry rather than treating an unreadable application as a new registration.
- New labels and messages are localized in Bangla and English. The existing presentation/domain/data boundaries and verified-state colour rules are preserved.
- The local demo adapter keeps a clearly labelled in-memory application snapshot without retaining the approval PIN.

## Successful verification

The current Role B1 changes passed these local checks:

| Check | Result |
| --- | --- |
| Dart formatting | Passed |
| Flutter analysis | No issues found |
| Full Flutter suite with coverage | 126 passed; 2 opt-in local integration tests skipped |
| Flutter line coverage | 3,680 / 5,225 lines, **70.43%**; above the 60% gate |
| Role B source-size gate | Passed: files under 800 lines; functions under 50 lines |
| Android debug build with local backend configuration | Passed |
| Android emulator | Updated APK installed; restored advocate session displayed the saved pending application with Edit and resubmit and Refresh actions |
| Git whitespace check | Passed |

Automated cases cover the Home exit in both languages and both app modes at enlarged text size; restored details and documents during resubmission; rejection feedback; refresh/polling to verified; unavailable status reads; attempt limits; approved direct registration links; own-account reads; and prevention of verified re-submission.

## Scope and remaining work

This records successful local verification of the implemented Role B1 app changes. It does not claim production SMS delivery or a new physical-device test. Real-number OTP login still requires a configured SMS provider and an appropriate hosted backend. The two opt-in integration tests were not re-run against the user's existing local accounts for this change.

Client advocate search/manual selection, new backend contracts, database security, Admin UI, and SOS acceptance were not added by this change. Local OTP fixture settings, credentials, screenshots, generated files, build output, and the user's local AGENTS.md edits are excluded from the commit.
