from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class ChatPushStaticTests(unittest.TestCase):
    def test_push_notification_failure_does_not_abort_user_message_send(self):
        text = (ROOT / "app" / "api" / "chat.py").read_text(encoding="utf-8")

        send_message_body = text.split("async def send_message", 1)[1].split(
            '@router.post("/rooms/{room_id}/close")',
            1,
        )[0]

        self.assertIn("await _push_message_to_room(room_id, msg, db, exclude_user_ids={user_id})", send_message_body)
        self.assertIn("try:", send_message_body)
        self.assertIn("except Exception", send_message_body)
        self.assertIn("logger.warning", send_message_body)

    def test_send_message_uses_text_fallback_for_agent_mentions(self):
        text = (ROOT / "app" / "api" / "chat.py").read_text(encoding="utf-8")

        send_message_body = text.split("async def send_message", 1)[1].split(
            '@router.post("/rooms/{room_id}/close")',
            1,
        )[0]

        self.assertIn("_mentioned_room_agents(data.content, data.mentions", send_message_body)
        self.assertIn("if mentioned_agent_names:", send_message_body)
        self.assertIn("mentions=mentioned_agent_names", send_message_body)

    def test_push_notification_failure_does_not_abort_agent_reply(self):
        text = (ROOT / "app" / "api" / "chat.py").read_text(encoding="utf-8")

        handler_body = text.split("async def _handle_agent_mention", 1)[1]
        push_call = "await _push_message_to_room(room_id, agent_msg, db)"
        push_index = handler_body.index(push_call)
        nearby = handler_body[max(0, push_index - 250):push_index + 350]

        self.assertIn("try:", nearby)
        self.assertIn(push_call, nearby)
        self.assertIn("except Exception", nearby)
        self.assertIn("logger.warning", nearby)

    def test_push_notification_failure_does_not_abort_vote_rejection(self):
        text = (ROOT / "app" / "api" / "chat.py").read_text(encoding="utf-8")

        submit_vote_body = text.split("async def submit_vote", 1)[1].split(
            '@router.get("/rooms/{room_id}/vote-status"',
            1,
        )[0]
        push_call = "await _push_message_to_room(room_id, close_msg, db)"
        push_index = submit_vote_body.index(push_call)
        nearby = submit_vote_body[max(0, push_index - 250):push_index + 350]

        self.assertIn("try:", nearby)
        self.assertIn(push_call, nearby)
        self.assertIn("except Exception", nearby)
        self.assertIn("logger.warning", nearby)

    def test_push_notification_failure_does_not_abort_vote_match(self):
        text = (ROOT / "app" / "api" / "chat.py").read_text(encoding="utf-8")

        submit_vote_body = text.split("async def submit_vote", 1)[1].split(
            '@router.get("/rooms/{room_id}/vote-status"',
            1,
        )[0]
        push_call = "await _push_message_to_room(room_id, match_msg, db)"
        push_index = submit_vote_body.index(push_call)
        nearby = submit_vote_body[max(0, push_index - 250):push_index + 350]

        self.assertIn("try:", nearby)
        self.assertIn(push_call, nearby)
        self.assertIn("except Exception", nearby)
        self.assertIn("logger.warning", nearby)


if __name__ == "__main__":
    unittest.main()
