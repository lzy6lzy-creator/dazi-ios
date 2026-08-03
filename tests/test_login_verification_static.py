from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class LoginVerificationStaticTests(unittest.TestCase):
    def test_whitelisted_user_can_type_fixed_code_without_sending_first(self):
        source = (ROOT / "dazi/Views/Onboarding/LoginView.swift").read_text(encoding="utf-8")

        self.assertIn("phone.count == 11 && code.count == 6", source)
        self.assertNotIn("code.count == 6 && codeSent", source)

    def test_send_code_checks_whitelist_without_prefilling_code(self):
        source = (ROOT / "dazi/Views/Onboarding/LoginView.swift").read_text(encoding="utf-8")

        self.assertIn("let response = try await api.sendVerificationCode(", source)
        self.assertIn("admissionToken = response.admissionToken", source)
        self.assertIn("codeSent = true", source)
        self.assertNotIn('private let internalTestCode = "121212"', source)
        self.assertNotIn("code = internalTestCode", source)

    def test_send_code_reveals_structured_invitation_requirement(self):
        source = (ROOT / "dazi/Views/Onboarding/LoginView.swift").read_text(encoding="utf-8")

        self.assertIn("invitationRequiredDetail", source)
        self.assertIn("LoginInvitationState", source)
        self.assertIn(".required(target: detail.qualifiedTarget)", source)
        self.assertIn("errorMessage = messageForSendCodeError(error)", source)

    def test_ios_accepts_legacy_send_code_response_without_admission_fields(self):
        api = (ROOT / "dazi/Services/APIClient.swift").read_text(encoding="utf-8")

        self.assertIn("let admissionToken: String?", api)
        self.assertIn("let expiresIn: Int?", api)
        self.assertIn("let registrationMode: String?", api)
        self.assertIn("let userState: String?", api)
        self.assertIn("let invitationState: String?", api)
        self.assertIn("let qualifiedTarget: Int?", api)
        self.assertIn("admissionToken: String?", api)
        self.assertIn('body["admission_token"] = admissionToken', api)

    def test_invitation_field_uses_backend_target_without_hardcoded_n(self):
        source = (ROOT / "dazi/Views/Onboarding/LoginView.swift").read_text(encoding="utf-8")

        self.assertIn("case notRequired(target: Int)", source)
        self.assertIn("case required(target: Int?)", source)
        self.assertIn('Text("前 \\(target) 位用户免邀请码")', source)
        self.assertIn("invitationNeedsInput", source)
        self.assertNotIn("前 500 位用户免邀请码", source)

    def test_offline_error_offers_system_network_settings(self):
        source = (ROOT / "dazi/Views/Onboarding/LoginView.swift").read_text(encoding="utf-8")

        self.assertIn("UIApplication.openSettingsURLString", source)
        self.assertIn('Label("打开系统设置", systemImage: "gearshape")', source)
        self.assertIn(".notConnectedToInternet, .dataNotAllowed", source)
        self.assertIn("允许 i搭不搭使用无线局域网与蜂窝数据", source)


if __name__ == "__main__":
    unittest.main()
