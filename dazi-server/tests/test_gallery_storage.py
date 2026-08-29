from __future__ import annotations

import base64
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from uuid import uuid4

from app.services import media_storage
from app.services.media_storage import (
    AvatarStorageError,
    delete_gallery_photo,
    delete_user_media_files,
    store_gallery_photo,
)
from tests.test_avatar_storage import PNG_1X1


class GalleryStorageTests(unittest.TestCase):
    def test_gallery_photo_deduplicates_and_is_scoped_to_user_event(self):
        user_id = uuid4()
        event_id = uuid4()
        encoded = base64.b64encode(PNG_1X1).decode()
        with tempfile.TemporaryDirectory() as directory, patch.object(
            media_storage, "GALLERY_ROOT", Path(directory)
        ), patch.object(media_storage, "AVATAR_ROOT", Path(directory) / "avatars"):
            first = store_gallery_photo(
                user_id=user_id,
                event_id=event_id,
                image_base64=encoded,
                mime_type="image/png",
            )
            second = store_gallery_photo(
                user_id=user_id,
                event_id=event_id,
                image_base64=encoded,
                mime_type="image/png",
            )
            self.assertEqual(first, second)
            self.assertTrue(first.startswith("/api/v1/gallery/media/"))
            self.assertEqual(len(list(Path(directory).glob("*.png"))), 1)

            with self.assertRaises(AvatarStorageError):
                delete_gallery_photo(user_id=uuid4(), photo_url=first)
            delete_gallery_photo(user_id=user_id, photo_url=first)
            self.assertEqual(list(Path(directory).glob("*.png")), [])

    def test_account_media_cleanup_removes_gallery_and_avatars(self):
        user_id = uuid4()
        with tempfile.TemporaryDirectory() as directory, patch.object(
            media_storage, "GALLERY_ROOT", Path(directory) / "gallery"
        ), patch.object(media_storage, "AVATAR_ROOT", Path(directory) / "avatars"):
            media_storage.GALLERY_ROOT.mkdir()
            media_storage.AVATAR_ROOT.mkdir()
            (media_storage.GALLERY_ROOT / f"{user_id}-{uuid4()}-photo.jpg").write_bytes(b"x")
            (media_storage.AVATAR_ROOT / f"user-{user_id}-avatar.jpg").write_bytes(b"x")
            delete_user_media_files(user_id)
            self.assertEqual(list(media_storage.GALLERY_ROOT.iterdir()), [])
            self.assertEqual(list(media_storage.AVATAR_ROOT.iterdir()), [])

    def test_gallery_routes_limit_photos_and_public_visibility(self):
        root = Path(__file__).resolve().parents[1]
        users = (root / "app/api/users.py").read_text(encoding="utf-8")
        models = (root / "app/models/event.py").read_text(encoding="utf-8")
        self.assertIn('UniqueConstraint("event_id", "user_id"', models)
        self.assertIn('/users/me/gallery/{event_id}/photos', users)
        self.assertIn('if len(current_urls) >= 3', users)
        self.assertIn('visibility == PROFILE_EVENT_VISIBILITY_PUBLIC', users)
        self.assertIn('EventGalleryItem.is_displayed.is_(True)', users)
        self.assertIn('owner.profile_event_visibility == PROFILE_EVENT_VISIBILITY_PUBLIC', users)
        self.assertIn('viewer_id == owner_id', users)


if __name__ == "__main__":
    unittest.main()
