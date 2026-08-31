import asyncio
import unittest
from unittest.mock import AsyncMock, MagicMock, patch

from app.core.distributed_lock import distributed_lock, singleton_job


class DistributedLockTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.connection = AsyncMock()
        self.connection.scalar.return_value = True
        self.context = AsyncMock()
        self.context.__aenter__.return_value = self.connection
        self.engine = MagicMock()
        self.engine.connect.return_value = self.context

    async def test_lock_is_released_after_success(self):
        with patch("app.core.distributed_lock.engine", self.engine):
            async with distributed_lock("matching") as acquired:
                self.assertTrue(acquired)
        self.assertIn("pg_try_advisory_lock", str(self.connection.scalar.call_args.args[0]))
        self.assertIn("pg_advisory_unlock", str(self.connection.execute.call_args.args[0]))

    async def test_contended_lock_does_not_run_job_or_unlock_other_owner(self):
        self.connection.scalar.return_value = False
        function = AsyncMock()
        with patch("app.core.distributed_lock.engine", self.engine):
            await singleton_job("matching")(function)()
        function.assert_not_awaited()
        self.connection.execute.assert_not_awaited()

    async def test_cancellation_releases_lock_and_propagates(self):
        with patch("app.core.distributed_lock.engine", self.engine):
            with self.assertRaises(asyncio.CancelledError):
                async with distributed_lock("matching"):
                    raise asyncio.CancelledError
        self.connection.execute.assert_awaited_once()

    async def test_failed_unlock_discards_connection(self):
        self.connection.execute.side_effect = ConnectionError
        with patch("app.core.distributed_lock.engine", self.engine):
            with self.assertRaises(ConnectionError):
                async with distributed_lock("matching"):
                    pass
        self.connection.invalidate.assert_awaited_once()

    async def test_body_exception_is_not_suppressed_when_lock_is_unavailable(self):
        self.connection.scalar.return_value = False
        with patch("app.core.distributed_lock.engine", self.engine):
            with self.assertRaises(ValueError):
                async with distributed_lock("matching"):
                    raise ValueError("keep original error")


if __name__ == "__main__":
    unittest.main()
