from __future__ import annotations

import secrets
from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field

from app.core.config import settings
from app.services.embedding_service import embedding_service


def require_internal_token(authorization: str | None = Header(default=None)) -> None:
    scheme, separator, token = (authorization or "").partition(" ")
    if (
        not separator
        or scheme.lower() != "bearer"
        or not settings.ADMIN_TOKEN
        or not secrets.compare_digest(token.encode(), settings.ADMIN_TOKEN.encode())
    ):
        raise HTTPException(status_code=401, detail="Unauthorized internal request")


router = APIRouter(
    prefix="/internal/embeddings",
    dependencies=[Depends(require_internal_token)],
    include_in_schema=False,
)


class EmbeddingRequest(BaseModel):
    texts: list[Annotated[str, Field(max_length=10000)]] = Field(min_length=1, max_length=32)


class CityAlignmentRequest(BaseModel):
    city: str | None = Field(default=None, max_length=200)


@router.post("")
async def encode_texts(request: EmbeddingRequest):
    return {"embeddings": await embedding_service.encode_batch(request.texts)}


@router.post("/align-city")
async def align_city(request: CityAlignmentRequest):
    return {"city": await embedding_service.align_city(request.city)}
