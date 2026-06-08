"""
User & Agent API - 用户信息、Agent 配置
"""
from __future__ import annotations

from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_db
from app.core.security import get_current_user_id
from app.models.user import User, Agent, AgentMemory
from app.models.event import Event
from app.services.embedding_service import embedding_service
from app.api.schemas import (
    UserResponse, UserUpdate,
    AgentResponse, AgentUpdate,
    MemoryResponse, MemoryUpdate,
    PublicProfileEventResponse, PublicUserProfileResponse,
)

router = APIRouter(prefix="/api/v1", tags=["users"])

PROFILE_EVENT_VISIBILITY_HIDDEN = "hidden"
PROFILE_EVENT_VISIBILITY_PARTIAL = "partial"
PROFILE_EVENT_VISIBILITY_PUBLIC = "public"
PROFILE_EVENT_VISIBILITY_OPTIONS = {
    PROFILE_EVENT_VISIBILITY_HIDDEN,
    PROFILE_EVENT_VISIBILITY_PARTIAL,
    PROFILE_EVENT_VISIBILITY_PUBLIC,
}


# ── User ──

@router.get("/users/me", response_model=UserResponse)
async def get_me(
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")
    return user


@router.put("/users/me", response_model=UserResponse)
async def update_me(
    data: UserUpdate,
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")

    update_data = data.model_dump(exclude_unset=True)
    if "profile_event_visibility" in update_data:
        update_data["profile_event_visibility"] = _normalize_profile_event_visibility(
            update_data["profile_event_visibility"]
        )
    for field, value in update_data.items():
        setattr(user, field, value)

    # 当兴趣相关字段变化时，重新生成 embedding
    embedding_fields = {"interests", "custom_interests", "occupation"}
    if embedding_fields & update_data.keys():
        user.embedding = await _generate_user_embedding(user)

    await db.flush()
    return user


@router.get("/users/{profile_user_id}/profile", response_model=PublicUserProfileResponse)
async def get_public_user_profile(
    profile_user_id: UUID,
    _viewer_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(User).where(User.id == profile_user_id, User.is_active == True)
    )
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")

    visibility = _normalize_profile_event_visibility(user.profile_event_visibility)
    events_result = await db.execute(
        select(Event)
        .where(Event.user_id == profile_user_id, Event.status == "completed")
        .order_by(Event.start_time.desc().nullslast(), Event.created_at.desc())
        .limit(20)
    )
    return _build_public_profile_response(user, events_result.scalars().all(), visibility)


# ── Agent ──

@router.get("/agents/me", response_model=AgentResponse)
async def get_my_agent(
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Agent).where(Agent.user_id == user_id))
    agent = result.scalar_one_or_none()
    if not agent:
        raise HTTPException(status_code=404, detail="Agent 不存在")
    return agent


@router.put("/agents/me", response_model=AgentResponse)
async def update_my_agent(
    data: AgentUpdate,
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Agent).where(Agent.user_id == user_id))
    agent = result.scalar_one_or_none()
    if not agent:
        raise HTTPException(status_code=404, detail="Agent 不存在")

    update_data = data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(agent, field, value)

    await db.flush()
    return agent


# ── Agent Memories ──

@router.get("/agents/me/memories", response_model=list[MemoryResponse])
async def get_my_memories(
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(AgentMemory)
        .where(
            AgentMemory.user_id == user_id,
            AgentMemory.is_active == True,
            AgentMemory.status != "inactive",
        )
        .order_by(AgentMemory.confidence.desc())
    )
    return result.scalars().all()


@router.patch("/agents/me/memories/{memory_id}", response_model=MemoryResponse)
async def update_my_memory(
    memory_id: UUID,
    data: MemoryUpdate,
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(AgentMemory).where(AgentMemory.id == memory_id, AgentMemory.user_id == user_id)
    )
    memory = result.scalar_one_or_none()
    if not memory:
        raise HTTPException(status_code=404, detail="记忆不存在")

    if data.content is not None:
        memory.content = data.content.strip()
    if data.status is not None:
        memory.status = data.status
        memory.is_active = data.status == "active"
    if data.is_active is not None:
        memory.is_active = data.is_active
        memory.status = "active" if data.is_active else "inactive"
    memory.updated_at = datetime.now(timezone.utc)
    await db.flush()
    return memory


@router.delete("/agents/me/memories/{memory_id}")
async def delete_my_memory(
    memory_id: UUID,
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(AgentMemory).where(AgentMemory.id == memory_id, AgentMemory.user_id == user_id)
    )
    memory = result.scalar_one_or_none()
    if not memory:
        raise HTTPException(status_code=404, detail="记忆不存在")

    memory.is_active = False
    memory.status = "inactive"
    memory.updated_at = datetime.now(timezone.utc)
    await db.flush()
    return {"ok": True}


# ── Helpers ──

def _normalize_profile_event_visibility(value: str | None) -> str:
    if value in PROFILE_EVENT_VISIBILITY_OPTIONS:
        return value
    return PROFILE_EVENT_VISIBILITY_PARTIAL


def _build_public_profile_response(
    user: User,
    events: list[Event],
    visibility: str | None = None,
) -> PublicUserProfileResponse:
    normalized_visibility = _normalize_profile_event_visibility(visibility)
    past_events = [
        payload
        for event in events
        if (payload := _public_profile_event_payload(event, normalized_visibility)) is not None
    ]
    return PublicUserProfileResponse(
        id=user.id,
        name=user.name,
        gender=user.gender,
        birth_year=user.birth_year,
        birth_date=user.birth_date,
        bio=user.bio,
        avatar_url=user.avatar_url,
        interests=user.interests,
        city=user.city,
        occupation=user.occupation,
        custom_interests=user.custom_interests,
        welcome_disturb=user.welcome_disturb,
        profile_event_visibility=normalized_visibility,
        past_events=past_events,
        created_at=user.created_at,
    )


def _public_profile_event_payload(
    event: Event,
    visibility: str,
) -> PublicProfileEventResponse | None:
    if visibility == PROFILE_EVENT_VISIBILITY_HIDDEN:
        return None

    if visibility == PROFILE_EVENT_VISIBILITY_PARTIAL:
        event_time = event.start_time or event.created_at
        return PublicProfileEventResponse(
            id=event.id,
            title=event.activity_type or event.title,
            activity_type=event.activity_type,
            detail_level=PROFILE_EVENT_VISIBILITY_PARTIAL,
            time_label=_month_label(event_time),
            location=event.city or event.location,
            city=event.city,
            status=event.status,
            created_at=event.created_at,
        )

    return PublicProfileEventResponse(
        id=event.id,
        title=event.title,
        activity_type=event.activity_type,
        detail_level=PROFILE_EVENT_VISIBILITY_PUBLIC,
        time_label=_full_time_label(event.start_time),
        start_time=event.start_time,
        end_time=event.end_time,
        location=event.location,
        city=event.city,
        description=event.description,
        preferences=event.preferences,
        constraints=event.constraints,
        status=event.status,
        created_at=event.created_at,
    )


def _month_label(value: datetime | None) -> str | None:
    if value is None:
        return None
    return f"{value.year}年{value.month}月"


def _full_time_label(value: datetime | None) -> str | None:
    if value is None:
        return None
    return value.strftime("%Y-%m-%d %H:%M")

async def _generate_user_embedding(user: User) -> list[float] | None:
    """基于用户兴趣信息生成 embedding"""
    parts = []
    if user.interests:
        parts.append(f"爱好: {', '.join(user.interests)}")
    if user.custom_interests:
        parts.append(user.custom_interests)
    if user.occupation:
        parts.append(f"职业: {user.occupation}")
    if not parts:
        return None
    text = ". ".join(parts)
    return await embedding_service.encode(text)
