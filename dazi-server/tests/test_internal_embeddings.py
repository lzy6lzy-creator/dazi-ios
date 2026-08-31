import unittest
from unittest.mock import AsyncMock, Mock, patch

import httpx
from fastapi import FastAPI

from app.api.internal import router
from app.core.config import settings
from app.services.embedding_service import EmbeddingService


class InternalEmbeddingTests(unittest.IsolatedAsyncioTestCase):
    async def test_endpoint_requires_server_credential(self):
        app = FastAPI()
        app.include_router(router)
        encoder = AsyncMock(return_value=[[0.1, 0.2]])
        with patch("app.api.internal.embedding_service.encode_batch", encoder):
            async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
                response = await client.post("/internal/embeddings", json={"texts": ["hello"]})
                self.assertEqual(response.status_code, 401)
                encoder.assert_not_awaited()
                response = await client.post(
                    "/internal/embeddings", json={"texts": ["hello"]},
                    headers={"Authorization": f"Bearer {settings.ADMIN_TOKEN}"},
                )
                self.assertEqual(response.status_code, 200)
                self.assertEqual(response.json(), {"embeddings": [[0.1, 0.2]]})

    async def test_worker_uses_remote_encoding_and_never_loads_local_model(self):
        service = EmbeddingService()
        requests = []

        def handler(request):
            requests.append(request)
            self.assertEqual(request.headers["Authorization"], f"Bearer {settings.ADMIN_TOKEN}")
            if request.url.path.endswith("align-city"):
                return httpx.Response(200, json={"city": "上海"})
            import json
            texts = json.loads(request.content)["texts"]
            return httpx.Response(200, json={"embeddings": [[0.1, 0.2] for _ in texts]})

        service._remote_client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
        try:
            with patch.object(settings, "EMBEDDING_REMOTE_URL", "http://api:8000/internal/embeddings"), patch.object(
                service, "_load_model", Mock(side_effect=AssertionError("must not load"))
            ):
                self.assertEqual(await service.encode("hello"), [0.1, 0.2])
                self.assertEqual(len(await service.encode_batch(["hello"] * 40)), 40)
                self.assertEqual(await service.encode_batch([]), [])
                self.assertEqual(await service.align_city("Shanghai"), "上海")
            self.assertEqual(len(requests), 4)
            self.assertIsNone(service._model)
        finally:
            await service.close()

    async def test_remote_errors_propagate_instead_of_falling_back_to_local_model(self):
        service = EmbeddingService()
        service._remote_client = httpx.AsyncClient(
            transport=httpx.MockTransport(lambda _: httpx.Response(503))
        )
        try:
            with patch.object(settings, "EMBEDDING_REMOTE_URL", "http://api/internal/embeddings"):
                with self.assertRaises(httpx.HTTPStatusError):
                    await service.encode("hello")
            self.assertIsNone(service._model)
        finally:
            await service.close()


if __name__ == "__main__":
    unittest.main()
