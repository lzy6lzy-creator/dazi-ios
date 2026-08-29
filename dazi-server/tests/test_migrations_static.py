from pathlib import Path
import unittest

from alembic.config import Config
from alembic.script import ScriptDirectory


ROOT = Path(__file__).resolve().parents[1]


class MigrationStaticTests(unittest.TestCase):
    def test_migration_chain_has_one_head(self):
        config = Config(str(ROOT / "alembic.ini"))
        script = ScriptDirectory.from_config(config)

        self.assertEqual(script.get_heads(), ["0002_push_token_lookup_index"])
        self.assertEqual(script.get_base(), "0001_baseline")

    def test_baseline_is_frozen_and_complete(self):
        sql = (ROOT / "migrations/sql/0001_baseline.sql").read_text(encoding="utf-8")

        self.assertEqual(sql.count("CREATE TABLE "), 27)
        self.assertIn("CREATE EXTENSION IF NOT EXISTS vector", sql)
        self.assertIn("CREATE TABLE event_feedbacks", sql)
        self.assertIn("CREATE TABLE event_gallery_items", sql)

    def test_application_startup_does_not_mutate_schema(self):
        source = (ROOT / "app/main.py").read_text(encoding="utf-8")

        self.assertNotIn("create_all", source)
        self.assertNotIn("ALTER TABLE", source)
        self.assertIn("_ensure_runtime_data", source)

    def test_containers_upgrade_before_starting_api(self):
        for compose_name in ("docker-compose.yml", "docker-compose.prod.yml"):
            source = (ROOT / compose_name).read_text(encoding="utf-8")
            self.assertIn("alembic upgrade head && exec uvicorn", source)


if __name__ == "__main__":
    unittest.main()
