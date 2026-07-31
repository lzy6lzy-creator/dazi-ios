from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class InvitationIosStaticTests(unittest.TestCase):
    def test_api_client_supports_policy_admission_and_invite_code(self):
        text = (ROOT / "dazi" / "Services" / "APIClient.swift").read_text(encoding="utf-8")

        self.assertIn("struct APIRegistrationPolicyResponse", text)
        self.assertIn("struct APISendCodeResponse", text)
        self.assertIn("func getRegistrationPolicy()", text)
        self.assertIn("inviteCode: String?", text)
        self.assertIn('body["invite_code"]', text)
        self.assertIn('"install_id": InstallationIdentity.current', text)
        self.assertIn("admissionToken: String", text)
        self.assertIn('body["admission_token"] = admissionToken', text)

    def test_login_view_reveals_invite_field_and_preserves_admission(self):
        text = (ROOT / "dazi" / "Views" / "Onboarding" / "LoginView.swift").read_text(encoding="utf-8")

        self.assertIn("LoginInvitationState", text)
        self.assertIn("invitationState", text)
        self.assertIn("inviteCodeField", text)
        self.assertIn("admissionToken", text)
        self.assertIn("applySendCodeResponse", text)
        self.assertIn("response.admissionToken", text)
        self.assertIn("inviteCode: invitationNeedsInput ? inviteCode : nil", text)

    def test_app_captures_invitation_universal_link(self):
        text = (ROOT / "dazi" / "daziApp.swift").read_text(encoding="utf-8")

        self.assertIn("onOpenURL", text)
        self.assertIn("pendingInvitationCode", text)
        self.assertIn('url.pathComponents', text)

    def test_location_manager_uploads_fresh_device_fix(self):
        api = (ROOT / "dazi" / "Services" / "APIClient.swift").read_text(encoding="utf-8")
        location = (ROOT / "dazi" / "Services" / "LocationManager.swift").read_text(encoding="utf-8")

        self.assertIn("struct APILocationVerificationResponse", api)
        self.assertIn("func verifyLaunchCityLocation", api)
        self.assertIn("location.horizontalAccuracy", location)
        self.assertIn("location.timestamp", location)
        self.assertIn("verifyLaunchCityLocation", location)

    def test_profile_has_invitation_center_with_system_share(self):
        api = (ROOT / "dazi" / "Services" / "APIClient.swift").read_text(encoding="utf-8")
        profile = (ROOT / "dazi" / "Views" / "Profile" / "ProfileView.swift").read_text(encoding="utf-8")

        self.assertIn("struct APIInvitationMeResponse", api)
        self.assertIn("func getMyInvitation()", api)
        self.assertIn("邀请好友", profile)
        self.assertIn("InvitationCenterView", profile)
        self.assertIn("ShareLink", profile)
        self.assertIn("https://idabuda.com/i/", profile)


if __name__ == "__main__":
    unittest.main()
