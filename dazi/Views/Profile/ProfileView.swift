import SwiftUI
import PhotosUI

struct ProfileView: View {
    @Environment(DataStore.self) private var dataStore
    @State private var showEditProfile = false
    @State private var showEditAgent = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileHeader
                    agentCard
                    statsCard
                    memorySection
                    aboutSection
                    logoutSection
                }
                .padding()
            }
            .background(AppTheme.backgroundColor)
            .navigationTitle("我的")
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
                    .environment(dataStore)
            }
            .sheet(isPresented: $showEditAgent) {
                EditAgentView()
                    .environment(dataStore)
            }
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 12) {
            Button { showEditProfile = true } label: {
                ZStack(alignment: .bottomTrailing) {
                    AvatarView(
                        imageData: dataStore.currentUser.avatarImageData,
                        emoji: dataStore.currentUser.avatarEmoji,
                        size: 80,
                        backgroundColor: AppTheme.primaryColor.opacity(0.1)
                    )

                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AppTheme.primaryColor)
                        .background(Circle().fill(.white).frame(width: 20, height: 20))
                }
            }

            Text(dataStore.currentUser.name)
                .font(.title2)
                .fontWeight(.bold)

            HStack(spacing: 8) {
                if !dataStore.currentUser.gender.isEmpty {
                    Text(dataStore.currentUser.gender)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(AppTheme.primaryColor.opacity(0.1))
                        .clipShape(Capsule())
                }

                if let age = dataStore.currentUser.age {
                    Text("\(age)岁")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(AppTheme.secondaryColor.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 4) {
                Image(systemName: "mappin")
                    .font(.caption)
                Text(dataStore.currentUser.city.isEmpty ? dataStore.locationManager.locationString : dataStore.currentUser.city)
                    .font(.subheadline)
            }
            .foregroundStyle(.secondary)

            if !dataStore.currentUser.bio.isEmpty {
                Text(dataStore.currentUser.bio)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !dataStore.currentUser.interests.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(dataStore.currentUser.interests, id: \.self) { interest in
                        Text(interest)
                            .font(.caption2)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(AppTheme.agentColor.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusXL))
        .shadow(color: AppTheme.shadowColor, radius: AppTheme.shadowRadius, y: AppTheme.shadowY)
    }

    private var agentCard: some View {
        Button { showEditAgent = true } label: {
            HStack(spacing: 14) {
                AvatarView(
                    imageData: dataStore.currentUser.agentAvatarImageData,
                    emoji: dataStore.currentUser.agentEmoji,
                    size: 56,
                    backgroundColor: AppTheme.agentColor.opacity(0.12)
                )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(dataStore.currentUser.agentName)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text("AI")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.agentColor)
                            .clipShape(Capsule())
                    }

                    Text("性格：\(dataStore.currentUser.agentPersonality)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("你的私人搭子经纪人")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
            .shadow(color: AppTheme.shadowColor, radius: AppTheme.shadowRadius, y: AppTheme.shadowY)
        }
    }

    private var statsCard: some View {
        HStack(spacing: 0) {
            statItem(value: "\(dataStore.events.count)", label: "活动", icon: "calendar")
            Divider().frame(height: 40)
            statItem(value: "\(dataStore.events.filter { $0.status == .completed }.count)", label: "已完成", icon: "checkmark.circle")
            Divider().frame(height: 40)
            statItem(value: "\(dataStore.memories.count)", label: "记忆", icon: "brain")
        }
        .padding(.vertical, 16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
        .shadow(color: AppTheme.shadowColor, radius: AppTheme.shadowRadius, y: AppTheme.shadowY)
    }

    private func statItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(AppTheme.primaryColor)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var memorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(AppTheme.agentColor)
                Text("\(dataStore.currentUser.agentName)对你的了解")
                    .font(.headline)
            }

            Text("\(dataStore.currentUser.agentName)通过和你的对话，记住了你的偏好和习惯，用于更精准地匹配搭子。")
                .font(.caption)
                .foregroundStyle(.secondary)

            if dataStore.memories.isEmpty {
                VStack(spacing: AppTheme.spacingMD) {
                    Image(systemName: "brain")
                        .font(.system(size: 36))
                        .foregroundStyle(AppTheme.agentColor.opacity(0.4))

                    Text("和\(dataStore.currentUser.agentName)多聊聊，ta 会记住你的偏好")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.spacingXL)
            } else {
                ForEach(dataStore.memories) { memory in
                    HStack(spacing: 8) {
                        Image(systemName: memoryIcon(for: memory.type))
                            .font(.caption)
                            .foregroundStyle(memoryColor(for: memory.type))
                            .frame(width: 24)

                        Text(memory.content)
                            .font(.subheadline)
                            .lineLimit(2)

                        Spacer()

                        ConfidenceBar(value: memory.confidence)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
        .shadow(color: AppTheme.shadowColor, radius: AppTheme.shadowRadius, y: AppTheme.shadowY)
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("关于")
                .font(.headline)

            VStack(spacing: 0) {
                aboutRow(icon: "info.circle", title: "版本", value: "1.0 MVP")
                Divider().padding(.leading, 40)
                aboutRow(icon: "sparkles", title: "AI模型", value: "Kimi (kimi-k2.5)")
                Divider().padding(.leading, 40)
                aboutRow(icon: "shield", title: "隐私", value: "数据加密传输至服务器")
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
        .shadow(color: AppTheme.shadowColor, radius: AppTheme.shadowRadius, y: AppTheme.shadowY)
    }

    @State private var showLogoutConfirm = false

    private var logoutSection: some View {
        Button(role: .destructive) {
            showLogoutConfirm = true
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("退出登录")
            }
            .font(.subheadline)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
            .shadow(color: AppTheme.shadowColor, radius: AppTheme.shadowRadius, y: AppTheme.shadowY)
        }
        .alert("确定退出？", isPresented: $showLogoutConfirm) {
            Button("取消", role: .cancel) {}
            Button("退出", role: .destructive) {
                dataStore.logout()
            }
        } message: {
            Text("退出后将清除本地数据，需要重新注册。")
        }
    }

    private func aboutRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
    }

    private func memoryIcon(for type: MemoryType) -> String {
        switch type {
        case .preference: return "heart.fill"
        case .constraint: return "xmark.circle.fill"
        case .behavior: return "figure.walk"
        case .feedback: return "star.fill"
        }
    }

    private func memoryColor(for type: MemoryType) -> Color {
        switch type {
        case .preference: return .pink
        case .constraint: return .orange
        case .behavior: return .blue
        case .feedback: return .yellow
        }
    }
}

// MARK: - Edit Profile Sheet

struct EditProfileView: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(\.dismiss) private var dismiss
    @State private var avatarEmoji = ""
    @State private var avatarImageData: Data?
    @State private var name = ""
    @State private var bio = ""

    private let avatarOptions = [
        "😊", "😎", "🤗", "🥰", "😄", "🤓",
        "🦊", "🐱", "🐶", "🐼", "🦁", "🐨",
        "🌟", "🌈", "🔥", "💎", "🎵", "🎮",
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("头像") {
                    AvatarPickerView(
                        imageData: $avatarImageData,
                        emoji: $avatarEmoji,
                        emojiOptions: avatarOptions,
                        size: 88,
                        accentColor: AppTheme.primaryColor
                    )
                    .listRowBackground(Color.clear)
                }

                Section("昵称") {
                    TextField("昵称", text: $name)
                }

                Section("简介") {
                    TextField("一句话简介", text: $bio)
                }
            }
            .navigationTitle("编辑资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                avatarEmoji = dataStore.currentUser.avatarEmoji
                avatarImageData = dataStore.currentUser.avatarImageData
                name = dataStore.currentUser.name
                bio = dataStore.currentUser.bio
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        dataStore.currentUser.avatarEmoji = avatarEmoji
        dataStore.currentUser.avatarImageData = avatarImageData
        dataStore.currentUser.name = trimmedName.isEmpty ? dataStore.currentUser.name : trimmedName
        dataStore.currentUser.bio = bio
        User.currentUser = dataStore.currentUser
        UserProfileStore().saveUser(dataStore.currentUser)
        dismiss()

        // 同步到后端
        Task {
            do {
                var data: [String: Any] = ["bio": bio]
                if !trimmedName.isEmpty { data["name"] = trimmedName }
                let _ = try await APIClient.shared.updateMe(data: data)
            } catch {
                print("Sync profile to server error: \(error)")
            }
        }
    }
}

// MARK: - Edit Agent Sheet

struct EditAgentView: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(\.dismiss) private var dismiss
    @State private var agentName = ""
    @State private var agentEmoji = ""
    @State private var agentAvatarImageData: Data?
    @State private var agentPersonality = ""

    private let emojiOptions = [
        "🤖", "✨", "🔮", "🧠", "💡", "🌟",
        "🦄", "🐙", "🎯", "🫧", "⚡", "🍀",
    ]

    private let personalityOptions = [
        "贴心、有趣", "理性、高效", "幽默、搞怪",
        "温柔、细心", "直爽、干脆", "可爱、活泼",
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Agent 头像") {
                    AvatarPickerView(
                        imageData: $agentAvatarImageData,
                        emoji: $agentEmoji,
                        emojiOptions: emojiOptions,
                        size: 80,
                        accentColor: AppTheme.agentColor
                    )
                    .listRowBackground(Color.clear)
                }

                Section("Agent 名字") {
                    TextField("给你的 Agent 起个名字", text: $agentName)
                }

                Section("Agent 性格") {
                    FlowLayout(spacing: 8) {
                        ForEach(personalityOptions, id: \.self) { p in
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
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("编辑 Agent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                agentName = dataStore.currentUser.agentName
                agentEmoji = dataStore.currentUser.agentEmoji
                agentAvatarImageData = dataStore.currentUser.agentAvatarImageData
                agentPersonality = dataStore.currentUser.agentPersonality
            }
        }
    }

    private func save() {
        let trimmedName = agentName.trimmingCharacters(in: .whitespaces)
        dataStore.currentUser.agentName = trimmedName.isEmpty ? "点点" : trimmedName
        dataStore.currentUser.agentEmoji = agentEmoji
        dataStore.currentUser.agentAvatarImageData = agentAvatarImageData
        dataStore.currentUser.agentPersonality = agentPersonality
        User.currentUser = dataStore.currentUser
        UserProfileStore().saveUser(dataStore.currentUser)
        dismiss()

        // 同步到后端
        Task {
            do {
                let data: [String: Any] = [
                    "name": trimmedName.isEmpty ? "点点" : trimmedName,
                    "emoji": agentEmoji,
                    "personality": agentPersonality,
                ]
                let _ = try await APIClient.shared.updateMyAgent(data: data)
            } catch {
                print("Sync agent to server error: \(error)")
            }
        }
    }
}

struct ConfidenceBar: View {
    let value: Double

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.15))
                .frame(width: 40, height: 4)

            RoundedRectangle(cornerRadius: 2)
                .fill(AppTheme.agentColor)
                .frame(width: 40 * value, height: 4)
        }
    }
}
