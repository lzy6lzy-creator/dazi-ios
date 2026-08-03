from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import Boolean, CheckConstraint, Float, ForeignKey, Integer, String, TIMESTAMP, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class InvitationProgram(Base):
    __tablename__ = "invitation_programs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, default=1)
    registration_mode: Mapped[str] = mapped_column(String(20), default="open", nullable=False)
    launch_city_code: Mapped[str] = mapped_column(String(12), default="310000", nullable=False)
    qualified_target: Mapped[int] = mapped_column(Integer, default=500, nullable=False)
    location_valid_days: Mapped[int] = mapped_column(Integer, default=30, nullable=False)
    qualified_user_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    ios_distribution_mode: Mapped[str] = mapped_column(String(20), default="testflight", nullable=False)
    testflight_public_url: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    app_store_url: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    transitioned_at: Mapped[Optional[datetime]] = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    updated_by: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    created_at: Mapped[datetime] = mapped_column(TIMESTAMP(timezone=True), default=utc_now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        TIMESTAMP(timezone=True),
        default=utc_now,
        onupdate=utc_now,
        nullable=False,
    )


class UserInvitationAccount(Base):
    __tablename__ = "user_invitation_accounts"
    __table_args__ = (
        CheckConstraint("granted_total >= 0", name="ck_invitation_account_granted_nonnegative"),
        CheckConstraint("consumed_total >= 0", name="ck_invitation_account_consumed_nonnegative"),
        CheckConstraint("reserved_total >= 0", name="ck_invitation_account_reserved_nonnegative"),
        CheckConstraint(
            "granted_total - consumed_total - reserved_total >= 0",
            name="ck_invitation_account_balance_nonnegative",
        ),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
    )
    code: Mapped[str] = mapped_column(String(8), unique=True, nullable=False, index=True)
    granted_total: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    consumed_total: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    reserved_total: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    status: Mapped[str] = mapped_column(String(20), default="active", nullable=False)
    first_qualified_at: Mapped[Optional[datetime]] = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(TIMESTAMP(timezone=True), default=utc_now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        TIMESTAMP(timezone=True),
        default=utc_now,
        onupdate=utc_now,
        nullable=False,
    )


class LocationVerification(Base):
    __tablename__ = "location_verifications"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    city_code: Mapped[Optional[str]] = mapped_column(String(12), nullable=True)
    is_launch_city: Mapped[bool] = mapped_column(default=False, nullable=False)
    accuracy_meters: Mapped[float] = mapped_column(nullable=False)
    risk_flags: Mapped[list] = mapped_column(JSONB, default=list, nullable=False)
    verified_at: Mapped[datetime] = mapped_column(TIMESTAMP(timezone=True), default=utc_now, nullable=False)
    expires_at: Mapped[datetime] = mapped_column(TIMESTAMP(timezone=True), nullable=False)


class SignupAdmission(Base):
    __tablename__ = "signup_admissions"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    token_hash: Mapped[str] = mapped_column(String(64), unique=True, nullable=False, index=True)
    phone: Mapped[str] = mapped_column(String(20), nullable=False, index=True)
    admission_type: Mapped[str] = mapped_column(String(20), nullable=False)
    registration_mode: Mapped[str] = mapped_column(String(20), nullable=False)
    invitation_account_user_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("user_invitation_accounts.user_id", ondelete="SET NULL"),
        nullable=True,
    )
    status: Mapped[str] = mapped_column(String(20), default="issued", nullable=False, index=True)
    failed_attempts: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    install_id_hash: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    ip_hash: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    location_city_code: Mapped[Optional[str]] = mapped_column(String(12), nullable=True)
    location_is_launch_city: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)
    location_accuracy_meters: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    location_verified_at: Mapped[Optional[datetime]] = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    expires_at: Mapped[datetime] = mapped_column(TIMESTAMP(timezone=True), nullable=False, index=True)
    consumed_at: Mapped[Optional[datetime]] = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(TIMESTAMP(timezone=True), default=utc_now, nullable=False)


class InvitationLedger(Base):
    __tablename__ = "invitation_ledger"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    entry_type: Mapped[str] = mapped_column(String(30), nullable=False)
    amount: Mapped[int] = mapped_column(Integer, nullable=False)
    idempotency_key: Mapped[str] = mapped_column(String(160), unique=True, nullable=False)
    source_event_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("events.id", ondelete="SET NULL"),
        nullable=True,
    )
    source_chat_room_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("chat_rooms.id", ondelete="SET NULL"),
        nullable=True,
    )
    invitee_user_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        unique=True,
        nullable=True,
    )
    location_verification_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("location_verifications.id", ondelete="SET NULL"),
        nullable=True,
    )
    operator_id: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    reason: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(TIMESTAMP(timezone=True), default=utc_now, nullable=False)


class InvitationMilestone(Base):
    __tablename__ = "invitation_milestones"
    __table_args__ = (
        UniqueConstraint("user_id", "milestone_type", name="uq_invitation_milestone_user_type"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    milestone_type: Mapped[str] = mapped_column(String(30), nullable=False)
    status: Mapped[str] = mapped_column(String(30), default="pending_location", nullable=False)
    source_event_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("events.id", ondelete="SET NULL"),
        nullable=True,
    )
    source_chat_room_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("chat_rooms.id", ondelete="SET NULL"),
        nullable=True,
    )
    settled_at: Mapped[Optional[datetime]] = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(TIMESTAMP(timezone=True), default=utc_now, nullable=False)
