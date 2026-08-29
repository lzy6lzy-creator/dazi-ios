from __future__ import annotations

import unittest
from pathlib import Path

from app.api.ws import websocket_auth_token


class WebSocketAuthTests(unittest.TestCase):
    def test_prefers_bearer_header(self):
        self.assertEqual(
            websocket_auth_token("Bearer header-token", "query-token"),
            "header-token",
        )

    def test_accepts_legacy_query_token(self):
        self.assertEqual(websocket_auth_token(None, "query-token"), "query-token")

    def test_rejects_non_bearer_authorization_without_query_fallback(self):
        self.assertIsNone(websocket_auth_token("Basic abc", None))

    def test_domain_smoke_uses_bearer_header(self):
        script = (Path(__file__).resolve().parents[1] / "scripts/smoke_domain_websocket.py").read_text(encoding="utf-8")
        self.assertIn('additional_headers={"Authorization": f"Bearer {token}"}', script)
        self.assertNotIn('f"{WS_URL}?token={token}"', script)


if __name__ == "__main__":
    unittest.main()
