import SwiftUI

enum AppTheme {
    // MARK: - Colors (Brand)
    static let primaryColor = Color(red: 1.0, green: 0.42, blue: 0.21)
    static let secondaryColor = Color(red: 0.29, green: 0.56, blue: 0.85)
    static let agentColor = Color(red: 0.55, green: 0.36, blue: 0.96)

    // MARK: - Colors (Adaptive)
    static let backgroundColor = Color(UIColor.systemGroupedBackground)
    static let cardBackground = Color(UIColor.secondarySystemGroupedBackground)
    static let agentBubbleColor = Color(UIColor.tertiarySystemFill)
    static let userBubbleColor = Color(red: 1.0, green: 0.42, blue: 0.21)
    static let partnerBubbleColor = Color(red: 0.91, green: 0.95, blue: 1.0)
    static let systemBubbleColor = Color(UIColor.quaternarySystemFill)

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
