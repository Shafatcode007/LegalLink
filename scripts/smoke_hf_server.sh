#!/usr/bin/env bash
# Sprint 1 DoD: ai/local_server/hf_server.py boots on port 8080 and returns
# valid JSON (OpenAI chat.completion shape; triage and summary payloads).
set -euo pipefail

PORT="${PORT:-8080}"
# Pick an interpreter that really runs code (Windows ships a python3 stub
# that only points at the Microsoft Store and still exits 0).
PY=""
for candidate in ${PYTHON:-} python3 python; do
  if [ "$("$candidate" -c 'print("ok")' 2>/dev/null)" = "ok" ]; then PY="$candidate"; break; fi
done
[ -n "$PY" ] || { echo "smoke_hf_server: no working Python found" >&2; exit 1; }
URL="http://127.0.0.1:$PORT"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

"$PY" "$ROOT/ai/local_server/hf_server.py" --port "$PORT" >/dev/null 2>&1 &
SERVER=$!
trap 'kill "$SERVER" 2>/dev/null || true' EXIT

for _ in $(seq 1 50); do
  kill -0 "$SERVER" 2>/dev/null || { echo "smoke_hf_server: server exited before listening" >&2; exit 1; }
  curl -fsS --max-time 1 -o /dev/null "$URL/health" 2>/dev/null && break
  sleep 0.2
done

chat() {
  curl -fsS -X POST "$URL/v1/chat/completions" -H 'content-type: application/json' \
    -d "{\"messages\":[{\"role\":\"system\",\"content\":\"$1\"},{\"role\":\"user\",\"content\":\"{\\\"case_type\\\":\\\"bail\\\"}\"}]}"
}

health="$(curl -fsS "$URL/health")"
triage="$(chat 'triage assistant')"
summary="$(chat 'case-summary assistant')"

HEALTH="$health" TRIAGE="$triage" SUMMARY="$summary" "$PY" - <<'EOF'
import json, os

health = json.loads(os.environ["HEALTH"])
assert health["status"] == "ok", health

def content(raw):
    body = json.loads(raw)
    assert body["object"] == "chat.completion", body
    return json.loads(body["choices"][0]["message"]["content"])

triage = content(os.environ["TRIAGE"])
assert triage["disclaimer_bn"] and triage["checklist"], triage
assert all(i["importance"] in {"high", "medium", "low"} for i in triage["checklist"])

summary = content(os.environ["SUMMARY"])
assert summary["draft_bn"] and summary["disclaimer_bn"], summary
print(f"hf_server smoke: port OK, health OK, triage {len(triage['checklist'])} items, summary OK")
EOF
