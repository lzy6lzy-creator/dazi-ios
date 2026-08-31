from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class ServiceReminderStaticTests(unittest.TestCase):
    def read(self, relative_path: str) -> str:
        return (ROOT / relative_path).read_text(encoding="utf-8")

    def test_runtime_seeds_confirmed_project_reminders(self):
        source = self.read("app/main.py")

        for slug in [
            "idabuda-domain",
            "idabuda-tls",
            "idabuda-icp",
            "aliyun-server",
            "aliyun-pnvs",
            "apple-developer-membership",
            "apple-development-certificate",
            "apple-testflight-build",
            "apple-keys-review",
            "moonshot-balance",
        ]:
            self.assertIn(f"'{slug}'", source)

        self.assertIn("DATE '2027-06-04'", source)
        self.assertIn("DATE '2026-11-27'", source)
        self.assertIn("DATE '2027-06-29'", source)
        self.assertIn("DATE '2027-06-30', 'month'", source)
        self.assertIn("余额没有固定到期日", source)
        self.assertIn("ON CONFLICT (slug) DO NOTHING", source)

    def test_model_stores_dates_without_credentials(self):
        source = self.read("app/models/service_reminder.py")

        for field in [
            "due_date",
            "date_precision",
            "recurrence_months",
            "reminder_days",
            "auto_renew",
            "action_url",
            "last_verified_at",
        ]:
            self.assertIn(field, source)

        self.assertNotIn("api_key", source.lower())
        self.assertNotIn("password", source.lower())
        self.assertNotIn("private_key", source.lower())

    def test_admin_api_supports_crud_and_cycle_completion(self):
        source = self.read("app/api/admin.py")

        self.assertIn('@router.get("/service-reminders")', source)
        self.assertIn('@router.post("/service-reminders")', source)
        self.assertIn('@router.post("/service-reminders/refresh-external")', source)
        self.assertIn('@router.patch("/service-reminders/{reminder_id}")', source)
        self.assertIn('@router.post("/service-reminders/{reminder_id}/complete-cycle")', source)
        self.assertIn('@router.delete("/service-reminders/{reminder_id}")', source)
        self.assertIn('ZoneInfo("Asia/Shanghai")', source)
        self.assertIn("date_precision", source)

    def test_admin_console_contains_reminder_page(self):
        html = self.read("app/static/admin.html")

        self.assertIn('data-panel="reminders"', html)
        self.assertIn('id="panel-reminders"', html)
        self.assertIn('id="reminderStats"', html)
        self.assertIn('id="reminderEditor"', html)
        self.assertIn("/api/admin/service-reminders", html)
        self.assertIn("具体日待核实", html)
        self.assertIn("不保存账号密钥", html)
        self.assertIn("completeServiceReminder", html)
        self.assertIn("refreshExternalServiceReminders", html)
        self.assertIn("在线核查域名/证书", html)
        self.assertIn("confirmAction", html)

    def test_daily_public_date_monitor_is_started_and_stopped(self):
        worker = self.read("app/worker.py")
        monitor = self.read("app/services/service_reminder_monitor.py")

        self.assertIn("service_reminder_monitor.start()", worker)
        self.assertIn("await service_reminder_monitor.stop()", worker)
        self.assertIn("24 * 60 * 60", monitor)
        self.assertIn("rdap.verisign.com", monitor)
        self.assertIn("asyncio.open_connection", monitor)


if __name__ == "__main__":
    unittest.main()
