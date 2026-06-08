import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EVENT_DETAIL = (ROOT / "dazi/Views/Events/EventDetailView.swift").read_text()
CHAT_ROOM = (ROOT / "dazi/Models/ChatRoom.swift").read_text()
API_CLIENT = (ROOT / "dazi/Services/APIClient.swift").read_text()
DATASTORE = (ROOT / "dazi/Services/DataStore.swift").read_text()
SERVER_CHAT = (ROOT / "dazi-server/app/api/chat.py").read_text()
SERVER_CHAT_MODEL = (ROOT / "dazi-server/app/models/chat.py").read_text()
SERVER_SCHEMA = (ROOT / "dazi-server/app/api/schemas.py").read_text()


class EventDetailStaticTests(unittest.TestCase):
    def test_chat_room_response_carries_event_ids_and_member_profile_fields(self):
        self.assertIn("let eventIdA: String?", API_CLIENT)
        self.assertIn("let eventIdB: String?", API_CLIENT)
        self.assertIn('case eventIdA = "event_id_a"', API_CLIENT)
        self.assertIn('case eventIdB = "event_id_b"', API_CLIENT)
        self.assertIn("let gender: String?", API_CLIENT)
        self.assertIn("let birthDate: String?", API_CLIENT)
        self.assertIn("let birthYear: Int?", API_CLIENT)

    def test_chat_room_response_carries_agent_dialogue_log(self):
        self.assertIn("let agentDialogue: String?", API_CLIENT)
        self.assertIn('case agentDialogue = "agent_dialogue"', API_CLIENT)
        self.assertIn("self.agentDialogueLog = api.agentDialogue ?? \"\"", CHAT_ROOM)

    def test_chat_room_response_carries_server_unread_state(self):
        self.assertIn("let hasUnread: Bool", API_CLIENT)
        self.assertIn('case hasUnread = "has_unread"', API_CLIENT)
        self.assertIn("self.hasUnread = api.hasUnread", CHAT_ROOM)
        self.assertIn("has_unread: bool = False", SERVER_SCHEMA)
        self.assertIn("last_read_at", SERVER_CHAT_MODEL)
        self.assertIn("has_unread=await _room_has_unread", SERVER_CHAT)

    def test_opening_chat_room_marks_server_room_read(self):
        self.assertIn("func markRoomAsRead(_ roomId: String)", DATASTORE)
        self.assertIn("try await api.markRoomAsRead(roomId: roomId)", DATASTORE)
        self.assertIn('path: "/api/v1/chat/rooms/\\(roomId)/read"', API_CLIENT)
        self.assertIn('@router.post("/rooms/{room_id}/read")', SERVER_CHAT)

    def test_remote_message_push_carries_server_badge_count(self):
        self.assertIn("badge = await _unread_room_count_for_user", SERVER_CHAT)
        self.assertIn("badge=badge", SERVER_CHAT)

    def test_chat_room_model_can_match_either_room_event_id(self):
        self.assertIn("var eventIds: [String]", CHAT_ROOM)
        self.assertIn("func containsEvent(_ eventId: String) -> Bool", CHAT_ROOM)
        self.assertIn("eventIds.contains(eventId)", CHAT_ROOM)
        self.assertIn("api.eventIdA, api.eventIdB", CHAT_ROOM)

    def test_event_detail_uses_matched_room_for_partner_and_navigation(self):
        self.assertIn("private var matchedRoom: ChatRoom?", EVENT_DETAIL)
        self.assertIn("room.containsEvent(event.id)", EVENT_DETAIL)
        self.assertIn("dataStore.pendingChatRoomId = room.id", EVENT_DETAIL)
        self.assertIn("await dataStore.fetchChatRoomsFromServer()", EVENT_DETAIL)

    def test_event_detail_displays_partner_gender_and_age(self):
        self.assertIn('partnerInfoChip(icon: "person.fill", text: gender)', EVENT_DETAIL)
        self.assertIn('partnerInfoChip(icon: "birthday.cake.fill", text: "\\(age)岁")', EVENT_DETAIL)
        self.assertIn('Text(matchedPartner?.name ?? "搭子")', EVENT_DETAIL)

    def test_websocket_event_update_uses_server_status_mapping(self):
        self.assertIn("EventStatus.fromServer(status)", DATASTORE)
        self.assertNotIn("EventStatus(rawValue: status)", DATASTORE)


if __name__ == "__main__":
    unittest.main()
