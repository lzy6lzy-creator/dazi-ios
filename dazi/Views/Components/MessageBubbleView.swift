import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    var showAvatar: Bool = true
    var onConfirm: (() -> Void)?
    var onSubmitClarification: ((String, [ClarificationAnswerInput], String?) -> Void)?

    @State private var selectedOptionIds: [String: Set<String>] = [:]
    @State private var customValues: [String: String] = [:]
    @State private var minAgeValues: [String: String] = [:]
    @State private var maxAgeValues: [String: String] = [:]

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

                if !message.clarificationQuestions.isEmpty {
                    clarificationCards
                }

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

    private var clarificationCards: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(message.clarificationQuestions) { question in
                clarificationQuestionCard(question)
            }

            Button {
                submitClarification()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: message.clarificationSubmitted ? "checkmark.circle.fill" : "arrow.up.circle.fill")
                    Text(message.clarificationSubmitted ? "已提交" : "提交补充")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .padding(.vertical, 11)
                .background(canSubmitClarification ? AppTheme.primaryColor : Color.gray.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMD))
            }
            .disabled(!canSubmitClarification)
        }
        .padding(12)
        .frame(maxWidth: 310, alignment: .leading)
        .background(AppTheme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLG)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
        .padding(.top, 6)
    }

    private func clarificationQuestionCard(_ question: ClarificationQuestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let category = question.category, !category.isEmpty {
                    Text(category)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.primaryColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(AppTheme.primaryColor.opacity(0.10))
                        .clipShape(Capsule())
                }
                if question.matchFilter == "hard_filter" {
                    Text("硬条件")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.red.opacity(0.08))
                        .clipShape(Capsule())
                }
            }

            Text(question.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if let helperText = question.helperText, !helperText.isEmpty {
                Text(helperText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            FlowLayout(spacing: 8) {
                ForEach(question.options) { option in
                    clarificationOptionButton(question: question, option: option)
                }
            }

            if question.allowCustom {
                if question.type == "age_range" {
                    ageCustomFields(question)
                } else {
                    TextField("自己输入", text: binding(for: question.id, in: $customValues))
                        .font(.subheadline)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                        .frame(minHeight: 44)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSM))
                }
            }
        }
        .padding(10)
        .background(Color(.systemBackground).opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMD))
    }

    private func clarificationOptionButton(
        question: ClarificationQuestion,
        option: ClarificationOption
    ) -> some View {
        let selected = selectedOptionIds[question.id]?.contains(option.id) == true
        return Button {
            toggleOption(question: question, optionId: option.id)
        } label: {
            Text(option.label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(selected ? .white : .primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .frame(minHeight: 44)
                .background(selected ? AppTheme.primaryColor : Color(.secondarySystemFill))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(message.clarificationSubmitted)
    }

    private func ageCustomFields(_ question: ClarificationQuestion) -> some View {
        HStack(spacing: 8) {
            TextField("最小", text: binding(for: question.id, in: $minAgeValues))
                .keyboardType(.numberPad)
            Text("到")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("最大", text: binding(for: question.id, in: $maxAgeValues))
                .keyboardType(.numberPad)
            Text("岁")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .textFieldStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(minHeight: 44)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSM))
    }

    private func binding(
        for questionId: String,
        in state: Binding<[String: String]>
    ) -> Binding<String> {
        Binding {
            state.wrappedValue[questionId] ?? ""
        } set: { newValue in
            state.wrappedValue[questionId] = newValue
        }
    }

    private func toggleOption(question: ClarificationQuestion, optionId: String) {
        guard !message.clarificationSubmitted else { return }
        var selected = selectedOptionIds[question.id] ?? []
        if question.type == "multi_choice" {
            if selected.contains(optionId) {
                selected.remove(optionId)
            } else {
                selected.insert(optionId)
            }
        } else {
            selected = [optionId]
        }
        selectedOptionIds[question.id] = selected
    }

    private var canSubmitClarification: Bool {
        guard !message.clarificationSubmitted else { return false }
        let hasAnyAnswer = message.clarificationQuestions.contains { hasAnswer(for: $0) }
        let requiredAnswered = message.clarificationQuestions.allSatisfy { question in
            !question.required || hasAnswer(for: question)
        }
        return hasAnyAnswer && requiredAnswered
    }

    private func hasAnswer(for question: ClarificationQuestion) -> Bool {
        if selectedOptionIds[question.id]?.isEmpty == false {
            return true
        }
        if question.type == "age_range" {
            return Int(minAgeValues[question.id] ?? "") != nil && Int(maxAgeValues[question.id] ?? "") != nil
        }
        return !(customValues[question.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submitClarification() {
        let answers = message.clarificationQuestions.compactMap { answer(for: $0) }
        guard !answers.isEmpty else { return }
        onSubmitClarification?(message.id, answers, nil)
    }

    private func answer(for question: ClarificationQuestion) -> ClarificationAnswerInput? {
        let optionIds = Array(selectedOptionIds[question.id] ?? [])
        if question.type == "age_range" {
            let minAge = Int(minAgeValues[question.id] ?? "")
            let maxAge = Int(maxAgeValues[question.id] ?? "")
            if optionIds.isEmpty && (minAge == nil || maxAge == nil) {
                return nil
            }
            return ClarificationAnswerInput(
                questionId: question.id,
                optionIds: optionIds,
                minAge: minAge,
                maxAge: maxAge
            )
        }

        let customText = customValues[question.id]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if optionIds.isEmpty && (customText ?? "").isEmpty {
            return nil
        }
        return ClarificationAnswerInput(
            questionId: question.id,
            optionIds: optionIds,
            customText: customText
        )
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
