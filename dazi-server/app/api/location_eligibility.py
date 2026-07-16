"""Short-lived device location verification for invitation rewards."""
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.schemas import LocationVerificationRequest, LocationVerificationResponse
from app.core.database import get_db
from app.core.security import get_current_user_id
from app.services.invitation_reward_service import (
    LocationSubmissionError,
    verify_launch_city_location,
)


router = APIRouter(prefix="/api/v1/location", tags=["location"])


@router.post("/verify", response_model=LocationVerificationResponse)
async def verify_location(
    data: LocationVerificationRequest,
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    try:
        verification, settled = await verify_launch_city_location(
            db,
            user_id=user_id,
            latitude=data.latitude,
            longitude=data.longitude,
            accuracy_meters=data.accuracy_meters,
            captured_at=data.captured_at,
        )
    except LocationSubmissionError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    return {
        "is_launch_city": verification.is_launch_city,
        "city_code": verification.city_code,
        "expires_at": verification.expires_at,
        "settled_milestones": settled,
    }
