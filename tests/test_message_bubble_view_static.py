import unittest
from pathlib import Path


SOURCE = Path(__file__).resolve().parents[1] / "dazi/Views/Components/MessageBubbleView.swift"
TEXT = SOURCE.read_text()
DATASTORE_SOURCE = Path(__file__).resolve().parents[1] / "dazi/Services/DataStore.swift"
DATASTORE_TEXT = DATASTORE_SOURCE.read_text()


class MessageBubbleViewStaticTests(unittest.TestCase):
    def test_age_default_range_clamps_base_age_before_applying_radius(self):
        self.assertIn("let baseAge = Self.clampedAge(User.currentUser.age ?? 25)", TEXT)
        self.assertIn("let minAge = max(baseAge - radius, Self.minimumAllowedAge)", TEXT)
        self.assertIn("let maxAge = min(baseAge + radius, Self.maximumAllowedAge)", TEXT)

    def test_age_sliders_never_receive_zero_length_bounds(self):
        self.assertIn("bounds: ClosedRange<Double>?", TEXT)
        self.assertIn("if let bounds, bounds.upperBound > bounds.lowerBound", TEXT)
        self.assertIn("guard upper > lower else { return nil }", TEXT)

        self.assertIn("ageSliderBounds(lower: Self.minimumAllowedAge, upper: range.max - 1)", TEXT)
        self.assertIn("ageSliderBounds(lower: range.min + 1, upper: Self.maximumAllowedAge)", TEXT)

    def test_age_bindings_keep_min_and_max_distinct(self):
        self.assertIn("currentMax - 1", TEXT)
        self.assertIn("currentMin + 1", TEXT)

    def test_agent_history_session_role_restores_session_divider(self):
        self.assertIn(
            'private static let agentSessionDividerText = "活动已发布。下面为你开启新的对话。"',
            DATASTORE_TEXT,
        )
        self.assertIn('case "session":', DATASTORE_TEXT)
        self.assertIn("rawContent.hasPrefix(Self.agentSessionResetPrefix)", DATASTORE_TEXT)
        self.assertIn("content = Self.agentSessionDividerText", DATASTORE_TEXT)


if __name__ == "__main__":
    unittest.main()
