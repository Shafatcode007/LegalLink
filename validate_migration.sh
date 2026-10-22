#!/usr/bin/bash

# Function to run commands with error checking
function run_cmd() {
    local cmd="$1"
    local desc="$2"
    echo "==> $desc"
    if ! bash -c "$cmd"; then
        echo "ERROR: $desc failed"
        exit 1
    fi
}

# Verify the migration file exists and has the right structure
if [[ ! -f "db/migrations/20261023000002_nid_and_sos_ratelimit.sql" ]]; then
    echo "ERROR: Migration file not found"
    exit 1
fi

# Check for key elements in the migration
if ! grep -q "p_nid_number text DEFAULT NULL" db/migrations/20261023000002_nid_and_sos_ratelimit.sql; then
    echo "ERROR: Missing p_nid_number parameter in migration"
    exit 1
fi

if ! grep -q "enforce_sos_rate_limit" db/migrations/20261023000002_nid_and_sos_ratelimit.sql; then
    echo "ERROR: Missing enforce_sos_rate_limit trigger in migration"
    exit 1
fi

if ! grep -q "CREATE TRIGGER trg_sos_rate_limit" db/migrations/20261023000002_nid_and_sos_ratelimit.sql; then
    echo "ERROR: Missing create trigger statement in migration"
    exit 1
fi

if ! grep -q "ON sos_requests" db/migrations/20261023000002_nid_and_sos_ratelimit.sql; then
    echo "ERROR: Missing trigger on sos_requests in migration"
    exit 1
fi

# Check the mirror file exists
if [[ ! -f "supabase/migrations/20261023000002_nid_and_sos_ratelimit.sql" ]]; then
    echo "ERROR: Mirror file not found in supabase/migrations/"
    exit 1
fi

# Check the mirror has the same content
if ! diff -q db/migrations/20261023000002_nid_and_sos_ratelimit.sql supabase/migrations/20261023000002_nid_and_sos_ratelimit.sql > /dev/null; then
    echo "ERROR: Migration files are not synchronized"
    exit 1
fi

echo "=== Migration File Validation PASSED ==="
echo "=== All required components present ==="
