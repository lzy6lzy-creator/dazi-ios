from __future__ import annotations

import logging
from contextlib import asynccontextmanager
from functools import wraps
from typing import AsyncIterator, Awaitable, Callable, ParamSpec, TypeVar
from sqlalchemy import text

from app.core.database import engine


logger = logging.getLogger(__name__)
P = ParamSpec("P")
R = TypeVar("R")

@asynccontextmanager
async def distributed_lock(name: str) -> AsyncIterator[bool]:
    """Hold a PostgreSQL session lock for the whole job, without an expiring TTL."""
    async with engine.connect() as connection:
        acquired = await connection.scalar(
            text("SELECT pg_try_advisory_lock(hashtextextended(:name, 0))"),
            {"name": f"dazi:job:{name}"},
        )
        try:
            yield bool(acquired)
        finally:
            if acquired:
                try:
                    await connection.execute(
                        text("SELECT pg_advisory_unlock(hashtextextended(:name, 0))"),
                        {"name": f"dazi:job:{name}"},
                    )
                except BaseException:
                    # Never return a still-locked physical connection to the pool.
                    await connection.invalidate()
                    raise


def singleton_job(
    name: str,
) -> Callable[[Callable[P, Awaitable[R]]], Callable[P, Awaitable[R | None]]]:
    """Skip a job when another process already owns its database lock."""

    def decorate(function: Callable[P, Awaitable[R]]) -> Callable[P, Awaitable[R | None]]:
        @wraps(function)
        async def wrapped(*args: P.args, **kwargs: P.kwargs) -> R | None:
            async with distributed_lock(name) as acquired:
                if not acquired:
                    logger.info("Job %s skipped because another process owns the lock", name)
                    return None
                return await function(*args, **kwargs)

        return wrapped

    return decorate
