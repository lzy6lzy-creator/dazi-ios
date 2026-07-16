from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class LoginVerificationStaticTests(unittest.TestCase):
    def test_send_code_waits_for_real_sms_code(self):
        source = (ROOT / "dazi/Views/Onboarding/LoginView.swift").read_text(encoding="utf-8")

        self.assertIn("let response = try await api.sendVerificationCode(", source)
        self.assertIn("admissionToken = response.admissionToken", source)
        self.assertIn("codeSent = true", source)
        self.assertIn("code.count == 6", source)
        self.assertNotIn("internalTestCode", source)
        self.assertNotIn("code = internalTestCode", source)

    def test_send_code_no_longer_mentions_phone_whitelist(self):
        source = (ROOT / "dazi/Views/Onboarding/LoginView.swift").read_text(encoding="utf-8")

        self.assertIn("messageForSendCodeError", source)
        self.assertIn("APIError.serverError(let statusCode, let body)", source)
        self.assertIn("errorMessage = messageForSendCodeError(error)", source)
        self.assertIn("短信服务暂时不可用", source)
        self.assertNotIn("内部测试白名单", source)


if __name__ == "__main__":
    unittest.main()
