from __future__ import annotations

import asyncio
from functools import lru_cache
from pathlib import Path

from alembic.config import Config
from alembic.script import ScriptDirectory
from sqlalchemy import text

from app.core.database import engine
from app.core.redis import get_redis


@lru_cache(maxsize=1)
def expected_migration_head() -> str:
    root = Path(__file__).resolve().parents[2]
    config = Config(str(root / "alembic.ini"))
    return ScriptDirectory.from_config(config).get_current_head()


async def readiness_report() -> tuple[bool, dict]:
    checks: dict[str, str] = {}
    ready = True

    try:
        async with asyncio.timeout(2), engine.connect() as connection:
            await connection.execute(text("SELECT 1"))
            revision = (
                await connection.execute(text("SELECT version_num FROM alembic_version"))
            ).scalar_one_or_none()
        checks["database"] = "ok"
        expected = expected_migration_head()
        if revision == expected:
            checks["migration"] = revision
        else:
            checks["migration"] = "outdated"
            ready = False
    except Exception:
        checks["database"] = "unavailable"
        checks["migration"] = "unknown"
        ready = False

    try:
        async with asyncio.timeout(2):
            redis = await get_redis()
            checks["redis"] = "ok" if await redis.ping() else "unavailable"
        ready = ready and checks["redis"] == "ok"
    except Exception:
        checks["redis"] = "unavailable"
        ready = False

    return ready, {
        "status": "ready" if ready else "not_ready",
        "checks": checks,
    }
