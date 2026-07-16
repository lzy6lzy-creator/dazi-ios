from __future__ import annotations

import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

from fastapi import HTTPException

from app.api.auth import login, send_code
from app.api.schemas import AuthLoginRequest, AuthSendCodeRequest
from app.services.sms_verification_service import SmsProviderError
from app.services.invitation_service import IssuedAdmission


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


class FakeRateLimiter:
    def __init__(self):
        self.calls = []

    async def enforce(self, *, phone: str, client_ip: str):
        self.calls.append((phone, client_ip))


class SmsAuthApiTests(unittest.IsolatedAsyncioTestCase):
    async def test_send_code_calls_sms_service_for_any_valid_phone(self):
        service = FakeSmsService()
        limiter = FakeRateLimiter()

        with patch(
            "app.api.auth.issue_signup_admission",
            AsyncMock(return_value=IssuedAdmission(
                raw_token="admission-token",
                expires_in=600,
                registration_mode="open",
            )),
        ):
            response = await send_code(
                AuthSendCodeRequest(phone="13800000000"),
                request=SimpleNamespace(client=SimpleNamespace(host="127.0.0.1")),
                db=object(),
                sms_service=service,
                rate_limiter=limiter,
            )

        self.assertEqual(response, {
            "message": "验证码已发送",
            "admission_token": "admission-token",
            "expires_in": 600,
            "registration_mode": "open",
        })
        self.assertEqual(service.sent, ["13800000000"])
        self.assertEqual(limiter.calls, [("13800000000", "127.0.0.1")])

    async def test_send_code_uses_first_forwarded_client_ip_behind_nginx(self):
        service = FakeSmsService()
        limiter = FakeRateLimiter()

        with patch(
            "app.api.auth.issue_signup_admission",
            AsyncMock(return_value=IssuedAdmission(
                raw_token="admission-token",
                expires_in=600,
                registration_mode="open",
            )),
        ):
            await send_code(
                AuthSendCodeRequest(phone="13800000000"),
                request=SimpleNamespace(
                    client=SimpleNamespace(host="172.20.0.4"),
                    headers={"x-forwarded-for": "203.0.113.8, 172.20.0.4"},
                ),
                db=object(),
                sms_service=service,
                rate_limiter=limiter,
            )

        self.assertEqual(limiter.calls, [("13800000000", "203.0.113.8")])

    async def test_send_code_maps_provider_failure_to_service_unavailable(self):
        service = FakeSmsService(send_error=SmsProviderError("provider detail"))
        limiter = FakeRateLimiter()
        cancel = AsyncMock()

        with patch(
            "app.api.auth.issue_signup_admission",
            AsyncMock(return_value=IssuedAdmission(
                raw_token="admission-token",
                expires_in=600,
                registration_mode="open",
            )),
        ), patch("app.api.auth.cancel_signup_admission", cancel):
            with self.assertLogs("app.api.auth", level="WARNING") as logs:
                with self.assertRaises(HTTPException) as raised:
                    await send_code(
                        AuthSendCodeRequest(phone="13800000000"),
                        request=SimpleNamespace(client=SimpleNamespace(host="127.0.0.1")),
                        db=object(),
                        sms_service=service,
                        rate_limiter=limiter,
                    )

        self.assertEqual(raised.exception.status_code, 503)
        self.assertEqual(raised.exception.detail, "短信服务暂时不可用")
        self.assertEqual(logs.output, [
            "WARNING:app.api.auth:SMS send failed: SmsProviderError"
        ])
        cancel.assert_awaited_once_with(
            unittest.mock.ANY,
            raw_token="admission-token",
        )

    async def test_login_rejects_non_pass_code_before_database_lookup(self):
        service = FakeSmsService(verified=False)

        record_failure = AsyncMock()
        with patch("app.api.auth.record_failed_verification", record_failure):
            with self.assertRaises(HTTPException) as raised:
                await login(
                    AuthLoginRequest(
                        phone="13800000000",
                        code="123456",
                        admission_token="admission-token",
                    ),
                    db=FailIfUsedDb(),
                    sms_service=service,
                )

        self.assertEqual(raised.exception.status_code, 400)
        self.assertEqual(raised.exception.detail, "验证码错误")
        self.assertEqual(service.checked, [("13800000000", "123456")])
        record_failure.assert_awaited_once_with(
            unittest.mock.ANY,
            raw_token="admission-token",
        )


if __name__ == "__main__":
    unittest.main()
