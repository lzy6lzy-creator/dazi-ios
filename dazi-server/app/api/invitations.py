"""Invitation balances and privacy-safe public code validation."""
from uuid import UUID

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.schemas import InvitationMeResponse, InvitationStatusResponse
from app.core.database import get_db
from app.core.security import get_current_user_id
from app.models.invitation import InvitationMilestone, UserInvitationAccount
from app.services.invitation_policy import available_balance
from app.services.invitation_service import normalize_invite_code, release_expired_reservations


router = APIRouter(prefix="/api/v1/invitations", tags=["invitations"])


@router.get("/me", response_model=InvitationMeResponse)
async def get_my_invitation(
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    account_result = await db.execute(
        select(UserInvitationAccount).where(UserInvitationAccount.user_id == user_id)
    )
    account = account_result.scalar_one_or_none()
    milestones_result = await db.execute(
        select(InvitationMilestone).where(InvitationMilestone.user_id == user_id)
    )
    milestones = {
        item.milestone_type: item.status
        for item in milestones_result.scalars().all()
    }

    if account is None:
        return {
            "code": None,
            "status": None,
            "granted": 0,
            "consumed": 0,
            "reserved": 0,
            "available": 0,
            "share_url": None,
            "milestones": milestones,
        }

    return {
        "code": account.code,
        "status": account.status,
        "granted": account.granted_total,
        "consumed": account.consumed_total,
        "reserved": account.reserved_total,
        "available": available_balance(account),
        "share_url": f"https://idabuda.com/i/{account.code}",
        "milestones": milestones,
    }


@router.get("/{code}/status", response_model=InvitationStatusResponse)
async def invitation_status(
    code: str,
    db: AsyncSession = Depends(get_db),
):
    normalized = normalize_invite_code(code)
    result = await db.execute(
        select(UserInvitationAccount)
        .where(UserInvitationAccount.code == normalized)
        .with_for_update()
    )
    account = result.scalar_one_or_none()
    if account is None or account.status != "active":
        return {"valid": False, "available": 0}

    await release_expired_reservations(db, account=account)

    remaining = available_balance(account)
    if remaining <= 0:
        return {"valid": False, "available": 0}
    return {"valid": True, "available": remaining}
