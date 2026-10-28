"""Export only public local settings; keep all privileged CLI output in memory."""
import json
from pathlib import Path
import subprocess
import sys


def main():
    app = Path(__file__).resolve().parents[1]
    cli = sys.argv[1] if len(sys.argv) > 1 else "supabase"
    result = subprocess.run(
        [cli, "status", "--output", "json"], cwd=app.parents[1],
        text=True, capture_output=True, timeout=30,
    )
    if result.returncode:
        raise RuntimeError(result.stderr.strip())
    settings = json.loads(result.stdout)
    public = settings.get("ANON_KEY") or settings.get("PUBLISHABLE_KEY")
    if not public:
        raise RuntimeError("The local stack did not supply a public key")
    target = app / ".dart_tool" / "local-public.json"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps({
        "SUPABASE_URL": settings["API_URL"], "SUPABASE_ANON_KEY": public,
        "USE_SUPABASE": "true", "RUN_LOCAL_INTEGRATION": "true",
    }), encoding="utf-8")
    print("Prepared gitignored local test configuration using public settings only")


if __name__ == "__main__":
    main()
