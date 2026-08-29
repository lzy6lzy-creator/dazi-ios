from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
ONBOARDING = (ROOT / "dazi/Views/Onboarding/OnboardingView.swift").read_text(encoding="utf-8")
TAB_BAR = (ROOT / "dazi/Views/Components/CoinTabBar.swift").read_text(encoding="utf-8")
MAIN_TAB = (ROOT / "dazi/Views/MainTabView.swift").read_text(encoding="utf-8")


class WorkActivityAndAgentTabStaticTests(unittest.TestCase):
    def test_onboarding_uses_action_based_multi_select_options(self):
        for activity in (
            "学习", "查资料", "写论文", "写方案", "做PPT", "做表格",
            "看数据", "写代码", "做产品", "做设计", "做内容", "做运营",
            "开会", "聊需求", "教学", "谈客户", "做生意", "服务顾客",
        ):
            self.assertIn(f'"{activity}"', ONBOARDING)

        for old_occupation in ("学生", "互联网", "金融", "医疗", "自由职业"):
            self.assertNotIn(f'"{old_occupation}"', ONBOARDING)

        self.assertIn("selectedWorkActivities: Set<String>", ONBOARDING)
        self.assertIn("maxWorkActivityCount = 5", ONBOARDING)
        self.assertIn('joined(separator: "、")', ONBOARDING)

    def test_custom_work_activity_is_revealed_by_a_button(self):
        self.assertIn("if showsCustomWorkActivity", ONBOARDING)
        self.assertIn('"自己填写"', ONBOARDING)
        self.assertIn('TextField("比如：做研究、值班、跑现场"', ONBOARDING)
        self.assertIn("case .occupation: return !workActivitiesValue.isEmpty", ONBOARDING)

    def test_main_agent_tab_uses_current_agent_identity(self):
        self.assertIn("let agentName: String", TAB_BAR)
        self.assertIn("let agentEmoji: String", TAB_BAR)
        self.assertIn("let agentAvatarImageData: Data?", TAB_BAR)
        self.assertIn("AvatarView(", TAB_BAR)
        self.assertIn("agentName: dataStore.currentUser.agentName", MAIN_TAB)
        self.assertIn("agentAvatarImageData: dataStore.currentUser.agentAvatarImageData", MAIN_TAB)

    def test_registration_waits_for_server_profile_sync(self):
        sync_call = ONBOARDING.index("let didSync = await syncProfileToBackend")
        local_save = ONBOARDING.index("UserProfileStore().saveUser(user)")
        completion = ONBOARDING.index("onComplete()", sync_call)
        self.assertLess(sync_call, local_save)
        self.assertLess(local_save, completion)
        self.assertIn("guard didSync else", ONBOARDING)


if __name__ == "__main__":
    unittest.main()
