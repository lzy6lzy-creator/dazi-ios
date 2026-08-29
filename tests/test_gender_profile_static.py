from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
ONBOARDING = (ROOT / "dazi/Views/Onboarding/OnboardingView.swift").read_text(encoding="utf-8")
PROFILE = (ROOT / "dazi/Views/Profile/ProfileView.swift").read_text(encoding="utf-8")
USER = (ROOT / "dazi/Models/User.swift").read_text(encoding="utf-8")


class GenderProfileStaticTests(unittest.TestCase):
    def test_registration_only_offers_male_and_female(self):
        self.assertIn('genderButton(label: "男", value: "男"', ONBOARDING)
        self.assertIn('genderButton(label: "女", value: "女"', ONBOARDING)
        self.assertNotIn('genderButton(label: "保密"', ONBOARDING)
        self.assertIn("User.normalizedGender(gender) != nil", ONBOARDING)

    def test_profile_edit_requires_supported_gender(self):
        self.assertNotIn('genderButton(label: "保密"', PROFILE)
        self.assertIn(".disabled(User.normalizedGender(gender) == nil || isSaving)", PROFILE)
        self.assertIn("guard let selectedGender = User.normalizedGender(gender)", PROFILE)

    def test_profile_and_agent_edits_persist_server_first(self):
        profile_sync = PROFILE.index("try await APIClient.shared.updateMe")
        profile_local_save = PROFILE.index("UserProfileStore().saveUser(dataStore.currentUser)", profile_sync)
        agent_sync = PROFILE.index("try await APIClient.shared.updateMyAgent")
        agent_local_save = PROFILE.index("UserProfileStore().saveUser(dataStore.currentUser)", agent_sync)
        self.assertLess(profile_sync, profile_local_save)
        self.assertLess(agent_sync, agent_local_save)

    def test_legacy_private_gender_is_not_preserved_locally(self):
        self.assertIn('case "男", "male": return "男"', USER)
        self.assertIn('case "女", "female": return "女"', USER)
        self.assertIn('self.gender = Self.normalizedGender(gender) ?? ""', USER)
        self.assertNotIn("暂时保密", USER)


if __name__ == "__main__":
    unittest.main()
