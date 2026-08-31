from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import AsyncMock, MagicMock, patch

import yaml

from app.services.prompt_builder import PromptBuilder
from app.services.prompt_overrides import load_prompt_overrides


ROOT = Path(__file__).resolve().parents[1]


class WorkerRuntimeTests(unittest.TestCase):
    def test_only_worker_starts_schedulers(self):
        main = (ROOT / "app/main.py").read_text()
        worker = (ROOT / "app/worker.py").read_text()
        for name in ("match_scheduler", "beta_invite_scheduler", "service_reminder_monitor"):
            self.assertNotIn(f"{name}.start()", main)
            self.assertIn(f"{name}.start()", worker)
        self.assertIn("await ws_manager.start()", main)
        self.assertIn("await ws_manager.stop()", main)

    def test_worker_and_api_share_settings_but_not_ports(self):
        for name in ("docker-compose.yml", "docker-compose.prod.yml"):
            services = yaml.safe_load((ROOT / name).read_text())["services"]
            self.assertEqual(services["api"]["environment"], services["worker"]["environment"])
            self.assertEqual(services["api"]["image"], services["worker"]["image"])
            self.assertNotIn("ports", services["worker"])
            self.assertEqual(services["worker"]["depends_on"]["api"]["condition"], "service_healthy")
            self.assertIn("/ready", str(services["api"]["healthcheck"]))
            self.assertIn("heartbeat", str(services["worker"]["healthcheck"]))


class PromptOverrideSyncTests(unittest.IsolatedAsyncioTestCase):
    async def test_reloading_removes_deleted_overrides_and_ignores_unknown_templates(self):
        original = PromptBuilder._overrides.copy()
        try:
            PromptBuilder._overrides = {"conversation_orchestrator": "stale"}
            result = MagicMock()
            result.scalars.return_value.all.return_value = [
                SimpleNamespace(name="unknown-retired-template", content="ignored"),
            ]
            session = AsyncMock()
            session.execute.return_value = result
            context = AsyncMock()
            context.__aenter__.return_value = session
            with patch("app.services.prompt_overrides.async_session", return_value=context):
                await load_prompt_overrides()
            self.assertEqual(PromptBuilder._overrides, {})
        finally:
            PromptBuilder._overrides = original


if __name__ == "__main__":
    unittest.main()
