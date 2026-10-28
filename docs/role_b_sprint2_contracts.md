# Role B1 Sprint 2 frontend integration contracts

This frontend uses the existing contracts in `docs/api_contracts.md`, `docs/database_schema.md`, and the migrations now on `main`. It does not add a backend RPC, policy, table or realtime topic.

## Advocate verification

`submit_verification` is defined by `20261023000002_nid_and_sos_ratelimit.sql`:

```json
{
  "p_bar_council_no": "BAR-42",
  "p_courts": ["Dhaka Court"],
  "p_districts": ["Dhaka"],
  "p_specializations": ["women_child"],
  "p_languages": ["bn", "en"],
  "p_fee_min_bdt": "1000.00",
  "p_fee_max_bdt": "5000.00",
  "p_pin": "4826",
  "p_nid_number": "1234567890"
}
```

It returns the caller's `advocates` row. The frontend does not map `pin_hash` or PIN counters into its models or persist them. The raw PIN exists only in the form and HTTPS RPC request. For retries/re-applications against an existing row, `p_pin` is null and the existing PIN is retained; PIN changes need an owner-provided lifecycle RPC.

`years_practice` and the existing free-form `availability` JSON column are updated on the caller's own row. This UI writes `availability.sos` as a boolean and preserves other availability keys. The optional profile photo is stored as an object path in the existing `profiles.avatar_url` column. Credential paths are persisted with `update_advocate_documents(p_sanad_url, p_nid_url)` after successful uploads. No signed URL is persisted.

Storage objects stay under `{auth.uid()}/` in `sanad` (NID/Sanad) or `avatars` (profile photo). Each replacement gets a versioned name; uploads never request overwrite privileges absent from the policies. Reads, when needed, use 900-second signed URLs. TUS uploads acknowledge progress and retain the upload URL in memory for retry/resume; credentials and bearer tokens are not written to disk.

## Client SOS

`POST /rest/v1/sos_requests` uses the existing columns `id`, `client_id`, `person_name`, `thana`, `district`, `court`, `charges`, `arrested_at`, `person_nid`, `urgency`, and `contact_phone`. `client_id` comes from the authenticated session. A client-generated UUID is retained across retries so a lost response does not produce a second emergency request. Timestamps are ISO-8601 UTC; optional values are null. The response supplies the canonical request state and expiry.

Cancel uses `PATCH /sos_requests?id=eq.{id}&client_id=eq.{uid}&status=eq.open` with `{ "status": "cancelled" }`. The client never sets `advocate_id` or accepted state and never queues acceptance.

Realtime keeps the fixed `sos:{district}` topic and filters `sos_requests` by district; callbacks additionally match the request ID. Polling refreshes the same authenticated record if realtime is delayed. Only persisted server state is presented as open/accepted/cancelled/expired. A network failure remains an error with retry; it never becomes mock success.

Local verification uses the repository's `auth.sms.test_otp` accounts and `123456`. It does not send a real SMS. A hosted SMS check is a separate release verification and cannot be inferred from local success.
