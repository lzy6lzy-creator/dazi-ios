from __future__ import annotations

import hashlib
import re
import secrets
import uuid
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Optional

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.invitation import (
    InvitationLedger,
    InvitationProgram,
    SignupAdmission,
    UserInvitationAccount,
)
from app.models.user import User
from app.services.invitation_policy import available_balance, is_admission_active


ADMISSION_TTL_SECONDS = 600
INVITE_CODE_RE = re.compile(r"^[A-HJ-NP-Z2-9]{8}$")


class InvitationServiceError(RuntimeError):
    pass


class RegistrationPausedError(InvitationServiceError):
    pass


class InvitationRequiredError(InvitationServiceError):
    def __init__(self, *, qualified_user_count: int, qualified_target: int):
        super().__init__("Invitation code is required")
        self.qualified_user_count = qualified_user_count
        self.qualified_target = qualified_target


class InvitationUnavailableError(InvitationServiceError):
    pass


class AdmissionInvalidError(InvitationServiceError):
    pass


class SmsRateLimitError(InvitationServiceError):
    def __init__(self, retry_after: int):
        super().__init__("SMS send rate limited")
        self.retry_after = retry_after


@dataclass(frozen=True)
class RegistrationPolicy:
    registration_mode: str
    launch_city_code: str
    qualified_user_count: int
    qualified_target: int
    ios_distribution_mode: str
    testflight_public_url: Optional[str]
    app_store_url: Optional[str]

    @property
    def invitation_required(self) -> bool:
        return self.registration_mode == "invite_only"


@dataclass(frozen=True)
class IssuedAdmission:
    raw_token: str
    expires_in: int
    registration_mode: str
    admission_type: str = "open"
    qualified_user_count: int = 0
    qualified_target: int = 0


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def normalize_invite_code(raw: Optional[str]) -> Optional[str]:
    if not raw:
        return None
    normalized = raw.strip().upper().replace("-", "").replace(" ", "")
    return normalized if INVITE_CODE_RE.fullmatch(normalized) else None


def hash_admission_token(raw_token: str) -> str:
    return hashlib.sha256(f"signup-admission:{raw_token}".encode("utf-8")).hexdigest()


def hash_identifier(value: Optional[str], namespace: str) -> Optional[str]:
    if not value:
        return None
    return hashlib.sha256(f"{namespace}:{value}".encode("utf-8")).hexdigest()


async def release_expired_reservations(
    db: AsyncSession,
    *,
    account: UserInvitationAccount,
    now: Optional[datetime] = None,
) -> int:
    current_time = now or utc_now()
    result = await db.execute(
        select(SignupAdmission)
        .where(
            SignupAdmission.invitation_account_user_id == account.user_id,
            SignupAdmission.status == "issued",
            SignupAdmission.expires_at <= current_time,
        )
        .with_for_update(skip_locked=True)
    )
    expired = result.scalars().all()
    for admission in expired:
        admission.status = "expired"
    released = min(len(expired), account.reserved_total)
    account.reserved_total -= released
    if expired:
        await db.flush()
    return released


async def get_invitation_program(
    db: AsyncSession,
    *,
    lock: bool = False,
) -> InvitationProgram:
    query = select(InvitationProgram).where(InvitationProgram.id == 1)
    if lock:
        query = query.with_for_update()
    result = await db.execute(query)
    program = result.scalar_one_or_none()
    if program is None:
        program = InvitationProgram(id=1)
        db.add(program)
        await db.flush()
    return program


async def get_registration_policy(db: AsyncSession) -> RegistrationPolicy:
    program = await get_invitation_program(db)
    return RegistrationPolicy(
        registration_mode=program.registration_mode,
        launch_city_code=program.launch_city_code,
        qualified_user_count=program.qualified_user_count,
        qualified_target=program.qualified_target,
        ios_distribution_mode=program.ios_distribution_mode,
        testflight_public_url=program.testflight_public_url,
        app_store_url=program.app_store_url,
    )


async def issue_signup_admission(
    db: AsyncSession,
    *,
    phone: str,
    invite_code: Optional[str] = None,
    install_id: Optional[str] = None,
    client_ip: Optional[str] = None,
    whitelist_bypass: bool = False,
    location_city_code: Optional[str] = None,
    location_is_launch_city: Optional[bool] = None,
    location_accuracy_meters: Optional[float] = None,
    location_verified_at: Optional[datetime] = None,
    now: Optional[datetime] = None,
) -> IssuedAdmission:
    current_time = now or utc_now()
    user_result = await db.execute(select(User.id).where(User.phone == phone))
    existing_user_id = user_result.scalar_one_or_none()
    program = await get_invitation_program(db, lock=True)
    qualified_user_count = int(getattr(program, "qualified_user_count", 0))
    qualified_target = int(getattr(program, "qualified_target", 0))

    invitation_account_user_id = None
    if existing_user_id is not None:
        admission_type = "existing"
    elif whitelist_bypass:
        admission_type = "whitelist"
    elif program.registration_mode == "paused":
        raise RegistrationPausedError("New registrations are paused")
    elif program.registration_mode == "open":
        admission_type = "open"
    elif program.registration_mode == "invite_only":
        normalized_code = normalize_invite_code(invite_code)
        if normalized_code is None:
            raise InvitationRequiredError(
                qualified_user_count=qualified_user_count,
                qualified_target=qualified_target,
            )
        account_result = await db.execute(
            select(UserInvitationAccount)
            .where(func.upper(UserInvitationAccount.code) == normalized_code)
            .with_for_update()
        )
        account = account_result.scalar_one_or_none()
        if account is not None:
            await release_expired_reservations(db, account=account, now=current_time)
        if (
            account is None
            or account.status != "active"
            or available_balance(account) <= 0
        ):
            raise InvitationUnavailableError("Invitation code is unavailable")
        account.reserved_total += 1
        invitation_account_user_id = account.user_id
        admission_type = "invitation"
    else:
        raise RegistrationPausedError("Registration mode is unavailable")

    raw_token = secrets.token_urlsafe(32)
    admission = SignupAdmission(
        id=uuid.uuid4(),
        token_hash=hash_admission_token(raw_token),
        phone=phone,
        admission_type=admission_type,
        registration_mode=program.registration_mode,
        invitation_account_user_id=invitation_account_user_id,
        status="issued",
        failed_attempts=0,
        install_id_hash=hash_identifier(install_id, "install"),
        ip_hash=hash_identifier(client_ip, "ip"),
        location_city_code=location_city_code,
        location_is_launch_city=location_is_launch_city,
        location_accuracy_meters=location_accuracy_meters,
        location_verified_at=location_verified_at,
        expires_at=current_time + timedelta(seconds=ADMISSION_TTL_SECONDS),
        created_at=current_time,
    )
    db.add(admission)
    await db.flush()
    return IssuedAdmission(
        raw_token=raw_token,
        expires_in=ADMISSION_TTL_SECONDS,
        registration_mode=program.registration_mode,
        admission_type=admission_type,
        qualified_user_count=qualified_user_count,
        qualified_target=qualified_target,
    )


async def _locked_admission(db: AsyncSession, raw_token: str):
    result = await db.execute(
        select(SignupAdmission)
        .where(SignupAdmission.token_hash == hash_admission_token(raw_token))
        .with_for_update()
    )
    return result.scalar_one_or_none()


async def _release_reservation(db: AsyncSession, admission: SignupAdmission) -> None:
    if admission.admission_type != "invitation" or admission.invitation_account_user_id is None:
        return
    result = await db.execute(
        select(UserInvitationAccount)
        .where(UserInvitationAccount.user_id == admission.invitation_account_user_id)
        .with_for_update()
    )
    account = result.scalar_one_or_none()
    if account is not None and account.reserved_total > 0:
        account.reserved_total -= 1


async def cancel_signup_admission(
    db: AsyncSession,
    *,
    raw_token: str,
    status: str = "cancelled",
) -> Optional[SignupAdmission]:
    admission = await _locked_admission(db, raw_token)
    if admission is None or admission.status != "issued":
        return None
    await _release_reservation(db, admission)
    admission.status = status
    await db.flush()
    return admission


async def record_failed_verification(
    db: AsyncSession,
    *,
    raw_token: Optional[str],
) -> None:
    if not raw_token:
        return
    admission = await _locked_admission(db, raw_token)
    if admission is None or admission.status != "issued":
        return
    admission.failed_attempts += 1
    if admission.failed_attempts >= 5:
        await _release_reservation(db, admission)
        admission.status = "cancelled"
    await db.flush()


async def consume_signup_admission(
    db: AsyncSession,
    *,
    raw_token: str,
    invitee_user_id: uuid.UUID,
    now: Optional[datetime] = None,
) -> SignupAdmission:
    current_time = now or utc_now()
    admission = await _locked_admission(db, raw_token)
    if admission is None or not is_admission_active(admission, current_time):
        raise AdmissionInvalidError("Signup admission is invalid or expired")

    if admission.admission_type == "invitation":
        result = await db.execute(
            select(UserInvitationAccount)
            .where(UserInvitationAccount.user_id == admission.invitation_account_user_id)
            .with_for_update()
        )
        account = result.scalar_one_or_none()
        if account is None or account.reserved_total <= 0:
            raise AdmissionInvalidError("Invitation reservation is missing")
        account.reserved_total -= 1
        account.consumed_total += 1
        db.add(InvitationLedger(
            user_id=account.user_id,
            entry_type="redemption",
            amount=-1,
            idempotency_key=f"redemption:{admission.id}",
            invitee_user_id=invitee_user_id,
            reason="App signup invitation redeemed",
        ))

    admission.status = "consumed"
    admission.consumed_at = current_time
    await db.flush()
    return admission


class SmsSendRateLimiter:
    SCRIPT = """
local cooldown = redis.call('SET', KEYS[1], '1', 'NX', 'EX', ARGV[1])
if not cooldown then return 1 end
local daily = redis.call('INCR', KEYS[2])
if daily == 1 then redis.call('EXPIRE', KEYS[2], ARGV[2]) end
if daily > tonumber(ARGV[3]) then return 2 end
local hourly = redis.call('INCR', KEYS[3])
if hourly == 1 then redis.call('EXPIRE', KEYS[3], ARGV[4]) end
if hourly > tonumber(ARGV[5]) then return 3 end
return 0
"""

    def __init__(self, redis_client):
        self.redis = redis_client

    async def enforce(self, *, phone: str, client_ip: Optional[str]) -> None:
        phone_hash = hash_identifier(phone, "sms-phone")
        ip_hash = hash_identifier(client_ip or "unknown", "sms-ip")
        result = await self.redis.eval(
            self.SCRIPT,
            3,
            f"sms:cooldown:{phone_hash}",
            f"sms:daily:{phone_hash}",
            f"sms:hourly-ip:{ip_hash}",
            60,
            86400,
            10,
            3600,
            30,
        )
        if result == 1:
            raise SmsRateLimitError(retry_after=60)
        if result == 2:
            raise SmsRateLimitError(retry_after=86400)
        if result == 3:
            raise SmsRateLimitError(retry_after=3600)
