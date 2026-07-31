from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from app.services.internal_test_access import (
    is_internal_test_code,
    is_internal_test_phone,
)


class InternalTestAccessTests(unittest.TestCase):
    def test_phone_membership_unions_csv_and_file_with_normalization(self):
        with tempfile.TemporaryDirectory() as directory:
            phones_file = Path(directory) / "phones.txt"
            phones_file.write_text(
                "# internal testers\n+86 139-0000-0000 # owner\ninvalid\n",
                encoding="utf-8",
            )

            self.assertTrue(is_internal_test_phone(
                phone="13800000000",
                allowed_phones_csv=" 138-0000-0000,not-a-phone ",
                allowed_phones_file=str(phones_file),
            ))
            self.assertTrue(is_internal_test_phone(
                phone="13900000000",
                allowed_phones_csv="",
                allowed_phones_file=str(phones_file),
            ))
            self.assertFalse(is_internal_test_phone(
                phone="13700000000",
                allowed_phones_csv="13800000000",
                allowed_phones_file=str(phones_file),
            ))

    def test_fixed_code_requires_both_matching_code_and_whitelist_phone(self):
        arguments = {
            "configured_code": "121212",
            "allowed_phones_csv": "13800000000",
            "allowed_phones_file": None,
        }

        self.assertTrue(is_internal_test_code(
            phone="13800000000",
            submitted_code="121212",
            **arguments,
        ))
        self.assertFalse(is_internal_test_code(
            phone="13800000000",
            submitted_code="654321",
            **arguments,
        ))
        self.assertFalse(is_internal_test_code(
            phone="13900000000",
            submitted_code="121212",
            **arguments,
        ))


if __name__ == "__main__":
    unittest.main()
