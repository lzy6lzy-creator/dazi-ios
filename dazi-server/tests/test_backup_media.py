from pathlib import Path
import tempfile
import unittest

from scripts.verify_backup_media import verify_media


class BackupMediaTests(unittest.TestCase):
    def test_only_local_media_is_checked(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "avatars").mkdir()
            (root / "gallery").mkdir()
            (root / "avatars/avatar.jpg").write_bytes(b"avatar")
            (root / "gallery/photo.jpg").write_bytes(b"photo")
            count = verify_media(root, [
                "/media/avatars/avatar.jpg", "/api/v1/gallery/media/photo.jpg",
                "https://example.com/external.jpg",
                "https://example.com/media/avatars/external.jpg",
            ])
            self.assertEqual(count, 2)

    def test_missing_file_and_path_escape_fail_verification(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for path in ("/media/avatars/missing.jpg", "/media/avatars/..%2F..%2Fetc%2Fpasswd"):
                with self.assertRaises(ValueError):
                    verify_media(root, [path])


if __name__ == "__main__":
    unittest.main()
