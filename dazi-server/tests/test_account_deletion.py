from __future__ import annotations

import unittest
import uuid
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

from fastapi import HTTPException
from fastapi.security import HTTPAuthorizationCredentials

from app.api.auth import refresh_token
from app.api.schemas import AuthRefreshRequest
from app.api.users import delete_me
from app.core.redis import ChatHistoryCache
from app.core.security import get_current_user_id
from app.services.account_deletion_service import delete_user_account


class FakeResult:
    def __init__(self, *, scalar=None, rows=None):
        self._scalar = scalar
        self._rows = rows or []

    def scalar_one_or_none(self):
        return self._scalar

    def all(self):
        return self._rows


class FakeDb:
    def __init__(self, user, event_ids):
        self.user = user
        self.event_ids = event_ids
        self.statements = []
        self.deleted = []
        self.flush_count = 0

    async def execute(self, statement):
        rendered = str(statement)
        self.statements.append(rendered)
        if rendered.startswith("SELECT users."):
            return FakeResult(scalar=self.user)
        if rendered.startswith("SELECT events.id"):
            return FakeResult(rows=[(event_id,) for event_id in self.event_ids])
        return FakeResult()

    async def delete(self, value):
        self.deleted.append(value)

    async def flush(self):
        self.flush_count += 1


class AccountDeletionServiceTests(unittest.IsolatedAsyncioTestCase):
    async def test_deletes_events_admissions_invitation_links_and_user(self):
        user_id = uuid.uuid4()
        user = SimpleNamespace(id=user_id, phone="13800000000", name="测试用户")
        db = FakeDb(user, [uuid.uuid4(), uuid.uuid4()])

        with patch.object(
            ChatHistoryCache,
            "clear_user_state",
            new=AsyncMock(),
        ) as clear_user_state:
            result = await delete_user_account(db, user_id=user_id)

        self.assertEqual(result.user_id, user_id)
        self.assertEqual(result.deleted_event_count, 2)
        self.assertEqual(db.deleted, [])
        self.assertEqual(db.flush_count, 1)
        clear_user_state.assert_awaited_once_with(str(user_id))
        statements = "\n".join(db.statements)
        self.assertIn("DELETE FROM match_logs", statements)
        self.assertIn("DELETE FROM chat_rooms", statements)
        self.assertIn("UPDATE events SET", statements)
        self.assertIn("DELETE FROM signup_admissions", statements)
        self.assertIn("signup_admissions.phone", statements)
        self.assertIn("signup_admissions.invitation_account_user_id", statements)
        self.assertIn("DELETE FROM invitation_ledger", statements)
        self.assertIn("invitation_ledger.invitee_user_id", statements)
        self.assertIn("DELETE FROM users", statements)

    async def test_missing_user_returns_none_without_deleting(self):
        db = FakeDb(None, [])

        with patch.object(
            ChatHistoryCache,
            "clear_user_state",
            new=AsyncMock(),
        ) as clear_user_state:
            result = await delete_user_account(db, user_id=uuid.uuid4())

        self.assertIsNone(result)
        self.assertEqual(db.deleted, [])
        self.assertEqual(db.flush_count, 0)
        clear_user_state.assert_not_awaited()


class AccountDeletionApiTests(unittest.IsolatedAsyncioTestCase):
    async def test_delete_me_returns_deleted_event_count(self):
        user_id = uuid.uuid4()
        deletion = SimpleNamespace(
            user_id=user_id,
            user_name="测试用户",
            deleted_event_count=3,
        )
        service = AsyncMock(return_value=deletion)
        db = object()

        with patch("app.api.users.delete_user_account", service):
            response = await delete_me(user_id=user_id, db=db)

        self.assertEqual(response.message, "账号已注销")
        self.assertEqual(response.deleted_event_count, 3)
        service.assert_awaited_once_with(db, user_id=user_id)

    async def test_delete_me_returns_not_found_for_stale_token(self):
        user_id = uuid.uuid4()
        with patch(
            "app.api.users.delete_user_account",
            AsyncMock(return_value=None),
        ):
            with self.assertRaises(HTTPException) as raised:
                await delete_me(user_id=user_id, db=object())

        self.assertEqual(raised.exception.status_code, 404)


class DeletedAccountTokenTests(unittest.IsolatedAsyncioTestCase):
    async def test_access_token_is_rejected_after_user_is_deleted(self):
        user_id = uuid.uuid4()
        db = FakeDb(None, [])
        credentials = HTTPAuthorizationCredentials(
            scheme="Bearer",
            credentials="deleted-user-token",
        )

        with patch(
            "app.core.security.decode_token",
            return_value={"type": "access", "user_id": str(user_id)},
        ):
            with self.assertRaises(HTTPException) as raised:
                await get_current_user_id(credentials=credentials, db=db)

        self.assertEqual(raised.exception.status_code, 401)

    async def test_refresh_token_is_rejected_after_user_is_deleted(self):
        user_id = uuid.uuid4()
        db = FakeDb(None, [])

        with patch(
            "app.api.auth.decode_token",
            return_value={"type": "refresh", "user_id": str(user_id)},
        ):
            with self.assertRaises(HTTPException) as raised:
                await refresh_token(
                    AuthRefreshRequest(refresh_token="deleted-user-refresh"),
                    db=db,
                )

        self.assertEqual(raised.exception.status_code, 401)


if __name__ == "__main__":
    unittest.main()
