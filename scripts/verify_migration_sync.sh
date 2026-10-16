#!/usr/bin/env bash
set -e
set -o pipefail

echo "==> Testing dual-folder migration synchronization..."
if ! diff -r db/migrations/ supabase/migrations/; then
  echo "❌ FAIL: Drift detected between db/migrations/ and supabase/migrations/"
  exit 1
fi

echo "==> Verifying 14-digit timestamp convention..."
for f in db/migrations/*.sql; do
  fname=$(basename "$f")
  if [[ ! "$fname" =~ ^[0-9]{14}_[a-zA-Z0-9_]+\.sql$ ]]; then
    echo "❌ FAIL: Invalid migration filename format: $fname (must match YYYYMMDDHHMMSS_description.sql)"
    exit 1
  fi
done

echo "✅ PASS: All migration files are synchronized and comply with Iron Laws."
