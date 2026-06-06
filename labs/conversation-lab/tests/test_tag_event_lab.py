import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from conversation_lab.tag_event_lab import (
    extract_openai_stream_delta,
    evaluate_tag_output,
    parse_tag_output,
)


class TagEventLabTests(unittest.TestCase):
    def test_parse_tag_output_extracts_allowed_fields(self):
        text = (
            "<city>上海</city>\n"
            "<activity>羽毛球</activity>\n"
            "<start_time>2026-04-18 19:00</start_time>\n"
            "<end_time>2026-04-18 21:00</end_time>\n"
            "<preferences>中等水平，想认真打</preferences>"
        )

        parsed = parse_tag_output(text)

        self.assertEqual(parsed["city"], "上海")
        self.assertEqual(parsed["activity"], "羽毛球")
        self.assertEqual(parsed["start_time"], "2026-04-18 19:00")
        self.assertEqual(parsed["preferences"], "中等水平，想认真打")

    def test_evaluate_tag_output_rejects_json_and_unknown_tags(self):
        result = evaluate_tag_output(
            '{"city":"上海"}\n<location>徐汇</location>',
            {"city": "上海"},
        )

        self.assertFalse(result["format_ok"])
        self.assertIn("contains_json_braces", result["issues"])
        self.assertIn("unknown_tag:location", result["issues"])

    def test_evaluate_tag_output_scores_expected_keywords(self):
        result = evaluate_tag_output(
            "<city>上海</city>\n"
            "<activity>羽毛球</activity>\n"
            "<start_time>2026-04-18 19:00</start_time>\n"
            "<end_time>2026-04-18 21:00</end_time>\n"
            "<preferences>中等水平，想认真打</preferences>",
            {
                "city": "上海",
                "activity": "羽毛球",
                "start_time": "2026-04-18 19:00",
                "end_time": "2026-04-18 21:00",
                "preferences_contains": ["中等", "认真"],
            },
        )

        self.assertEqual(result["field_score"], 1.0)
        self.assertTrue(result["format_ok"])

    def test_extract_openai_stream_delta_reads_content_only(self):
        chunk = {
            "choices": [
                {
                    "delta": {
                        "reasoning_content": "hidden thought",
                        "content": "<city>上海",
                    }
                }
            ]
        }

        self.assertEqual(extract_openai_stream_delta(chunk), "<city>上海")


if __name__ == "__main__":
    unittest.main()
