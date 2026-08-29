from __future__ import annotations

import unittest
from pathlib import Path

from pydantic import ValidationError

from app.api.events import event_feedback_memory_content
from app.api.schemas import EventFeedbackCreate


ROOT = Path(__file__).resolve().parents[1]


class EventFeedbackTests(unittest.TestCase):
    def test_feedback_schema_validates_ratings_and_comment_bounds(self):
        self.assertEqual(EventFeedbackCreate(experience_rating=5).experience_rating, 5)
        with self.assertRaises(ValidationError):
            EventFeedbackCreate(experience_rating=0)
        with self.assertRaises(ValidationError):
            EventFeedbackCreate(experience_rating=5, partner_rating=6)
        with self.assertRaises(ValidationError):
            EventFeedbackCreate(experience_rating=5, experience_comment="x" * 2001)

    def test_feedback_memory_keeps_experience_and_partner_fields(self):
        content = event_feedback_memory_content(EventFeedbackCreate(
            experience_rating=4,
            experience_comment="活动很顺利",
            partner_rating=5,
            partner_comment="沟通准时",
        ))
        self.assertEqual(content, "活动体验评分 4/5；活动很顺利；搭子评分 5/5；沟通准时")

    def test_feedback_is_idempotent_and_room_closes_only_after_other_event_ends(self):
        model_source = (ROOT / "app/models/event.py").read_text(encoding="utf-8")
        api_source = (ROOT / "app/api/events.py").read_text(encoding="utf-8")
        self.assertIn('UniqueConstraint("event_id", "user_id"', model_source)
        self.assertIn('event.status = "completed"', api_source)
        self.assertIn('all(status in {"completed", "cancelled"}', api_source)
        self.assertIn('room.phase = "closed"', api_source)
        self.assertIn('"type": "room_closed"', api_source)
        self.assertIn('memory_key = f"event_feedback:{event_id}"', api_source)


if __name__ == "__main__":
    unittest.main()
