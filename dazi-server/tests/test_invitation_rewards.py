from __future__ import annotations

import re
import unittest
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch
from uuid import uuid4

from fastapi import HTTPException
from pydantic import ValidationError


class InvitationRewardPolicyTests(unittest.TestCase):
    def test_fresh_accurate_shanghai_location_is_eligible(self):
        from app.services.invitation_reward_service import assess_launch_city_location

        now = datetime(2026, 7, 17, 8, 0, tzinfo=timezone.utc)
        result = assess_launch_city_location(
            latitude=31.2304,
            longitude=121.4737,
            accuracy_meters=40,
            captured_at=now - timedelta(seconds=30),
            now=now,
        )

        self.assertTrue(result.is_launch_city)
        self.assertEqual(result.city_code, "310000")
        self.assertEqual(result.risk_flags, ())

    def test_fresh_accurate_non_shanghai_location_is_stored_as_ineligible(self):
        from app.services.invitation_reward_service import assess_launch_city_location

        now = datetime(2026, 7, 17, 8, 0, tzinfo=timezone.utc)
        result = assess_launch_city_location(
            latitude=30.2741,
            longitude=120.1551,
            accuracy_meters=40,
            captured_at=now,
            now=now,
        )

        self.assertFalse(result.is_launch_city)
        self.assertIsNone(result.city_code)

    def test_stale_location_is_rejected(self):
        from app.services.invitation_reward_service import (
            LocationSubmissionError,
            assess_launch_city_location,
        )

        now = datetime(2026, 7, 17, 8, 0, tzinfo=timezone.utc)
        with self.assertRaisesRegex(LocationSubmissionError, "定位已过期"):
            assess_launch_city_location(
                latitude=31.2304,
                longitude=121.4737,
                accuracy_meters=40,
                captured_at=now - timedelta(minutes=5, seconds=1),
                now=now,
            )

    def test_inaccurate_location_is_rejected(self):
        from app.services.invitation_reward_service import (
            LocationSubmissionError,
            assess_launch_city_location,
        )

        now = datetime(2026, 7, 17, 8, 0, tzinfo=timezone.utc)
        with self.assertRaisesRegex(LocationSubmissionError, "定位精度不足"):
            assess_launch_city_location(
                latitude=31.2304,
                longitude=121.4737,
                accuracy_meters=1000.1,
                captured_at=now,
                now=now,
            )

    def test_reward_amounts_are_fixed_and_codes_avoid_ambiguous_characters(self):
        from app.services.invitation_reward_service import (
            MILESTONE_REWARDS,
            generate_invite_code,
        )

        self.assertEqual(MILESTONE_REWARDS, {
            "first_event_publish": 3,
            "first_match": 2,
        })
        for _ in range(50):
            self.assertRegex(generate_invite_code(), re.compile(r"^[A-HJ-NP-Z2-9]{8}$"))


class LocationEligibilityApiTests(unittest.IsolatedAsyncioTestCase):
    def test_request_requires_timezone_aware_capture_time(self):
        from app.api.schemas import LocationVerificationRequest

        with self.assertRaises(ValidationError):
            LocationVerificationRequest(
                latitude=31.2304,
                longitude=121.4737,
                accuracy_meters=40,
                captured_at=datetime(2026, 7, 17, 8, 0),
            )

    async def test_endpoint_returns_eligibility_and_settled_milestones(self):
        from app.api.location_eligibility import verify_location
        from app.api.schemas import LocationVerificationRequest

        now = datetime(2026, 7, 17, 8, 0, tzinfo=timezone.utc)
        verification = SimpleNamespace(
            is_launch_city=True,
            city_code="310000",
            expires_at=now + timedelta(days=30),
        )
        service = AsyncMock(return_value=(verification, ["first_event_publish"]))
        request = LocationVerificationRequest(
            latitude=31.2304,
            longitude=121.4737,
            accuracy_meters=40,
            captured_at=now,
        )

        with patch("app.api.location_eligibility.verify_launch_city_location", service):
            response = await verify_location(data=request, user_id=uuid4(), db=object())

        self.assertEqual(response["is_launch_city"], True)
        self.assertEqual(response["city_code"], "310000")
        self.assertEqual(response["settled_milestones"], ["first_event_publish"])

    async def test_endpoint_maps_invalid_location_to_bad_request(self):
        from app.api.location_eligibility import verify_location
        from app.api.schemas import LocationVerificationRequest
        from app.services.invitation_reward_service import LocationSubmissionError

        now = datetime(2026, 7, 17, 8, 0, tzinfo=timezone.utc)
        request = LocationVerificationRequest(
            latitude=31.2304,
            longitude=121.4737,
            accuracy_meters=40,
            captured_at=now,
        )
        service = AsyncMock(side_effect=LocationSubmissionError("定位已过期，请重新获取"))

        with patch("app.api.location_eligibility.verify_launch_city_location", service):
            with self.assertRaises(HTTPException) as raised:
                await verify_location(data=request, user_id=uuid4(), db=object())

        self.assertEqual(raised.exception.status_code, 400)
        self.assertEqual(raised.exception.detail, "定位已过期，请重新获取")


class _MilestoneScalarsResult:
    def __init__(self, values):
        self.values = values

    class _Scalars:
        def __init__(self, values):
            self.values = values

        def all(self):
            return self.values

    def scalars(self):
        return self._Scalars(self.values)


class _RewardDb:
    def __init__(self, milestones):
        self.milestones = milestones
        self.added = []
        self.flush_count = 0

    async def execute(self, _query):
        return _MilestoneScalarsResult(self.milestones)

    def add(self, value):
        self.added.append(value)

    async def flush(self):
        self.flush_count += 1


class InvitationRewardSettlementTests(unittest.IsolatedAsyncioTestCase):
    async def test_first_reward_counts_user_once_and_exactly_500_closes_open_mode(self):
        from app.models.invitation import InvitationLedger
        from app.services.invitation_reward_service import settle_pending_milestones

        now = datetime(2026, 7, 17, 8, 0, tzinfo=timezone.utc)
        user_id = uuid4()
        verification = SimpleNamespace(
            id=uuid4(),
            is_launch_city=True,
            expires_at=now + timedelta(days=30),
        )
        milestones = [
            SimpleNamespace(
                id=uuid4(), milestone_type="first_event_publish", status="pending_location",
                source_event_id=uuid4(), source_chat_room_id=None, settled_at=None,
            ),
            SimpleNamespace(
                id=uuid4(), milestone_type="first_match", status="pending_location",
                source_event_id=uuid4(), source_chat_room_id=uuid4(), settled_at=None,
            ),
        ]
        program = SimpleNamespace(
            registration_mode="open",
            qualified_user_count=499,
            qualified_target=500,
            transitioned_at=None,
        )
        account = SimpleNamespace(
            granted_total=0,
            first_qualified_at=None,
        )
        db = _RewardDb(milestones)

        with patch(
            "app.services.invitation_reward_service.get_invitation_program",
            AsyncMock(return_value=program),
        ), patch(
            "app.services.invitation_reward_service._locked_or_created_account",
            AsyncMock(return_value=account),
        ):
            settled = await settle_pending_milestones(
                db,
                user_id=user_id,
                verification=verification,
                now=now,
            )

        self.assertEqual(settled, ["first_event_publish", "first_match"])
        self.assertEqual(account.granted_total, 5)
        self.assertEqual(program.qualified_user_count, 500)
        self.assertEqual(program.registration_mode, "invite_only")
        self.assertEqual(account.first_qualified_at, now)
        self.assertEqual(len([item for item in db.added if isinstance(item, InvitationLedger)]), 2)


if __name__ == "__main__":
    unittest.main()
