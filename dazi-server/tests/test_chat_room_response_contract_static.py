import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCHEMAS = (ROOT / "app/api/schemas.py").read_text()
CHAT_API = (ROOT / "app/api/chat.py").read_text()


class ChatRoomResponseContractStaticTests(unittest.TestCase):
    def test_room_response_exposes_both_event_ids(self):
        self.assertIn("event_id_a: Optional[UUID] = None", SCHEMAS)
        self.assertIn("event_id_b: Optional[UUID] = None", SCHEMAS)
        self.assertIn("event_id_a=room.event_id_a", CHAT_API)
        self.assertIn("event_id_b=room.event_id_b", CHAT_API)

    def test_room_response_exposes_agent_dialogue_log(self):
        self.assertIn("agent_dialogue: Optional[str] = None", SCHEMAS)
        self.assertIn("agent_dialogue=room.agent_dialogue", CHAT_API)

    def test_room_member_response_exposes_public_profile_fields(self):
        self.assertIn("gender: Optional[str] = None", SCHEMAS)
        self.assertIn("birth_year: Optional[int] = None", SCHEMAS)
        self.assertIn("birth_date: Optional[date] = None", SCHEMAS)
        self.assertIn('gender=getattr(user, "gender", None) if user else None', CHAT_API)
        self.assertIn('birth_date=getattr(user, "birth_date", None) if user else None', CHAT_API)


if __name__ == "__main__":
    unittest.main()
