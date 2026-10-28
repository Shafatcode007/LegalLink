@echo off
wsl bash -c "cd /mnt/d/LegalLink && docker exec -i \$(docker ps -q -f name=_db_) psql -U postgres -v ON_ERROR_STOP=1 < db/tests/rls_test.sql"
