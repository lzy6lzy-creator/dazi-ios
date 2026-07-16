from __future__ import annotations

import unittest

from fastapi import HTTPException

from app.api.auth import login, send_code
from app.api.schemas import AuthLoginRequest, AuthSendCodeRequest
from app.services.sms_verification_service import SmsProviderError


class FakeSmsService:
    def __init__(self, *, verified: bool = True, send_error: Exception | None = None):
        self.verified = verified
        self.send_error = send_error
        self.sent: list[str] = []
        self.checked: list[tuple[str, str]] = []

    async def send_code(self, phone: str) -> None:
        self.sent.append(phone)
        if self.send_error:
            raise self.send_error

    async def verify_code(self, phone: str, code: str) -> bool:
        self.checked.append((phone, code))
        return self.verified


class FailIfUsedDb:
    async def execute(self, _query):
        raise AssertionError("database must not be queried before SMS verification passes")


class SmsAuthApiTests(unittest.IsolatedAsyncioTestCase):
    async def test_send_code_calls_sms_service_for_any_valid_phone(self):
        service = FakeSmsService()

        response = await send_code(
            AuthSendCodeRequest(phone="13800000000"),
            sms_service=service,
        )

        self.assertEqual(response, {"message": "验证码已发送"})
        self.assertEqual(service.sent, ["13800000000"])

    async def test_send_code_maps_provider_failure_to_service_unavailable(self):
        service = FakeSmsService(send_error=SmsProviderError("provider detail"))

        with self.assertLogs("app.api.auth", level="WARNING") as logs:
            with self.assertRaises(HTTPException) as raised:
                await send_code(
                    AuthSendCodeRequest(phone="13800000000"),
                    sms_service=service,
                )

        self.assertEqual(raised.exception.status_code, 503)
        self.assertEqual(raised.exception.detail, "短信服务暂时不可用")
        self.assertEqual(logs.output, [
            "WARNING:app.api.auth:SMS send failed: SmsProviderError"
        ])

    async def test_login_rejects_non_pass_code_before_database_lookup(self):
        service = FakeSmsService(verified=False)

        with self.assertRaises(HTTPException) as raised:
            await login(
                AuthLoginRequest(phone="13800000000", code="123456"),
                db=FailIfUsedDb(),
                sms_service=service,
            )

        self.assertEqual(raised.exception.status_code, 400)
        self.assertEqual(raised.exception.detail, "验证码错误")
        self.assertEqual(service.checked, [("13800000000", "123456")])


if __name__ == "__main__":
    unittest.main()
