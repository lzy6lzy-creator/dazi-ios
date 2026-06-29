import SwiftUI

enum AppTheme {
    enum ThemePreset {
        case classicOrange
        case warmGreen
    }

    private struct ThemePalette {
        let primaryColor: Color
        let secondaryColor: Color
        let agentColor: Color
        let warmAccent: Color
        let surfaceCream: Color
        let primaryLight: Color
        let backgroundColor: Color
        let cardBackground: Color
        let agentBubbleColor: Color
        let userBubbleColor: Color
        let partnerBubbleColor: Color
        let systemBubbleColor: Color
    }

    // Change this preset to switch the app between preserved theme versions.
    static let activePreset: ThemePreset = .warmGreen

    private static var palette: ThemePalette {
        switch activePreset {
        case .classicOrange:
            return ThemePalette(
                primaryColor: Color(red: 1.0, green: 0.42, blue: 0.21), // #FF6B36
                secondaryColor: Color(red: 0.29, green: 0.56, blue: 0.85),
                agentColor: Color(red: 0.55, green: 0.36, blue: 0.96),
                warmAccent: Color(red: 1.0, green: 0.42, blue: 0.21), // #FF6B36
                surfaceCream: Color(UIColor.systemGroupedBackground),
                primaryLight: Color(red: 1.0, green: 0.42, blue: 0.21).opacity(0.18),
                backgroundColor: Color(UIColor.systemGroupedBackground),
                cardBackground: Color(UIColor.secondarySystemGroupedBackground),
                agentBubbleColor: Color(UIColor.tertiarySystemFill),
                userBubbleColor: Color(red: 1.0, green: 0.42, blue: 0.21), // #FF6B36
                partnerBubbleColor: Color(red: 0.91, green: 0.95, blue: 1.0),
                systemBubbleColor: Color(UIColor.quaternarySystemFill)
            )
        case .warmGreen:
            return ThemePalette(
                primaryColor: Color(red: 0.243, green: 0.510, blue: 0.345), // #3E8258
                secondaryColor: Color(red: 0.29, green: 0.56, blue: 0.85),
                agentColor: Color(red: 0.271, green: 0.706, blue: 0.769), // #45B4C4
                warmAccent: Color(red: 1.0, green: 0.42, blue: 0.21), // #FF6B36
                surfaceCream: Color(red: 0.984, green: 0.973, blue: 0.945), // #FBF8F1
                primaryLight: Color(red: 0.243, green: 0.510, blue: 0.345).opacity(0.18),
                backgroundColor: Color(red: 0.984, green: 0.973, blue: 0.945), // #FBF8F1
                cardBackground: Color.white,
                agentBubbleColor: Color(red: 0.965, green: 0.945, blue: 0.902), // #F6F1E6
                userBubbleColor: Color(red: 0.243, green: 0.510, blue: 0.345), // #3E8258
                partnerBubbleColor: Color(red: 0.894, green: 0.941, blue: 0.988), // #E4F0FC
                systemBubbleColor: Color(red: 0.949, green: 0.937, blue: 0.918) // #F2EFEA
            )
        }
    }

    // MARK: - Colors (Brand)
    static var primaryColor: Color { palette.primaryColor }
    static var secondaryColor: Color { palette.secondaryColor }
    static var agentColor: Color { palette.agentColor }
    static var warmAccent: Color { palette.warmAccent }
    static var surfaceCream: Color { palette.surfaceCream }
    static var primaryLight: Color { palette.primaryLight }

    // MARK: - Colors (Adaptive)
    static var backgroundColor: Color { palette.backgroundColor }
    static var cardBackground: Color { palette.cardBackground }
    static var agentBubbleColor: Color { palette.agentBubbleColor }
    static var userBubbleColor: Color { palette.userBubbleColor }
    static var partnerBubbleColor: Color { palette.partnerBubbleColor }
    static var systemBubbleColor: Color { palette.systemBubbleColor }

    // MARK: - Spacing
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 12
    static let spacingLG: CGFloat = 16
    static let spacingXL: CGFloat = 20
    static let spacingXXL: CGFloat = 24
    static let spacingSection: CGFloat = 32

    // MARK: - Corner Radius
    static let radiusSM: CGFloat = 8
    static let radiusMD: CGFloat = 12
    static let radiusLG: CGFloat = 16
    static let radiusXL: CGFloat = 20
    static let radiusBubble: CGFloat = 18
    static let radiusFull: CGFloat = .infinity

    // MARK: - Shadow
    static let shadowColor = Color.black.opacity(0.04)
    static let shadowRadius: CGFloat = 8
    static let shadowY: CGFloat = 2

    /// 活动类型颜色（关键词模糊匹配，支持开放类型）
    static func activityTypeColor(_ type: String) -> Color {
        let t = type.lowercased()
        if t.contains("电影") || t.contains("影") || t.contains("剧") { return .blue }
        if t.contains("吃") || t.contains("美食") || t.contains("火锅") || t.contains("烧烤") || t.contains("餐") { return .orange }
        if t.contains("运动") || t.contains("徒步") || t.contains("爬") || t.contains("骑") || t.contains("球") || t.contains("跑") || t.contains("游泳") { return .green }
        if t.contains("展") || t.contains("博物") || t.contains("画") || t.contains("艺术") { return .purple }
        if t.contains("咖啡") || t.contains("茶") || t.contains("喝") { return .brown }
        if t.contains("音乐") || t.contains("演出") || t.contains("演唱") || t.contains("live") { return .pink }
        if t.contains("旅") || t.contains("露营") || t.contains("星") { return .cyan }
        if t.contains("桌游") || t.contains("游戏") || t.contains("玩") { return .indigo }
        return Color.secondary
    }

    /// 活动类型图标（关键词模糊匹配，支持开放类型）
    static func activityTypeIcon(_ type: String) -> String {
        let t = type.lowercased()
        if t.contains("电影") || t.contains("影") || t.contains("剧") { return "film" }
        if t.contains("吃") || t.contains("美食") || t.contains("火锅") || t.contains("烧烤") || t.contains("餐") { return "fork.knife" }
        if t.contains("徒步") || t.contains("爬") || t.contains("登") { return "figure.hiking" }
        if t.contains("运动") || t.contains("球") || t.contains("跑") || t.contains("游泳") { return "sportscourt" }
        if t.contains("展") || t.contains("博物") || t.contains("画") || t.contains("艺术") { return "paintpalette" }
        if t.contains("咖啡") || t.contains("茶") || t.contains("喝") { return "cup.and.saucer" }
        if t.contains("音乐") || t.contains("演出") || t.contains("演唱") { return "music.mic" }
        if t.contains("旅") || t.contains("露营") { return "tent" }
        if t.contains("星") { return "star" }
        if t.contains("桌游") || t.contains("游戏") { return "dice" }
        if t.contains("摄影") || t.contains("拍照") { return "camera" }
        if t.contains("阅读") || t.contains("读书") { return "book" }
        if t.contains("聊") || t.contains("闲") { return "bubble.left.and.bubble.right" }
        if t.contains("骑") { return "bicycle" }
        if t.contains("瑜伽") { return "figure.yoga" }
        return "sparkles"
    }

    static func statusColor(for status: EventStatus) -> Color {
        switch status {
        case .pending: return .orange
        case .matching: return .blue
        case .matched: return .green
        case .active: return .purple
        case .completed: return .gray
        case .cancelled: return .red
        }
    }
}

enum AppLocale {
    static let chinese = Locale(identifier: "zh_CN")

    static var chineseCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = chinese
        calendar.firstWeekday = 2
        return calendar
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
