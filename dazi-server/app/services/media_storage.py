from __future__ import annotations

import base64
import binascii
import hashlib
import os
from pathlib import Path
from uuid import UUID


MAX_AVATAR_BYTES = 1_000_000
MAX_GALLERY_PHOTO_BYTES = 2_000_000
UPLOAD_ROOT = Path(os.environ.get("UPLOAD_ROOT", str(Path.cwd() / "uploads")))
AVATAR_ROOT = UPLOAD_ROOT / "avatars"
GALLERY_ROOT = UPLOAD_ROOT / "gallery"
MIME_EXTENSIONS = {
    "image/jpeg": "jpg",
    "image/png": "png",
    "image/webp": "webp",
}


class AvatarStorageError(ValueError):
    pass


def ensure_upload_directories() -> None:
    AVATAR_ROOT.mkdir(parents=True, exist_ok=True)
    GALLERY_ROOT.mkdir(parents=True, exist_ok=True)


def store_avatar(*, owner_kind: str, user_id: UUID, image_base64: str, mime_type: str) -> str:
    extension, payload = _decode_image(
        image_base64=image_base64,
        mime_type=mime_type,
        max_bytes=MAX_AVATAR_BYTES,
        size_error="头像大小不能超过 1MB",
    )
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


def store_gallery_photo(*, user_id: UUID, event_id: UUID, image_base64: str, mime_type: str) -> str:
    extension, payload = _decode_image(
        image_base64=image_base64,
        mime_type=mime_type,
        max_bytes=MAX_GALLERY_PHOTO_BYTES,
        size_error="相册照片大小不能超过 2MB",
    )
    ensure_upload_directories()
    digest = hashlib.sha256(payload).hexdigest()[:16]
    stem = f"{user_id}-{event_id}-{digest}"
    target = GALLERY_ROOT / f"{stem}.{extension}"
    if not target.exists():
        temporary = GALLERY_ROOT / f".{stem}.{extension}.tmp"
        temporary.write_bytes(payload)
        temporary.replace(target)
    return f"/api/v1/gallery/media/{target.name}"


def delete_gallery_photo(*, user_id: UUID, photo_url: str) -> None:
    filename = Path(photo_url or "").name
    if not filename.startswith(f"{user_id}-"):
        raise AvatarStorageError("无权删除该相册照片")
    (GALLERY_ROOT / filename).unlink(missing_ok=True)


def gallery_photo_path(photo_name: str) -> Path | None:
    if not photo_name or Path(photo_name).name != photo_name:
        return None
    path = GALLERY_ROOT / photo_name
    return path if path.is_file() else None


def delete_event_gallery_files(*, user_id: UUID, event_id: UUID) -> None:
    if not GALLERY_ROOT.exists():
        return
    for path in GALLERY_ROOT.glob(f"{user_id}-{event_id}-*"):
        if path.is_file():
            path.unlink(missing_ok=True)


def delete_user_media_files(user_id: UUID) -> None:
    delete_user_avatar_files(user_id)
    if not GALLERY_ROOT.exists():
        return
    for path in GALLERY_ROOT.glob(f"{user_id}-*"):
        if path.is_file():
            path.unlink(missing_ok=True)


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


def _decode_image(*, image_base64: str, mime_type: str, max_bytes: int, size_error: str) -> tuple[str, bytes]:
    normalized_mime = (mime_type or "").strip().lower()
    extension = MIME_EXTENSIONS.get(normalized_mime)
    if extension is None:
        raise AvatarStorageError("图片只支持 JPEG、PNG 或 WebP")
    try:
        payload = base64.b64decode(image_base64, validate=True)
    except (binascii.Error, ValueError) as exc:
        raise AvatarStorageError("图片数据格式无效") from exc
    if not payload or len(payload) > max_bytes:
        raise AvatarStorageError(size_error)
    if not _matches_image_signature(payload, normalized_mime):
        raise AvatarStorageError("图片文件类型与内容不一致")
    return extension, payload
