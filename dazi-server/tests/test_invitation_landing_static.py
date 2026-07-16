from pathlib import Path
import json
import unittest


ROOT = Path(__file__).resolve().parents[1]


class InvitationLandingStaticTests(unittest.TestCase):
    def test_landing_page_validates_code_and_supports_share_copy_and_install(self):
        text = (ROOT / "site" / "invitation.html").read_text(encoding="utf-8")

        self.assertIn("/api/v1/invitations/", text)
        self.assertIn("/api/v1/auth/registration-policy", text)
        self.assertIn("navigator.share", text)
        self.assertIn("navigator.clipboard", text)
        self.assertIn("通过 TestFlight 安装", text)
        self.assertIn("已安装，打开 i搭不搭", text)

    def test_aasa_claims_invitation_paths_for_release_app(self):
        path = ROOT / "site" / ".well-known" / "apple-app-site-association"
        payload = json.loads(path.read_text(encoding="utf-8"))

        details = payload["applinks"]["details"]
        self.assertIn("96TW3HL4U4.com.linke.dazi", [item["appID"] for item in details])
        self.assertIn("/i/*", details[0]["paths"])

    def test_nginx_routes_invitation_page_and_aasa(self):
        text = (ROOT / "nginx.conf").read_text(encoding="utf-8")

        self.assertIn("location /i/", text)
        self.assertIn("/invitation.html", text)
        self.assertIn("location = /.well-known/apple-app-site-association", text)
        self.assertIn("default_type application/json", text)


if __name__ == "__main__":
    unittest.main()
