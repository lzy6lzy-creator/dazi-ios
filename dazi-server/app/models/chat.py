from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import String, Boolean, Text, ARRAY, TIMESTAMP, ForeignKey, Index, UniqueConstraint, Float, Integer
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class ChatRoom(Base):
    __tablename__ = "chat_rooms"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    event_id_a: Mapped[Optional[uuid.UUID]] = mapped_column(ForeignKey("events.id", ondelete="SET NULL"))
    event_id_b: Mapped[Optional[uuid.UUID]] = mapped_column(ForeignKey("events.id", ondelete="SET NULL"))
    match_summary: Mapped[Optional[str]] = mapped_column(Text)
    agent_dialogue: Mapped[Optional[str]] = mapped_column(Text)
    match_type: Mapped[str] = mapped_column(String(20), default="active")  # active / passive
    phase: Mapped[str] = mapped_column(String(30), default="matched")  # a2a_negotiating / matched / closed
    a2a_candidate_rank: Mapped[Optional[int]] = mapped_column(Integer)
    a2a_result: Mapped[Optional[str]] = mapped_column(String(40))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(TIMESTAMP(timezone=True), default=lambda: datetime.now(timezone.utc))
    closed_at: Mapped[Optional[datetime]] = mapped_column(TIMESTAMP(timezone=True))


class ChatRoomMember(Base):
    __tablename__ = "chat_room_members"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    room_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("chat_rooms.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    agent_id: Mapped[Optional[uuid.UUID]] = mapped_column(ForeignKey("agents.id", ondelete="SET NULL"), nullable=True, index=True)
    role: Mapped[str] = mapped_column(String(20), nullable=False)  # user / agent
    is_owner: Mapped[bool] = mapped_column(Boolean, default=False)
    joined_at: Mapped[datetime] = mapped_column(TIMESTAMP(timezone=True), default=lambda: datetime.now(timezone.utc))
    last_read_at: Mapped[Optional[datetime]] = mapped_column(TIMESTAMP(timezone=True))


class ChatMessage(Base):
    """聊天室消息"""
    __tablename__ = "chat_messages"
    __table_args__ = (
        Index('ix_chat_messages_room_created', 'room_id', 'created_at'),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    room_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("chat_rooms.id", ondelete="CASCADE"), nullable=False, index=True)
    sender_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    sender_type: Mapped[str] = mapped_column(String(20), nullable=False)  # user / agent / system
    content: Mapped[str] = mapped_column(Text, nullable=False)
    mentions: Mapped[Optional[list[str]]] = mapped_column(ARRAY(String))
    visibility: Mapped[str] = mapped_column(String(30), default="public_room")  # public_room / private_to_agent / system
    recipient_user_id: Mapped[Optional[uuid.UUID]] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=True, index=True)
    created_at: Mapped[datetime] = mapped_column(TIMESTAMP(timezone=True), default=lambda: datetime.now(timezone.utc))


class ChatRoomVote(Base):
    """聊天室投票（搭/不搭）"""
    __tablename__ = "chat_room_votes"
    __table_args__ = (
        UniqueConstraint('room_id', 'user_id', name='uq_chat_room_votes_room_user'),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    room_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("chat_rooms.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    vote: Mapped[str] = mapped_column(String(10), nullable=False)  # da / bu_da
    created_at: Mapped[datetime] = mapped_column(TIMESTAMP(timezone=True), default=lambda: datetime.now(timezone.utc))


class PassiveMatchRequest(Base):
    """Opt-in request sent before passive matching creates a chat room."""
    __tablename__ = "passive_match_requests"
    __table_args__ = (
        Index('ix_passive_match_requests_target_status', 'target_user_id', 'status'),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    event_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("events.id", ondelete="CASCADE"), nullable=False, index=True)
    requester_user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    target_user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    status: Mapped[str] = mapped_column(String(20), default="pending", index=True)  # pending / accepted / rejected
    similarity: Mapped[Optional[float]] = mapped_column(Float)
    message: Mapped[Optional[str]] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(TIMESTAMP(timezone=True), default=lambda: datetime.now(timezone.utc))
    responded_at: Mapped[Optional[datetime]] = mapped_column(TIMESTAMP(timezone=True))
