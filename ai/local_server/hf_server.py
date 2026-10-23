"""Local AI server stub (AI_PROVIDER=local).

Speaks the OpenAI-compatible /v1/chat/completions shape on localhost:8080 so
the Worker can target it exactly like router.huggingface.co. Sprint 1 returns
fixed triage or summary JSON (TRD §7.2); a transformers + Qwen 2.5-3B backend replaces
`complete()` later without changing the wire format.

    python ai/local_server/hf_server.py [--port 8080]
"""

import argparse
import json
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

MODEL = "mock-qwen2.5-3b-instruct"

# Mirrors checklist_templates in db/seed.sql (the admin template set, TRD §7.2).
TEMPLATES = {
    "bail": [("এফআইআর কপি", "high", "মামলার মূল দলিল"),
             ("গ্রেপ্তার মেমো", "high", "গ্রেপ্তারের আইনি প্রমাণ"),
             ("গ্রেপ্তার ব্যক্তির এনআইডি", "medium", "পরিচয় যাচাই")],
    "criminal": [("এফআইআর কপি", "high", "অভিযোগের ভিত্তি"),
                 ("সাক্ষীর তালিকা", "medium", "সাক্ষ্য প্রস্তুতি")],
    "family": [("বিবাহের কাবিননামা", "high", "মামলার ভিত্তি দলিল"),
               ("ভরণপোষণের হিসাব", "medium", "দাবির পরিমাণ নির্ধারণ")],
    "property": [("দলিল/খতিয়ান", "high", "মালিকানার প্রমাণ"),
                 ("মৌজা ম্যাপ", "medium", "সীমানা নির্ধারণ")],
    "women_child": [("মেডিকেল রিপোর্ট", "high", "প্রমাণ সংরক্ষণ"),
                    ("নিরাপত্তা আবেদন খসড়া", "high", "জরুরি সুরক্ষা")],
}

TRIAGE_DISCLAIMER = "এটি সাধারণ তথ্য, আইনি পরামর্শ নয়।"
SUMMARY_DISCLAIMER = "এটি আপনার আইনজীবীর অনুমোদন সাপেক্ষ।"


def _message(messages, role):
    return next((m.get("content") or "" for m in messages if m.get("role") == role), "")


def _case_type(user_content):
    try:
        data = json.loads(user_content)
    except (json.JSONDecodeError, TypeError):
        return "bail"
    case_type = data.get("case_type") if isinstance(data, dict) else None
    return case_type if case_type in TEMPLATES else "bail"


def mock_triage(case_type):
    return {
        "case_type": case_type,
        "urgency": "high" if case_type == "bail" else "medium",
        "overview_bn": "আপনার মামলার প্রাথমিক তথ্য ও প্রয়োজনীয় কাগজপত্র নিচে দেওয়া হলো।",
        "actions_bn": ["প্রয়োজনীয় কাগজপত্র সংগ্রহ করুন"],
        "checklist": [
            {"template_id": None, "item_name_bn": name,
             "importance": importance, "reason_bn": reason}
            for name, importance, reason in TEMPLATES[case_type]
        ],
        "questions_to_ask_lawyer_bn": ["পরবর্তী শুনানির তারিখ কবে?"],
        "disclaimer_bn": TRIAGE_DISCLAIMER,
    }


def mock_summary():
    text = "শুনানিতে জামিনের আবেদন দাখিল করা হয়েছে। পরবর্তী তারিখ আদালত নির্ধারণ করবে।"
    return {
        "draft_bn": text,
        "summary_bn": text,
        "next_hearing_date": None,
        "events": ["জামিন আবেদন দাখিল"],
        "disclaimer_bn": SUMMARY_DISCLAIMER,
    }


def complete(messages):
    """Return the assistant message content for a chat request."""
    if "summary" in _message(messages, "system").lower():
        payload = mock_summary()
    else:
        payload = mock_triage(_case_type(_message(messages, "user")))
    return json.dumps(payload, ensure_ascii=False)


def chat_completion(body):
    content = complete(body.get("messages", []))
    return {
        "id": f"chatcmpl-mock-{int(time.time() * 1000)}",
        "object": "chat.completion",
        "created": int(time.time()),
        "model": MODEL,
        "choices": [{
            "index": 0,
            "message": {"role": "assistant", "content": content},
            "finish_reason": "stop",
        }],
        "usage": {"prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0},
    }


class Handler(BaseHTTPRequestHandler):
    def _send(self, status, payload):
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _error(self, status, message):
        self._send(status, {"error": {"message": message, "type": "invalid_request_error"}})

    def do_GET(self):
        if self.path == "/health":
            return self._send(200, {"status": "ok", "provider": "local", "model": MODEL})
        if self.path == "/v1/models":
            return self._send(200, {"object": "list", "data": [{"id": MODEL, "object": "model"}]})
        self._error(404, f"no route for GET {self.path}")

    def do_POST(self):
        if self.path != "/v1/chat/completions":
            return self._error(404, f"no route for POST {self.path}")
        length = int(self.headers.get("Content-Length") or 0)
        try:
            body = json.loads(self.rfile.read(length) or b"{}")
        except json.JSONDecodeError:
            return self._error(400, "body must be JSON")
        if not isinstance(body, dict):
            return self._error(400, "body must be a JSON object")
        self._send(200, chat_completion(body))


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8080)
    args = parser.parse_args()

    server = ThreadingHTTPServer((args.host, args.port), Handler)
    print(f"hf_server (mock) listening on http://{args.host}:{args.port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
