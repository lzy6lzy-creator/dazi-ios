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
    @State private var expandedCustomQuestionIds: Set<String> = []
    @State private var startTimeValues: [String: Date] = [:]
    @State private var endTimeValues: [String: Date] = [:]

    private var isFromUser: Bool {
        message.role == .user
    }

    private var isPublishingStatus: Bool {
        message.role == .agent && message.content == Message.publishingContent
    }

    private var isAgentSessionDivider: Bool {
        message.role == .system && message.content.contains("下面为你开启新的对话")
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

    @ViewBuilder
    private var systemBubble: some View {
        if isAgentSessionDivider {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.22))
                    .frame(height: 1)
                Text(message.content)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Rectangle()
                    .fill(Color.secondary.opacity(0.22))
                    .frame(height: 1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        } else {
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

                Group {
                    if isPublishingStatus {
                        HStack(spacing: 10) {
                            Text(message.content)
                                .font(.body)
                                .foregroundStyle(textColor)
                            TypingIndicator()
                        }
                    } else {
                        Text(message.content)
                            .font(.body)
                            .foregroundStyle(textColor)
                    }
                }
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
        VStack(alignment: .leading, spacing: 8) {
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("活动确认")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(message.clarificationQuestions.count) 项")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)

                Divider()

                ForEach(Array(message.clarificationQuestions.enumerated()), id: \.element.id) { index, question in
                    clarificationQuestionRow(question)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    if index < message.clarificationQuestions.count - 1 {
                        Divider()
                            .padding(.leading, 10)
                    }
                }
            }
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusSM)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSM))
            .animation(.snappy(duration: 0.22), value: message.clarificationQuestions.count)

            HStack {
                Spacer()
                Button {
                    submitClarification()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark")
                            .font(.caption2)
                        Text(message.clarificationSubmitted ? "已提交" : "确认")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(minHeight: 34)
                    .background(canSubmitClarification ? AppTheme.primaryColor : Color.gray.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(!canSubmitClarification)
            }
        }
        .padding(10)
        .frame(maxWidth: 304, alignment: .leading)
        .background(AppTheme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMD)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMD))
        .padding(.top, 6)
        .onAppear {
            seedDefaultClarificationSelections()
        }
        .onChange(of: message.id) { _, _ in
            resetClarificationInputs()
        }
        .onChange(of: message.clarificationQuestions.map(\.id)) { _, _ in
            seedDefaultClarificationSelections()
        }
    }

    private func clarificationQuestionRow(_ question: ClarificationQuestion) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Text(questionSectionTitle(question))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

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
                Spacer(minLength: 0)
            }

            if shouldShowQuestionTitle(question) {
                Text(question.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if isTimeQuestion(question) {
                timeRangeFields(question)
            } else if isAgeQuestion(question) {
                ageRangeSliderFields(question)
            } else if isGenderQuestion(question) {
                horizontalOptionScroller(question, showsCustomInput: false)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(question.options) { option in
                        clarificationOptionButton(question: question, option: option)
                    }
                    if question.allowCustom {
                        customInputToggleButton(question)
                    }
                }
            }

            if !isTimeQuestion(question),
               !isAgeQuestion(question),
               !isGenderQuestion(question),
               expandedCustomQuestionIds.contains(question.id) {
                TextField(customInputPlaceholder(for: question), text: binding(for: question.id, in: $customValues))
                    .font(.subheadline)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(minHeight: 44)
                    .background(Color(.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.radiusSM)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSM))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
    }

    private func clarificationOptionButton(
        question: ClarificationQuestion,
        option: ClarificationOption
    ) -> some View {
        let selected = selectedOptionIds[question.id]?.contains(option.id) == true
        let location = isLocationQuestion(question)
        let selectedColor = location ? Color(red: 0.08, green: 0.48, blue: 0.52) : AppTheme.primaryColor
        let selectedBackground = selectedColor.opacity(0.12)
        let normalBackground = Color(.secondarySystemGroupedBackground)
        let borderColor = selected ? selectedColor : Color.black.opacity(0.10)
        return Button {
            toggleOption(question: question, optionId: option.id)
        } label: {
            Text(option.label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(selected ? selectedColor : .primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .frame(minHeight: 34)
                .background(selected ? selectedBackground : normalBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(message.clarificationSubmitted)
    }

    private func horizontalOptionScroller(
        _ question: ClarificationQuestion,
        showsCustomInput: Bool = true
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(question.options) { option in
                    clarificationOptionButton(question: question, option: option)
                }
                if showsCustomInput && question.allowCustom {
                    customInputToggleButton(question)
                }
            }
            .padding(.vertical, 1)
        }
    }

    private func timeRangeFields(_ question: ClarificationQuestion) -> some View {
        VStack(spacing: 8) {
            timePickerBox(
                title: "开始",
                selection: startTimeBinding(for: question),
                question: question
            )
            timePickerBox(
                title: "结束",
                selection: endTimeBinding(for: question),
                question: question
            )
        }
    }

    private func timePickerBox(
        title: String,
        selection: Binding<Date>,
        question: ClarificationQuestion
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)

            DatePicker(
                title,
                selection: selection,
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .environment(\.locale, AppLocale.chinese)
            .environment(\.calendar, AppLocale.chineseCalendar)
            .disabled(message.clarificationSubmitted)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minHeight: 48)
        .background(Color(.secondarySystemGroupedBackground))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusSM)
                .stroke(AppTheme.primaryColor.opacity(0.20), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSM))
        .onAppear {
            seedDefaultTimeValues(for: question)
        }
    }

    private func customInputToggleButton(_ question: ClarificationQuestion) -> some View {
        let expanded = expandedCustomQuestionIds.contains(question.id)
        return Button {
            toggleCustomInput(for: question)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: expanded ? "minus" : "plus")
                    .font(.caption2)
                Text(expanded ? "收起手动输入" : "手动输入")
            }
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(AppTheme.secondaryColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(minHeight: 34)
            .background(AppTheme.secondaryColor.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        AppTheme.secondaryColor.opacity(0.45),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(message.clarificationSubmitted)
    }

    private func ageRangeSliderFields(_ question: ClarificationQuestion) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            horizontalOptionScroller(question, showsCustomInput: false)

            if isAgeUnlimitedSelected(question) {
                Text("不限年龄")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSM))
            } else {
                let range = ageRange(for: question) ?? defaultAgeRange(for: question)
                HStack {
                    Text("年龄范围")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(range.min)-\(range.max) 岁")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.primaryColor)
                }
                .padding(.horizontal, 2)

                VStack(spacing: 10) {
                    ageSliderRow(
                        title: "下限",
                        valueText: "\(range.min) 岁",
                        selection: minAgeBinding(for: question),
                        bounds: Self.ageSliderBounds(lower: Self.minimumAllowedAge, upper: range.max - 1)
                    )
                    ageSliderRow(
                        title: "上限",
                        valueText: "\(range.max) 岁",
                        selection: maxAgeBinding(for: question),
                        bounds: Self.ageSliderBounds(lower: range.min + 1, upper: Self.maximumAllowedAge)
                    )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusSM)
                        .stroke(AppTheme.primaryColor.opacity(0.18), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSM))
            }
        }
        .onAppear {
            seedDefaultAgeValues(for: question)
        }
    }

    private func ageSliderRow(
        title: String,
        valueText: String,
        selection: Binding<Double>,
        bounds: ClosedRange<Double>?
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)

            if let bounds, bounds.upperBound > bounds.lowerBound {
                Slider(value: selection, in: bounds, step: 1)
                    .tint(AppTheme.primaryColor)
                    .disabled(message.clarificationSubmitted)
            } else {
                Capsule()
                    .fill(Color.secondary.opacity(0.20))
                    .frame(height: 4)
            }

            Text(valueText)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .frame(width: 44, alignment: .trailing)
        }
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

    private func seedDefaultClarificationSelections() {
        for question in message.clarificationQuestions {
            if selectedOptionIds[question.id] == nil {
                let optionIds = Set(question.options.map(\.id))
                let defaults = Set(question.defaultOptionIds.filter { optionIds.contains($0) })
                if !defaults.isEmpty {
                    selectedOptionIds[question.id] = defaults
                }
            }
            if isTimeQuestion(question) {
                seedDefaultTimeValues(for: question)
            }
            if isAgeQuestion(question) {
                seedDefaultAgeValues(for: question)
            }
        }
    }

    private func resetClarificationInputs() {
        selectedOptionIds = [:]
        customValues = [:]
        minAgeValues = [:]
        maxAgeValues = [:]
        expandedCustomQuestionIds = []
        startTimeValues = [:]
        endTimeValues = [:]
        seedDefaultClarificationSelections()
    }

    private func toggleCustomInput(for question: ClarificationQuestion) {
        if expandedCustomQuestionIds.contains(question.id) {
            expandedCustomQuestionIds.remove(question.id)
            customValues[question.id] = nil
            minAgeValues[question.id] = nil
            maxAgeValues[question.id] = nil
        } else {
            expandedCustomQuestionIds.insert(question.id)
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
        if isTimeQuestion(question) {
            seedDefaultTimeValues(for: question, force: true)
        }
        if isAgeQuestion(question) {
            if isAgeUnlimitedSelected(question) {
                minAgeValues[question.id] = nil
                maxAgeValues[question.id] = nil
            } else {
                seedDefaultAgeValues(for: question, force: true)
            }
        }
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
        if isAgeQuestion(question) {
            return isAgeUnlimitedSelected(question) || ageRange(for: question) != nil
        }
        if selectedOptionIds[question.id]?.isEmpty == false {
            return true
        }
        if isTimeQuestion(question) {
            return timeRange(for: question) != nil
        }
        return !(customValues[question.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func questionSectionTitle(_ question: ClarificationQuestion) -> String {
        let id = question.id.lowercased()
        if ["event", "activity", "activity_type"].contains(id) { return "活动" }
        if id == "time" { return "时间" }
        if isLocationQuestion(question) { return "地点" }
        if isGenderQuestion(question) { return "搭子偏好" }
        if ["preferences", "preference"].contains(id) { return "特殊偏好" }
        if isAgeQuestion(question) { return "年龄" }
        if let category = question.category, !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return category
        }
        return question.title
    }

    private func isTimeQuestion(_ question: ClarificationQuestion) -> Bool {
        question.id.lowercased() == "time"
    }

    private func isAgeQuestion(_ question: ClarificationQuestion) -> Bool {
        let id = question.id.lowercased()
        return question.type == "age_range" || ["age", "age_range", "partner_age"].contains(id)
    }

    private func isGenderQuestion(_ question: ClarificationQuestion) -> Bool {
        ["gender", "sex", "partner_gender"].contains(question.id.lowercased())
    }

    private func shouldShowQuestionTitle(_ question: ClarificationQuestion) -> Bool {
        let id = question.id.lowercased()
        let coreIds = [
            "event",
            "activity",
            "activity_type",
            "time",
            "location",
            "area",
            "gender",
            "sex",
            "partner_gender",
            "age",
            "age_range",
            "partner_age",
            "preferences",
            "preference",
        ]
        return !coreIds.contains(id)
    }

    private func isLocationQuestion(_ question: ClarificationQuestion) -> Bool {
        let id = question.id.lowercased()
        if ["location", "area", "place", "district", "region"].contains(id) {
            return true
        }
        let text = "\(question.category ?? "") \(question.title)"
        return ["地点", "位置", "城市", "区域", "哪片区", "哪里", "在哪"].contains { text.contains($0) }
    }

    private func customInputPlaceholder(for question: ClarificationQuestion) -> String {
        if isLocationQuestion(question) {
            return "输入商圈、影院或地址"
        }
        let id = question.id.lowercased()
        if id == "time" {
            return "输入具体时间"
        }
        if ["event", "activity", "activity_type"].contains(id) {
            return "输入活动内容"
        }
        return "自己输入"
    }

    private func startTimeBinding(for question: ClarificationQuestion) -> Binding<Date> {
        Binding {
            timeRange(for: question)?.start ?? Date()
        } set: { newValue in
            startTimeValues[question.id] = newValue
            let currentEnd = endTimeValues[question.id] ?? timeRange(for: question)?.end ?? newValue.addingTimeInterval(2 * 3600)
            if currentEnd <= newValue {
                endTimeValues[question.id] = newValue.addingTimeInterval(2 * 3600)
            }
        }
    }

    private func endTimeBinding(for question: ClarificationQuestion) -> Binding<Date> {
        Binding {
            timeRange(for: question)?.end ?? Date().addingTimeInterval(2 * 3600)
        } set: { newValue in
            let currentStart = startTimeValues[question.id] ?? timeRange(for: question)?.start ?? Date()
            endTimeValues[question.id] = newValue > currentStart ? newValue : currentStart.addingTimeInterval(3600)
        }
    }

    private func seedDefaultTimeValues(for question: ClarificationQuestion, force: Bool = false) {
        guard isTimeQuestion(question), let range = defaultTimeRange(for: question) else { return }
        if force || startTimeValues[question.id] == nil {
            startTimeValues[question.id] = range.start
        }
        if force || endTimeValues[question.id] == nil {
            endTimeValues[question.id] = range.end
        }
    }

    private func timeRange(for question: ClarificationQuestion) -> (start: Date, end: Date)? {
        let fallback = defaultTimeRange(for: question)
        let start = startTimeValues[question.id] ?? fallback?.start
        let end = endTimeValues[question.id] ?? fallback?.end
        guard let start, let end else { return nil }
        if end <= start {
            return (start, start.addingTimeInterval(3600))
        }
        return (start, end)
    }

    private func defaultTimeRange(for question: ClarificationQuestion) -> (start: Date, end: Date)? {
        let selectedIds = selectedOptionIds[question.id] ?? Set(question.defaultOptionIds)
        let candidateOptions = question.options.filter { selectedIds.contains($0.id) } + question.options
        for option in candidateOptions {
            guard let startText = option.value?.startTime,
                  let endText = option.value?.endTime,
                  let start = Self.parseClarificationDate(startText),
                  let end = Self.parseClarificationDate(endText) else {
                continue
            }
            return (start, end > start ? end : start.addingTimeInterval(3600))
        }
        return nil
    }

    private func seedDefaultAgeValues(for question: ClarificationQuestion, force: Bool = false) {
        guard isAgeQuestion(question), !isAgeUnlimitedSelected(question) else { return }
        let range = defaultAgeRange(for: question)
        if force || minAgeValues[question.id] == nil {
            minAgeValues[question.id] = "\(range.min)"
        }
        if force || maxAgeValues[question.id] == nil {
            maxAgeValues[question.id] = "\(range.max)"
        }
    }

    private func ageRange(for question: ClarificationQuestion) -> (min: Int, max: Int)? {
        guard isAgeQuestion(question), !isAgeUnlimitedSelected(question) else { return nil }
        let fallback = defaultAgeRange(for: question)
        let rawMin = Int(minAgeValues[question.id] ?? "") ?? fallback.min
        let rawMax = Int(maxAgeValues[question.id] ?? "") ?? fallback.max
        return Self.normalizedAgeRange(min: rawMin, max: rawMax)
    }

    private func defaultAgeRange(for question: ClarificationQuestion) -> (min: Int, max: Int) {
        let radius = max(selectedAgeRadius(for: question) ?? 5, 1)
        let baseAge = Self.clampedAge(User.currentUser.age ?? 25)
        let minAge = max(baseAge - radius, Self.minimumAllowedAge)
        let maxAge = min(baseAge + radius, Self.maximumAllowedAge)
        return Self.normalizedAgeRange(min: minAge, max: maxAge)
    }

    private func selectedAgeRadius(for question: ClarificationQuestion) -> Int? {
        let selectedIds = selectedOptionIds[question.id] ?? Set(question.defaultOptionIds)
        let selectedOptions = question.options.filter { selectedIds.contains($0.id) }
        let candidateOptions = selectedOptions.isEmpty ? question.options : selectedOptions
        for option in candidateOptions {
            if isUnlimitedAgeOption(option) {
                continue
            }
            if let range = option.value?.range, range > 0 {
                return range
            }
            if let range = Self.ageRadius(from: option.label) {
                return range
            }
        }
        return nil
    }

    private func minAgeBinding(for question: ClarificationQuestion) -> Binding<Double> {
        Binding {
            Double(ageRange(for: question)?.min ?? defaultAgeRange(for: question).min)
        } set: { newValue in
            let currentMax = ageRange(for: question)?.max ?? defaultAgeRange(for: question).max
            let upperBound = max(currentMax - 1, Self.minimumAllowedAge)
            let value = min(Self.clampedAge(Int(newValue.rounded())), upperBound)
            minAgeValues[question.id] = "\(value)"
        }
    }

    private func maxAgeBinding(for question: ClarificationQuestion) -> Binding<Double> {
        Binding {
            Double(ageRange(for: question)?.max ?? defaultAgeRange(for: question).max)
        } set: { newValue in
            let currentMin = ageRange(for: question)?.min ?? defaultAgeRange(for: question).min
            let lowerBound = min(currentMin + 1, Self.maximumAllowedAge)
            let value = max(Self.clampedAge(Int(newValue.rounded())), lowerBound)
            maxAgeValues[question.id] = "\(value)"
        }
    }

    private func isAgeUnlimitedSelected(_ question: ClarificationQuestion) -> Bool {
        let selectedIds = selectedOptionIds[question.id] ?? Set(question.defaultOptionIds)
        return question.options.contains { option in
            selectedIds.contains(option.id) && isUnlimitedAgeOption(option)
        }
    }

    private func isUnlimitedAgeOption(_ option: ClarificationOption) -> Bool {
        let text = "\(option.id) \(option.label)".lowercased()
        return text.contains("unlimited") || text.contains("any") || option.label.contains("不限")
    }

    private func submitClarification() {
        let answers = message.clarificationQuestions.compactMap { answer(for: $0) }
        guard !answers.isEmpty else { return }
        onSubmitClarification?(message.id, answers, nil)
    }

    private func answer(for question: ClarificationQuestion) -> ClarificationAnswerInput? {
        let optionIds = Array(selectedOptionIds[question.id] ?? [])
        if isTimeQuestion(question), let range = timeRange(for: question) {
            return ClarificationAnswerInput(
                questionId: question.id,
                optionIds: optionIds,
                customValue: [
                    "start_time": Self.isoFormatter.string(from: range.start),
                    "end_time": Self.isoFormatter.string(from: range.end),
                ]
            )
        }
        if isAgeQuestion(question) {
            if isAgeUnlimitedSelected(question) {
                return ClarificationAnswerInput(questionId: question.id, optionIds: optionIds)
            }
            guard let range = ageRange(for: question) else {
                return nil
            }
            return ClarificationAnswerInput(
                questionId: question.id,
                optionIds: optionIds,
                minAge: range.min,
                maxAge: range.max
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

    private static let minimumAllowedAge = 18
    private static let maximumAllowedAge = 80

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let fractionalIsoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static func parseClarificationDate(_ value: String) -> Date? {
        isoFormatter.date(from: value) ?? fractionalIsoFormatter.date(from: value)
    }

    private static func clampedAge(_ value: Int) -> Int {
        min(max(value, minimumAllowedAge), maximumAllowedAge)
    }

    private static func normalizedAgeRange(min rawMin: Int, max rawMax: Int) -> (min: Int, max: Int) {
        var minAge = clampedAge(rawMin)
        var maxAge = clampedAge(rawMax)
        if minAge > maxAge {
            swap(&minAge, &maxAge)
        }
        if minAge == maxAge {
            if maxAge < maximumAllowedAge {
                maxAge += 1
            } else if minAge > minimumAllowedAge {
                minAge -= 1
            }
        }
        return (minAge, maxAge)
    }

    private static func ageSliderBounds(lower: Int, upper: Int) -> ClosedRange<Double>? {
        guard upper > lower else { return nil }
        return Double(lower)...Double(upper)
    }

    private static func ageRadius(from label: String) -> Int? {
        let parts = label.split { !$0.isNumber }
        return parts.compactMap { Int($0) }.first
    }

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
