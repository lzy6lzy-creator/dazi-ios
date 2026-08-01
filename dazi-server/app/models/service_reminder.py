from __future__ import annotations

import uuid
from datetime import date, datetime, timezone
from typing import Optional

from sqlalchemy import Boolean, Date, Index, Integer, String, Text, TIMESTAMP
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class ServiceReminder(Base):
    """Operational renewal, expiry, and periodic-review reminder."""

    __tablename__ = "service_reminders"
    __table_args__ = (
        Index("ix_service_reminders_status_due", "status", "due_date"),
        Index("ix_service_reminders_category_due", "category", "due_date"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    slug: Mapped[str] = mapped_column(String(80), nullable=False, unique=True, index=True)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    category: Mapped[str] = mapped_column(String(40), nullable=False, index=True)
    provider: Mapped[Optional[str]] = mapped_column(String(80), nullable=True)
    reminder_type: Mapped[str] = mapped_column(String(30), nullable=False, default="expiry")
    due_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True, index=True)
    date_precision: Mapped[str] = mapped_column(String(20), nullable=False, default="exact")
    recurrence_months: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    reminder_days: Mapped[str] = mapped_column(String(80), nullable=False, default="90,60,30,14,7,1")
    auto_renew: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    owner: Mapped[Optional[str]] = mapped_column(String(80), nullable=True)
    action_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    source: Mapped[str] = mapped_column(String(40), nullable=False, default="manual")
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="active", index=True)
    last_verified_at: Mapped[Optional[datetime]] = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        TIMESTAMP(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    updated_at: Mapped[datetime] = mapped_column(
        TIMESTAMP(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )
