from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
SERVER = ROOT / "app"
IOS_ROOT = ROOT.parents[1] / "dazi"


class A2ANegotiatingChatroomStaticTests(unittest.TestCase):
    def test_backend_models_add_room_phase_and_message_visibility(self):
        chat_model = (SERVER / "models" / "chat.py").read_text(encoding="utf-8")
        schemas = (SERVER / "api" / "schemas.py").read_text(encoding="utf-8")
        main = (SERVER / "main.py").read_text(encoding="utf-8")

        self.assertIn('phase: Mapped[str] = mapped_column(String(30), default="matched")', chat_model)
        self.assertIn("a2a_candidate_rank", chat_model)
        self.assertIn("a2a_result", chat_model)
        self.assertIn('visibility: Mapped[str] = mapped_column(String(30), default="public_room")', chat_model)
        self.assertIn("recipient_user_id", chat_model)
        self.assertIn('phase: str = "matched"', schemas)
        self.assertIn("is_anonymous: bool = False", schemas)
        self.assertIn('visibility: str = "public_room"', schemas)
        self.assertIn("ALTER TABLE chat_rooms ADD COLUMN IF NOT EXISTS phase", main)
        self.assertIn("ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS visibility", main)

    def test_chat_api_filters_private_messages_and_anonymizes_negotiating_partner(self):
        chat_api = (SERVER / "api" / "chat.py").read_text(encoding="utf-8")

        self.assertIn('ROOM_PHASE_A2A_NEGOTIATING = "a2a_negotiating"', chat_api)
        self.assertIn('VISIBILITY_PRIVATE_TO_AGENT = "private_to_agent"', chat_api)
        self.assertIn("def _room_is_anonymous_for_user", chat_api)
        self.assertIn("def _anonymous_candidate_name", chat_api)
        self.assertIn("ChatMessage.visibility == VISIBILITY_PRIVATE_TO_AGENT", chat_api)
        self.assertIn("ChatMessage.recipient_user_id == user_id", chat_api)
        self.assertIn("visibility=VISIBILITY_PRIVATE_TO_AGENT", chat_api)
        self.assertIn("await _broadcast_message_to_room(room_id, msg, db)", chat_api)
        self.assertIn("AI 协商阶段不能投票", chat_api)

    def test_matching_service_creates_negotiating_rooms_and_promotes_winner(self):
        matching_service = (SERVER / "services" / "matching_service.py").read_text(encoding="utf-8")
        a2a_matcher = (SERVER / "services" / "a2a_matcher.py").read_text(encoding="utf-8")
        prompt_builder = (SERVER / "services" / "prompt_builder.py").read_text(encoding="utf-8")

        self.assertIn("async def _create_a2a_negotiating_room", matching_service)
        self.assertIn("async def _promote_a2a_room", matching_service)
        self.assertIn("async def _close_superseded_a2a_rooms", matching_service)
        self.assertIn("async def _close_rejected_a2a_rooms", matching_service)
        self.assertIn('phase=ROOM_PHASE_A2A_NEGOTIATING', matching_service)
        self.assertIn('room.phase = ROOM_PHASE_MATCHED', matching_service)
        self.assertIn('room.a2a_result = "matched"', matching_service)
        self.assertIn('result="lost_to_other_candidate"', matching_service)
        self.assertIn("on_public_message=publish_agent_turn", matching_service)
        self.assertIn("room_id: Optional[UUID] = None", a2a_matcher)
        self.assertIn("room_user_additions", a2a_matcher)
        self.assertIn("self_private.room_user_additions", prompt_builder)

    def test_ios_decodes_and_displays_negotiating_phase(self):
        api_client = (IOS_ROOT / "dazi" / "Services" / "APIClient.swift").read_text(encoding="utf-8")
        chat_room = (IOS_ROOT / "dazi" / "Models" / "ChatRoom.swift").read_text(encoding="utf-8")
        message = (IOS_ROOT / "dazi" / "Models" / "Message.swift").read_text(encoding="utf-8")
        data_store = (IOS_ROOT / "dazi" / "Services" / "DataStore.swift").read_text(encoding="utf-8")
        list_view = (IOS_ROOT / "dazi" / "Views" / "ChatRoom" / "ChatRoomListView.swift").read_text(encoding="utf-8")
        detail_view = (IOS_ROOT / "dazi" / "Views" / "ChatRoom" / "ChatRoomDetailView.swift").read_text(encoding="utf-8")

        self.assertIn("let phase: String", api_client)
        self.assertIn("let isAnonymous: Bool", api_client)
        self.assertIn("let visibility: String?", api_client)
        self.assertIn("var isNegotiating: Bool", chat_room)
        self.assertIn('phase == "a2a_negotiating"', chat_room)
        self.assertIn("var visibility: String?", message)
        self.assertIn('visibility: isNegotiating ? "private_to_agent" : "public_room"', data_store)
        self.assertIn("Section(\"AI 协商中\")", list_view)
        self.assertIn("补充给你的 AI，不会发给对方", detail_view)
        self.assertIn("这是 AI 与 AI 的协商阶段", detail_view)
        self.assertIn("!room.isNegotiating", detail_view)


if __name__ == "__main__":
    unittest.main()
