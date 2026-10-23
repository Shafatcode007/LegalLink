#!/usr/bin/env bash
# Enforces the Flutter layer rules from TRD §8.1:
#   - lib/**/domain/**       must not import presentation/, data/, flutter, supabase_flutter, hive
#   - lib/**/presentation/** must not import data/
#   - lib/app/di.dart is the only composition-root exemption (it lives outside both layers)
set -euo pipefail

LIB="${1:-apps/legal_link/lib}"
fail=0

report() {
  echo "❌ $1"
  echo "$2" | sed 's/^/     /'
  fail=1
}

imports_in() {
  grep -rnE "^\s*(import|export)\s+'" --include='*.dart' "$@" 2>/dev/null || true
}

domain_dirs=$(find "$LIB" -type d -name domain)
presentation_dirs=$(find "$LIB" -type d -name presentation)

if [ -n "$domain_dirs" ]; then
  # shellcheck disable=SC2086
  hits=$(imports_in $domain_dirs | grep -E "/(presentation|data)/|'package:(flutter|flutter_riverpod|supabase_flutter|hive|hive_flutter)/" || true)
  [ -n "$hits" ] && report "domain/ must stay pure Dart (no presentation/, data/, flutter, supabase, hive):" "$hits"
fi

if [ -n "$presentation_dirs" ]; then
  # shellcheck disable=SC2086
  hits=$(imports_in $presentation_dirs | grep -E "/data/" || true)
  [ -n "$hits" ] && report "presentation/ must not import data/ (bind implementations in lib/app/di.dart):" "$hits"
fi

if [ "$fail" -ne 0 ]; then
  echo "Layer rules: TRD §8.1 · docs/push&commit_rules.md §3.2"
  exit 1
fi

echo "✅ arch-lint: layer rules hold in $LIB"
