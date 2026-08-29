from __future__ import annotations

import ast
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class ChatRoomBatchingTests(unittest.TestCase):
    def test_room_list_has_no_database_execute_inside_python_loops(self):
        source = (ROOT / "app/api/chat.py").read_text(encoding="utf-8")
        tree = ast.parse(source)
        function = next(
            node for node in tree.body
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and node.name == "list_my_rooms"
        )
        for loop in [node for node in ast.walk(function) if isinstance(node, (ast.For, ast.AsyncFor))]:
            execute_calls = [
                node for node in ast.walk(loop)
                if isinstance(node, ast.Call)
                and isinstance(node.func, ast.Attribute)
                and node.func.attr == "execute"
            ]
            self.assertEqual(execute_calls, [], f"database query inside loop at line {loop.lineno}")

    def test_room_list_batches_latest_messages_and_unread_rooms(self):
        source = (ROOT / "app/api/chat.py").read_text(encoding="utf-8")
        self.assertIn("func.row_number().over", source)
        self.assertIn("partition_by=ChatMessage.room_id", source)
        self.assertIn("unread_room_ids = set", source)
        self.assertIn("ChatRoomMember.room_id.in_(room_ids)", source)
        self.assertIn("User.id.in_(user_ids)", source)
        self.assertIn("Agent.id.in_(agent_ids)", source)


if __name__ == "__main__":
    unittest.main()
