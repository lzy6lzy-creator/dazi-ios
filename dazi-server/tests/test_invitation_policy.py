from __future__ import annotations

import unittest
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

from app.services.invitation_policy import (
    available_balance,
    is_admission_active,
    is_location_current,
    point_in_shanghai,
    should_transition,
    SHANGHAI_BOUNDARY_POLYGONS,
)


class InvitationPolicyTests(unittest.TestCase):
    def test_available_balance_subtracts_consumed_and_reserved(self):
        account = SimpleNamespace(granted_total=5, consumed_total=1, reserved_total=2)

        self.assertEqual(available_balance(account), 2)

    def test_admission_is_active_only_while_issued_and_unexpired(self):
        now = datetime(2026, 7, 17, tzinfo=timezone.utc)

        self.assertTrue(is_admission_active(
            SimpleNamespace(status="issued", expires_at=now + timedelta(minutes=10)),
            now,
        ))
        self.assertFalse(is_admission_active(
            SimpleNamespace(status="issued", expires_at=now),
            now,
        ))
        self.assertFalse(is_admission_active(
            SimpleNamespace(status="consumed", expires_at=now + timedelta(minutes=10)),
            now,
        ))

    def test_location_must_be_launch_city_and_unexpired(self):
        now = datetime(2026, 7, 17, tzinfo=timezone.utc)

        self.assertTrue(is_location_current(
            SimpleNamespace(is_launch_city=True, expires_at=now + timedelta(days=30)),
            now,
        ))
        self.assertFalse(is_location_current(
            SimpleNamespace(is_launch_city=False, expires_at=now + timedelta(days=30)),
            now,
        ))
        self.assertFalse(is_location_current(
            SimpleNamespace(is_launch_city=True, expires_at=now),
            now,
        ))

    def test_shanghai_polygon_accepts_city_center_and_rejects_nearby_cities(self):
        self.assertTrue(point_in_shanghai(latitude=31.2304, longitude=121.4737))
        self.assertTrue(point_in_shanghai(latitude=31.626, longitude=121.397))  # 崇明岛
        self.assertTrue(point_in_shanghai(latitude=30.744, longitude=121.337))  # 金山
        self.assertFalse(point_in_shanghai(latitude=30.2741, longitude=120.1551))
        self.assertFalse(point_in_shanghai(latitude=31.2989, longitude=120.5853))
        self.assertFalse(point_in_shanghai(latitude=31.385, longitude=120.980))  # 昆山

    def test_boundary_uses_full_district_geometry(self):
        self.assertGreater(len(SHANGHAI_BOUNDARY_POLYGONS), 16)

    def test_transition_occurs_at_exact_target(self):
        self.assertFalse(should_transition(qualified_user_count=499, qualified_target=500))
        self.assertTrue(should_transition(qualified_user_count=500, qualified_target=500))
        self.assertTrue(should_transition(qualified_user_count=501, qualified_target=500))


if __name__ == "__main__":
    unittest.main()
