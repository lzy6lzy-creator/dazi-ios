from __future__ import annotations

import unittest
from pathlib import Path

from app.models.invitation import (
    InvitationLedger,
    InvitationMilestone,
    InvitationProgram,
    LocationVerification,
    SignupAdmission,
    UserInvitationAccount,
)


class InvitationModelTests(unittest.TestCase):
    def test_expected_tables_exist(self):
        self.assertEqual(InvitationProgram.__tablename__, "invitation_programs")
        self.assertEqual(UserInvitationAccount.__tablename__, "user_invitation_accounts")
        self.assertEqual(InvitationLedger.__tablename__, "invitation_ledger")
        self.assertEqual(SignupAdmission.__tablename__, "signup_admissions")
        self.assertEqual(LocationVerification.__tablename__, "location_verifications")
        self.assertEqual(InvitationMilestone.__tablename__, "invitation_milestones")

    def test_audit_and_idempotency_columns_are_unique(self):
        self.assertTrue(UserInvitationAccount.__table__.c.code.unique)
        self.assertTrue(InvitationLedger.__table__.c.idempotency_key.unique)
        self.assertTrue(SignupAdmission.__table__.c.token_hash.unique)

        constraints = {constraint.name for constraint in InvitationMilestone.__table__.constraints}
        self.assertIn("uq_invitation_milestone_user_type", constraints)

    def test_account_table_enforces_nonnegative_counters(self):
        constraints = {constraint.name for constraint in UserInvitationAccount.__table__.constraints}

        self.assertIn("ck_invitation_account_granted_nonnegative", constraints)
        self.assertIn("ck_invitation_account_consumed_nonnegative", constraints)
        self.assertIn("ck_invitation_account_reserved_nonnegative", constraints)
        self.assertIn("ck_invitation_account_balance_nonnegative", constraints)

    def test_startup_bootstraps_single_open_program(self):
        main_source = (
            Path(__file__).resolve().parents[1] / "app/main.py"
        ).read_text(encoding="utf-8")

        self.assertIn("INSERT INTO invitation_programs", main_source)
        self.assertIn("ON CONFLICT (id) DO NOTHING", main_source)

    def test_startup_backfills_existing_publish_and_match_milestones(self):
        main_source = (
            Path(__file__).resolve().parents[1] / "app/main.py"
        ).read_text(encoding="utf-8")

        self.assertIn("first_event_publish", main_source)
        self.assertIn("first_match", main_source)
        self.assertIn("ON CONFLICT (user_id, milestone_type) DO NOTHING", main_source)


if __name__ == "__main__":
    unittest.main()
