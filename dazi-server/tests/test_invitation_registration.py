from __future__ import annotations

import unittest
import uuid
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

from app.services.invitation_service import (
    AdmissionInvalidError,
    InvitationRequiredError,
    RegistrationPausedError,
    SmsRateLimitError,
    SmsSendRateLimiter,
    consume_signup_admission,
    hash_admission_token,
    issue_signup_admission,
    normalize_invite_code,
    release_expired_reservations,
)


class FakeResult:
    def __init__(self, scalar):
        self.scalar = scalar

    def scalar_one_or_none(self):
        return self.scalar

    def scalars(self):
        return self

    def all(self):
        return self.scalar


class FakeDb:
    def __init__(self, *responses):
        self.responses = list(responses)
        self.added = []
        self.flush_count = 0

    async def execute(self, _query):
        if not self.responses:
            raise AssertionError("unexpected database query")
        return FakeResult(self.responses.pop(0))

    def add(self, value):
        self.added.append(value)

    async def flush(self):
        self.flush_count += 1


class FakeRedis:
    def __init__(self, result: int):
        self.result = result
        self.calls = []

    async def eval(self, script, number_of_keys, *args):
        self.calls.append((script, number_of_keys, args))
        return self.result


class InvitationRegistrationTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.now = datetime(2026, 7, 17, tzinfo=timezone.utc)

    def test_invite_code_is_normalized_without_ambiguous_characters(self):
        self.assertEqual(normalize_invite_code(" ab-cd 2345 "), "ABCD2345")
        self.assertIsNone(normalize_invite_code(""))

    def test_admission_token_hash_is_namespaced_and_deterministic(self):
        first = hash_admission_token("raw-token")
        second = hash_admission_token("raw-token")

        self.assertEqual(first, second)
        self.assertEqual(len(first), 64)
        self.assertNotEqual(first, hash_admission_token("other-token"))

    async def test_open_mode_issues_ten_minute_admission_without_invite(self):
        program = SimpleNamespace(registration_mode="open")
        db = FakeDb(None, program)

        issued = await issue_signup_admission(
            db,
            phone="13800000000",
            invite_code=None,
            install_id="install-1",
            client_ip="127.0.0.1",
            now=self.now,
        )

        admission = db.added[0]
        self.assertEqual(issued.registration_mode, "open")
        self.assertEqual(issued.expires_in, 600)
        self.assertEqual(admission.admission_type, "open")
        self.assertEqual(admission.expires_at, self.now + timedelta(minutes=10))
        self.assertEqual(admission.token_hash, hash_admission_token(issued.raw_token))
        self.assertNotEqual(admission.token_hash, issued.raw_token)

    async def test_admission_stores_only_derived_location_result(self):
        verified_at = self.now - timedelta(seconds=10)
        db = FakeDb(None, SimpleNamespace(registration_mode="open"))

        await issue_signup_admission(
            db,
            phone="13800000000",
            location_city_code="310000",
            location_is_launch_city=True,
            location_accuracy_meters=36.5,
            location_verified_at=verified_at,
            now=self.now,
        )

        admission = db.added[0]
        self.assertEqual(admission.location_city_code, "310000")
        self.assertTrue(admission.location_is_launch_city)
        self.assertEqual(admission.location_accuracy_meters, 36.5)
        self.assertEqual(admission.location_verified_at, verified_at)
        self.assertFalse(hasattr(admission, "latitude"))
        self.assertFalse(hasattr(admission, "longitude"))

    async def test_existing_user_bypasses_paused_mode(self):
        program = SimpleNamespace(registration_mode="paused")
        db = FakeDb(uuid.uuid4(), program)

        issued = await issue_signup_admission(
            db,
            phone="13800000000",
            invite_code=None,
            now=self.now,
        )

        self.assertEqual(db.added[0].admission_type, "existing")
        self.assertEqual(issued.registration_mode, "paused")

    async def test_whitelist_new_user_bypasses_invite_only_with_policy_metadata(self):
        program = SimpleNamespace(
            registration_mode="invite_only",
            qualified_user_count=127,
            qualified_target=500,
        )
        db = FakeDb(None, program)

        issued = await issue_signup_admission(
            db,
            phone="13800000000",
            whitelist_bypass=True,
            now=self.now,
        )

        self.assertEqual(db.added[0].admission_type, "whitelist")
        self.assertEqual(issued.admission_type, "whitelist")
        self.assertEqual(issued.qualified_user_count, 127)
        self.assertEqual(issued.qualified_target, 500)

    async def test_new_user_is_rejected_while_paused(self):
        db = FakeDb(None, SimpleNamespace(registration_mode="paused"))

        with self.assertRaises(RegistrationPausedError):
            await issue_signup_admission(db, phone="13800000000", now=self.now)

        self.assertEqual(db.added, [])

    async def test_invite_only_reserves_one_available_slot(self):
        inviter_id = uuid.uuid4()
        account = SimpleNamespace(
            user_id=inviter_id,
            status="active",
            granted_total=3,
            consumed_total=1,
            reserved_total=1,
        )
        db = FakeDb(
            None,
            SimpleNamespace(registration_mode="invite_only"),
            account,
            [],
        )

        issued = await issue_signup_admission(
            db,
            phone="13800000000",
            invite_code="abcd2345",
            now=self.now,
        )

        self.assertEqual(account.reserved_total, 2)
        self.assertEqual(db.added[0].admission_type, "invitation")
        self.assertEqual(db.added[0].invitation_account_user_id, inviter_id)
        self.assertEqual(issued.registration_mode, "invite_only")

    async def test_invite_only_requires_code(self):
        db = FakeDb(None, SimpleNamespace(
            registration_mode="invite_only",
            qualified_user_count=500,
            qualified_target=500,
        ))

        with self.assertRaises(InvitationRequiredError) as raised:
            await issue_signup_admission(db, phone="13800000000", now=self.now)

        self.assertEqual(raised.exception.qualified_user_count, 500)
        self.assertEqual(raised.exception.qualified_target, 500)

    async def test_consuming_invitation_moves_reserved_to_consumed(self):
        inviter_id = uuid.uuid4()
        invitee_id = uuid.uuid4()
        admission = SimpleNamespace(
            id=uuid.uuid4(),
            status="issued",
            expires_at=self.now + timedelta(minutes=5),
            admission_type="invitation",
            invitation_account_user_id=inviter_id,
            consumed_at=None,
        )
        account = SimpleNamespace(
            user_id=inviter_id,
            reserved_total=1,
            consumed_total=0,
        )
        db = FakeDb(admission, account)

        await consume_signup_admission(
            db,
            raw_token="raw-token",
            invitee_user_id=invitee_id,
            now=self.now,
        )

        self.assertEqual(admission.status, "consumed")
        self.assertEqual(admission.consumed_at, self.now)
        self.assertEqual(account.reserved_total, 0)
        self.assertEqual(account.consumed_total, 1)
        ledger = db.added[0]
        self.assertEqual(ledger.amount, -1)
        self.assertEqual(ledger.invitee_user_id, invitee_id)

    async def test_expired_admission_cannot_be_consumed(self):
        admission = SimpleNamespace(
            status="issued",
            expires_at=self.now,
            admission_type="open",
            invitation_account_user_id=None,
        )
        db = FakeDb(admission)

        with self.assertRaises(AdmissionInvalidError):
            await consume_signup_admission(
                db,
                raw_token="raw-token",
                invitee_user_id=uuid.uuid4(),
                now=self.now,
            )

    async def test_expired_invitation_reservations_are_released(self):
        inviter_id = uuid.uuid4()
        account = SimpleNamespace(user_id=inviter_id, reserved_total=2)
        expired = [
            SimpleNamespace(status="issued"),
            SimpleNamespace(status="issued"),
        ]
        db = FakeDb(expired)

        released = await release_expired_reservations(
            db,
            account=account,
            now=self.now,
        )

        self.assertEqual(released, 2)
        self.assertEqual(account.reserved_total, 0)
        self.assertEqual([item.status for item in expired], ["expired", "expired"])

    async def test_rate_limiter_maps_redis_result_to_public_limit(self):
        limiter = SmsSendRateLimiter(FakeRedis(result=1))

        with self.assertRaises(SmsRateLimitError) as raised:
            await limiter.enforce(phone="13800000000", client_ip="127.0.0.1")

        self.assertEqual(raised.exception.retry_after, 60)


if __name__ == "__main__":
    unittest.main()
