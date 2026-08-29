from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
API_CLIENT = (ROOT / "dazi/Services/APIClient.swift").read_text(encoding="utf-8")
TOKEN_STORE = (ROOT / "dazi/Services/SecureTokenStore.swift").read_text(encoding="utf-8")
WEBSOCKET = (ROOT / "dazi/Services/WebSocketService.swift").read_text(encoding="utf-8")
NOTIFICATIONS = (ROOT / "dazi/Services/NotificationService.swift").read_text(encoding="utf-8")
DATA_STORE = (ROOT / "dazi/Services/DataStore.swift").read_text(encoding="utf-8")


class AuthStorageAndWebSocketStaticTests(unittest.TestCase):
    def test_auth_tokens_use_keychain_with_legacy_migration(self):
        self.assertIn("SecItemCopyMatching", TOKEN_STORE)
        self.assertIn("SecItemUpdate", TOKEN_STORE)
        self.assertIn("kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly", TOKEN_STORE)
        self.assertIn("guard store(legacyValue, for: account) else", TOKEN_STORE)
        self.assertIn('migrating: "dazi_access_token"', API_CLIENT)
        self.assertIn('migrating: "dazi_refresh_token"', API_CLIENT)
        self.assertNotIn('UserDefaults.standard.string(forKey: "dazi_access_token")', API_CLIENT)

    def test_websocket_uses_header_and_reconnects_only_current_task(self):
        self.assertIn('request.setValue("Bearer \\(token)", forHTTPHeaderField: "Authorization")', WEBSOCKET)
        self.assertNotIn('/ws?token=', WEBSOCKET)
        self.assertIn("guard webSocketTask === task else { return }", WEBSOCKET)
        self.assertIn("reconnectWorkItem?.cancel()", WEBSOCKET)
        connect_body = WEBSOCKET.split("func connect()", 1)[1].split("func disconnect()", 1)[0]
        self.assertLess(connect_body.index("disconnect()"), connect_body.index("isIntentionallyClosed = false"))
        self.assertNotIn("reconnectDelay = 1", connect_body)

    def test_device_websocket_fallback_does_not_duplicate_apns(self):
        self.assertIn("#if targetEnvironment(simulator)", NOTIFICATIONS)
        self.assertIn("duplicate banners", NOTIFICATIONS)

    def test_stale_local_profile_does_not_bypass_login(self):
        self.assertIn("profileStore.loadUser(), api.isLoggedIn", DATA_STORE)
        self.assertIn("else if profileStore.isRegistered", DATA_STORE)
        self.assertIn("profileStore.clearUser()", DATA_STORE)


if __name__ == "__main__":
    unittest.main()
