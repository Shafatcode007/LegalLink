#!/usr/bin/env bash
# Fails with a plain fix-it message when a Cloudflare secret was mis-pasted,
# instead of Cloudflare's opaque 6111/9109 errors. Never prints the token.
#   CF_TOKEN, CF_ACCOUNT  secret values (from the workflow env)
#   TOKEN_NAME            secret name shown in messages (default CLOUDFLARE_API_TOKEN)
set -euo pipefail

name="${TOKEN_NAME:-CLOUDFLARE_API_TOKEN}"
token="${CF_TOKEN:-}"
fail() { echo "::error::$1"; exit 1; }

[ -n "$token" ] || fail "$name is empty. Add it under Settings > Secrets and variables > Actions."
case "$token" in
  Bearer*|bearer*) fail "$name starts with 'Bearer'. Save only the token itself." ;;
  \"*|\'*|*\"|*\') fail "$name is wrapped in quotes. Save it without quotes." ;;
  curl\ *|http://*|https://*) fail "$name looks like a command or URL. Save only the token." ;;
  *[[:space:]]*) fail "$name contains spaces or line breaks. Re-paste only the token, on one line." ;;
esac
[ "${#token}" -ge 30 ] || fail "$name is too short (${#token} characters). Did you copy the token ID instead of the token?"
echo "${CF_ACCOUNT:-}" | grep -Eq '^[0-9a-f]{32}$' \
  || fail "CLOUDFLARE_ACCOUNT_ID must be the 32-character hex account ID (are the two secrets swapped?)."
echo "Cloudflare secrets look well-formed ($name length ${#token})."
