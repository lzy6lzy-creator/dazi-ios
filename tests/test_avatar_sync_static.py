from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
API_CLIENT = (ROOT / "dazi/Services/APIClient.swift").read_text(encoding="utf-8")
AVATAR_VIEW = (ROOT / "dazi/Views/Components/AvatarView.swift").read_text(encoding="utf-8")
USER = (ROOT / "dazi/Models/User.swift").read_text(encoding="utf-8")
PROFILE = (ROOT / "dazi/Views/Profile/ProfileView.swift").read_text(encoding="utf-8")
ONBOARDING = (ROOT / "dazi/Views/Onboarding/OnboardingView.swift").read_text(encoding="utf-8")
CHAT_ROOM = (ROOT / "dazi/Models/ChatRoom.swift").read_text(encoding="utf-8")


class AvatarSyncStaticTests(unittest.TestCase):
    def test_avatar_upload_and_delete_endpoints_are_used(self):
        for path in (
            "/api/v1/users/me/avatar",
            "/api/v1/agents/me/avatar",
        ):
            self.assertIn(path, API_CLIENT)
        self.assertIn("data.base64EncodedString()", API_CLIENT)
        self.assertIn("uploadMyAvatar", ONBOARDING)
        self.assertIn("uploadMyAgentAvatar", ONBOARDING)
        self.assertIn("deleteMyAvatar", PROFILE)
        self.assertIn("deleteMyAgentAvatar", PROFILE)

    def test_remote_avatar_urls_flow_into_all_avatar_models(self):
        self.assertIn("var avatarURL: String?", USER)
        self.assertIn("var agentAvatarURL: String?", USER)
        self.assertIn("AsyncImage(url: remoteURL)", AVATAR_VIEW)
        self.assertIn("avatarURL: member.avatarUrl", CHAT_ROOM)
        self.assertNotIn("avatarEmoji: member.avatarUrl", CHAT_ROOM)

    def test_picker_clears_remote_url_when_user_selects_new_avatar(self):
        self.assertIn("@Binding var imageURL: String?", AVATAR_VIEW)
        self.assertGreaterEqual(AVATAR_VIEW.count("imageURL = nil"), 2)


if __name__ == "__main__":
    unittest.main()
