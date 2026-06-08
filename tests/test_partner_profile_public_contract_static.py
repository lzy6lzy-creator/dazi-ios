import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
API_CLIENT = (ROOT / "dazi/Services/APIClient.swift").read_text()
PARTNER_PROFILE = (ROOT / "dazi/Views/ChatRoom/PartnerProfileView.swift").read_text()
PROFILE_VIEW = (ROOT / "dazi/Views/Profile/ProfileView.swift").read_text()
USER_MODEL = (ROOT / "dazi/Models/User.swift").read_text()
PROFILE_STORE = (ROOT / "dazi/Services/UserProfileStore.swift").read_text()


class PartnerProfilePublicContractStaticTests(unittest.TestCase):
    def test_public_profile_uses_dedicated_decodable_contract(self):
        self.assertIn("struct APIPublicUserProfileResponse: Codable", API_CLIENT)
        self.assertIn("struct APIPublicProfileEventResponse: Codable", API_CLIENT)
        self.assertIn("func getUserProfile(userId: String) async throws -> APIPublicUserProfileResponse", API_CLIENT)
        self.assertIn("@State private var profileData: APIPublicUserProfileResponse?", PARTNER_PROFILE)

    def test_partner_profile_renders_all_public_fields_and_event_history(self):
        self.assertIn("customInterestsSection", PARTNER_PROFILE)
        self.assertIn("disturbSection", PARTNER_PROFILE)
        self.assertIn("pastEventsSection", PARTNER_PROFILE)
        self.assertIn("profileEventVisibility", PARTNER_PROFILE)
        self.assertIn("pastEvents", PARTNER_PROFILE)
        self.assertIn("过往事件", PARTNER_PROFILE)

    def test_my_profile_can_save_event_visibility_setting(self):
        self.assertIn("profileEventVisibility", USER_MODEL)
        self.assertIn("userProfileEventVisibility", PROFILE_STORE)
        self.assertIn("profileEventVisibility = dataStore.currentUser.profileEventVisibility", PROFILE_VIEW)
        self.assertIn('"profile_event_visibility": profileEventVisibility', PROFILE_VIEW)
        self.assertIn("过往事件可见性", PROFILE_VIEW)


if __name__ == "__main__":
    unittest.main()
