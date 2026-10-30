#!/usr/bin/env bash
# Sprint 1 (TRD §6.2, §8.2): prove the access token carries
# app_metadata.role after onboarding, end to end against local Supabase:
# test OTP sign-in -> complete_signup -> refresh -> decode the new JWT.
# Never prints a token.
#   API_URL / ANON_KEY  taken from `supabase status -o env` when unset
#   TEST_PHONE          a supabase/config.toml test_otp number with no seeded user
set -euo pipefail

if [ -z "${API_URL:-}" ] || [ -z "${ANON_KEY:-}" ]; then
  eval "$(supabase status -o env | grep -E '^(API_URL|ANON_KEY|PUBLISHABLE_KEY)=')"
  ANON_KEY="${ANON_KEY:-${PUBLISHABLE_KEY:-}}"
fi
[ -n "${API_URL:-}" ] && [ -n "${ANON_KEY:-}" ] || { echo "::error::Supabase API_URL / ANON_KEY not found" >&2; exit 1; }

PHONE="${TEST_PHONE:-+8801700000099}"
OTP="${TEST_OTP:-123456}"
ROLE="advocate"

PY=""
for candidate in ${PYTHON:-} python3 python; do
  if [ "$("$candidate" -c 'print("ok")' 2>/dev/null)" = "ok" ]; then PY="$candidate"; break; fi
done
[ -n "$PY" ] || { echo "verify_jwt_role_claim: no working Python found" >&2; exit 1; }

post() { # path, json body, [bearer]
  local auth=()
  [ -n "${3:-}" ] && auth=(-H "authorization: Bearer $3")
  curl -fsS -X POST "$API_URL$1" -H "apikey: $ANON_KEY" -H 'content-type: application/json' "${auth[@]}" -d "$2"
}
field() { "$PY" -c "import json,sys; print(json.load(sys.stdin)['$1'])"; }

post /auth/v1/otp "{\"phone\":\"$PHONE\"}" >/dev/null
session="$(post /auth/v1/verify "{\"type\":\"sms\",\"phone\":\"$PHONE\",\"token\":\"$OTP\"}")"
access="$(field access_token <<<"$session")"
refresh="$(field refresh_token <<<"$session")"

post /rest/v1/rpc/complete_signup \
  "{\"p_role\":\"$ROLE\",\"p_full_name\":\"CI JWT check\",\"p_language\":\"bn\"}" "$access" >/dev/null

refreshed="$(post '/auth/v1/token?grant_type=refresh_token' "{\"refresh_token\":\"$refresh\"}")"
token="$(field access_token <<<"$refreshed")"

TOKEN="$token" WANT="$ROLE" "$PY" - <<'EOF'
import base64, json, os, sys

payload = os.environ["TOKEN"].split(".")[1]
claims = json.loads(base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4)))
role = (claims.get("app_metadata") or {}).get("role")
if claims.get("role") != "authenticated" or role != os.environ["WANT"]:
    sys.exit(f"::error::JWT claims wrong: role={claims.get('role')!r}, app_metadata.role={role!r}")
print(f"JWT role claim OK: role=authenticated, app_metadata.role={role}")
EOF
