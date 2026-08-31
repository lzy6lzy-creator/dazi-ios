import unittest
from unittest.mock import AsyncMock, MagicMock, patch

from app.core.readiness import expected_migration_head, readiness_report


class ReadinessTests(unittest.IsolatedAsyncioTestCase):
    async def report(self, *, revision=None, database_error=False, redis_error=False):
        result = MagicMock()
        result.scalar_one_or_none.return_value = revision or expected_migration_head()
        connection = AsyncMock()
        connection.execute.return_value = result
        if database_error:
            connection.execute.side_effect = ConnectionError
        context = AsyncMock()
        context.__aenter__.return_value = connection
        engine = MagicMock()
        engine.connect.return_value = context
        redis = AsyncMock()
        redis.ping.return_value = True
        if redis_error:
            redis.ping.side_effect = ConnectionError
        with patch("app.core.readiness.engine", engine), patch(
            "app.core.readiness.get_redis", AsyncMock(return_value=redis)
        ):
            return await readiness_report()

    async def test_ready_only_with_current_database_and_redis(self):
        ready, report = await self.report()
        self.assertTrue(ready)
        self.assertEqual(report["status"], "ready")
        self.assertEqual(report["checks"]["migration"], expected_migration_head())

    async def test_outdated_migration_is_not_ready(self):
        ready, report = await self.report(revision="0001_baseline")
        self.assertFalse(ready)
        self.assertEqual(report["checks"]["migration"], "outdated")

    async def test_database_failure_is_not_ready(self):
        ready, report = await self.report(database_error=True)
        self.assertFalse(ready)
        self.assertEqual(report["checks"]["database"], "unavailable")

    async def test_redis_failure_is_not_ready(self):
        ready, report = await self.report(redis_error=True)
        self.assertFalse(ready)
        self.assertEqual(report["checks"]["redis"], "unavailable")


if __name__ == "__main__":
    unittest.main()
