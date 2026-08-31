"""
WebSocket API - 实时消息推送

功能：
- 用户连接 WebSocket 后，实时接收聊天室消息、事件状态更新
- 替代客户端 30 秒轮询
- 新客户端使用 Authorization header，旧客户端 query token 暂时兼容
"""
from __future__ import annotations

import asyncio
import json
import logging
from uuid import uuid4

from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query
from jose import JWTError, jwt

from app.core.config import settings
from app.core.redis import get_redis

logger = logging.getLogger(__name__)

router = APIRouter(tags=["websocket"])


class ConnectionManager:
    """管理所有活跃的 WebSocket 连接"""

    CHANNEL_PREFIX = "dazi:ws:user:"

    def __init__(self):
        # user_id -> list of WebSocket connections (同一用户可能多设备)
        self._connections: dict[str, list[WebSocket]] = {}
        self._subscriber_task: asyncio.Task | None = None
        self._instance_id = uuid4().hex
        self.is_subscribed = False

    async def start(self) -> None:
        if self._subscriber_task and not self._subscriber_task.done():
            return
        self._subscriber_task = asyncio.create_task(
            self._subscriber_loop(),
            name="websocket-redis-subscriber",
        )

    async def stop(self) -> None:
        if not self._subscriber_task:
            return
        self._subscriber_task.cancel()
        try:
            await self._subscriber_task
        except asyncio.CancelledError:
            pass
        self._subscriber_task = None

    async def connect(self, user_id: str, ws: WebSocket):
        await ws.accept()
        if user_id not in self._connections:
            self._connections[user_id] = []
        self._connections[user_id].append(ws)
        logger.info(f"WebSocket connected: user={user_id}, total={self.count}")

    def disconnect(self, user_id: str, ws: WebSocket):
        if user_id in self._connections:
            self._connections[user_id] = [
                c for c in self._connections[user_id] if c is not ws
            ]
            if not self._connections[user_id]:
                del self._connections[user_id]
        logger.info(f"WebSocket disconnected: user={user_id}, total={self.count}")

    async def _send_local(self, user_id: str, data: dict) -> None:
        conns = self._connections.get(user_id, [])
        dead = []
        for ws in conns:
            try:
                await asyncio.wait_for(ws.send_json(data), timeout=5)
            except Exception:
                dead.append(ws)
        # 清理断开的连接
        for ws in dead:
            self.disconnect(user_id, ws)

    async def send_to_user(self, user_id: str, data: dict):
        """Publish once so every API replica can deliver to its local sockets."""
        await self._send_local(user_id, data)
        try:
            redis = await get_redis()
            await redis.publish(
                f"{self.CHANNEL_PREFIX}{user_id}",
                json.dumps({"origin": self._instance_id, "data": data}, ensure_ascii=False),
            )
        except Exception:
            logger.exception("Redis WebSocket publish failed; only local delivery succeeded")

    async def _subscriber_loop(self) -> None:
        while True:
            pubsub = None
            try:
                redis = await get_redis()
                pubsub = redis.pubsub()
                await pubsub.psubscribe(f"{self.CHANNEL_PREFIX}*")
                self.is_subscribed = True
                logger.info("WebSocket Redis subscriber started")
                async for message in pubsub.listen():
                    if message.get("type") not in {"message", "pmessage"}:
                        continue
                    await self._handle_pubsub_message(message)
            except asyncio.CancelledError:
                raise
            except Exception:
                logger.exception("WebSocket Redis subscriber failed; retrying")
                await asyncio.sleep(1)
            finally:
                self.is_subscribed = False
                if pubsub is not None:
                    try:
                        await pubsub.aclose()
                    except Exception:
                        logger.debug("WebSocket Redis subscriber close failed", exc_info=True)

    async def _handle_pubsub_message(self, message: dict) -> None:
        channel = message.get("channel")
        payload = message.get("data")
        if isinstance(channel, bytes):
            channel = channel.decode("utf-8")
        if isinstance(payload, bytes):
            payload = payload.decode("utf-8")
        if not isinstance(channel, str) or not channel.startswith(self.CHANNEL_PREFIX):
            return

        user_id = channel[len(self.CHANNEL_PREFIX):]
        try:
            envelope = json.loads(payload)
        except (TypeError, json.JSONDecodeError):
            logger.warning("Ignored malformed WebSocket Pub/Sub payload")
            return
        if not user_id or not isinstance(envelope, dict):
            return
        if envelope.get("origin") == self._instance_id:
            return
        data = envelope.get("data")
        if not isinstance(data, dict):
            return
        await self._send_local(user_id, data)

    async def broadcast_to_users(self, user_ids: list[str], data: dict):
        """向多个用户广播消息"""
        for uid in user_ids:
            await self.send_to_user(uid, data)

    @property
    def count(self) -> int:
        return sum(len(v) for v in self._connections.values())


# 全局连接管理器
manager = ConnectionManager()


def _authenticate_token(token: str) -> str | None:
    """验证 JWT token，返回 user_id 或 None"""
    try:
        payload = jwt.decode(token, settings.JWT_SECRET, algorithms=[settings.JWT_ALGORITHM])
        if payload.get("type") != "access":
            return None
        return payload.get("user_id")
    except JWTError:
        return None


def websocket_auth_token(authorization: str | None, query_token: str | None) -> str | None:
    """Prefer a Bearer header while retaining compatibility with older clients."""
    if authorization:
        scheme, separator, credential = authorization.strip().partition(" ")
        if separator and scheme.lower() == "bearer" and credential.strip():
            return credential.strip()
    return query_token


@router.websocket("/ws")
async def websocket_endpoint(
    ws: WebSocket,
    token: str | None = Query(default=None),
):
    """
    WebSocket 端点

    连接: Authorization: Bearer <jwt_access_token>
    兼容旧客户端: ws://host/ws?token=<jwt_access_token>

    服务端推送消息格式:
    {
        "type": "new_message",
        "room_id": "...",
        "message": { ... }
    }
    {
        "type": "event_update",
        "event_id": "...",
        "status": "..."
    }
    {
        "type": "room_created",
        "room": { ... }
    }

    客户端可发送 ping:
    { "type": "ping" }
    服务端回复:
    { "type": "pong" }
    """
    raw_token = websocket_auth_token(ws.headers.get("authorization"), token)
    user_id = _authenticate_token(raw_token or "")
    if not user_id:
        await ws.close(code=4001, reason="Invalid token")
        return

    await manager.connect(user_id, ws)
    try:
        while True:
            # 等待客户端消息（主要用于 ping/pong 保活）
            data = await ws.receive_text()
            try:
                msg = json.loads(data)
                if msg.get("type") == "ping":
                    await ws.send_json({"type": "pong"})
            except json.JSONDecodeError:
                pass
    except WebSocketDisconnect:
        manager.disconnect(user_id, ws)
    except Exception as e:
        logger.error(f"WebSocket error for user={user_id}: {e}")
        manager.disconnect(user_id, ws)
