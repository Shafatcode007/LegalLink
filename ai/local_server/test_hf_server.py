import json
import threading
import unittest
import urllib.error
import urllib.request
from http.server import ThreadingHTTPServer

from hf_server import Handler


class HfServerTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        cls.base = f"http://127.0.0.1:{cls.server.server_address[1]}"
        threading.Thread(target=cls.server.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()

    def request(self, path, body=None):
        data = None if body is None else body.encode("utf-8")
        req = urllib.request.Request(self.base + path, data=data,
                                     headers={"Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req) as res:
                return res.status, json.loads(res.read())
        except urllib.error.HTTPError as err:
            with err:
                return err.code, json.loads(err.read())

    def test_health(self):
        status, body = self.request("/health")
        self.assertEqual(status, 200)
        self.assertEqual(body["provider"], "local")

    def chat(self, system, user):
        status, body = self.request("/v1/chat/completions", json.dumps({
            "model": "any",
            "response_format": {"type": "json_object"},
            "messages": [{"role": "system", "content": system},
                         {"role": "user", "content": user}],
        }))
        self.assertEqual(status, 200)
        self.assertEqual(body["object"], "chat.completion")
        return json.loads(body["choices"][0]["message"]["content"])

    def test_triage_follows_requested_case_type(self):
        triage = self.chat("You are a Bangla legal-information assistant. triage schema",
                           json.dumps({"case_type": "family", "answers": {}}))
        self.assertEqual(triage["case_type"], "family")
        self.assertEqual([i["item_name_bn"] for i in triage["checklist"]],
                         ["বিবাহের কাবিননামা", "ভরণপোষণের হিসাব"])
        self.assertTrue(triage["disclaimer_bn"])
        self.assertLessEqual(len(triage["actions_bn"]), 5)
        for item in triage["checklist"]:
            self.assertIn(item["importance"], {"high", "medium", "low"})

    def test_triage_without_json_input_defaults_to_bail(self):
        triage = self.chat("triage", "not json")
        self.assertEqual(triage["case_type"], "bail")
        self.assertEqual(len(triage["checklist"]), 3)

    def test_summary_prompt_returns_summary_schema(self):
        summary = self.chat("You are a Bangla legal case-summary assistant",
                            json.dumps({"raw_notes": "x", "case_type": "bail"}))
        self.assertTrue(summary["draft_bn"])
        self.assertEqual(summary["summary_bn"], summary["draft_bn"])
        self.assertIsInstance(summary["events"], list)
        self.assertEqual(summary["disclaimer_bn"], "এটি আপনার আইনজীবীর অনুমোদন সাপেক্ষ।")
        self.assertNotIn("জামিন পাবেন", summary["draft_bn"])

    def test_invalid_json_is_400(self):
        status, body = self.request("/v1/chat/completions", "not json")
        self.assertEqual(status, 400)
        self.assertIn("error", body)

    def test_unknown_route_is_404(self):
        status, _ = self.request("/nope")
        self.assertEqual(status, 404)


if __name__ == "__main__":
    unittest.main()
