from __future__ import annotations

import unittest
from types import SimpleNamespace
from uuid import uuid4


class ScalarResult:
    def __init__(self, value):
        self.value = value

    def scalar_one_or_none(self):
        return self.value


class ScalarsResult:
    def __init__(self, values):
        self.values = values

    class _Scalars:
        def __init__(self, values):
            self.values = values

        def all(self):
            return self.values

    def scalars(self):
        return self._Scalars(self.values)


class FakeDb:
    def __init__(self, results):
        self.results = list(results)

    async def execute(self, _query):
        return self.results.pop(0)

    async def flush(self):
        return None


class InvitationApiTests(unittest.IsolatedAsyncioTestCase):
    async def test_me_returns_balance_and_milestones(self):
        from app.api.invitations import get_my_invitation

        user_id = uuid4()
        account = SimpleNamespace(
            code="DAZI8K3M",
            granted_total=5,
            consumed_total=1,
            reserved_total=2,
            status="active",
        )
        milestones = [
            SimpleNamespace(milestone_type="first_event_publish", status="settled"),
            SimpleNamespace(milestone_type="first_match", status="pending_location"),
        ]
        db = FakeDb([ScalarResult(account), ScalarsResult(milestones)])

        response = await get_my_invitation(user_id=user_id, db=db)

        self.assertEqual(response["code"], "DAZI8K3M")
        self.assertEqual(response["available"], 2)
        self.assertEqual(response["share_url"], "https://idabuda.com/i/DAZI8K3M")
        self.assertEqual(response["milestones"], {
            "first_event_publish": "settled",
            "first_match": "pending_location",
        })

    async def test_me_without_rewards_has_no_code_or_balance(self):
        from app.api.invitations import get_my_invitation

        db = FakeDb([ScalarResult(None), ScalarsResult([])])

        response = await get_my_invitation(user_id=uuid4(), db=db)

        self.assertIsNone(response["code"])
        self.assertEqual(response["available"], 0)
        self.assertIsNone(response["share_url"])

    async def test_public_status_exposes_no_inviter_identity(self):
        from app.api.invitations import invitation_status

        account = SimpleNamespace(
            code="DAZI8K3M",
            granted_total=3,
            consumed_total=1,
            reserved_total=1,
            status="active",
            user_id=uuid4(),
        )
        db = FakeDb([ScalarResult(account), ScalarsResult([])])

        response = await invitation_status(code=" dazi-8k3m ", db=db)

        self.assertEqual(response, {"valid": True, "available": 1})
        self.assertNotIn("user_id", response)
        self.assertNotIn("name", response)

    async def test_public_status_masks_missing_suspended_and_exhausted_codes(self):
        from app.api.invitations import invitation_status

        cases = [
            None,
            SimpleNamespace(user_id=uuid4(), granted_total=3, consumed_total=0, reserved_total=0, status="suspended"),
            SimpleNamespace(user_id=uuid4(), granted_total=3, consumed_total=2, reserved_total=1, status="active"),
        ]
        for account in cases:
            with self.subTest(account=account):
                response = await invitation_status(
                    code="NOTREAL",
                    db=FakeDb(
                        [ScalarResult(account)]
                        if account is None or account.status != "active"
                        else [ScalarResult(account), ScalarsResult([])]
                    ),
                )
                self.assertEqual(response, {"valid": False, "available": 0})

    async def test_public_status_releases_expired_reservation_before_reporting(self):
        from app.api.invitations import invitation_status

        account = SimpleNamespace(
            user_id=uuid4(),
            granted_total=1,
            consumed_total=0,
            reserved_total=1,
            status="active",
        )
        expired = SimpleNamespace(status="issued")
        db = FakeDb([ScalarResult(account), ScalarsResult([expired])])

        response = await invitation_status(code="DAZI8K3M", db=db)

        self.assertEqual(response, {"valid": True, "available": 1})
        self.assertEqual(expired.status, "expired")


if __name__ == "__main__":
    unittest.main()
