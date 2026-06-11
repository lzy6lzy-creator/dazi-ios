import SwiftUI

struct CoinTabBar: View {
    @Binding var selection: Int
    var unreadCount: Int = 0

    private let items: [(icon: String, label: String)] = [
        ("sparkles",                     "点点"),
        ("calendar",                     "活动"),
        ("ellipsis.bubble",              "聊天"),
        ("person",                       "我的")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                CoinTab(
                    icon: items[i].icon,
                    label: items[i].label,
                    isActive: selection == i,
                    showBadge: i == 2 && unreadCount > 0
                )
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    selection = i
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color(red: 0.12, green: 0.16, blue: 0.16).opacity(0.10),
                radius: 14, x: 0, y: 6)
        .padding(.horizontal, 12)
    }
}

private struct CoinTab: View {
    let icon: String
    let label: String
    let isActive: Bool
    var showBadge: Bool = false

    private var iconSize: CGFloat {
        icon == "ellipsis.bubble" ? 19 : 21
    }

    private var activeIcon: String {
        switch icon {
        case "sparkles": return "sparkles"
        case "calendar": return "calendar"
        case "ellipsis.bubble": return "ellipsis.bubble.fill"
        case "person": return "person.fill"
        default: return icon
        }
    }

    @State private var sparklePulse = false

    private let spring = Animation.spring(response: 0.32, dampingFraction: 0.62)

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(AppTheme.primaryColor)
                    .frame(width: 40, height: 40)
                    .shadow(color: AppTheme.primaryColor.opacity(0.4),
                            radius: 7, x: 0, y: 6)
                    .scaleEffect(isActive ? 1 : 0.1)
                    .opacity(isActive ? 1 : 0)

                Image(systemName: isActive ? activeIcon : icon)
                    .font(.system(size: iconSize, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? .white : Color(.systemGray2))
            }
            .frame(width: 40, height: 40)
            .offset(y: isActive ? -2 : 0)
            .overlay(alignment: .topTrailing) {
                if isActive {
                    Image(systemName: "sparkle")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppTheme.warmAccent)
                        .offset(x: 8, y: -6)
                        .opacity(sparklePulse ? 0.4 : 1)
                        .scaleEffect(sparklePulse ? 0.7 : 1)
                        .onAppear {
                            withAnimation(
                                .easeInOut(duration: 1.4)
                                .repeatForever(autoreverses: true)
                            ) {
                                sparklePulse = true
                            }
                        }
                        .onDisappear {
                            sparklePulse = false
                        }
                }
            }
            .overlay(alignment: .topTrailing) {
                if showBadge {
                    Circle()
                        .fill(AppTheme.warmAccent)
                        .frame(width: 6, height: 6)
                        .offset(x: 4, y: 2)
                }
            }

            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(isActive ? AppTheme.primaryColor : Color(.systemGray2))
        }
        .animation(spring, value: isActive)
    }
}
