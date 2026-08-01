from __future__ import annotations

import unittest
from datetime import datetime, timezone
from unittest.mock import AsyncMock, patch

from app.core.redis import ChatHistoryCache


class FakeRedis:
    def __init__(self):
        self.values: dict[str, str] = {}

    async def set(self, key: str, value: str, ex: int | None = None):
        self.values[key] = value

    async def get(self, key: str):
        return self.values.get(key)

    async def delete(self, *keys: str):
        for key in keys:
            self.values.pop(key, None)

    async def scan_iter(self, match: str):
        prefix = match.removesuffix("*")
        for key in list(self.values):
            if key.startswith(prefix):
                yield key


class ClarificationCacheTests(unittest.IsolatedAsyncioTestCase):
    async def test_latest_clarification_session_tracks_and_clears_active_session(self):
        fake = FakeRedis()
        payload = {
            "reply": "我先帮你确认几个点。",
            "questions": [{"id": "location", "title": "地点？", "options": []}],
        }

        with patch("app.core.redis.get_redis", new=AsyncMock(return_value=fake)):
            await ChatHistoryCache.set_clarification_session("user-1", "session-1", payload)

            latest = await ChatHistoryCache.get_latest_clarification_session("user-1")
            self.assertEqual(latest, {
                "session_id": "session-1",
                "reply": "我先帮你确认几个点。",
                "questions": [{"id": "location", "title": "地点？", "options": []}],
            })

            await ChatHistoryCache.clear_clarification_session("user-1", "session-1")

            self.assertIsNone(await ChatHistoryCache.get_latest_clarification_session("user-1"))

    async def test_clearing_old_session_does_not_clear_newer_latest_session(self):
        fake = FakeRedis()

        with patch("app.core.redis.get_redis", new=AsyncMock(return_value=fake)):
            await ChatHistoryCache.set_clarification_session("user-1", "old-session", {"reply": "old"})
            await ChatHistoryCache.set_clarification_session("user-1", "new-session", {"reply": "new"})

            await ChatHistoryCache.clear_clarification_session("user-1", "old-session")

            latest = await ChatHistoryCache.get_latest_clarification_session("user-1")
            self.assertEqual(latest, {"session_id": "new-session", "reply": "new"})

    async def test_agent_chat_session_start_is_recorded_and_clears_cached_history(self):
        fake = FakeRedis()

        with patch("app.core.redis.get_redis", new=AsyncMock(return_value=fake)):
            await ChatHistoryCache.append_message("user-1", "user", "我要发布今晚火锅")

            session_start = datetime(2026, 6, 5, 12, 0, tzinfo=timezone.utc)
            await ChatHistoryCache.start_new_agent_chat_session("user-1", started_at=session_start)

            self.assertEqual(await ChatHistoryCache.get_history("user-1"), [])
            self.assertEqual(await ChatHistoryCache.get_agent_chat_session_start("user-1"), session_start)

    async def test_clear_user_state_removes_all_account_scoped_cache(self):
        fake = FakeRedis()

        with patch("app.core.redis.get_redis", new=AsyncMock(return_value=fake)):
            await ChatHistoryCache.append_message("user-1", "user", "今晚吃火锅")
            await ChatHistoryCache.set_event_draft("user-1", {"activity": "火锅"})
            await ChatHistoryCache.set_editing_event("user-1", "event-1")
            await ChatHistoryCache.set_clarification_session(
                "user-1", "session-1", {"reply": "请选择地点"}
            )
            await ChatHistoryCache.set_clarification_session(
                "user-1", "session-2", {"reply": "请选择时间"}
            )
            await fake.set("agent_chat:user-2", "keep")

            await ChatHistoryCache.clear_user_state("user-1")

            self.assertEqual(fake.values, {"agent_chat:user-2": "keep"})


if __name__ == "__main__":
    unittest.main()
