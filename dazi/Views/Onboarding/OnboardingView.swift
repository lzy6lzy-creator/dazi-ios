import SwiftUI
import PhotosUI

struct OnboardingView: View {
    @Environment(DataStore.self) private var dataStore
    var onComplete: () -> Void

    @State private var step: OnboardingStep = .name
    @State private var name = ""
    @State private var avatarEmoji = "😊"
    @State private var avatarImageData: Data?
    @State private var gender = ""
    @State private var birthYear = 2000
    @State private var selectedInterests: Set<String> = []
    @State private var customInterests = ""
    @State private var occupation = ""
    @State private var welcomeDisturb = false
    @State private var bio = ""
    @State private var agentName = ""
    @State private var agentEmoji = "🤖"
    @State private var agentAvatarImageData: Data?
    @State private var agentPersonality = "贴心、有趣"
    @State private var isAnimating = false

    enum OnboardingStep: Int, CaseIterable {
        case name, avatar, gender, birthYear, occupation, interests, bio, agentSetup, ready
    }

    private static let userAvatarOptions = [
        "😊", "😎", "🤗", "🥰", "😄", "🤓",
        "🦊", "🐱", "🐶", "🐼", "🦁", "🐨",
        "🌟", "🌈", "🔥", "💎", "🎵", "🎮",
    ]

    private static let agentAvatarOptions = [
        "🤖", "✨", "🔮", "🧠", "💡", "🌟",
        "🦄", "🐙", "🎯", "🫧", "⚡", "🍀",
    ]

    private static let personalityOptions = [
        "贴心、有趣", "理性、高效", "幽默、搞怪",
        "温柔、细心", "直爽、干脆", "可爱、活泼",
    ]

    var body: some View {
        ZStack {
            AppTheme.backgroundColor.ignoresSafeArea()

            VStack(spacing: 0) {
                if step != .ready {
                    progressBar
                }

                Spacer()

                Group {
                    switch step {
                    case .name: nameStep
                    case .avatar: avatarStep
                    case .gender: genderStep
                    case .birthYear: birthYearStep
                    case .occupation: occupationStep
                    case .interests: interestsStep
                    case .bio: bioStep
                    case .agentSetup: agentSetupStep
                    case .ready: readyStep
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                Spacer()

                if step != .ready {
                    navigationButtons
                }
            }
            .padding()
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
        .onAppear { isAnimating = true }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        let totalSteps = OnboardingStep.allCases.count - 2
        let currentStep = step.rawValue
        let progress = Double(currentStep) / Double(totalSteps)

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 6)

                RoundedRectangle(cornerRadius: 3)
                    .fill(AppTheme.primaryColor)
                    .frame(width: geo.size.width * progress, height: 6)
                    .animation(.spring(duration: 0.4), value: progress)
            }
        }
        .frame(height: 6)
        .padding(.top, 8)
        .padding(.bottom, 20)
    }

    // MARK: - Steps

    private var nameStep: some View {
        VStack(spacing: 16) {
            stepHeader(title: "你叫什么名字？", subtitle: "搭子们会看到这个名字", icon: "person.text.rectangle")

            TextField("输入你的昵称", text: $name)
                .font(.title2)
                .multilineTextAlignment(.center)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
        }
    }

    private var avatarStep: some View {
        VStack(spacing: 16) {
            stepHeader(title: "选个头像吧", subtitle: "可以从相册上传，也可以选择 Emoji", icon: "photo.circle")

            AvatarPickerView(
                imageData: $avatarImageData,
                emoji: $avatarEmoji,
                emojiOptions: Self.userAvatarOptions,
                size: 100,
                accentColor: AppTheme.primaryColor
            )
        }
    }

    private var genderStep: some View {
        VStack(spacing: 16) {
            stepHeader(title: "你的性别", subtitle: "帮助我们更好地匹配", icon: "figure.stand")

            HStack(spacing: 16) {
                genderButton(label: "男", value: "男", icon: "figure.stand")
                genderButton(label: "女", value: "女", icon: "figure.stand.dress")
                genderButton(label: "保密", value: "保密", icon: "questionmark")
            }
        }
    }

    private func genderButton(label: String, value: String, icon: String) -> some View {
        Button {
            gender = value
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title)
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundStyle(gender == value ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(gender == value ? AppTheme.primaryColor : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
        }
    }

    private var birthYearStep: some View {
        VStack(spacing: 16) {
            stepHeader(title: "出生年份", subtitle: "我们不会公开显示你的年龄", icon: "calendar.badge.clock")

            Picker("出生年份", selection: $birthYear) {
                ForEach(1970...2010, id: \.self) { year in
                    Text("\(String(year))年").tag(year)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 150)
        }
    }

    private var occupationStep: some View {
        VStack(spacing: 16) {
            stepHeader(title: "你的职业", subtitle: "可选，帮助更精准匹配", icon: "briefcase")

            TextField("例如：产品经理、设计师、学生", text: $occupation)
                .font(.body)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
        }
    }

    private var interestsStep: some View {
        let allInterests = [
            "电影", "徒步", "美食", "看展", "咖啡",
            "桌游", "摄影", "演出", "运动", "阅读",
            "旅行", "音乐", "烹饪", "骑行", "瑜伽",
        ]

        return VStack(spacing: 16) {
            stepHeader(title: "你喜欢什么？", subtitle: "选择你感兴趣的活动（至少1个）", icon: "heart.text.square")

            FlowLayout(spacing: 10) {
                ForEach(allInterests, id: \.self) { interest in
                    interestChip(interest)
                }
            }

            TextField("补充其他爱好（可选）", text: $customInterests)
                .font(.subheadline)
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMD))

            Toggle(isOn: $welcomeDisturb) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("欢迎打扰")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("开启后，即使你没有发布活动，也可能被匹配到")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(AppTheme.primaryColor)
        }
    }

    private func interestChip(_ interest: String) -> some View {
        let isSelected = selectedInterests.contains(interest)
        return Button {
            if isSelected {
                selectedInterests.remove(interest)
            } else {
                selectedInterests.insert(interest)
            }
        } label: {
            Text(interest)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? AppTheme.primaryColor : Color(.systemGray6))
                .clipShape(Capsule())
        }
    }

    private var bioStep: some View {
        VStack(spacing: 16) {
            stepHeader(title: "一句话介绍自己", subtitle: "可选，让搭子更了解你", icon: "text.quote")

            TextField("例如：喜欢探索城市的新居民", text: $bio)
                .font(.body)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
        }
    }

    private var agentSetupStep: some View {
        VStack(spacing: 20) {
            stepHeader(title: "设置你的私人 Agent", subtitle: "它会代表你去匹配搭子", icon: "brain.head.profile")

            VStack(alignment: .leading, spacing: 4) {
                Text("Agent 名字")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("给你的 Agent 起个名字", text: $agentName)
                    .font(.body)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMD))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Agent 头像")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                AvatarPickerView(
                    imageData: $agentAvatarImageData,
                    emoji: $agentEmoji,
                    emojiOptions: Self.agentAvatarOptions,
                    size: 80,
                    accentColor: AppTheme.agentColor
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Agent 性格")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                FlowLayout(spacing: 8) {
                    ForEach(Self.personalityOptions, id: \.self) { p in
                        Button {
                            agentPersonality = p
                        } label: {
                            Text(p)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(agentPersonality == p ? .white : .primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(agentPersonality == p ? AppTheme.agentColor : Color(.systemGray6))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    private var readyStep: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    AvatarView(
                        imageData: avatarImageData,
                        emoji: avatarEmoji,
                        size: 64,
                        backgroundColor: AppTheme.primaryColor.opacity(0.1)
                    )
                    Text(name)
                        .font(.caption)
                        .fontWeight(.medium)
                }

                Image(systemName: "plus")
                    .foregroundStyle(.secondary)

                VStack(spacing: 4) {
                    AvatarView(
                        imageData: agentAvatarImageData,
                        emoji: agentEmoji,
                        size: 64,
                        backgroundColor: AppTheme.agentColor.opacity(0.15)
                    )
                    HStack(spacing: 2) {
                        Text(agentName.isEmpty ? "点点" : agentName)
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("AI")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(AppTheme.agentColor)
                            .clipShape(Capsule())
                    }
                }
            }

            Text("准备就绪！")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 6) {
                profileRow(label: "昵称", value: name)
                if avatarImageData != nil {
                    profileRow(label: "头像", value: "📷 自定义图片")
                } else {
                    profileRow(label: "头像", value: avatarEmoji)
                }
                if !gender.isEmpty { profileRow(label: "性别", value: gender) }
                profileRow(label: "出生年份", value: "\(birthYear)")
                profileRow(label: "兴趣", value: Array(selectedInterests).joined(separator: "、"))
                if !bio.isEmpty { profileRow(label: "简介", value: bio) }
                Divider().padding(.vertical, 4)
                if agentAvatarImageData != nil {
                    profileRow(label: "Agent", value: "📷 \(agentName.isEmpty ? "点点" : agentName)")
                } else {
                    profileRow(label: "Agent", value: "\(agentEmoji) \(agentName.isEmpty ? "点点" : agentName)")
                }
                profileRow(label: "性格", value: agentPersonality)
            }
            .padding()
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))

            Button {
                completeRegistration()
            } label: {
                Text("开始找搭子")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.primaryColor)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private func profileRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.subheadline)
        }
    }

    // MARK: - Navigation

    private var navigationButtons: some View {
        HStack {
            if step.rawValue > OnboardingStep.name.rawValue {
                Button("上一步") {
                    withAnimation {
                        if let prev = OnboardingStep(rawValue: step.rawValue - 1) {
                            step = prev
                        }
                    }
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                withAnimation {
                    if let next = OnboardingStep(rawValue: step.rawValue + 1) {
                        step = next
                    }
                }
            } label: {
                Text(step == .agentSetup ? "完成" : "下一步")
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(canProceed ? AppTheme.primaryColor : Color.gray)
                    .clipShape(Capsule())
            }
            .disabled(!canProceed)
        }
        .padding(.bottom, 8)
    }

    private var canProceed: Bool {
        switch step {
        case .name: return name.trimmingCharacters(in: .whitespaces).count >= 1
        case .avatar: return true
        case .gender: return !gender.isEmpty
        case .birthYear: return true
        case .occupation: return true
        case .interests: return !selectedInterests.isEmpty
        case .bio: return true
        case .agentSetup: return true
        default: return true
        }
    }

    // MARK: - Helpers

    private func stepHeader(title: String, subtitle: String, icon: String) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: AppTheme.spacingSM) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(AppTheme.primaryColor)
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @State private var isRegistering = false

    private func completeRegistration() {
        guard !isRegistering else { return }
        isRegistering = true

        let finalAgentName = agentName.trimmingCharacters(in: .whitespaces).isEmpty ? "点点" : agentName.trimmingCharacters(in: .whitespaces)
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let cityName = dataStore.locationManager.cityName
        let interestsArray = Array(selectedInterests)

        // 使用服务器分配的 user ID（LoginView 已完成登录）
        let userId = APIClient.shared.serverUserId ?? UUID().uuidString

        let user = User(
            id: userId,
            name: trimmedName,
            avatarEmoji: avatarEmoji,
            avatarImageData: avatarImageData,
            city: cityName,
            bio: bio,
            gender: gender,
            birthYear: birthYear,
            interests: interestsArray,
            occupation: occupation.trimmingCharacters(in: .whitespaces),
            customInterests: customInterests.trimmingCharacters(in: .whitespaces),
            welcomeDisturb: welcomeDisturb,
            agentName: finalAgentName,
            agentEmoji: agentEmoji,
            agentAvatarImageData: agentAvatarImageData,
            agentPersonality: agentPersonality
        )

        // Save locally
        let store = UserProfileStore()
        store.saveUser(user)

        dataStore.currentUser = user
        User.currentUser = user
        dataStore.isRegistered = true
        dataStore.locationManager.requestPermission()
        dataStore.loadInitialData()

        // Sync profile to backend
        Task {
            await syncProfileToBackend(
                name: trimmedName,
                gender: gender,
                birthYear: birthYear,
                bio: bio,
                interests: interestsArray,
                city: cityName,
                occupation: occupation.trimmingCharacters(in: .whitespaces),
                customInterests: customInterests.trimmingCharacters(in: .whitespaces),
                welcomeDisturb: welcomeDisturb,
                agentName: finalAgentName,
                agentEmoji: agentEmoji,
                agentPersonality: agentPersonality
            )
        }

        onComplete()
    }

    private func syncProfileToBackend(
        name: String,
        gender: String,
        birthYear: Int,
        bio: String,
        interests: [String],
        city: String,
        occupation: String,
        customInterests: String,
        welcomeDisturb: Bool,
        agentName: String,
        agentEmoji: String,
        agentPersonality: String
    ) async {
        let api = APIClient.shared
        do {
            // 用户已在 LoginView 登录，token 已保存，直接更新 profile
            var userData: [String: Any] = ["name": name]
            if !gender.isEmpty { userData["gender"] = gender }
            if birthYear > 0 { userData["birth_year"] = birthYear }
            if !bio.isEmpty { userData["bio"] = bio }
            if !interests.isEmpty { userData["interests"] = interests }
            if !city.isEmpty { userData["city"] = city }
            if !occupation.isEmpty { userData["occupation"] = occupation }
            if !customInterests.isEmpty { userData["custom_interests"] = customInterests }
            userData["welcome_disturb"] = welcomeDisturb
            _ = try await api.updateMe(data: userData)

            var agentData: [String: Any] = ["name": agentName]
            agentData["emoji"] = agentEmoji
            if !agentPersonality.isEmpty { agentData["personality"] = agentPersonality }
            _ = try await api.updateMyAgent(data: agentData)

            print("[Onboarding] Profile sync successful")
        } catch {
            print("[Onboarding] Profile sync failed: \(error)")
            dataStore.showToast("资料同步失败，请检查网络", type: .error)
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(
                x: bounds.minX + position.x,
                y: bounds.minY + position.y
            ), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
