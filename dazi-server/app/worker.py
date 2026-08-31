from __future__ import annotations

import asyncio
import logging
import signal
import time
from pathlib import Path

from app.core.database import engine
from app.core.redis import close_redis
from app.services.agent_server import agent_server
from app.services.embedding_service import embedding_service
from app.services.scheduler import beta_invite_scheduler, match_scheduler
from app.services.service_reminder_monitor import service_reminder_monitor
from app.services.prompt_overrides import load_prompt_overrides


logger = logging.getLogger(__name__)
HEARTBEAT_FILE = Path("/tmp/dazi-worker-heartbeat")


async def run_worker() -> None:
    stop_event = asyncio.Event()
    loop = asyncio.get_running_loop()
    for signal_name in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(signal_name, stop_event.set)

    await load_prompt_overrides()
    agent_server.start()
    match_scheduler.start()
    beta_invite_scheduler.start()
    service_reminder_monitor.start()
    logger.info("Scheduler worker started")

    try:
        while not stop_event.is_set():
            for scheduler in (match_scheduler, beta_invite_scheduler, service_reminder_monitor):
                if scheduler._task is None or scheduler._task.done():
                    raise RuntimeError(f"Scheduler task stopped: {type(scheduler).__name__}")
            HEARTBEAT_FILE.write_text(str(time.time()), encoding="ascii")
            try:
                await asyncio.wait_for(stop_event.wait(), timeout=15)
            except asyncio.TimeoutError:
                pass
    finally:
        await match_scheduler.stop()
        await beta_invite_scheduler.stop()
        await service_reminder_monitor.stop()
        await agent_server.close()
        await embedding_service.close()
        await close_redis()
        await engine.dispose()
        HEARTBEAT_FILE.unlink(missing_ok=True)
        logger.info("Scheduler worker stopped")


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    )
    asyncio.run(run_worker())


if __name__ == "__main__":
    main()
