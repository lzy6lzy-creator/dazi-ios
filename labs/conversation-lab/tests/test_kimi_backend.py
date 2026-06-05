import sys
import unittest
from pathlib import Path
from socket import timeout as SocketTimeout

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from conversation_lab.kimi_backend import KimiBackend


class KimiBackendTests(unittest.TestCase):
    def test_kimi_backend_parses_chat_completion_json_content(self):
        calls = []

        def fake_transport(url, headers, payload, timeout):
            calls.append((url, headers, payload, timeout))
            return {
                "choices": [
                    {
                        "message": {
                            "content": '{"action":"chat","reply":"先聊聊","draft":{},"questions":[]}'
                        }
                    }
                ]
            }

        backend = KimiBackend(
            api_key="test-key",
            model="kimi-test",
            base_url="https://example.test/v1",
            transport=fake_transport,
        )

        decision = backend.decide(
            [{"role": "user", "content": "我今天有点累"}],
            {"draft": {}, "pending_questions": [], "user_profile": {"city": "上海"}},
        )

        self.assertEqual(decision["action"], "chat")
        self.assertEqual(calls[0][0], "https://example.test/v1/chat/completions")
        self.assertEqual(calls[0][1]["Authorization"], "Bearer test-key")
        self.assertEqual(calls[0][2]["model"], "kimi-test")

    def test_kimi_k2_defaults_to_supported_model_and_disables_thinking(self):
        calls = []

        def fake_transport(url, headers, payload, timeout):
            calls.append(payload)
            return {
                "choices": [
                    {
                        "message": {
                            "content": '{"action":"chat","reply":"ok","draft":{},"questions":[]}'
                        }
                    }
                ]
            }

        backend = KimiBackend(api_key="test-key", transport=fake_transport)

        backend.decide([{"role": "user", "content": "hi"}], {})

        self.assertEqual(calls[0]["model"], "kimi-k2.5")
        self.assertEqual(calls[0]["temperature"], 0.6)
        self.assertEqual(calls[0]["thinking"], {"type": "disabled"})

    def test_kimi_backend_retries_transient_timeout(self):
        calls = []

        def fake_transport(url, headers, payload, timeout):
            calls.append(payload)
            if len(calls) == 1:
                raise SocketTimeout("temporary read timeout")
            return {
                "choices": [
                    {
                        "message": {
                            "content": '{"action":"chat","reply":"ok","draft":{},"questions":[]}'
                        }
                    }
                ]
            }

        backend = KimiBackend(api_key="test-key", transport=fake_transport, retries=1)

        decision = backend.decide([{"role": "user", "content": "hi"}], {})

        self.assertEqual(decision["action"], "chat")
        self.assertEqual(len(calls), 2)


if __name__ == "__main__":
    unittest.main()
