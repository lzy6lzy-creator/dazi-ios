"""
Event API - 活动 CRUD + 匹配触发
"""
from datetime import datetime, timezone
from uuid import UUID
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import or_, select

from app.services.embedding_service import embedding_service

from app.core.database import get_db
from app.core.security import get_current_user_id
from app.models.chat import ChatMessage, ChatRoom, ChatRoomMember
from app.models.event import Event, EventFeedback
from app.models.user import AgentMemory
from app.api.schemas import (
    EventCreate,
    EventFeedbackCreate,
    EventFeedbackResponse,
    EventUpdate,
    EventResponse,
    EventPlazaResponse,
)
from app.api.ws import manager as ws_manager
from app.services.match_blocklist_service import clear_event_match_state
from app.services.matching_tasks import schedule_event_matching
from app.services.invitation_reward_service import record_invitation_milestone_safely
from app.services.memory_service import memory_updated_payload

router = APIRouter(prefix="/api/v1/events", tags=["events"])


def _single_location(location: Optional[str], legacy_city: Optional[str] = None) -> Optional[str]:
    location_value = location.strip() if isinstance(location, str) and location.strip() else None
    city_value = legacy_city.strip() if isinstance(legacy_city, str) and legacy_city.strip() else None
    return location_value or city_value


def _clean_feedback_text(value: Optional[str]) -> Optional[str]:
    cleaned = (value or "").strip()
    return cleaned or None


def event_feedback_memory_content(data: EventFeedbackCreate) -> str:
    parts = [f"活动体验评分 {data.experience_rating}/5"]
    if experience_comment := _clean_feedback_text(data.experience_comment):
        parts.append(experience_comment)
    if data.partner_rating is not None:
        parts.append(f"搭子评分 {data.partner_rating}/5")
    if partner_comment := _clean_feedback_text(data.partner_comment):
        parts.append(partner_comment)
    return "；".join(parts)


@router.post("", response_model=EventResponse)
async def create_event(
    data: EventCreate,
    background_tasks: BackgroundTasks = None,
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    location_value = _single_location(data.location, data.city)
    event = Event(
        user_id=user_id,
        title=data.title,
        activity_type=data.activity_type,
        city=None,
        city_normalized=None,
        start_time=data.start_time,
        end_time=data.end_time,
        location=location_value,
        preferences=data.preferences or [],
        constraints=data.constraints or [],
        clarification_answers=data.clarification_answers,
        age_filter_min=data.age_filter_min,
        age_filter_max=data.age_filter_max,
        age_filter_mode=data.age_filter_mode,
        status="pending",
    )
    db.add(event)
    await db.flush()

    # 生成 embedding
    text = embedding_service.build_event_text(
        event.title, event.activity_type, None,
        event.location, event.preferences, event.constraints
    )
    event.embedding = await embedding_service.encode(text)

    await record_invitation_milestone_safely(
        db,
        user_id=user_id,
        milestone_type="first_event_publish",
        source_event_id=event.id,
    )

    schedule_event_matching(background_tasks, event.id)
    return event


@router.get("", response_model=list[EventResponse])
async def list_events(
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Event)
        .where(Event.user_id == user_id)
        .order_by(Event.created_at.desc())
    )
    return result.scalars().all()


@router.get("/plaza", response_model=list[EventPlazaResponse])
async def list_event_plaza(
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
    limit: int = Query(50, ge=1, le=100),
):
    result = await db.execute(
        select(Event)
        .where(
            Event.status == "pending",
            Event.user_id != user_id,
        )
        .order_by(Event.created_at.desc())
        .limit(limit)
    )
    return result.scalars().all()


@router.get("/{event_id}", response_model=EventResponse)
async def get_event(
    event_id: UUID,
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Event).where(Event.id == event_id, Event.user_id == user_id)
    )
    event = result.scalar_one_or_none()
    if not event:
        raise HTTPException(status_code=404, detail="活动不存在")
    return event


@router.put("/{event_id}", response_model=EventResponse)
async def update_event(
    event_id: UUID,
    data: EventUpdate,
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Event).where(Event.id == event_id, Event.user_id == user_id)
    )
    event = result.scalar_one_or_none()
    if not event:
        raise HTTPException(status_code=404, detail="活动不存在或无权修改")
    if event.status != "pending":
        raise HTTPException(status_code=400, detail=f"活动状态为 {event.status}，只有待匹配的活动可以编辑")

    update_data = data.model_dump(exclude_unset=True)
    if "city" in update_data:
        if "location" not in update_data:
            update_data["location"] = update_data.get("city")
        update_data.pop("city", None)
    for field, value in update_data.items():
        setattr(event, field, value)

    event.location = _single_location(event.location)
    event.city = None
    event.city_normalized = None
    event.matched_event_id = None
    event.match_score = None
    event.match_round = 0

    # 重新生成 embedding
    text = embedding_service.build_event_text(
        event.title, event.activity_type, None,
        event.location, event.preferences, event.constraints
    )
    event.embedding = await embedding_service.encode(text)
    await clear_event_match_state(db, event_id=event_id)

    await db.flush()
    return event


@router.delete("/{event_id}")
async def cancel_event(
    event_id: UUID,
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Event).where(Event.id == event_id, Event.user_id == user_id)
    )
    event = result.scalar_one_or_none()
    if not event:
        raise HTTPException(status_code=404, detail="活动不存在或无权操作")
    if event.status not in ("pending", "matching"):
        raise HTTPException(status_code=400, detail=f"活动状态为 {event.status}，无法取消")

    event.status = "cancelled"
    await db.flush()
    return {"message": "活动已取消"}


@router.post("/{event_id}/match")
async def trigger_matching(
    event_id: UUID,
    background_tasks: BackgroundTasks,
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """手动触发匹配（也可由系统定时触发）"""
    result = await db.execute(
        select(Event).where(Event.id == event_id, Event.user_id == user_id)
    )
    event = result.scalar_one_or_none()
    if not event:
        raise HTTPException(status_code=404, detail="活动不存在或无权操作")
    if event.status != "pending":
        raise HTTPException(status_code=400, detail=f"活动状态为 {event.status}，无法匹配")

    schedule_event_matching(background_tasks, event_id)
    return {"message": "匹配已触发", "event_id": str(event_id)}


@router.post("/{event_id}/feedback", response_model=EventFeedbackResponse)
async def submit_event_feedback(
    event_id: UUID,
    data: EventFeedbackCreate,
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Persist one user's feedback and close a shared room only after both events end."""
    event_result = await db.execute(
        select(Event)
        .where(Event.id == event_id, Event.user_id == user_id)
        .with_for_update()
    )
    event = event_result.scalar_one_or_none()
    if not event:
        raise HTTPException(status_code=404, detail="活动不存在或无权评价")
    if event.status not in {"matched", "active", "completed"}:
        raise HTTPException(status_code=400, detail=f"活动状态为 {event.status}，暂时不能评价")

    now = datetime.now(timezone.utc)
    feedback_result = await db.execute(
        select(EventFeedback)
        .where(EventFeedback.event_id == event_id, EventFeedback.user_id == user_id)
        .with_for_update()
    )
    feedback = feedback_result.scalar_one_or_none()
    if feedback is None:
        feedback = EventFeedback(event_id=event_id, user_id=user_id)
        db.add(feedback)

    feedback.experience_rating = data.experience_rating
    feedback.experience_comment = _clean_feedback_text(data.experience_comment)
    feedback.partner_rating = data.partner_rating
    feedback.partner_comment = _clean_feedback_text(data.partner_comment)
    feedback.updated_at = now
    event.status = "completed"

    memory_key = f"event_feedback:{event_id}"
    memory_result = await db.execute(
        select(AgentMemory)
        .where(AgentMemory.user_id == user_id, AgentMemory.key == memory_key)
        .with_for_update()
    )
    memory = memory_result.scalar_one_or_none()
    memory_action = "update"
    if memory is None:
        memory = AgentMemory(
            user_id=user_id,
            type="feedback",
            key=memory_key,
            category="event_feedback",
            scope="long_term",
            source="event_feedback",
            source_event_id=event_id,
            confidence=0.9,
        )
        db.add(memory)
        memory_action = "create"
    memory.content = event_feedback_memory_content(data)
    memory.value = {
        "event_id": str(event_id),
        "experience_rating": data.experience_rating,
        "partner_rating": data.partner_rating,
    }
    memory.status = "active"
    memory.is_active = True
    memory.last_seen_at = now
    memory.updated_at = now

    room_closed = False
    room_result = await db.execute(
        select(ChatRoom)
        .where(
            ChatRoom.is_active.is_(True),
            or_(ChatRoom.event_id_a == event_id, ChatRoom.event_id_b == event_id),
        )
        .with_for_update()
    )
    for room in room_result.scalars().all():
        other_event_ids = [
            candidate_id
            for candidate_id in (room.event_id_a, room.event_id_b)
            if candidate_id is not None and candidate_id != event_id
        ]
        other_statuses: list[str] = []
        if other_event_ids:
            statuses_result = await db.execute(
                select(Event.status).where(Event.id.in_(other_event_ids))
            )
            other_statuses = list(statuses_result.scalars().all())
        should_close = (
            not other_event_ids
            or (
                len(other_statuses) == len(other_event_ids)
                and all(status in {"completed", "cancelled"} for status in other_statuses)
            )
        )
        if not should_close:
            continue

        room.is_active = False
        room.phase = "closed"
        room.closed_at = now
        system_message = ChatMessage(
            room_id=room.id,
            sender_id=user_id,
            sender_type="system",
            content="双方活动均已结束，聊天室已关闭。感谢参与！",
            visibility="system",
        )
        db.add(system_message)
        await db.flush()

        members_result = await db.execute(
            select(ChatRoomMember.user_id).where(
                ChatRoomMember.room_id == room.id,
                ChatRoomMember.role == "user",
            )
        )
        member_ids = [str(member_id) for member_id in members_result.scalars().all()]
        await ws_manager.broadcast_to_users(
            member_ids,
            {
                "type": "new_message",
                "room_id": str(room.id),
                "message": {
                    "id": str(system_message.id),
                    "room_id": str(room.id),
                    "sender_id": str(user_id),
                    "sender_type": "system",
                    "content": system_message.content,
                    "mentions": None,
                    "visibility": "system",
                    "recipient_user_id": None,
                    "created_at": system_message.created_at.isoformat(),
                },
            },
        )
        await ws_manager.broadcast_to_users(
            member_ids,
            {"type": "room_closed", "room_id": str(room.id)},
        )
        room_closed = True

    await db.flush()
    await ws_manager.send_to_user(
        str(user_id),
        {"type": "event_update", "event_id": str(event_id), "status": "completed"},
    )
    await ws_manager.send_to_user(
        str(user_id),
        memory_updated_payload(memory, action=memory_action),
    )

    return EventFeedbackResponse(
        id=feedback.id,
        event_id=event_id,
        experience_rating=feedback.experience_rating,
        experience_comment=feedback.experience_comment,
        partner_rating=feedback.partner_rating,
        partner_comment=feedback.partner_comment,
        event_status=event.status,
        room_closed=room_closed,
        created_at=feedback.created_at,
        updated_at=feedback.updated_at,
    )
