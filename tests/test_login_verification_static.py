from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class LoginVerificationStaticTests(unittest.TestCase):
    def test_send_code_prefills_internal_test_code_after_whitelist_check(self):
        source = (ROOT / "dazi/Views/Onboarding/LoginView.swift").read_text(encoding="utf-8")

        self.assertIn('private let internalTestCode = "121212"', source)
        self.assertIn("let _ = try await api.sendVerificationCode(phone: phone)", source)
        self.assertIn("code = internalTestCode", source)
        self.assertIn("codeSent = true", source)

    def test_send_code_shows_whitelist_error_for_forbidden_phone(self):
        source = (ROOT / "dazi/Views/Onboarding/LoginView.swift").read_text(encoding="utf-8")

        self.assertIn("messageForSendCodeError", source)
        self.assertIn("APIError.serverError(let statusCode, let body)", source)
        self.assertIn("statusCode == 403", source)
        self.assertIn("未加入内部测试白名单", source)
        self.assertIn("errorMessage = messageForSendCodeError(error)", source)


if __name__ == "__main__":
    unittest.main()
