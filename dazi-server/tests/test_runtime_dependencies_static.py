from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
REQUIREMENTS = (ROOT / "requirements.txt").read_text(encoding="utf-8")


class RuntimeDependenciesStaticTests(unittest.TestCase):
    def test_removed_unused_password_form_and_migration_dependencies(self):
        self.assertNotIn("passlib", REQUIREMENTS)
        self.assertNotIn("python-multipart", REQUIREMENTS)
        self.assertNotIn("alembic==", REQUIREMENTS)


if __name__ == "__main__":
    unittest.main()
