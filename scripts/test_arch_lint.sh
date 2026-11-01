#!/usr/bin/env bash
# Fixture tests for scripts/arch_lint.sh: one clean tree, one tree per rule.
set -uo pipefail

LINT="$(cd "$(dirname "$0")" && pwd)/arch_lint.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
failures=0

# fixture <name> <file-under-lib> <import-line>
fixture() {
  local root="$WORK/$1/lib"
  mkdir -p "$root/features/x/domain" "$root/features/x/data" "$root/features/x/presentation"
  echo "class Entity {}" > "$root/features/x/domain/entity.dart"
  echo "import '../domain/entity.dart';" > "$root/features/x/data/repo.dart"
  echo "import '../domain/entity.dart';" > "$root/features/x/presentation/screen.dart"
  if [ -n "${2:-}" ]; then
    printf '%s\n' "$3" >> "$root/features/x/$2"
  fi
  echo "$root"
}

expect() {
  local want="$1" name="$2" root="$3"
  if bash "$LINT" "$root" >/dev/null 2>&1; then got=pass; else got=fail; fi
  if [ "$got" = "$want" ]; then
    echo "ok   $name ($got)"
  else
    echo "FAIL $name: expected $want, got $got"
    failures=$((failures + 1))
  fi
}

expect pass "clean presentation -> domain <- data" "$(fixture clean)"
expect fail "domain imports data" "$(fixture d1 domain/entity.dart "import '../data/repo.dart';")"
expect fail "domain imports presentation" "$(fixture d2 domain/entity.dart "import '../presentation/screen.dart';")"
expect fail "domain imports flutter" "$(fixture d3 domain/entity.dart "import 'package:flutter/material.dart';")"
expect pass "domain imports pure riverpod" "$(fixture d4 domain/entity.dart "import 'package:riverpod/riverpod.dart';")"
expect fail "presentation imports data" "$(fixture p1 presentation/screen.dart "import '../data/repo.dart';")"
expect fail "data imports presentation" "$(fixture a1 data/repo.dart "import '../presentation/screen.dart';")"
expect fail "data exports presentation" "$(fixture a2 data/repo.dart "export '../presentation/screen.dart';")"

[ "$failures" -eq 0 ] && echo "arch-lint fixtures: all passed" || { echo "arch-lint fixtures: $failures failed"; exit 1; }
