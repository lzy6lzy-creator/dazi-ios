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

    def test_age_question_uses_presets_without_slider_or_manual_range(self):
        self.assertIn("ageRangePresetFields(question)", TEXT)
        self.assertIn("selectedAgeOptionIds(for: question)", TEXT)
        self.assertNotIn("Slider(value:", TEXT)
        self.assertNotIn("ageSliderRow(", TEXT)
        self.assertNotIn("minAgeBinding(for:", TEXT)
        self.assertNotIn("maxAgeBinding(for:", TEXT)
        self.assertNotIn("minAgeValues", TEXT)
        self.assertNotIn("maxAgeValues", TEXT)

    def test_age_answer_submits_only_selected_preset_option(self):
        answer_body = TEXT.split("private func answer(for question: ClarificationQuestion)", 1)[1]
        age_answer_body = answer_body.split("if isAgeQuestion(question) {", 1)[1].split("\n        }\n\n        let customText", 1)[0]
        self.assertIn("selectedAgeOptionIds(for: question)", age_answer_body)
        self.assertIn("ClarificationAnswerInput(questionId: question.id, optionIds: Array(optionIds))", age_answer_body)
        self.assertNotIn("minAge:", age_answer_body)
        self.assertNotIn("maxAge:", age_answer_body)

    def test_time_picker_bindings_do_not_mutate_the_other_picker_while_scrolling(self):
        start_binding_body = TEXT.split("private func startTimeBinding", 1)[1].split("private func endTimeBinding", 1)[0]
        end_binding_body = TEXT.split("private func endTimeBinding", 1)[1].split("private func seedDefaultTimeValues", 1)[0]
        self.assertNotIn("endTimeValues[question.id] =", start_binding_body)
        self.assertNotIn("startTimeValues[question.id] =", end_binding_body)
        self.assertIn("normalizedTimeRange(start: start, end: end)", TEXT)

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
