from __future__ import annotations

import unittest
from datetime import date

from app.services.service_reminder_monitor import domain_expiration_from_rdap


class ServiceReminderMonitorTests(unittest.TestCase):
    def test_domain_expiration_uses_shanghai_calendar_date(self):
        payload = {
            "events": [
                {"eventAction": "registration", "eventDate": "2026-06-04T07:27:56Z"},
                {"eventAction": "expiration", "eventDate": "2027-06-04T23:30:00Z"},
            ]
        }

        self.assertEqual(domain_expiration_from_rdap(payload), date(2027, 6, 5))

    def test_domain_expiration_requires_expiration_event(self):
        with self.assertRaises(ValueError):
            domain_expiration_from_rdap({"events": []})


if __name__ == "__main__":
    unittest.main()
