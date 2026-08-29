"""
User & Agent API - 用户信息、Agent 配置
"""
from __future__ import annotations

from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_db
from app.core.security import get_current_user_id
from app.models.user import User, Agent, AgentMemory
from app.models.event import Event, EventGalleryItem
from app.services.embedding_service import embedding_service
from app.services.account_deletion_service import delete_user_account
from app.services.media_storage import (
    AvatarStorageError,
    delete_avatar,
    delete_gallery_photo,
    gallery_photo_path,
    store_avatar,
    store_gallery_photo,
)
from app.api.schemas import (
    UserResponse, UserUpdate,
    AgentResponse, AgentUpdate,
    MemoryResponse, MemoryUpdate,
    PublicProfileEventResponse, PublicUserProfileResponse,
    AccountDeletionResponse, AvatarUploadRequest, AvatarUploadResponse,
    GalleryItemResponse, GalleryItemUpdate, GalleryPhotoUploadRequest,
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


@router.delete("/users/me", response_model=AccountDeletionResponse)
async def delete_me(
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    deletion = await delete_user_account(db, user_id=user_id)
    if deletion is None:
        raise HTTPException(status_code=404, detail="用户不存在")
    return AccountDeletionResponse(
        message="账号已注销",
        deleted_event_count=deletion.deleted_event_count,
    )


@router.put("/users/me/avatar", response_model=AvatarUploadResponse)
async def upload_my_avatar(
    data: AvatarUploadRequest,
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")
    try:
        user.avatar_url = store_avatar(
            owner_kind="user",
            user_id=user_id,
            image_base64=data.image_base64,
            mime_type=data.mime_type,
        )
    except AvatarStorageError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    await db.flush()
    return AvatarUploadResponse(avatar_url=user.avatar_url)


@router.delete("/users/me/avatar", response_model=AvatarUploadResponse)
async def delete_my_avatar(
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")
    delete_avatar(owner_kind="user", user_id=user_id)
    user.avatar_url = None
    await db.flush()
    return AvatarUploadResponse(avatar_url=None)


@router.get("/users/me/gallery", response_model=list[GalleryItemResponse])
async def get_my_gallery(
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(EventGalleryItem, Event)
        .join(Event, Event.id == EventGalleryItem.event_id)
        .where(EventGalleryItem.user_id == user_id)
        .order_by(Event.start_time.desc().nullslast(), EventGalleryItem.created_at.desc())
    )
    return [_gallery_item_response(item, event) for item, event in result.all()]


@router.put("/users/me/gallery/{event_id}", response_model=GalleryItemResponse)
async def update_my_gallery_item(
    event_id: UUID,
    data: GalleryItemUpdate,
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    event = await _completed_owned_event(db, user_id=user_id, event_id=event_id)
    item = await _get_or_create_gallery_item(db, user_id=user_id, event_id=event_id)
    item.is_displayed = data.is_displayed
    item.updated_at = datetime.now(timezone.utc)
    await db.flush()
    return _gallery_item_response(item, event)


@router.post("/users/me/gallery/{event_id}/photos", response_model=GalleryItemResponse)
async def upload_my_gallery_photo(
    event_id: UUID,
    data: GalleryPhotoUploadRequest,
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    event = await _completed_owned_event(db, user_id=user_id, event_id=event_id)
    item = await _get_or_create_gallery_item(db, user_id=user_id, event_id=event_id)
    current_urls = list(item.photo_urls or [])
    if len(current_urls) >= 3:
        raise HTTPException(status_code=400, detail="每个活动最多上传 3 张照片")
    try:
        photo_url = store_gallery_photo(
            user_id=user_id,
            event_id=event_id,
            image_base64=data.image_base64,
            mime_type=data.mime_type,
        )
    except AvatarStorageError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    if photo_url not in current_urls:
        current_urls.append(photo_url)
    item.photo_urls = current_urls
    item.is_displayed = True
    item.updated_at = datetime.now(timezone.utc)
    await db.flush()
    return _gallery_item_response(item, event)


@router.delete("/users/me/gallery/{event_id}/photos/{photo_name}", response_model=GalleryItemResponse)
async def delete_my_gallery_photo(
    event_id: UUID,
    photo_name: str,
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    event = await _completed_owned_event(db, user_id=user_id, event_id=event_id)
    result = await db.execute(
        select(EventGalleryItem)
        .where(EventGalleryItem.user_id == user_id, EventGalleryItem.event_id == event_id)
        .with_for_update()
    )
    item = result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=404, detail="相册记录不存在")
    photo_url = next(
        (url for url in (item.photo_urls or []) if url.rsplit("/", 1)[-1] == photo_name),
        None,
    )
    if not photo_url:
        raise HTTPException(status_code=404, detail="相册照片不存在")
    try:
        delete_gallery_photo(user_id=user_id, photo_url=photo_url)
    except AvatarStorageError as exc:
        raise HTTPException(status_code=403, detail=str(exc)) from exc
    item.photo_urls = [url for url in (item.photo_urls or []) if url != photo_url]
    item.updated_at = datetime.now(timezone.utc)
    await db.flush()
    return _gallery_item_response(item, event)


@router.get("/gallery/media/{photo_name}")
async def get_gallery_photo(
    photo_name: str,
    viewer_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    try:
        owner_id = UUID(photo_name[:36])
    except (ValueError, TypeError):
        raise HTTPException(status_code=404, detail="相册照片不存在")
    photo_url = f"/api/v1/gallery/media/{photo_name}"
    result = await db.execute(
        select(EventGalleryItem, Event, User)
        .join(Event, Event.id == EventGalleryItem.event_id)
        .join(User, User.id == EventGalleryItem.user_id)
        .where(EventGalleryItem.user_id == owner_id)
    )
    allowed = False
    for item, event, owner in result.all():
        if photo_url not in (item.photo_urls or []):
            continue
        allowed = viewer_id == owner_id or (
            owner.profile_event_visibility == PROFILE_EVENT_VISIBILITY_PUBLIC
            and item.is_displayed
            and event.status == "completed"
        )
        break
    if not allowed:
        raise HTTPException(status_code=404, detail="相册照片不存在")
    path = gallery_photo_path(photo_name)
    if path is None:
        raise HTTPException(status_code=404, detail="相册照片不存在")
    media_type = {
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".png": "image/png",
        ".webp": "image/webp",
    }.get(path.suffix.lower(), "application/octet-stream")
    return FileResponse(
        path,
        media_type=media_type,
        headers={"Cache-Control": "private, max-age=3600"},
    )


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
    gallery_rows = []
    if visibility == PROFILE_EVENT_VISIBILITY_PUBLIC:
        gallery_result = await db.execute(
            select(EventGalleryItem, Event)
            .join(Event, Event.id == EventGalleryItem.event_id)
            .where(
                EventGalleryItem.user_id == profile_user_id,
                EventGalleryItem.is_displayed.is_(True),
                Event.status == "completed",
            )
            .order_by(Event.start_time.desc().nullslast(), EventGalleryItem.created_at.desc())
            .limit(20)
        )
        gallery_rows = gallery_result.all()
    return _build_public_profile_response(
        user,
        events_result.scalars().all(),
        visibility,
        gallery_rows=gallery_rows,
    )


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


@router.put("/agents/me/avatar", response_model=AvatarUploadResponse)
async def upload_my_agent_avatar(
    data: AvatarUploadRequest,
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Agent).where(Agent.user_id == user_id))
    agent = result.scalar_one_or_none()
    if not agent:
        raise HTTPException(status_code=404, detail="Agent 不存在")
    try:
        agent.avatar_url = store_avatar(
            owner_kind="agent",
            user_id=user_id,
            image_base64=data.image_base64,
            mime_type=data.mime_type,
        )
    except AvatarStorageError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    await db.flush()
    return AvatarUploadResponse(avatar_url=agent.avatar_url)


@router.delete("/agents/me/avatar", response_model=AvatarUploadResponse)
async def delete_my_agent_avatar(
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Agent).where(Agent.user_id == user_id))
    agent = result.scalar_one_or_none()
    if not agent:
        raise HTTPException(status_code=404, detail="Agent 不存在")
    delete_avatar(owner_kind="agent", user_id=user_id)
    agent.avatar_url = None
    await db.flush()
    return AvatarUploadResponse(avatar_url=None)


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

async def _completed_owned_event(
    db: AsyncSession,
    *,
    user_id: UUID,
    event_id: UUID,
) -> Event:
    result = await db.execute(
        select(Event)
        .where(Event.id == event_id, Event.user_id == user_id)
        .with_for_update()
    )
    event = result.scalar_one_or_none()
    if not event:
        raise HTTPException(status_code=404, detail="活动不存在或无权操作")
    if event.status != "completed":
        raise HTTPException(status_code=400, detail="只有已完成活动可以加入相册")
    return event


async def _get_or_create_gallery_item(
    db: AsyncSession,
    *,
    user_id: UUID,
    event_id: UUID,
) -> EventGalleryItem:
    result = await db.execute(
        select(EventGalleryItem)
        .where(EventGalleryItem.user_id == user_id, EventGalleryItem.event_id == event_id)
        .with_for_update()
    )
    item = result.scalar_one_or_none()
    if item is None:
        item = EventGalleryItem(
            user_id=user_id,
            event_id=event_id,
            photo_urls=[],
            is_displayed=True,
        )
        db.add(item)
        await db.flush()
    return item


def _gallery_item_response(item: EventGalleryItem, event: Event) -> GalleryItemResponse:
    return GalleryItemResponse(
        id=item.id,
        event_id=event.id,
        activity_type=event.activity_type,
        title=event.title,
        start_time=event.start_time,
        location=event.location,
        photo_urls=list(item.photo_urls or []),
        is_displayed=item.is_displayed,
        added_at=item.created_at,
    )

def _normalize_profile_event_visibility(value: str | None) -> str:
    if value in PROFILE_EVENT_VISIBILITY_OPTIONS:
        return value
    return PROFILE_EVENT_VISIBILITY_PARTIAL


def _build_public_profile_response(
    user: User,
    events: list[Event],
    visibility: str | None = None,
    *,
    gallery_rows: list[tuple[EventGalleryItem, Event]] | None = None,
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
        avatar_emoji=user.avatar_emoji or "😊",
        interests=user.interests,
        city=user.city,
        occupation=user.occupation,
        custom_interests=user.custom_interests,
        welcome_disturb=user.welcome_disturb,
        profile_event_visibility=normalized_visibility,
        past_events=past_events,
        gallery_items=[
            _gallery_item_response(item, event)
            for item, event in (gallery_rows or [])
        ] if normalized_visibility == PROFILE_EVENT_VISIBILITY_PUBLIC else [],
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
        parts.append(f"工作内容: {user.occupation}")
    if not parts:
        return None
    text = ". ".join(parts)
    return await embedding_service.encode(text)
