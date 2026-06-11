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
    @State private var birthDate = OnboardingView.defaultBirthDate
    @State private var selectedInterests: Set<String> = []
    @State private var customInterests = ""
    @State private var occupation = ""
    @State private var selectedOccupation: String?
    @State private var welcomeDisturb = false
    @State private var bio = ""
    @State private var agentName = ""
    @State private var agentEmoji = "🤖"
    @State private var agentAvatarImageData: Data?
    @State private var agentPersonality = "贴心、有趣"
    @State private var isAnimating = false

    enum OnboardingStep: Int, CaseIterable {
        case name, avatar, genderAndBirth, occupation, interests, bio, agentIntro, agentSetup, ready
    }

    private static let personalityOptions = [
        "贴心、有趣", "理性、高效", "幽默、搞怪",
        "温柔、细心", "直爽、干脆", "可爱、活泼",
    ]

    private static let occupationPresets = [
        "学生", "互联网", "金融", "设计",
        "医疗", "教育", "自由职业", "其他",
    ]

    private static let interestItems: [(String, String)] = [
        ("电影", "film"),
        ("徒步", "figure.hiking"),
        ("美食", "fork.knife"),
        ("看展", "paintpalette"),
        ("咖啡", "cup.and.saucer"),
        ("桌游", "dice"),
        ("摄影", "camera"),
        ("演出", "music.mic"),
        ("运动", "sportscourt"),
        ("阅读", "book"),
        ("旅行", "airplane"),
        ("音乐", "headphones"),
        ("烹饪", "frying.pan"),
        ("骑行", "bicycle"),
        ("瑜伽", "figure.yoga"),
        ("露营", "tent"),
        ("潜水", "water.waves"),
        ("滑雪", "figure.skiing.downhill"),
        ("剧本杀", "theatermasks"),
        ("电竞", "gamecontroller"),
        ("播客", "radio"),
        ("手作", "scissors"),
        ("逛集市", "bag"),
        ("City Walk", "figure.walk"),
    ]

    private static let defaultBirthDate: Date = {
        Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? .now
    }()

    private static let birthDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private var birthDateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(year: 1970, month: 1, day: 1)) ?? .distantPast
        let end = calendar.date(from: DateComponents(year: 2010, month: 12, day: 31)) ?? .now
        return start...end
    }

    private var selectedBirthYear: Int {
        Calendar.current.component(.year, from: birthDate)
    }

    private var birthDateString: String {
        Self.birthDateFormatter.string(from: birthDate)
    }

    var body: some View {
        ZStack {
            AppTheme.backgroundColor.ignoresSafeArea()

            VStack(spacing: 0) {
                if step != .ready && step != .agentIntro {
                    progressBar
                }

                Spacer()

                Group {
                    switch step {
                    case .name: nameStep
                    case .avatar: avatarStep
                    case .genderAndBirth: genderAndBirthStep
                    case .occupation: occupationStep
                    case .interests: interestsStep
                    case .bio: bioStep
                    case .agentIntro: agentIntroStep
                    case .agentSetup: agentSetupStep
                    case .ready: readyStep
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                Spacer()

                if step != .ready && step != .agentIntro {
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
        let stepsWithBar = OnboardingStep.allCases.filter { $0 != .ready && $0 != .agentIntro }
        let totalSteps = stepsWithBar.count
        let currentIndex = stepsWithBar.firstIndex(of: step) ?? 0
        let progress = Double(currentIndex) / Double(totalSteps - 1)
        let starSize: CGFloat = 20

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 6)

                RoundedRectangle(cornerRadius: 3)
                    .fill(AppTheme.primaryLight)
                    .frame(width: geo.size.width * progress, height: 6)

                FourPointStar()
                    .fill(AppTheme.primaryColor)
                    .frame(width: starSize, height: starSize)
                    .offset(x: geo.size.width * progress - starSize / 2)
            }
            .animation(.spring(duration: 0.4), value: progress)
        }
        .frame(height: starSize)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    // MARK: - Steps

    private var nameStep: some View {
        VStack(spacing: 16) {
            stepHeader(title: "你叫什么名字？", subtitle: "搭子们会看到这个名字", icon: "person.text.rectangle")

            TextField("输入你的昵称", text: $name)
                .font(.title2)
                .multilineTextAlignment(.center)
                .padding()
                .background(AppTheme.systemBubbleColor)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
        }
    }

    private var avatarStep: some View {
        VStack(spacing: 16) {
            stepHeader(title: "选个头像吧", subtitle: "可以从相册上传，也可以选择 Emoji", icon: "photo.circle")

            AvatarPickerView(
                imageData: $avatarImageData,
                emoji: $avatarEmoji,
                emojiOptions: [],
                size: 100,
                accentColor: AppTheme.primaryColor,
                gridHeight: 180
            )
        }
    }

    // MARK: - Gender + Birth (merged)

    private var genderAndBirthStep: some View {
        VStack(spacing: 0) {
            stepHeader(title: "基本信息", subtitle: "帮助我们更好地匹配", icon: "person.crop.circle")

            Spacer().frame(height: 28)

            VStack(spacing: 12) {
                Text("性别")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    genderButton(label: "男", value: "男", icon: "sun.max")
                    genderButton(label: "女", value: "女", icon: "moon.stars")
                    genderButton(label: "保密", value: "暂时保密", icon: "sparkles")
                }
            }

            Spacer().frame(height: 32)

            VStack(spacing: 12) {
                Text("生日")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                DatePicker("", selection: $birthDate, in: birthDateRange, displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .environment(\.locale, AppLocale.chinese)
                    .environment(\.calendar, AppLocale.chineseCalendar)
                    .frame(height: 140)
                    .clipped()
                    .onChange(of: birthDate) {
                        birthYear = selectedBirthYear
                    }
            }
        }
    }

    private func genderButton(label: String, value: String, icon: String) -> some View {
        Button {
            gender = value
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundStyle(gender == value ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(gender == value ? AppTheme.primaryColor : AppTheme.systemBubbleColor)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
        }
    }

    // MARK: - Occupation

    private var occupationStep: some View {
        VStack(spacing: 16) {
            stepHeader(
                title: "☀️ 工作时间在忙什么",
                subtitle: "让搭子们认识你",
                icon: nil
            )

            Spacer().frame(height: 8)

            FlowLayout(spacing: 10) {
                ForEach(Self.occupationPresets, id: \.self) { preset in
                    occupationChip(preset)
                }
            }

            TextField("或者直接输入...", text: $occupation)
                .font(.body)
                .padding()
                .background(AppTheme.systemBubbleColor)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
                .onChange(of: occupation) {
                    if !occupation.isEmpty {
                        selectedOccupation = nil
                    }
                }
        }
    }

    private func occupationChip(_ preset: String) -> some View {
        let isSelected = selectedOccupation == preset
        return Button {
            if isSelected {
                selectedOccupation = nil
                occupation = ""
            } else {
                selectedOccupation = preset
                occupation = preset
            }
        } label: {
            Text(preset)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? AppTheme.primaryColor : AppTheme.systemBubbleColor)
                .clipShape(Capsule())
        }
    }

    // MARK: - Interests

    private var interestsStep: some View {
        VStack(spacing: 16) {
            stepHeader(
                title: "🌙 休息时间喜欢做点什么",
                subtitle: "让搭子们认识你 (至少选1个)",
                icon: nil
            )

            ScrollView {
                FlowLayout(spacing: 10) {
                    ForEach(Self.interestItems, id: \.0) { item in
                        interestChip(item.0, icon: item.1)
                    }
                }
            }
            .frame(maxHeight: 240)

            TextField("补充其他爱好（可选）", text: $customInterests)
                .font(.subheadline)
                .padding(12)
                .background(AppTheme.systemBubbleColor)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMD))

            Toggle(isOn: $welcomeDisturb) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("欢迎惊喜")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("开启后，即使你没有发布活动，也可能被匹配到")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(AppTheme.primaryColor)
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 4)
    }

    private func interestChip(_ interest: String, icon: String) -> some View {
        let isSelected = selectedInterests.contains(interest)
        return Button {
            if isSelected {
                selectedInterests.remove(interest)
            } else {
                selectedInterests.insert(interest)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(interest)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? AppTheme.primaryColor : AppTheme.systemBubbleColor)
            .clipShape(Capsule())
        }
    }

    // MARK: - Bio

    private var bioStep: some View {
        VStack(spacing: 16) {
            stepHeader(title: "一句话介绍自己", subtitle: "可选，让搭子更了解你", icon: "text.quote")

            TextField("例如：喜欢探索城市的新居民", text: $bio)
                .font(.body)
                .padding()
                .background(AppTheme.systemBubbleColor)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
        }
    }

    // MARK: - Agent Intro

    private var agentIntroStep: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 12) {
                Text("🐙")
                    .font(.system(size: 52))

                Text("你的找搭子 Agent")
                    .font(.title2)
                    .fontWeight(.bold)
            }

            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    agentIntroRow(
                        icon: "bubble.left.and.text.bubble.right",
                        title: "自由表达，精准理解",
                        detail: "放心说出偏好，用具体的事件找到合适的人"
                    )
                    agentIntroExamples
                }

                agentIntroRow(
                    icon: "hand.wave",
                    title: "预先沟通，省去重复尬聊",
                    detail: "Agent之间先交流，代你提前问出在意的点，避免重复破冰寒暄"
                )
            }
            .padding(.horizontal, 8)

            Spacer()

            HStack {
                Button("上一步") {
                    withAnimation {
                        step = .bio
                    }
                }
                .foregroundStyle(.secondary)

                Spacer()

                Button {
                    withAnimation {
                        step = .agentSetup
                    }
                } label: {
                    Text("去设定你的 Agent")
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(AppTheme.primaryColor)
                        .clipShape(Capsule())
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.bottom, 8)
        }
    }

    private var agentIntroExamples: some View {
        let examples = [
            "想找人一起探下新开的咖啡店但是不想花时间出片",
            "学街舞报班找搭子，新人零基础求互相鼓励",
            "上海出发武汉4天3晚找搭子，美食之旅",
        ]
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(examples, id: \.self) { example in
                Text("\u{201C}\(example)\u{201D}")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                    )
            }
        }
        .padding(.leading, 46)
    }

    private func agentIntroRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(AppTheme.primaryColor)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Agent Setup

    private var agentSetupStep: some View {
        VStack(spacing: 20) {
            stepHeader(title: "🐙 设置你的 Agent", subtitle: "给它起个名字，选个形象", icon: nil)

            VStack(alignment: .leading, spacing: 4) {
                Text("Agent 名字")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("给你的 Agent 起个名字", text: $agentName)
                    .font(.body)
                    .padding(12)
                    .background(AppTheme.systemBubbleColor)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMD))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Agent 头像")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                AvatarPickerView(
                    imageData: $agentAvatarImageData,
                    emoji: $agentEmoji,
                    emojiOptions: [],
                    size: 80,
                    accentColor: AppTheme.primaryColor,
                    gridHeight: 130
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
                                .background(agentPersonality == p ? AppTheme.primaryColor : AppTheme.systemBubbleColor)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    // MARK: - Ready

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
                    profileRow(label: "头像", value: "自定义图片")
                } else {
                    profileRow(label: "头像", value: avatarEmoji)
                }
                if !gender.isEmpty { profileRow(label: "性别", value: gender) }
                profileRow(label: "出生日期", value: birthDateString)
                profileRow(label: "兴趣", value: Array(selectedInterests).joined(separator: "、"))
                if !bio.isEmpty { profileRow(label: "简介", value: bio) }
                Divider().padding(.vertical, 4)
                if agentAvatarImageData != nil {
                    profileRow(label: "Agent", value: "\(agentName.isEmpty ? "点点" : agentName)")
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
            if step.rawValue > OnboardingStep.name.rawValue && step != .agentSetup {
                Button("上一步") {
                    withAnimation {
                        if let prev = OnboardingStep(rawValue: step.rawValue - 1) {
                            step = prev
                        }
                    }
                }
                .foregroundStyle(.secondary)
            } else if step == .agentSetup {
                Button("上一步") {
                    withAnimation {
                        step = .agentIntro
                    }
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                withAnimation {
                    if step == .bio {
                        step = .agentIntro
                    } else if let next = OnboardingStep(rawValue: step.rawValue + 1) {
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
        case .genderAndBirth: return !gender.isEmpty
        case .occupation: return true
        case .interests: return !selectedInterests.isEmpty
        case .bio: return true
        case .agentIntro: return true
        case .agentSetup: return true
        default: return true
        }
    }

    // MARK: - Helpers

    private func stepHeader(title: String, subtitle: String, icon: String?) -> some View {
        VStack(spacing: 6) {
            if let icon {
                HStack(spacing: AppTheme.spacingSM) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(AppTheme.primaryColor)
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                }
            } else {
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
        let finalBirthYear = selectedBirthYear
        let finalBirthDate = birthDateString

        let userId = APIClient.shared.serverUserId ?? UUID().uuidString

        let user = User(
            id: userId,
            name: trimmedName,
            avatarEmoji: avatarEmoji,
            avatarImageData: avatarImageData,
            city: cityName,
            bio: bio,
            gender: gender,
            birthYear: finalBirthYear,
            birthDate: finalBirthDate,
            interests: interestsArray,
            occupation: occupation.trimmingCharacters(in: .whitespaces),
            customInterests: customInterests.trimmingCharacters(in: .whitespaces),
            welcomeDisturb: welcomeDisturb,
            agentName: finalAgentName,
            agentEmoji: agentEmoji,
            agentAvatarImageData: agentAvatarImageData,
            agentPersonality: agentPersonality
        )

        let store = UserProfileStore()
        store.saveUser(user)

        dataStore.currentUser = user
        User.currentUser = user
        dataStore.isRegistered = true
        dataStore.locationManager.requestPermission()
        dataStore.loadInitialData()

        Task {
            await syncProfileToBackend(
                name: trimmedName,
                gender: gender,
                birthYear: finalBirthYear,
                birthDate: finalBirthDate,
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
        birthDate: String,
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
            var userData: [String: Any] = ["name": name]
            if !gender.isEmpty { userData["gender"] = gender }
            if birthYear > 0 { userData["birth_year"] = birthYear }
            if !birthDate.isEmpty { userData["birth_date"] = birthDate }
            if !bio.isEmpty { userData["bio"] = bio }
            if !interests.isEmpty { userData["interests"] = interests }
            if !city.isEmpty { userData["city"] = city }
            if !occupation.isEmpty { userData["occupation"] = occupation }
            if !customInterests.isEmpty { userData["custom_interests"] = customInterests }
            userData["welcome_disturb"] = welcomeDisturb
            userData["profile_event_visibility"] = "partial"
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

// MARK: - Four Point Star Shape

struct FourPointStar: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let innerRatio: CGFloat = 0.35
        let bottomStretch: CGFloat = 1.25

        var path = Path()
        for i in 0..<8 {
            let angle = Angle(degrees: Double(i) * 45 - 90)
            var radius: CGFloat
            if i.isMultiple(of: 2) {
                radius = i == 4 ? r * bottomStretch : r
            } else {
                radius = r * innerRatio
            }
            let point = CGPoint(
                x: center.x + cos(angle.radians) * radius,
                y: center.y + sin(angle.radians) * radius
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}
