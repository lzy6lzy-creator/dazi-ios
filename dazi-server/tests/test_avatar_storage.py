from __future__ import annotations

import base64
import hashlib
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from uuid import uuid4

from app.services import media_storage
from app.services.media_storage import AvatarStorageError, delete_user_avatar_files, store_avatar


PNG_1X1 = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
)


class AvatarStorageTests(unittest.TestCase):
    def test_avatar_is_written_atomically_and_old_extension_is_removed(self):
        user_id = uuid4()
        with tempfile.TemporaryDirectory() as directory, patch.object(
            media_storage, "AVATAR_ROOT", Path(directory)
        ):
            url = store_avatar(
                owner_kind="user",
                user_id=user_id,
                image_base64=base64.b64encode(PNG_1X1).decode(),
                mime_type="image/png",
            )
            digest = hashlib.sha256(PNG_1X1).hexdigest()[:12]
            self.assertEqual(url, f"/media/avatars/user-{user_id}-{digest}.png")
            self.assertEqual((Path(directory) / f"user-{user_id}-{digest}.png").read_bytes(), PNG_1X1)
            self.assertFalse(any(path.suffix == ".tmp" for path in Path(directory).iterdir()))

            delete_user_avatar_files(user_id)
            self.assertEqual(list(Path(directory).iterdir()), [])

    def test_avatar_rejects_mime_mismatch_and_oversized_payload(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(
            media_storage, "AVATAR_ROOT", Path(directory)
        ):
            with self.assertRaises(AvatarStorageError):
                store_avatar(
                    owner_kind="user",
                    user_id=uuid4(),
                    image_base64=base64.b64encode(PNG_1X1).decode(),
                    mime_type="image/jpeg",
                )
            with self.assertRaises(AvatarStorageError):
                store_avatar(
                    owner_kind="agent",
                    user_id=uuid4(),
                    image_base64=base64.b64encode(b"\xff\xd8\xff" + b"x" * 1_000_001).decode(),
                    mime_type="image/jpeg",
                )

    def test_routes_and_persistent_volume_are_declared(self):
        root = Path(__file__).resolve().parents[1]
        users = (root / "app/api/users.py").read_text(encoding="utf-8")
        compose = (root / "docker-compose.prod.yml").read_text(encoding="utf-8")
        nginx = (root / "nginx.conf").read_text(encoding="utf-8")
        deletion = (root / "app/services/account_deletion_service.py").read_text(encoding="utf-8")
        for route in ('/users/me/avatar', '/agents/me/avatar'):
            self.assertIn(route, users)
        self.assertIn("./uploads:/code/uploads", compose)
        self.assertIn("./uploads:/usr/share/nginx/dazi-media:ro", compose)
        self.assertIn("location /media/", nginx)
        self.assertIn("delete_user_avatar_files(user_id)", deletion)


if __name__ == "__main__":
    unittest.main()
