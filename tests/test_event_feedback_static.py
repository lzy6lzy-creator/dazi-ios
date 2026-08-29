from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
API_CLIENT = (ROOT / "dazi/Services/APIClient.swift").read_text(encoding="utf-8")
DATA_STORE = (ROOT / "dazi/Services/DataStore.swift").read_text(encoding="utf-8")
FEEDBACK_VIEW = (ROOT / "dazi/Views/Feedback/EventFeedbackView.swift").read_text(encoding="utf-8")
WEBSOCKET = (ROOT / "dazi/Services/WebSocketService.swift").read_text(encoding="utf-8")


class EventFeedbackStaticTests(unittest.TestCase):
    def test_feedback_uses_backend_and_preserves_both_ratings(self):
        self.assertIn('/api/v1/events/\\(eventId)/feedback', API_CLIENT)
        self.assertIn('"partner_rating"', API_CLIENT)
        self.assertIn("try await api.submitEventFeedback", DATA_STORE)
        self.assertNotIn("memories.append(memory)", DATA_STORE)
        self.assertIn("partnerRating: partnerRating > 0 ? partnerRating : nil", FEEDBACK_VIEW)
        self.assertIn('case "room_closed"', WEBSOCKET)
        self.assertIn("onRoomClosed?(roomId)", WEBSOCKET)

    def test_success_is_shown_only_after_async_submit(self):
        self.assertIn("let didSubmit = await dataStore.submitFeedback", FEEDBACK_VIEW)
        self.assertIn("guard didSubmit else { return }", FEEDBACK_VIEW)
        self.assertIn("isSubmitting", FEEDBACK_VIEW)


if __name__ == "__main__":
    unittest.main()
