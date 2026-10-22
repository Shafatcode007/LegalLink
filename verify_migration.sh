#!/usr/bin/env bash
set -e

# Function to run commands with error checking
function run_command {
    local cmd="$1"
    local description="$2"
    echo "==> $description"
    if ! bash -c "$cmd"; then
        echo "ERROR: $description failed"
        exit 1
    fi
}

# Check if migration files exist
if [[ ! -f "db/migrations/20261023000001_verification_attempt_guard.sql" || ! -f "supabase/migrations/20261023000001_verification_attempt_guard.sql" ]]; then
    echo "ERROR: Migration files not found"
    exit 1
fi

# Run verification sync script
echo "==> Verifying migration sync..."
if ! bash -c "./scripts/verify_migration_sync.sh"; then
    echo "ERROR: Migration sync verification failed"
    exit 1
fi

# Reset database
echo "==> Resetting database..."
if ! ~/.local/bin/supabase-linux db reset --local --no-seed; then
    echo "ERROR: Database reset failed"
    exit 1
fi

# Run seed data
echo "==> Running seed data..."
if ! psql -v ON_ERROR_STOP=1 "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -f db/seed.sql; then
    echo "ERROR: Seed data failed"
    exit 1
fi

# Run RLS tests - Run 1
echo "==> Running RLS tests (Run 1)..."
if ! psql -v ON_ERROR_STOP=1 "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -f db/tests/rls_test.sql; then
    echo "ERROR: RLS tests (Run 1) failed"
    exit 1
fi

# Run RLS tests - Run 2 (Drift guard)
echo "==> Running RLS tests (Run 2 - Drift guard)..."
if ! psql -v ON_ERROR_STOP=1 "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -f db/tests/rls_test.sql; then
    echo "ERROR: RLS tests (Run 2) failed"
    exit 1
fi

echo "==> All verification checks passed successfully!"
