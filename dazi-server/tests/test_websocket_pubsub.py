import json
import unittest
from unittest.mock import AsyncMock, patch

from app.api.ws import ConnectionManager


class WebSocketPubSubTests(unittest.IsolatedAsyncioTestCase):
    async def test_local_and_remote_replicas_receive_once(self):
        sender = ConnectionManager()
        replica = ConnectionManager()
        local_socket, remote_socket, unrelated_socket = AsyncMock(), AsyncMock(), AsyncMock()
        await sender.connect("user-a", local_socket)
        await replica.connect("user-a", remote_socket)
        await replica.connect("user-b", unrelated_socket)
        redis = AsyncMock()
        data = {"type": "new_message", "room_id": "room-a"}

        with patch("app.api.ws.get_redis", AsyncMock(return_value=redis)):
            await sender.send_to_user("user-a", data)
        channel, payload = redis.publish.call_args.args
        message = {"channel": channel, "data": payload}
        await sender._handle_pubsub_message(message)
        await replica._handle_pubsub_message(message)

        local_socket.send_json.assert_awaited_once_with(data)
        remote_socket.send_json.assert_awaited_once_with(data)
        unrelated_socket.send_json.assert_not_awaited()

    async def test_worker_without_sockets_can_publish(self):
        worker = ConnectionManager()
        redis = AsyncMock()
        with patch("app.api.ws.get_redis", AsyncMock(return_value=redis)):
            await worker.send_to_user("user-a", {"type": "event_update"})
        channel, payload = redis.publish.call_args.args
        self.assertEqual(channel, "dazi:ws:user:user-a")
        self.assertEqual(json.loads(payload)["data"], {"type": "event_update"})

    async def test_redis_failure_preserves_local_delivery(self):
        manager = ConnectionManager()
        socket = AsyncMock()
        await manager.connect("user-a", socket)
        with patch("app.api.ws.get_redis", AsyncMock(side_effect=ConnectionError)):
            await manager.send_to_user("user-a", {"type": "event_update"})
        socket.send_json.assert_awaited_once()

    async def test_dead_sockets_are_removed_and_malformed_messages_ignored(self):
        manager = ConnectionManager()
        socket = AsyncMock()
        socket.send_json.side_effect = ConnectionError
        await manager.connect("user-a", socket)
        await manager._handle_pubsub_message({
            "channel": "dazi:ws:user:user-a",
            "data": json.dumps({"origin": "worker", "data": {"type": "event_update"}}),
        })
        self.assertEqual(manager.count, 0)
        for payload in ("invalid", "[]", '{"data": []}'):
            await manager._handle_pubsub_message({"channel": "dazi:ws:user:user-a", "data": payload})


if __name__ == "__main__":
    unittest.main()
