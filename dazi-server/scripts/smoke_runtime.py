"""Read-only cross-process checks. Run with python -m scripts.smoke_runtime."""
from __future__ import annotations

import argparse
import asyncio
import json
import sys
import time
from uuid import uuid4

from jose import jwt

from app.api.ws import ConnectionManager
from app.core.config import settings
from app.core.database import engine
from app.core.distributed_lock import distributed_lock
from app.core.readiness import readiness_report
from app.core.redis import close_redis


async def child(*arguments: str) -> dict:
    process = await asyncio.create_subprocess_exec(
        sys.executable, "-m", "scripts.smoke_runtime", *arguments,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    try:
        stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=30)
    except BaseException:
        process.kill()
        await process.wait()
        raise
    if process.returncode:
        raise RuntimeError(f"Smoke child failed: {stderr.decode()}")
    return json.loads(stdout)


class CaptureSocket:
    def __init__(self):
        self.messages: asyncio.Queue = asyncio.Queue()

    async def accept(self):
        pass

    async def send_json(self, data):
        await self.messages.put(data)


async def check_runtime(ws_url: str | None) -> None:
    ready, report = await readiness_report()
    assert ready, report
    print("[ok] database, Redis and migrations", flush=True)

    lock_name = f"smoke-{uuid4()}"
    async with distributed_lock(lock_name) as acquired:
        assert acquired
        assert await child("--check-lock", lock_name) == {"acquired": False}
    assert await child("--check-lock", lock_name) == {"acquired": True}
    print("[ok] cross-process exclusion and lock release", flush=True)

    user_id = str(uuid4())
    manager = ConnectionManager()
    socket = CaptureSocket()
    await manager.connect(user_id, socket)
    await manager.start()
    try:
        async with asyncio.timeout(10):
            while not manager.is_subscribed:
                await asyncio.sleep(0.05)
        await child("--publish", user_id)
        assert await asyncio.wait_for(socket.messages.get(), 5) == {"type": "runtime_smoke"}
        await asyncio.sleep(0.2)
        assert socket.messages.empty(), "Duplicate Pub/Sub delivery"
        print("[ok] child publisher -> Redis -> parent subscriber, delivered once", flush=True)
    finally:
        await manager.stop()

    if ws_url:
        import websockets

        token = jwt.encode(
            {"user_id": user_id, "type": "access", "exp": int(time.time()) + 60},
            settings.JWT_SECRET,
            algorithm=settings.JWT_ALGORITHM,
        )
        async with websockets.connect(
            ws_url, additional_headers={"Authorization": f"Bearer {token}"}, open_timeout=10,
        ) as ws:
            await ws.send(json.dumps({"type": "ping"}))
            assert json.loads(await asyncio.wait_for(ws.recv(), 5)) == {"type": "pong"}
            await child("--publish", user_id)
            assert json.loads(await asyncio.wait_for(ws.recv(), 5)) == {"type": "runtime_smoke"}
            try:
                await asyncio.wait_for(ws.recv(), 0.3)
                raise AssertionError("Duplicate network WebSocket delivery")
            except asyncio.TimeoutError:
                pass
        print("[ok] child publisher -> live authenticated WebSocket, delivered once", flush=True)


async def run(arguments) -> None:
    try:
        if arguments.publish:
            await ConnectionManager().send_to_user(arguments.publish, {"type": "runtime_smoke"})
            print(json.dumps({"published": True}))
        elif arguments.check_lock:
            async with distributed_lock(arguments.check_lock) as acquired:
                print(json.dumps({"acquired": acquired}))
        else:
            await check_runtime(arguments.ws_url)
    finally:
        await close_redis()
        await engine.dispose()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--publish")
    parser.add_argument("--check-lock")
    parser.add_argument("--ws-url")
    asyncio.run(run(parser.parse_args()))
