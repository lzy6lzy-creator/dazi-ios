import SwiftUI

struct AgentChatView: View {
    @Environment(DataStore.self) private var dataStore
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    private let suggestedPrompts = [
        "周末想看电影", "找人一起吃饭", "想去徒步",
        "约个咖啡", "找人打球",
    ]

    private var isNewUser: Bool {
        dataStore.agentMessages.count <= 1
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messageList
                if isNewUser {
                    promptChips
                }
                ChatInputBar(text: $inputText, isInputFocused: $isInputFocused, placeholder: "告诉点点你想做什么...") {
                    sendMessage()
                }
            }
            .background(AppTheme.backgroundColor)
            .onTapGesture {
                isInputFocused = false
            }
            .navigationTitle("点点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        AvatarView(
                            imageData: dataStore.currentUser.agentAvatarImageData,
                            emoji: dataStore.currentUser.agentEmoji,
                            size: 26,
                            backgroundColor: AppTheme.agentColor.opacity(0.12)
                        )
                        Text(dataStore.currentUser.agentName)
                            .font(.headline)
                        Text("你的个人助理")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(dataStore.agentMessages.enumerated()), id: \.element.id) { index, message in
                        if index == 0 || !Calendar.current.isDate(message.timestamp, inSameDayAs: dataStore.agentMessages[index - 1].timestamp) {
                            DateSeparator(date: message.timestamp)
                        }
                        MessageBubbleView(
                            message: message,
                            onConfirm: message.showConfirmButtons ? {
                                confirmDraft(messageId: message.id)
                            } : nil,
                            onSubmitClarification: { messageId, answers, freeText in
                                dataStore.submitClarification(
                                    messageId: messageId,
                                    answers: answers,
                                    freeText: freeText
                                )
                            }
                        )
                            .id(message.id)
                    }
                }
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: dataStore.agentMessages.count) {
                withAnimation(.easeOut(duration: 0.3)) {
                    if let lastId = dataStore.agentMessages.last?.id {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var promptChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestedPrompts, id: \.self) { prompt in
                    Button {
                        dataStore.sendMessageToAgent(prompt)
                    } label: {
                        Text(prompt)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(AppTheme.primaryColor)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(AppTheme.primaryColor.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        dataStore.sendMessageToAgent(text)
    }

    private func confirmDraft(messageId: String) {
        if let idx = dataStore.agentMessages.firstIndex(where: { $0.id == messageId }) {
            dataStore.agentMessages[idx].confirmButtonsTapped = true
        }
        dataStore.sendMessageToAgent("确认")
    }
}
