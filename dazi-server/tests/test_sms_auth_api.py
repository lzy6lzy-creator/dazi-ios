from __future__ import annotations

import unittest
import uuid
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

from fastapi import HTTPException

from app.api.auth import login, send_code
from app.api.schemas import AuthLoginRequest, AuthSendCodeRequest
from app.core.config import settings
from app.services.sms_verification_service import SmsProviderError
from app.services.invitation_service import InvitationRequiredError, IssuedAdmission


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


class FakeResult:
    def __init__(self, value):
        self.value = value

    def scalar_one_or_none(self):
        return self.value


class FakeAuthDb:
    def __init__(self, *results):
        self.results = list(results)
        self.added = []

    async def execute(self, _query):
        if not self.results:
            raise AssertionError("unexpected database query")
        return FakeResult(self.results.pop(0))

    def add(self, value):
        self.added.append(value)

    async def flush(self):
        for value in self.added:
            if getattr(value, "id", None) is None:
                value.id = uuid.uuid4()


class FakeRateLimiter:
    def __init__(self):
        self.calls = []

    async def enforce(self, *, phone: str, client_ip: str):
        self.calls.append((phone, client_ip))


class SmsAuthApiTests(unittest.IsolatedAsyncioTestCase):
    async def test_send_code_new_open_user_sends_sms_with_actual_free_target(self):
        service = FakeSmsService()
        limiter = FakeRateLimiter()

        with patch(
            "app.api.auth.issue_signup_admission",
            AsyncMock(return_value=IssuedAdmission(
                raw_token="admission-token",
                expires_in=600,
                registration_mode="open",
                admission_type="open",
                qualified_user_count=127,
                qualified_target=500,
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
            "user_state": "new",
            "invitation_state": "not_required",
            "qualified_user_count": 127,
            "qualified_target": 500,
        })
        self.assertEqual(service.sent, ["13800000000"])
        self.assertEqual(limiter.calls, [("13800000000", "127.0.0.1")])

    async def test_send_code_whitelist_user_still_sends_real_sms(self):
        service = FakeSmsService()
        limiter = FakeRateLimiter()

        async def issue_for_whitelist(_db, **kwargs):
            if not kwargs["whitelist_bypass"]:
                raise AssertionError("whitelist bypass was not forwarded")
            return IssuedAdmission(
                raw_token="whitelist-admission",
                expires_in=600,
                registration_mode="invite_only",
                admission_type="whitelist",
                qualified_user_count=500,
                qualified_target=500,
            )

        with patch.object(settings, "INTERNAL_TEST_PHONES", "13800000000"), patch.object(
            settings, "INTERNAL_TEST_PHONES_FILE", ""
        ), patch("app.api.auth.issue_signup_admission", issue_for_whitelist):
            response = await send_code(
                AuthSendCodeRequest(phone="13800000000"),
                request=SimpleNamespace(client=SimpleNamespace(host="127.0.0.1")),
                db=object(),
                sms_service=service,
                rate_limiter=limiter,
            )

        self.assertEqual(response["user_state"], "whitelist")
        self.assertEqual(response["invitation_state"], "hidden")
        self.assertEqual(service.sent, ["13800000000"])

    async def test_send_code_missing_invite_returns_target_without_sending_sms(self):
        service = FakeSmsService()
        limiter = FakeRateLimiter()

        with patch.object(settings, "INTERNAL_TEST_PHONES", ""), patch.object(
            settings, "INTERNAL_TEST_PHONES_FILE", ""
        ), patch(
            "app.api.auth.issue_signup_admission",
            AsyncMock(side_effect=InvitationRequiredError(
                qualified_user_count=500,
                qualified_target=500,
            )),
        ):
            with self.assertRaises(HTTPException) as raised:
                await send_code(
                    AuthSendCodeRequest(phone="13900000000"),
                    request=SimpleNamespace(client=SimpleNamespace(host="127.0.0.1")),
                    db=object(),
                    sms_service=service,
                    rate_limiter=limiter,
                )

        self.assertEqual(raised.exception.status_code, 403)
        self.assertEqual(raised.exception.detail, {
            "code": "invitation_required",
            "message": "当前注册需要邀请码",
            "invitation_state": "required",
            "qualified_user_count": 500,
            "qualified_target": 500,
        })
        self.assertEqual(service.sent, [])
        self.assertEqual(limiter.calls, [])

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

    async def test_whitelist_fixed_code_skips_sms_provider_and_allows_new_user(self):
        service = FakeSmsService(verified=False)
        db = FakeAuthDb(None)

        with patch.object(settings, "INTERNAL_TEST_CODE", "121212"), patch.object(
            settings, "INTERNAL_TEST_PHONES", "13800000000"
        ), patch.object(settings, "INTERNAL_TEST_PHONES_FILE", ""):
            response = await login(
                AuthLoginRequest(phone="13800000000", code="121212"),
                db=db,
                sms_service=service,
            )

        self.assertTrue(response["is_new_user"])
        self.assertEqual(service.checked, [])
        self.assertEqual(len(db.added), 2)

    async def test_whitelist_dynamic_code_still_uses_sms_provider(self):
        service = FakeSmsService(verified=True)
        existing_user = SimpleNamespace(id=uuid.uuid4())

        with patch.object(settings, "INTERNAL_TEST_CODE", "121212"), patch.object(
            settings, "INTERNAL_TEST_PHONES", "13800000000"
        ), patch.object(settings, "INTERNAL_TEST_PHONES_FILE", ""):
            response = await login(
                AuthLoginRequest(phone="13800000000", code="654321"),
                db=FakeAuthDb(existing_user),
                sms_service=service,
            )

        self.assertFalse(response["is_new_user"])
        self.assertEqual(service.checked, [("13800000000", "654321")])

    async def test_non_whitelist_fixed_code_must_pass_sms_provider(self):
        service = FakeSmsService(verified=False)

        with patch.object(settings, "INTERNAL_TEST_CODE", "121212"), patch.object(
            settings, "INTERNAL_TEST_PHONES", "13800000000"
        ), patch.object(settings, "INTERNAL_TEST_PHONES_FILE", ""), patch(
            "app.api.auth.record_failed_verification", AsyncMock()
        ):
            with self.assertRaises(HTTPException) as raised:
                await login(
                    AuthLoginRequest(phone="13900000000", code="121212"),
                    db=FailIfUsedDb(),
                    sms_service=service,
                )

        self.assertEqual(raised.exception.status_code, 400)
        self.assertEqual(service.checked, [("13900000000", "121212")])


if __name__ == "__main__":
    unittest.main()
