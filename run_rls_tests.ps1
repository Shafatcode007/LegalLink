$psqlPath = "postgresql://postgres:postgres@127.0.0.1:54322/postgres"
$scriptPath = "db/tests/rls_test.sql"
$command = "psql -v ON_ERROR_STOP=1 \"$psqlPath\" -f \"$scriptPath\""
Write-Host "Running RLS tests..."
$content = Invoke-Expression $command
Write-Host $content
