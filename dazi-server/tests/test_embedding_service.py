import unittest
import time
from concurrent.futures import ThreadPoolExecutor
from types import SimpleNamespace
from unittest.mock import Mock, patch

from app.services.embedding_service import EmbeddingService


class EmbeddingServiceTextTests(unittest.TestCase):
    def test_concurrent_first_requests_only_load_one_model(self):
        service = EmbeddingService()
        model = object()

        def load_model(_name):
            time.sleep(0.05)
            return model

        factory = Mock(side_effect=load_model)
        try:
            with patch.dict("sys.modules", {"sentence_transformers": SimpleNamespace(SentenceTransformer=factory)}):
                with ThreadPoolExecutor(max_workers=2) as executor:
                    results = list(executor.map(lambda _: service._load_model(), range(2)))
            self.assertEqual(results, [model, model])
            factory.assert_called_once()
        finally:
            service._executor.shutdown(wait=True)

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
