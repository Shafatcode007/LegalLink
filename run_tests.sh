#!/usr/bin/env bash
set -e

# Run drift guard test in the PostgreSQL container
CONTAINER_ID=$(docker ps -q -f name=_db_)
if [ -z "$CONTAINER_ID" ]; then
    echo "ERROR: PostgreSQL container (*_db_*) is not running."
    exit 1
fi

docker exec -i "$CONTAINER_ID" psql -U postgres -v ON_ERROR_STOP=1 < db/tests/rls_test.sql
