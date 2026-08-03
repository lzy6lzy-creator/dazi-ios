from __future__ import annotations

import secrets
import uuid
import logging
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Optional

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.invitation import (
    InvitationLedger,
    InvitationMilestone,
    LocationVerification,
    UserInvitationAccount,
)
from app.services.invitation_policy import point_in_shanghai, should_transition
from app.services.invitation_service import get_invitation_program


MILESTONE_REWARDS = {
    "first_event_publish": 3,
    "first_match": 2,
}
INVITE_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
MAX_LOCATION_AGE = timedelta(minutes=5)
MAX_LOCATION_FUTURE_SKEW = timedelta(minutes=1)
MAX_LOCATION_ACCURACY_METERS = 1000.0
logger = logging.getLogger(__name__)


class LocationSubmissionError(ValueError):
    pass


@dataclass(frozen=True)
class LocationAssessment:
    is_launch_city: bool
    city_code: Optional[str]
    risk_flags: tuple[str, ...]


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def generate_invite_code() -> str:
    return "".join(secrets.choice(INVITE_CODE_ALPHABET) for _ in range(8))


def assess_launch_city_location(
    *,
    latitude: float,
    longitude: float,
    accuracy_meters: float,
    captured_at: datetime,
    now: Optional[datetime] = None,
) -> LocationAssessment:
    current_time = now or utc_now()
    if captured_at.tzinfo is None:
        raise LocationSubmissionError("定位时间缺少时区")
    if not (-90 <= latitude <= 90 and -180 <= longitude <= 180):
        raise LocationSubmissionError("定位坐标无效")
    if accuracy_meters <= 0 or accuracy_meters > MAX_LOCATION_ACCURACY_METERS:
        raise LocationSubmissionError("定位精度不足，请在开阔位置重试")
    if current_time - captured_at > MAX_LOCATION_AGE:
        raise LocationSubmissionError("定位已过期，请重新获取")
    if captured_at - current_time > MAX_LOCATION_FUTURE_SKEW:
        raise LocationSubmissionError("定位时间无效")

    is_launch_city = point_in_shanghai(latitude=latitude, longitude=longitude)
    return LocationAssessment(
        is_launch_city=is_launch_city,
        city_code="310000" if is_launch_city else None,
        risk_flags=(),
    )


async def verify_launch_city_location(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    latitude: float,
    longitude: float,
    accuracy_meters: float,
    captured_at: datetime,
    now: Optional[datetime] = None,
) -> tuple[LocationVerification, list[str]]:
    current_time = now or utc_now()
    assessment = assess_launch_city_location(
        latitude=latitude,
        longitude=longitude,
        accuracy_meters=accuracy_meters,
        captured_at=captured_at,
        now=current_time,
    )
    return await record_launch_city_assessment(
        db,
        user_id=user_id,
        is_launch_city=assessment.is_launch_city,
        city_code=assessment.city_code,
        accuracy_meters=accuracy_meters,
        verified_at=current_time,
        risk_flags=assessment.risk_flags,
        now=current_time,
    )


async def record_launch_city_assessment(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    is_launch_city: bool,
    city_code: Optional[str],
    accuracy_meters: float,
    verified_at: datetime,
    risk_flags: tuple[str, ...] = (),
    now: Optional[datetime] = None,
) -> tuple[LocationVerification, list[str]]:
    current_time = now or utc_now()
    program = await get_invitation_program(db)
    verification = LocationVerification(
        user_id=user_id,
        city_code=city_code,
        is_launch_city=is_launch_city,
        accuracy_meters=accuracy_meters,
        risk_flags=list(risk_flags),
        verified_at=verified_at,
        expires_at=verified_at + timedelta(days=program.location_valid_days),
    )
    db.add(verification)
    await db.flush()

    settled: list[str] = []
    if verification.is_launch_city:
        settled = await settle_pending_milestones(
            db,
            user_id=user_id,
            verification=verification,
            now=current_time,
        )
    return verification, settled


async def record_invitation_milestone(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    milestone_type: str,
    source_event_id: Optional[uuid.UUID] = None,
    source_chat_room_id: Optional[uuid.UUID] = None,
    now: Optional[datetime] = None,
) -> InvitationMilestone:
    if milestone_type not in MILESTONE_REWARDS:
        raise ValueError(f"Unsupported invitation milestone: {milestone_type}")
    current_time = now or utc_now()
    insert_result = await db.execute(
        pg_insert(InvitationMilestone)
        .values(
            id=uuid.uuid4(),
            user_id=user_id,
            milestone_type=milestone_type,
            status="pending_location",
            source_event_id=source_event_id,
            source_chat_room_id=source_chat_room_id,
            created_at=current_time,
        )
        .on_conflict_do_nothing(
            constraint="uq_invitation_milestone_user_type",
        )
        .returning(InvitationMilestone.id)
    )
    milestone_id = insert_result.scalar_one_or_none()
    result = await db.execute(
        select(InvitationMilestone).where(
            InvitationMilestone.id == milestone_id
            if milestone_id is not None
            else (
                (InvitationMilestone.user_id == user_id)
                & (InvitationMilestone.milestone_type == milestone_type)
            )
        )
    )
    milestone = result.scalar_one()
    await settle_pending_milestones(db, user_id=user_id, now=current_time)
    return milestone


async def record_invitation_milestone_safely(
    db: AsyncSession,
    **kwargs,
) -> bool:
    """Record a reward hook behind a savepoint so product actions still succeed."""
    if not hasattr(db, "begin_nested"):
        return False
    try:
        async with db.begin_nested():
            await record_invitation_milestone(db, **kwargs)
        return True
    except Exception:
        logger.exception(
            "Invitation milestone recording failed: type=%s user_id=%s",
            kwargs.get("milestone_type"),
            kwargs.get("user_id"),
        )
        return False


async def _current_launch_city_verification(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    now: datetime,
) -> Optional[LocationVerification]:
    result = await db.execute(
        select(LocationVerification)
        .where(
            LocationVerification.user_id == user_id,
            LocationVerification.is_launch_city.is_(True),
            LocationVerification.expires_at > now,
        )
        .order_by(LocationVerification.verified_at.desc())
        .limit(1)
    )
    return result.scalar_one_or_none()


async def _locked_or_created_account(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    now: datetime,
) -> UserInvitationAccount:
    result = await db.execute(
        select(UserInvitationAccount)
        .where(UserInvitationAccount.user_id == user_id)
        .with_for_update()
    )
    account = result.scalar_one_or_none()
    if account is not None:
        return account

    for _ in range(12):
        await db.execute(
            pg_insert(UserInvitationAccount)
            .values(
                user_id=user_id,
                code=generate_invite_code(),
                granted_total=0,
                consumed_total=0,
                reserved_total=0,
                status="active",
                created_at=now,
                updated_at=now,
            )
            .on_conflict_do_nothing()
        )
        result = await db.execute(
            select(UserInvitationAccount)
            .where(UserInvitationAccount.user_id == user_id)
            .with_for_update()
        )
        account = result.scalar_one_or_none()
        if account is not None:
            return account
    raise RuntimeError("Unable to allocate a unique invitation code")


async def settle_pending_milestones(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    verification: Optional[LocationVerification] = None,
    now: Optional[datetime] = None,
) -> list[str]:
    current_time = now or utc_now()
    if verification is None:
        verification = await _current_launch_city_verification(
            db,
            user_id=user_id,
            now=current_time,
        )
    if verification is None or not verification.is_launch_city or verification.expires_at <= current_time:
        return []

    milestones_result = await db.execute(
        select(InvitationMilestone)
        .where(
            InvitationMilestone.user_id == user_id,
            InvitationMilestone.status == "pending_location",
        )
        .with_for_update()
    )
    milestones = milestones_result.scalars().all()
    if not milestones:
        return []

    program = await get_invitation_program(db, lock=True)
    account = await _locked_or_created_account(db, user_id=user_id, now=current_time)
    first_positive_reward = account.first_qualified_at is None
    settled: list[str] = []

    for milestone in milestones:
        amount = MILESTONE_REWARDS.get(milestone.milestone_type)
        if amount is None:
            continue
        account.granted_total += amount
        milestone.status = "settled"
        milestone.settled_at = current_time
        db.add(InvitationLedger(
            user_id=user_id,
            entry_type="reward",
            amount=amount,
            idempotency_key=f"milestone:{milestone.id}",
            source_event_id=milestone.source_event_id,
            source_chat_room_id=milestone.source_chat_room_id,
            location_verification_id=verification.id,
            reason=milestone.milestone_type,
        ))
        settled.append(milestone.milestone_type)

    if settled and first_positive_reward:
        account.first_qualified_at = current_time
        program.qualified_user_count += 1
        if (
            program.registration_mode == "open"
            and should_transition(program.qualified_user_count, program.qualified_target)
        ):
            program.registration_mode = "invite_only"
            program.transitioned_at = current_time

    await db.flush()
    return settled
