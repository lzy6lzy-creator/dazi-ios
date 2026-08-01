from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class AccountDeletionStaticTests(unittest.TestCase):
    def test_api_client_calls_authenticated_delete_me_endpoint(self):
        api = (ROOT / "dazi/Services/APIClient.swift").read_text(encoding="utf-8")

        self.assertIn("func deleteMyAccount()", api)
        self.assertIn('method: "DELETE", path: "/api/v1/users/me"', api)

    def test_data_store_waits_for_server_before_clearing_local_session(self):
        store = (ROOT / "dazi/Services/DataStore.swift").read_text(encoding="utf-8")

        request_index = store.index("try await api.deleteMyAccount()")
        reset_index = store.index("resetLocalSession(unregisterRemoteToken: false)")
        self.assertLess(request_index, reset_index)

    def test_profile_exposes_irreversible_account_deletion_confirmation(self):
        profile = (ROOT / "dazi/Views/Profile/ProfileView.swift").read_text(encoding="utf-8")

        self.assertIn('Text("注销账号")', profile)
        self.assertIn("showDeleteAccountConfirm", profile)
        self.assertIn("永久删除你的个人资料、活动、聊天室、记忆和邀请数据", profile)
        self.assertIn("try await dataStore.deleteAccount()", profile)


if __name__ == "__main__":
    unittest.main()
