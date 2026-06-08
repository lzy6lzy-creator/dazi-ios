import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
API_CLIENT = (ROOT / "dazi/Services/APIClient.swift").read_text()
DATASTORE = (ROOT / "dazi/Services/DataStore.swift").read_text()
EVENT_MODEL = (ROOT / "dazi/Models/Event.swift").read_text()
EVENT_LIST = (ROOT / "dazi/Views/Events/EventListView.swift").read_text()
SERVER_EVENTS = (ROOT / "dazi-server/app/api/events.py").read_text()
SERVER_SCHEMAS = (ROOT / "dazi-server/app/api/schemas.py").read_text()


class EventPlazaStaticTests(unittest.TestCase):
    def test_backend_exposes_anonymous_pending_event_plaza(self):
        self.assertIn("class EventPlazaResponse", SERVER_SCHEMAS)
        self.assertNotIn("class EventPlazaResponse(BaseModel):\n    id: UUID\n    user_id", SERVER_SCHEMAS)
        self.assertIn('@router.get("/plaza", response_model=list[EventPlazaResponse])', SERVER_EVENTS)
        self.assertIn('Event.status == "pending"', SERVER_EVENTS)
        self.assertIn("Event.user_id != user_id", SERVER_EVENTS)
        self.assertIn(".limit(limit)", SERVER_EVENTS)

    def test_ios_fetches_and_stores_plaza_events(self):
        self.assertIn("struct APIPlazaEventResponse: Codable", API_CLIENT)
        self.assertIn('path: "/api/v1/events/plaza"', API_CLIENT)
        self.assertIn("struct PlazaEvent", EVENT_MODEL)
        self.assertIn("var plazaEvents: [PlazaEvent] = []", DATASTORE)
        self.assertIn("func fetchPlazaEventsFromServer() async", DATASTORE)

    def test_event_list_has_my_events_and_plaza_segments(self):
        self.assertIn("enum EventListScope", EVENT_LIST)
        self.assertIn('case plaza', EVENT_LIST)
        self.assertIn('Text("活动广场")', EVENT_LIST)
        self.assertIn("PlazaEventCard", EVENT_LIST)
        self.assertIn("dataStore.plazaEvents", EVENT_LIST)


if __name__ == "__main__":
    unittest.main()
