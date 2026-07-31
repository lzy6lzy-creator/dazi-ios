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
        self.assertIn("primaryColor: Color(red: 0.137, green: 0.420, blue: 0.353)", TEXT)
        self.assertIn("agentColor: Color(red: 0.184, green: 0.620, blue: 0.584)", TEXT)
        self.assertIn("surfaceCream: Color(red: 0.969, green: 0.953, blue: 0.922)", TEXT)

    def test_public_theme_api_stays_stable(self):
        self.assertIn("static var primaryColor: Color { palette.primaryColor }", TEXT)
        self.assertIn("static var backgroundColor: Color { palette.backgroundColor }", TEXT)
        self.assertIn("static var userBubbleColor: Color { palette.userBubbleColor }", TEXT)


if __name__ == "__main__":
    unittest.main()
