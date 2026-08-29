from __future__ import annotations

import unittest

from pydantic import ValidationError

from app.api.schemas import AgentChatRequest, MessageCreate, UserUpdate


class APIInputBoundsTests(unittest.TestCase):
    def test_chat_inputs_reject_empty_or_oversized_content(self):
        with self.assertRaises(ValidationError):
            AgentChatRequest(message="")
        with self.assertRaises(ValidationError):
            AgentChatRequest(message="x" * 4001)
        with self.assertRaises(ValidationError):
            MessageCreate(content="x" * 4001)

    def test_profile_fields_respect_database_column_bounds(self):
        with self.assertRaises(ValidationError):
            UserUpdate(name="x" * 51)
        with self.assertRaises(ValidationError):
            UserUpdate(city="x" * 51)
        with self.assertRaises(ValidationError):
            UserUpdate(occupation="x" * 101)


if __name__ == "__main__":
    unittest.main()
