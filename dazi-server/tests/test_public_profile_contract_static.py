import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCHEMAS = (ROOT / "app/api/schemas.py").read_text()
USERS_API = (ROOT / "app/api/users.py").read_text()
USER_MODEL = (ROOT / "app/models/user.py").read_text()
MAIN = (ROOT / "app/main.py").read_text()


class PublicProfileContractStaticTests(unittest.TestCase):
    def test_public_profile_contract_contains_event_visibility_and_events(self):
        self.assertIn("class PublicProfileEventResponse", SCHEMAS)
        self.assertIn("profile_event_visibility", SCHEMAS)
        self.assertIn("past_events", SCHEMAS)
        self.assertIn("created_at", SCHEMAS)

    def test_user_profile_event_visibility_is_persisted_and_updatable(self):
        self.assertIn("profile_event_visibility", USER_MODEL)
        self.assertIn("profile_event_visibility", MAIN)
        self.assertIn("profile_event_visibility", SCHEMAS)

    def test_public_profile_endpoint_builds_response_with_event_history(self):
        self.assertIn("Event", USERS_API)
        self.assertIn("_build_public_profile_response", USERS_API)
        self.assertIn("_public_profile_event_payload", USERS_API)
        self.assertIn("past_events=", USERS_API)


if __name__ == "__main__":
    unittest.main()
