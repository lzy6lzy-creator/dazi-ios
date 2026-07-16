from __future__ import annotations

import unittest

from pydantic import ValidationError

from app.api.schemas import AuthLoginRequest, AuthSendCodeRequest


class AuthSchemaTests(unittest.TestCase):
    def test_send_code_phone_is_normalized(self):
        request = AuthSendCodeRequest(phone="+86 138-0000-0000")

        self.assertEqual(request.phone, "13800000000")

    def test_login_phone_with_country_code_is_normalized(self):
        request = AuthLoginRequest(phone="8613900000000", code="123456")

        self.assertEqual(request.phone, "13900000000")

    def test_invalid_mainland_phone_is_rejected(self):
        with self.assertRaises(ValidationError):
            AuthSendCodeRequest(phone="123")

    def test_login_code_must_be_six_digits(self):
        invalid_codes = ("12345", "1234567", "abcdef", "12 3456")

        for code in invalid_codes:
            with self.subTest(code=code):
                with self.assertRaises(ValidationError):
                    AuthLoginRequest(phone="13800000000", code=code)

    def test_invitation_admission_fields_are_optional_and_trimmed(self):
        send_request = AuthSendCodeRequest(
            phone="13800000000",
            invite_code=" abcd2345 ",
            install_id=" install-1 ",
        )
        login_request = AuthLoginRequest(
            phone="13800000000",
            code="123456",
            admission_token=" admission-token ",
        )

        self.assertEqual(send_request.invite_code, "ABCD2345")
        self.assertEqual(send_request.install_id, "install-1")
        self.assertEqual(login_request.admission_token, "admission-token")


if __name__ == "__main__":
    unittest.main()
