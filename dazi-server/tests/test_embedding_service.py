import unittest

from app.services.embedding_service import EmbeddingService


class EmbeddingServiceTextTests(unittest.TestCase):
    def test_build_event_text_augments_shanghai_place_hierarchy(self):
        text = EmbeddingService.build_event_text(
            title="今晚吃饭",
            activity_type="吃饭",
            location="新天地",
        )

        self.assertIn("新天地", text)
        self.assertIn("上海", text)
        self.assertIn("黄浦", text)

    def test_build_event_text_augments_shanghai_district(self):
        text = EmbeddingService.build_event_text(
            title="找饭搭子",
            activity_type="吃饭",
            location="黄浦区",
        )

        self.assertIn("上海", text)
        self.assertIn("黄浦", text)


if __name__ == "__main__":
    unittest.main()
