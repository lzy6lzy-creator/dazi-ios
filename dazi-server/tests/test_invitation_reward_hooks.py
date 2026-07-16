from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class InvitationRewardHookTests(unittest.TestCase):
    def test_direct_event_creation_records_first_publish(self):
        text = (ROOT / "app" / "api" / "events.py").read_text(encoding="utf-8")
        body = text.split("async def create_event", 1)[1].split("@router.get", 1)[0]

        self.assertIn("record_invitation_milestone_safely", body)
        self.assertIn('milestone_type="first_event_publish"', body)
        self.assertIn("source_event_id=event.id", body)

    def test_agent_draft_creation_records_first_publish_but_edit_does_not(self):
        text = (ROOT / "app" / "api" / "agent_chat.py").read_text(encoding="utf-8")
        create_body = text.split("async def _create_event_from_draft", 1)[1].split(
            "async def _update_event_from_draft", 1
        )[0]
        update_body = text.split("async def _update_event_from_draft", 1)[1].split(
            "@router.post", 1
        )[0]

        self.assertIn("record_invitation_milestone_safely", create_body)
        self.assertIn('milestone_type="first_event_publish"', create_body)
        self.assertNotIn("record_invitation_milestone_safely", update_body)

    def test_successful_room_creation_rewards_both_users(self):
        text = (ROOT / "app" / "services" / "matching_service.py").read_text(encoding="utf-8")
        create_body = text.split("async def _create_chat_room", 1)[1].split(
            "async def _create_a2a_negotiating_room", 1
        )[0]

        self.assertIn("_record_match_invitation_milestones", create_body)
        self.assertIn("event_a", create_body)
        self.assertIn("event_b", create_body)

    def test_negotiating_room_does_not_reward_and_promotion_does(self):
        text = (ROOT / "app" / "services" / "matching_service.py").read_text(encoding="utf-8")
        negotiating_body = text.split("async def _create_a2a_negotiating_room", 1)[1].split(
            "async def _promote_a2a_room", 1
        )[0]
        promote_body = text.split("async def _promote_a2a_room", 1)[1].split(
            "async def", 1
        )[0]

        self.assertNotIn("_record_match_invitation_milestones", negotiating_body)
        self.assertIn("_record_match_invitation_milestones", promote_body)


if __name__ == "__main__":
    unittest.main()
