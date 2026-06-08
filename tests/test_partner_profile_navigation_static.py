import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MESSAGE = (ROOT / "dazi/Models/Message.swift").read_text()
MESSAGE_BUBBLE = (ROOT / "dazi/Views/Components/MessageBubbleView.swift").read_text()
PROFILE_AVATAR = (ROOT / "dazi/Views/Components/ProfileAvatarButton.swift")
CHAT_ROOM_DETAIL = (ROOT / "dazi/Views/ChatRoom/ChatRoomDetailView.swift").read_text()
EVENT_DETAIL = (ROOT / "dazi/Views/Events/EventDetailView.swift").read_text()
DATASTORE = (ROOT / "dazi/Services/DataStore.swift").read_text()


class PartnerProfileNavigationStaticTests(unittest.TestCase):
    def test_messages_carry_sender_user_id_for_avatar_navigation(self):
        self.assertIn("var senderUserId: String?", MESSAGE)
        self.assertIn("senderUserId: String? = nil", MESSAGE)
        self.assertIn("self.senderUserId = senderUserId", MESSAGE)
        self.assertIn("senderUserId: apiMsg.senderId", DATASTORE)
        self.assertIn("senderUserId: payload.senderId", DATASTORE)

    def test_message_avatar_exposes_tap_callback(self):
        self.assertIn("var onAvatarTap: ((String) -> Void)?", MESSAGE_BUBBLE)
        self.assertIn("onAvatarTap?(senderUserId)", MESSAGE_BUBBLE)

    def test_profile_avatar_button_exists_and_only_links_other_real_users(self):
        self.assertTrue(PROFILE_AVATAR.exists())
        text = PROFILE_AVATAR.read_text()
        self.assertIn("struct ProfileAvatarButton", text)
        self.assertIn("user.id != currentUserId", text)
        self.assertIn("!user.isAgent", text)
        self.assertIn("PartnerProfileView(partner: user)", text)

    def test_chat_room_detail_uses_profile_avatar_button_for_user_avatars(self):
        self.assertIn("@State private var selectedProfileUser: User?", CHAT_ROOM_DETAIL)
        self.assertIn("ProfileAvatarButton(", CHAT_ROOM_DETAIL)
        self.assertIn("user: partner", CHAT_ROOM_DETAIL)
        self.assertIn("user: user", CHAT_ROOM_DETAIL)
        self.assertIn("user: member", CHAT_ROOM_DETAIL)
        self.assertIn("MessageBubbleView(message: message) { userId in", CHAT_ROOM_DETAIL)
        self.assertIn("openProfile(forUserId: userId, in: room)", CHAT_ROOM_DETAIL)
        self.assertIn(".sheet(item: $selectedProfileUser)", CHAT_ROOM_DETAIL)

    def test_event_detail_uses_profile_avatar_button_for_matched_partner(self):
        self.assertIn("if let matchedPartner", EVENT_DETAIL)
        self.assertIn("ProfileAvatarButton(", EVENT_DETAIL)
        self.assertIn("user: matchedPartner", EVENT_DETAIL)


if __name__ == "__main__":
    unittest.main()
