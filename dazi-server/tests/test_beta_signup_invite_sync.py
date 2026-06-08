from __future__ import annotations

import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path
from unittest.mock import patch

from app.api.admin import invite_beta_signup_record
from app.models.beta_signup import BetaSignup


class FakeAscClient:
    def __init__(self):
        self.calls: list[str] = []
        self.invite_result = {
            "user_invitation_status": "accepted",
            "beta_tester_status": "waiting_for_user_acceptance",
        }
        self.synced_status = {
            "user_invitation_status": "accepted",
            "in_internal_group": False,
            "user_id": "asc-user-1",
            "beta_tester_id": None,
        }

    async def invite_internal_tester(self, *, email: str, name: str):
        self.calls.append(f"invite:{email}:{name}")
        return self.invite_result

    async def get_internal_tester_status(self, email: str):
        self.calls.append(f"sync:{email}")
        return self.synced_status


class BetaSignupInviteSyncTests(unittest.IsolatedAsyncioTestCase):
    async def test_invite_syncs_asc_status_before_returning_payload(self):
        client = FakeAscClient()
        now = datetime.now(timezone.utc)
        signup = BetaSignup(
            name="测试用户",
            email="tester@example.com",
            contact="18800000000",
            status="new",
            created_at=now,
            updated_at=now,
        )

        with tempfile.TemporaryDirectory() as tmpdir:
            phones_path = str(Path(tmpdir) / "internal_test_phones.txt")
            with patch("app.api.admin.settings.INTERNAL_TEST_PHONES_FILE", phones_path):
                payload = await invite_beta_signup_record(signup, client)  # type: ignore[arg-type]

        self.assertEqual(client.calls, ["invite:tester@example.com:测试用户", "sync:tester@example.com"])
        self.assertEqual(signup.status, "invited")
        self.assertEqual(payload["app_store_connect"], client.synced_status)
        self.assertEqual(payload["app_store_connect_invite_result"], client.invite_result)
        self.assertEqual(payload["phone_status"], "added")


if __name__ == "__main__":
    unittest.main()
