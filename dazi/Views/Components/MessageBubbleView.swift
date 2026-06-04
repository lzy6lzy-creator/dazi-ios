import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    var showAvatar: Bool = true
    var onConfirm: (() -> Void)?

    private var isFromUser: Bool {
        message.role == .user
    }

    private var bubbleColor: Color {
        switch message.role {
        case .user:
            return AppTheme.userBubbleColor
        case .agent:
            return AppTheme.agentBubbleColor
        case .partner:
            return AppTheme.partnerBubbleColor
        case .partnerAgent:
            return AppTheme.agentBubbleColor
        case .system:
            return AppTheme.systemBubbleColor
        }
    }

    private var textColor: Color {
        message.role == .user ? .white : .primary
    }

    var body: some View {
        if message.role == .system {
            systemBubble
        } else if message.isTyping {
            typingBubble
        } else {
            chatBubble
        }
    }

    private var systemBubble: some View {
        HStack {
            Spacer()
            Text(message.content)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(bubbleColor.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMD))
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var chatBubble: some View {
        HStack(alignment: .top, spacing: 8) {
            if isFromUser { Spacer(minLength: 48) }

            if !isFromUser && showAvatar {
                avatarView
            }

            VStack(alignment: isFromUser ? .trailing : .leading, spacing: 2) {
                if !isFromUser && showAvatar {
                    Text(message.senderName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(message.content)
                    .font(.body)
                    .foregroundStyle(textColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(bubbleColor)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: isFromUser ? AppTheme.radiusBubble : 4,
                            bottomLeadingRadius: AppTheme.radiusBubble,
                            bottomTrailingRadius: isFromUser ? 4 : AppTheme.radiusBubble,
                            topTrailingRadius: AppTheme.radiusBubble
                        )
                    )

                if message.showConfirmButtons && !message.confirmButtonsTapped {
                    Button {
                        onConfirm?()
                    } label: {
                        Text("确认发布")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(AppTheme.primaryColor)
                            .clipShape(Capsule())
                    }
                    .padding(.top, 6)
                }

                Text(timeString)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if isFromUser && showAvatar {
                avatarView
            }

            if !isFromUser { Spacer(minLength: 48) }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
    }

    private var typingBubble: some View {
        HStack(alignment: .top, spacing: 8) {
            if showAvatar {
                avatarView
            }

            TypingIndicator()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(bubbleColor)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusBubble))

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
    }

    private var avatarView: some View {
        let isAgentRole = message.role == .agent || message.role == .partnerAgent
        let fallbackEmoji = message.senderAvatar.isEmpty ? (isAgentRole ? "🤖" : "😊") : message.senderAvatar
        let bgColor = isAgentRole ? AppTheme.agentColor.opacity(0.12) : Color.gray.opacity(0.08)

        return AvatarView(
            imageData: message.senderAvatarImageData,
            emoji: fallbackEmoji,
            size: 34,
            backgroundColor: bgColor
        )
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private var timeString: String {
        Self.timeFormatter.string(from: message.timestamp)
    }
}

struct DateSeparator: View {
    let date: Date

    private var dateText: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "今天" }
        if calendar.isDateInYesterday(date) { return "昨天" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: date)
    }

    var body: some View {
        Text(dateText)
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, AppTheme.spacingMD)
            .padding(.vertical, AppTheme.spacingXS)
            .background(Color(.quaternarySystemFill))
            .clipShape(Capsule())
            .padding(.vertical, AppTheme.spacingSM)
    }
}

struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 7, height: 7)
                    .offset(y: animating ? -4 : 0)
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                        value: animating
                    )
            }
        }
        .onAppear {
            animating = true
        }
    }
}
