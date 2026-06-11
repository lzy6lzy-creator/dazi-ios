import SwiftUI

struct ChatInputBar: View {
    @Binding var text: String
    var isInputFocused: FocusState<Bool>.Binding
    var placeholder: String = "输入消息..."
    var mentionCandidates: [User] = []
    var onSend: () -> Void

    @State private var showMentionList = false

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 检测是否刚输入了 @
    private var shouldShowMentions: Bool {
        guard !mentionCandidates.isEmpty else { return false }
        // 当文本以 @ 结尾，或者最后一个 @ 后面没有空格时显示
        if let lastAt = text.lastIndex(of: "@") {
            let afterAt = text[text.index(after: lastAt)...]
            return !afterAt.contains(" ") && !afterAt.contains("\n")
        }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            // @ 提及候选人列表
            if showMentionList && !mentionCandidates.isEmpty {
                mentionListView
            }

            HStack(spacing: 12) {
                TextField(placeholder, text: $text, axis: .vertical)
                    .focused(isInputFocused)
                    .lineLimit(1...5)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AppTheme.agentBubbleColor)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .onChange(of: text) { _, newValue in
                        showMentionList = shouldShowMentions
                    }

                Button(action: {
                    guard !trimmedText.isEmpty else { return }
                    onSend()
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(
                            trimmedText.isEmpty
                                ? Color.gray.opacity(0.4)
                                : AppTheme.primaryColor
                        )
                        .scaleEffect(trimmedText.isEmpty ? 0.9 : 1.0)
                        .animation(.spring(duration: 0.25), value: trimmedText.isEmpty)
                }
                .disabled(trimmedText.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(AppTheme.cardBackground)
    }

    private var mentionListView: some View {
        VStack(spacing: 0) {
            Divider()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(mentionCandidates) { user in
                        Button {
                            insertMention(user)
                        } label: {
                            HStack(spacing: 6) {
                                AvatarView(
                                    imageData: user.avatarImageData,
                                    emoji: user.avatarEmoji,
                                    size: 28,
                                    backgroundColor: user.isAgent ? AppTheme.agentColor.opacity(0.12) : AppTheme.primaryColor.opacity(0.08)
                                )
                                Text(user.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                if user.isAgent {
                                    Text("AI")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(AppTheme.agentColor)
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppTheme.agentBubbleColor)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func insertMention(_ user: User) {
        // 替换最后一个 @ 及其后的内容为 @name + 空格
        if let lastAt = text.lastIndex(of: "@") {
            text = String(text[..<lastAt]) + "@\(user.name) "
        } else {
            text += "@\(user.name) "
        }
        showMentionList = false
    }
}
