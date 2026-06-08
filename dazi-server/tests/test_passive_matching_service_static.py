from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class PassiveMatchingServiceStaticTests(unittest.TestCase):
    def test_passive_blocklist_is_scoped_to_event_and_candidate_user(self):
        text = (ROOT / "app" / "services" / "passive_matching_service.py").read_text(encoding="utf-8")

        blocklist_clause = text.split("blocklist_exists = ", 1)[1].split("distance = ", 1)[0]

        self.assertIn("MatchBlocklist.event_a_id == event.id", blocklist_clause)
        self.assertIn("MatchBlocklist.event_b_id == event.id", blocklist_clause)
        self.assertIn("MatchBlocklist.user_a_id == event.user_id", blocklist_clause)
        self.assertIn("MatchBlocklist.user_b_id == User.id", blocklist_clause)
        self.assertIn("MatchBlocklist.user_b_id == event.user_id", blocklist_clause)
        self.assertIn("MatchBlocklist.user_a_id == User.id", blocklist_clause)

    def test_passive_recall_uses_gender_filter_and_adjusted_score(self):
        text = (ROOT / "app" / "services" / "passive_matching_service.py").read_text(encoding="utf-8")

        self.assertIn("User.gender", text)
        self.assertIn("is_gender_filter_compatible", text)
        self.assertIn("adjusted_candidate_score", text)
        self.assertIn("gender_decision.should_pass", text)
        self.assertIn("if adjusted_similarity < PASSIVE_VECTOR_THRESHOLD", text)
        self.assertIn("candidates.sort(key=lambda item: item[1], reverse=True)", text)
        self.assertIn("chosen, similarity = candidates[0]", text)

    def test_passive_recall_uses_pgvector_orm_comparator(self):
        text = (ROOT / "app" / "services" / "passive_matching_service.py").read_text(encoding="utf-8")

        self.assertIn('User.embedding.cosine_distance(event.embedding).label("distance")', text)
        self.assertNotIn("u.embedding <=> :embedding", text)

    def test_passive_scan_does_not_hold_event_objects_across_commits(self):
        text = (ROOT / "app" / "services" / "passive_matching_service.py").read_text(encoding="utf-8")
        run_body = text.split("async def run_passive_matching", 1)[1].split(
            "async def _create_request_for_event_id", 1
        )[0]

        self.assertIn("select(Event.id)", run_body)
        self.assertIn("event_ids = result.scalars().all()", run_body)
        self.assertIn("for event_id in event_ids:", run_body)
        self.assertIn("await self._create_request_for_event_id(event_id, db)", run_body)
        self.assertNotIn("for event in events:", run_body)


if __name__ == "__main__":
    unittest.main()
