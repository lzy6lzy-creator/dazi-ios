from __future__ import annotations

import asyncio
import logging
import ssl
from datetime import date, datetime, timezone
from typing import Optional
from zoneinfo import ZoneInfo

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import async_session
from app.models.service_reminder import ServiceReminder


logger = logging.getLogger(__name__)

DOMAIN_RDAP_URL = "https://rdap.verisign.com/com/v1/domain/idabuda.com"
DOMAIN_SLUG = "idabuda-domain"
TLS_SLUG = "idabuda-tls"
TLS_HOST = "idabuda.com"
CHECK_INTERVAL_SECONDS = 24 * 60 * 60


def domain_expiration_from_rdap(payload: dict) -> date:
    for event in payload.get("events") or []:
        if event.get("eventAction") != "expiration":
            continue
        raw_value = str(event.get("eventDate") or "").strip()
        if not raw_value:
            break
        expires_at = datetime.fromisoformat(raw_value.replace("Z", "+00:00"))
        return expires_at.astimezone(ZoneInfo("Asia/Shanghai")).date()
    raise ValueError("RDAP response does not contain a domain expiration event")


async def fetch_domain_expiration(client: Optional[httpx.AsyncClient] = None) -> date:
    owns_client = client is None
    request_client = client or httpx.AsyncClient(timeout=15.0)
    try:
        response = await request_client.get(DOMAIN_RDAP_URL)
        response.raise_for_status()
        return domain_expiration_from_rdap(response.json())
    finally:
        if owns_client:
            await request_client.aclose()


async def fetch_tls_expiration(host: str = TLS_HOST, port: int = 443) -> date:
    context = ssl.create_default_context()
    reader, writer = await asyncio.wait_for(
        asyncio.open_connection(host, port, ssl=context, server_hostname=host),
        timeout=15.0,
    )
    del reader
    try:
        ssl_object = writer.get_extra_info("ssl_object")
        certificate = ssl_object.getpeercert() if ssl_object else None
        not_after = (certificate or {}).get("notAfter")
        if not not_after:
            raise ValueError("TLS certificate does not contain notAfter")
        expires_at = datetime.fromtimestamp(ssl.cert_time_to_seconds(not_after), timezone.utc)
        return expires_at.astimezone(ZoneInfo("Asia/Shanghai")).date()
    finally:
        writer.close()
        try:
            await writer.wait_closed()
        except Exception:
            pass


async def refresh_external_service_reminders(db: AsyncSession) -> dict:
    """Refresh public domain and TLS dates without reading account credentials."""
    checked_at = datetime.now(timezone.utc)
    refreshed: list[dict] = []
    errors: list[dict] = []

    checks = [
        (DOMAIN_SLUG, fetch_domain_expiration),
        (TLS_SLUG, fetch_tls_expiration),
    ]
    for slug, check in checks:
        try:
            due_date = await check()
            result = await db.execute(select(ServiceReminder).where(ServiceReminder.slug == slug))
            item = result.scalar_one_or_none()
            if not item:
                errors.append({"slug": slug, "error": "reminder_missing"})
                continue
            item.due_date = due_date
            item.date_precision = "exact"
            item.last_verified_at = checked_at
            item.updated_at = checked_at
            refreshed.append({"slug": slug, "due_date": due_date.isoformat()})
        except Exception as exc:
            logger.warning("Service reminder online check failed for %s: %s", slug, exc)
            errors.append({"slug": slug, "error": "online_check_failed"})

    await db.flush()
    return {
        "checked_at": checked_at.isoformat(),
        "refreshed": refreshed,
        "errors": errors,
    }


class ServiceReminderMonitor:
    def __init__(self, interval_seconds: int = CHECK_INTERVAL_SECONDS):
        self.interval_seconds = interval_seconds
        self._task: Optional[asyncio.Task] = None

    def start(self) -> None:
        if self._task and not self._task.done():
            return
        self._task = asyncio.create_task(self._run(), name="service-reminder-monitor")
        logger.info("Service reminder monitor started with a 24-hour interval.")

    async def stop(self) -> None:
        if not self._task:
            return
        self._task.cancel()
        try:
            await self._task
        except asyncio.CancelledError:
            pass
        self._task = None

    async def _run(self) -> None:
        while True:
            try:
                async with async_session() as db:
                    await refresh_external_service_reminders(db)
                    await db.commit()
            except asyncio.CancelledError:
                raise
            except Exception:
                logger.exception("Service reminder monitor run failed")
            await asyncio.sleep(self.interval_seconds)


service_reminder_monitor = ServiceReminderMonitor()
