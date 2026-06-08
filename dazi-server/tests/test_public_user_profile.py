from __future__ import annotations

import unittest
from datetime import datetime, timezone
from types import SimpleNamespace
from uuid import uuid4

from app.api.schemas import PublicUserProfileResponse
from app.api.users import (
    PROFILE_EVENT_VISIBILITY_HIDDEN,
    PROFILE_EVENT_VISIBILITY_PARTIAL,
    PROFILE_EVENT_VISIBILITY_PUBLIC,
    _public_profile_event_payload,
)


class PublicUserProfileTests(unittest.TestCase):
    def test_public_profile_response_exposes_partner_safe_fields(self):
        user_id = uuid4()
        user = SimpleNamespace(
            id=user_id,
            name="阿树",
            phone="13800000000",
            gender="暂时保密",
            birth_year=1998,
            birth_date=None,
            bio="喜欢周末看展",
            avatar_url="https://example.com/avatar.png",
            interests=["看展", "咖啡"],
            city="上海",
            occupation="设计师",
            custom_interests="爵士现场",
            welcome_disturb=True,
            profile_event_visibility="partial",
            created_at=datetime(2026, 6, 1, 8, 30, tzinfo=timezone.utc),
            past_events=[],
        )

        response = PublicUserProfileResponse.model_validate(user)
        payload = response.model_dump()

        self.assertEqual(payload["id"], user_id)
        self.assertEqual(payload["name"], "阿树")
        self.assertEqual(payload["interests"], ["看展", "咖啡"])
        self.assertEqual(payload["city"], "上海")
        self.assertEqual(payload["occupation"], "设计师")
        self.assertEqual(payload["welcome_disturb"], True)
        self.assertEqual(payload["profile_event_visibility"], "partial")
        self.assertEqual(payload["past_events"], [])
        self.assertEqual(payload["created_at"], datetime(2026, 6, 1, 8, 30, tzinfo=timezone.utc))
        self.assertNotIn("phone", payload)

    def test_public_profile_event_visibility_controls_event_detail(self):
        event = SimpleNamespace(
            id=uuid4(),
            title="周末去静安吃鸳鸯锅",
            description="想找能聊天的搭子",
            activity_type="火锅",
            start_time=datetime(2026, 6, 7, 11, 30, tzinfo=timezone.utc),
            end_time=datetime(2026, 6, 7, 14, 0, tzinfo=timezone.utc),
            location="静安大融城",
            city="上海",
            preferences=["鸳鸯锅"],
            constraints=["不迟到"],
            status="completed",
            created_at=datetime(2026, 6, 1, 8, 30, tzinfo=timezone.utc),
        )

        self.assertIsNone(_public_profile_event_payload(event, PROFILE_EVENT_VISIBILITY_HIDDEN))

        partial = _public_profile_event_payload(event, PROFILE_EVENT_VISIBILITY_PARTIAL)
        self.assertEqual(partial.title, "火锅")
        self.assertEqual(partial.detail_level, "partial")
        self.assertEqual(partial.time_label, "2026年6月")
        self.assertEqual(partial.location, "上海")
        self.assertIsNone(partial.start_time)
        self.assertIsNone(partial.description)
        self.assertIsNone(partial.preferences)

        public = _public_profile_event_payload(event, PROFILE_EVENT_VISIBILITY_PUBLIC)
        self.assertEqual(public.title, "周末去静安吃鸳鸯锅")
        self.assertEqual(public.detail_level, "public")
        self.assertEqual(public.location, "静安大融城")
        self.assertEqual(public.preferences, ["鸳鸯锅"])
        self.assertEqual(public.constraints, ["不迟到"])


if __name__ == "__main__":
    unittest.main()
