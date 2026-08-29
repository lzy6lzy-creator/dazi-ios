from __future__ import annotations

from dataclasses import dataclass
from typing import Optional
from uuid import UUID

from sqlalchemy import delete, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.redis import ChatHistoryCache
from app.models.chat import ChatRoom
from app.models.event import Event, MatchLog
from app.models.invitation import InvitationLedger, SignupAdmission
from app.models.user import User
from app.services.media_storage import delete_user_media_files


@dataclass(frozen=True)
class AccountDeletionResult:
    user_id: UUID
    user_name: str
    phone: Optional[str]
    deleted_event_count: int


async def delete_user_account(
    db: AsyncSession,
    *,
    user_id: UUID,
) -> Optional[AccountDeletionResult]:
    """Permanently remove a user and invalidate data not covered by FK cascades."""
    user_result = await db.execute(select(User).where(User.id == user_id))
    user = user_result.scalar_one_or_none()
    if user is None:
        return None

    event_result = await db.execute(select(Event.id).where(Event.user_id == user_id))
    event_ids = [row[0] for row in event_result.all()]

    if event_ids:
        await db.execute(
            delete(MatchLog).where(
                or_(MatchLog.event_a_id.in_(event_ids), MatchLog.event_b_id.in_(event_ids))
            )
        )
        await db.execute(
            delete(ChatRoom).where(
                or_(ChatRoom.event_id_a.in_(event_ids), ChatRoom.event_id_b.in_(event_ids))
            )
        )
        await db.execute(
            update(Event)
            .where(Event.matched_event_id.in_(event_ids))
            .values(status="pending", matched_event_id=None, match_score=None)
        )

    admission_filters = [SignupAdmission.invitation_account_user_id == user_id]
    if user.phone:
        admission_filters.append(SignupAdmission.phone == user.phone)
    await db.execute(delete(SignupAdmission).where(or_(*admission_filters)))

    # This FK uses SET NULL so delete the redemption record explicitly.
    await db.execute(
        delete(InvitationLedger).where(InvitationLedger.invitee_user_id == user_id)
    )

    result = AccountDeletionResult(
        user_id=user.id,
        user_name=user.name,
        phone=user.phone,
        deleted_event_count=len(event_ids),
    )
    # Use a SQL delete so PostgreSQL owns the ON DELETE behavior. Deleting the
    # loaded ORM object would first try to detach Agent by setting user_id NULL.
    await db.execute(delete(User).where(User.id == user_id))
    await db.flush()
    delete_user_media_files(user_id)
    await ChatHistoryCache.clear_user_state(str(user_id))
    return result
