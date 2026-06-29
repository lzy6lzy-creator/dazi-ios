import unittest
from pathlib import Path


SOURCE = Path(__file__).resolve().parents[1] / "dazi/Theme/AppTheme.swift"
TEXT = SOURCE.read_text()


class AppThemeStaticTests(unittest.TestCase):
    def test_preserves_switchable_theme_versions(self):
        self.assertIn("enum ThemePreset", TEXT)
        self.assertIn("case classicOrange", TEXT)
        self.assertIn("case warmGreen", TEXT)
        self.assertIn("static let activePreset: ThemePreset = .warmGreen", TEXT)

    def test_preserves_classic_orange_palette(self):
        self.assertIn("case .classicOrange:", TEXT)
        self.assertIn("primaryColor: Color(red: 1.0, green: 0.42, blue: 0.21)", TEXT)
        self.assertIn("agentColor: Color(red: 0.55, green: 0.36, blue: 0.96)", TEXT)
        self.assertIn("cardBackground: Color(UIColor.secondarySystemGroupedBackground)", TEXT)

    def test_preserves_warm_green_palette(self):
        self.assertIn("case .warmGreen:", TEXT)
        self.assertIn("primaryColor: Color(red: 0.243, green: 0.510, blue: 0.345)", TEXT)
        self.assertIn("agentColor: Color(red: 0.271, green: 0.706, blue: 0.769)", TEXT)
        self.assertIn("surfaceCream: Color(red: 0.984, green: 0.973, blue: 0.945)", TEXT)

    def test_public_theme_api_stays_stable(self):
        self.assertIn("static var primaryColor: Color { palette.primaryColor }", TEXT)
        self.assertIn("static var backgroundColor: Color { palette.backgroundColor }", TEXT)
        self.assertIn("static var userBubbleColor: Color { palette.userBubbleColor }", TEXT)


if __name__ == "__main__":
    unittest.main()
