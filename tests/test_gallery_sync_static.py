from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
GALLERY_MODEL = (ROOT / "dazi/Models/GalleryItem.swift").read_text(encoding="utf-8")
GALLERY_STORE = (ROOT / "dazi/Services/GalleryStore.swift").read_text(encoding="utf-8")
API_CLIENT = (ROOT / "dazi/Services/APIClient.swift").read_text(encoding="utf-8")
DATA_STORE = (ROOT / "dazi/Services/DataStore.swift").read_text(encoding="utf-8")
PROFILE = (ROOT / "dazi/Views/Profile/ProfileView.swift").read_text(encoding="utf-8")
PARTNER_PROFILE = (ROOT / "dazi/Views/ChatRoom/PartnerProfileView.swift").read_text(encoding="utf-8")
AVATAR_VIEWS = (ROOT / "dazi/Views/Components/AvatarView.swift").read_text(encoding="utf-8")


class GallerySyncStaticTests(unittest.TestCase):
    def test_gallery_model_stores_urls_instead_of_photo_blobs(self):
        self.assertIn("var photoURLs: [String]", GALLERY_MODEL)
        self.assertNotIn("var photos: [Data]", GALLERY_MODEL)
        self.assertNotIn("saveItems", GALLERY_STORE)

    def test_gallery_crud_uses_backend(self):
        for marker in (
            "getMyGallery",
            "updateGalleryDisplay",
            "uploadGalleryPhoto",
            "deleteGalleryPhoto",
        ):
            self.assertIn(marker, API_CLIENT)
        self.assertIn("fetchGalleryFromServer", DATA_STORE)
        self.assertIn("migrateLegacyGalleryIfNeeded", DATA_STORE)
        self.assertIn("AuthenticatedMediaImage", PROFILE)

    def test_gallery_images_require_authenticated_loading(self):
        self.assertIn("getAuthenticatedMedia", API_CLIENT)
        self.assertIn("struct AuthenticatedMediaImage", AVATAR_VIEWS)
        self.assertIn("AuthenticatedMediaImage", PARTNER_PROFILE)
        self.assertNotIn("AsyncImage(url: APIConfig.mediaURL(from: photoURL))", PARTNER_PROFILE)


if __name__ == "__main__":
    unittest.main()
