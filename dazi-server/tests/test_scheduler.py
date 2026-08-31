from datetime import datetime, timezone
import asyncio
import unittest

from app.services.scheduler import BetaInviteScheduler, MatchScheduler, next_hourly_run_at


class SchedulerTests(unittest.TestCase):
    def test_next_hourly_run_at_rounds_to_next_hour(self):
        now = datetime(2026, 6, 4, 14, 15, 30, tzinfo=timezone.utc)

        self.assertEqual(
            next_hourly_run_at(now),
            datetime(2026, 6, 4, 15, 0, 0, tzinfo=timezone.utc),
        )

    def test_next_hourly_run_at_moves_forward_from_exact_hour(self):
        now = datetime(2026, 6, 4, 14, 0, 0, tzinfo=timezone.utc)

        self.assertEqual(
            next_hourly_run_at(now),
            datetime(2026, 6, 4, 15, 0, 0, tzinfo=timezone.utc),
        )


class SchedulerShutdownTests(unittest.IsolatedAsyncioTestCase):
    async def test_failed_scheduler_does_not_prevent_worker_cleanup(self):
        async def fail():
            raise ConnectionError("database unavailable")

        for scheduler in (MatchScheduler(), BetaInviteScheduler()):
            scheduler._task = asyncio.create_task(fail())
            await asyncio.sleep(0)
            await scheduler.stop()
            self.assertIsNone(scheduler._task)


if __name__ == "__main__":
    unittest.main()
