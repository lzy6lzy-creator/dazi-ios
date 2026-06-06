import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from conversation_lab.normalizer import normalize_decision


class NormalizerTests(unittest.TestCase):
    def test_normalize_decision_accepts_draft_with_time_and_lists(self):
        result = normalize_decision({
            "action": "draft",
            "reply": "确认一下",
            "draft": {
                "title": "今晚火锅",
                "activity_type": "火锅",
                "city": "上海",
                "location": "徐汇",
                "start_time": "2026-06-05T19:00:00",
                "end_time": "2026-06-05T21:00:00",
                "preferences": ["实惠"],
                "constraints": ["不吃辣"],
            },
            "questions": [{"id": "ignored", "title": "忽略", "options": [{"id": "a", "label": "A"}]}],
        })

        self.assertEqual(result["action"], "draft")
        self.assertEqual(result["draft"]["city"], "上海")
        self.assertEqual(result["draft"]["preferences"], ["实惠"])
        self.assertEqual(result["questions"], [])

    def test_normalize_decision_keeps_only_valid_clarify_questions(self):
        result = normalize_decision({
            "action": "clarify",
            "reply": "我确认两个点",
            "draft": {"activity_type": "火锅"},
            "questions": [
                {"id": "budget", "title": "预算？", "options": [{"id": "low", "label": "50-80"}]},
                {"id": "bad", "title": "缺选项", "options": []},
            ],
        })

        self.assertEqual(result["action"], "clarify")
        self.assertEqual(len(result["questions"]), 1)
        self.assertEqual(result["questions"][0]["id"], "budget")

    def test_normalize_decision_downgrades_unknown_action_to_chat(self):
        result = normalize_decision({"action": "publish", "reply": "先聊聊"})

        self.assertEqual(result, {"action": "chat", "reply": "先聊聊", "draft": {}, "questions": []})


if __name__ == "__main__":
    unittest.main()
