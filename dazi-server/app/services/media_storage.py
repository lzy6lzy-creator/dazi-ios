from __future__ import annotations

import base64
import binascii
import hashlib
import os
from pathlib import Path
from uuid import UUID


MAX_AVATAR_BYTES = 1_000_000
UPLOAD_ROOT = Path(os.environ.get("UPLOAD_ROOT", str(Path.cwd() / "uploads")))
AVATAR_ROOT = UPLOAD_ROOT / "avatars"
MIME_EXTENSIONS = {
    "image/jpeg": "jpg",
    "image/png": "png",
    "image/webp": "webp",
}


class AvatarStorageError(ValueError):
    pass


def ensure_upload_directories() -> None:
    AVATAR_ROOT.mkdir(parents=True, exist_ok=True)


def store_avatar(*, owner_kind: str, user_id: UUID, image_base64: str, mime_type: str) -> str:
    normalized_mime = (mime_type or "").strip().lower()
    extension = MIME_EXTENSIONS.get(normalized_mime)
    if extension is None:
        raise AvatarStorageError("头像只支持 JPEG、PNG 或 WebP")
    try:
        payload = base64.b64decode(image_base64, validate=True)
    except (binascii.Error, ValueError) as exc:
        raise AvatarStorageError("头像数据格式无效") from exc
    if not payload or len(payload) > MAX_AVATAR_BYTES:
        raise AvatarStorageError("头像大小不能超过 1MB")
    if not _matches_image_signature(payload, normalized_mime):
        raise AvatarStorageError("头像文件类型与内容不一致")
    if owner_kind not in {"user", "agent"}:
        raise AvatarStorageError("头像所属类型无效")

    ensure_upload_directories()
    stem = f"{owner_kind}-{user_id}"
    _delete_matching(stem)
    digest = hashlib.sha256(payload).hexdigest()[:12]
    target = AVATAR_ROOT / f"{stem}-{digest}.{extension}"
    temporary = AVATAR_ROOT / f".{stem}-{digest}.{extension}.tmp"
    temporary.write_bytes(payload)
    temporary.replace(target)
    return f"/media/avatars/{target.name}"


def delete_avatar(*, owner_kind: str, user_id: UUID) -> None:
    _delete_matching(f"{owner_kind}-{user_id}")


def delete_user_avatar_files(user_id: UUID) -> None:
    delete_avatar(owner_kind="user", user_id=user_id)
    delete_avatar(owner_kind="agent", user_id=user_id)


def _delete_matching(stem: str) -> None:
    if not AVATAR_ROOT.exists():
        return
    for pattern in (f"{stem}.*", f"{stem}-*", f".{stem}-*"):
        for path in AVATAR_ROOT.glob(pattern):
            if path.is_file():
                path.unlink(missing_ok=True)


def _matches_image_signature(payload: bytes, mime_type: str) -> bool:
    if mime_type == "image/jpeg":
        return payload.startswith(b"\xff\xd8\xff")
    if mime_type == "image/png":
        return payload.startswith(b"\x89PNG\r\n\x1a\n")
    if mime_type == "image/webp":
        return len(payload) >= 12 and payload.startswith(b"RIFF") and payload[8:12] == b"WEBP"
    return False
