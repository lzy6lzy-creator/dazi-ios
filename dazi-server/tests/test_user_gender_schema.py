from __future__ import annotations

import unittest
from pathlib import Path

from pydantic import ValidationError

from app.api.schemas import UserCreate, UserUpdate


class UserGenderSchemaTests(unittest.TestCase):
    def test_gender_accepts_supported_values_and_normalizes_aliases(self):
        self.assertEqual(UserCreate(name="小林", gender="男").gender, "男")
        self.assertEqual(UserUpdate(gender="female").gender, "女")

    def test_gender_can_be_omitted_for_partial_or_pre_onboarding_records(self):
        self.assertIsNone(UserCreate(name="新用户").gender)
        self.assertIsNone(UserUpdate().gender)

    def test_gender_rejects_private_empty_and_null_values_when_submitted(self):
        for value in ("保密", "暂时保密", "不透露", "", None):
            with self.subTest(value=value):
                with self.assertRaises(ValidationError):
                    UserUpdate(gender=value)

    def test_runtime_schema_clears_legacy_private_gender_values(self):
        main_source = (Path(__file__).resolve().parents[1] / "app/main.py").read_text(
            encoding="utf-8"
        )

        self.assertIn("UPDATE users SET gender = NULL", main_source)
        self.assertIn("'保密', '暂时保密', '不透露', '不公开'", main_source)


if __name__ == "__main__":
    unittest.main()
