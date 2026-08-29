import SwiftUI
import PhotosUI
import UIKit

struct ProfileView: View {
    @Environment(DataStore.self) private var dataStore
    @State private var showEditProfile = false
    @State private var showEditAgent = false
    @State private var editingMemory: AgentMemory?
    @State private var editMemoryText = ""
    @State private var showEditGallery = false
    @State private var showInvitationCenter = false
    @State private var showLogoutConfirm = false
    @State private var showDeleteAccountConfirm = false
    @State private var isDeletingAccount = false
    @State private var accountActionError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileHeader
                    agentCard
                    interestsSection
                    statsCard
                    invitationEntryCard
                    gallerySection
                    memorySection
                    aboutSection
                    accountActionsSection
                    Spacer().frame(height: 80)
                }
                .padding()
            }
            .background(AppTheme.backgroundColor)
            .navigationTitle("我的")
            .sheet(isPresented: $showEditGallery) {
                EditGalleryView()
                    .environment(dataStore)
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
                    .environment(dataStore)
            }
            .sheet(isPresented: $showEditAgent) {
                EditAgentView()
                    .environment(dataStore)
            }
            .sheet(isPresented: $showInvitationCenter) {
                InvitationCenterView()
                    .environment(dataStore)
            }
            .sheet(item: $editingMemory) { memory in
                EditMemoryView(
                    memory: memory,
                    text: $editMemoryText,
                    onSave: {
                        dataStore.updateMemory(memory, content: editMemoryText)
                        editingMemory = nil
                    }
                )
            }
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 12) {
            AvatarView(
                imageData: dataStore.currentUser.avatarImageData,
                emoji: dataStore.currentUser.avatarEmoji,
                size: 80,
                backgroundColor: AppTheme.primaryColor.opacity(0.1)
            )

            Text(dataStore.currentUser.name)
                .font(.title2)
                .fontWeight(.bold)

            HStack(spacing: 8) {
                if let gender = User.normalizedGender(dataStore.currentUser.gender) {
                    Text(gender)
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

            if !dataStore.currentUser.occupation.isEmpty {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "briefcase")
                        .font(.caption)
                    Text(dataStore.currentUser.occupation)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.secondary)
            }

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
        .overlay(alignment: .topTrailing) {
            cardEditButton(label: "编辑个人资料", tint: AppTheme.primaryColor) {
                showEditProfile = true
            }
            .padding(12)
        }
    }

    private var agentCard: some View {
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

                Text("你的找搭子 Agent")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            cardEditButton(label: "编辑 Agent", tint: AppTheme.agentColor) {
                showEditAgent = true
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
        .shadow(color: AppTheme.shadowColor, radius: AppTheme.shadowRadius, y: AppTheme.shadowY)
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

    private var invitationEntryCard: some View {
        Button {
            showInvitationCenter = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "person.2.badge.plus")
                    .font(.title2)
                    .foregroundStyle(AppTheme.primaryColor)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.primaryColor.opacity(0.1))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("邀请好友")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("发布和匹配成功可获得邀请次数")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
            .shadow(color: AppTheme.shadowColor, radius: AppTheme.shadowRadius, y: AppTheme.shadowY)
        }
        .buttonStyle(.plain)
    }

    private var interestsSection: some View {
        Group {
            if !dataStore.currentUser.interests.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("兴趣")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)

                    FlowLayout(spacing: 8) {
                        ForEach(dataStore.currentUser.interests, id: \.self) { interest in
                            Text(interest)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(AppTheme.primaryColor)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(AppTheme.primaryColor.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    private var gallerySection: some View {
        let displayedItems = dataStore.galleryItems.filter(\.isDisplayed)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundStyle(AppTheme.primaryColor)
                Text("过往活动相册")
                    .font(.headline)
                Spacer()
                Button { showEditGallery = true } label: {
                    Text("编辑")
                        .font(.caption)
                        .foregroundStyle(AppTheme.primaryColor)
                }
            }

            if displayedItems.isEmpty {
                VStack(spacing: AppTheme.spacingMD) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 36))
                        .foregroundStyle(AppTheme.primaryColor.opacity(0.4))
                    Text("已完成的活动会放入记忆相册")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.spacingXL)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(displayedItems) { item in
                            galleryCard(item)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
        .shadow(color: AppTheme.shadowColor, radius: AppTheme.shadowRadius, y: AppTheme.shadowY)
    }

    private func galleryCard(_ item: GalleryItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let photoData = item.photos.first, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 140, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSM))
            } else {
                RoundedRectangle(cornerRadius: AppTheme.radiusSM)
                    .fill(AppTheme.activityTypeColor(item.activityType).opacity(0.12))
                    .frame(width: 140, height: 90)
                    .overlay {
                        Image(systemName: AppTheme.activityTypeIcon(item.activityType))
                            .font(.title2)
                            .foregroundStyle(AppTheme.activityTypeColor(item.activityType))
                    }
            }

            Text(item.title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)

            if let startTime = item.startTime {
                Text(startTime.formatted(.dateTime.month().day()))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !item.location.isEmpty {
                HStack(spacing: 2) {
                    Image(systemName: "mappin")
                        .font(.system(size: 8))
                    Text(item.location)
                        .lineLimit(1)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .frame(width: 140)
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
                    memoryRow(memory)
                }
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
        .shadow(color: AppTheme.shadowColor, radius: AppTheme.shadowRadius, y: AppTheme.shadowY)
    }

    private func memoryRow(_ memory: AgentMemory) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: memoryIcon(for: memory.type))
                .font(.caption)
                .foregroundStyle(memoryColor(for: memory.type))
                .frame(width: 24, height: 28)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(memoryTypeLabel(for: memory.type))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(memoryColor(for: memory.type))
                    if let category = memory.category, !category.isEmpty {
                        Text(category)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }

                Text(memory.content)
                    .font(.subheadline)
                    .lineLimit(3)

                HStack(spacing: 8) {
                    ConfidenceBar(value: memory.confidence)
                    if memory.occurrenceCount > 1 {
                        Text("x\(memory.occurrenceCount)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 2) {
                Button {
                    editMemoryText = memory.content
                    editingMemory = memory
                } label: {
                    Image(systemName: "pencil")
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Button(role: .destructive) {
                    dataStore.deleteMemory(memory)
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red.opacity(0.8))
            }
        }
        .padding(.vertical, 6)
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("关于")
                .font(.headline)

            VStack(spacing: 0) {
                aboutRow(icon: "info.circle", title: "版本", value: "1.0 MVP")
                Divider().padding(.leading, 40)
                aboutRow(icon: "shield", title: "隐私", value: "数据加密传输至服务器")
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
        .shadow(color: AppTheme.shadowColor, radius: AppTheme.shadowRadius, y: AppTheme.shadowY)
    }

    private var accountActionsSection: some View {
        VStack(spacing: 0) {
            Button(role: .destructive) {
                showLogoutConfirm = true
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("退出登录")
                    Spacer()
                }
                .font(.subheadline)
                .foregroundStyle(.red)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }

            Divider().padding(.leading, 48)

            Button(role: .destructive) {
                showDeleteAccountConfirm = true
            } label: {
                HStack {
                    Image(systemName: "person.crop.circle.badge.xmark")
                    Text("注销账号")
                    Spacer()
                    if isDeletingAccount {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.red)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .disabled(isDeletingAccount)

            if let accountActionError {
                Text(accountActionError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
        .shadow(color: AppTheme.shadowColor, radius: AppTheme.shadowRadius, y: AppTheme.shadowY)
        .alert("确定退出？", isPresented: $showLogoutConfirm) {
            Button("取消", role: .cancel) {}
            Button("退出", role: .destructive) {
                dataStore.logout()
            }
        } message: {
            Text("退出后会清除本机登录信息，可使用手机号重新登录。")
        }
        .confirmationDialog(
            "永久注销账号？",
            isPresented: $showDeleteAccountConfirm,
            titleVisibility: .visible
        ) {
            Button("永久删除账号", role: .destructive) {
                deleteAccount()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("注销后将永久删除你的个人资料、活动、聊天室、记忆和邀请数据，且无法恢复。")
        }
    }

    private func deleteAccount() {
        isDeletingAccount = true
        accountActionError = nil
        Task {
            do {
                try await dataStore.deleteAccount()
            } catch {
                accountActionError = accountDeletionErrorMessage(for: error)
            }
            isDeletingAccount = false
        }
    }

    private func accountDeletionErrorMessage(for error: Error) -> String {
        if case APIError.serverError(let statusCode, _) = error, statusCode >= 500 {
            return "注销失败，服务暂时不可用，请稍后重试"
        }
        if case APIError.unauthorized = error {
            return "登录状态已失效，请重新登录后再试"
        }
        if (error as NSError).domain == NSURLErrorDomain {
            return "网络连接异常，请检查网络后重试"
        }
        return "注销失败，请稍后重试"
    }

    private func cardEditButton(
        label: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: "pencil")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.1))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel(label)
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
        case .style: return "text.bubble.fill"
        case .feedback: return "star.fill"
        }
    }

    private func memoryColor(for type: MemoryType) -> Color {
        switch type {
        case .preference: return .pink
        case .constraint: return .orange
        case .behavior: return .blue
        case .style: return .purple
        case .feedback: return .yellow
        }
    }

    private func memoryTypeLabel(for type: MemoryType) -> String {
        switch type {
        case .preference: return "偏好"
        case .constraint: return "限制"
        case .behavior: return "习惯"
        case .style: return "风格"
        case .feedback: return "反馈"
        }
    }
}

private struct InvitationCenterView: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(\.dismiss) private var dismiss
    @State private var invitation: APIInvitationMeResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var copiedMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        ProgressView("正在读取邀请资格…")
                            .padding(.top, 80)
                    } else if let invitation, let code = invitation.code {
                        invitationBalance(invitation, code: code)
                    } else {
                        earningGuide
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(20)
            }
            .background(AppTheme.backgroundColor)
            .navigationTitle("邀请好友")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .task { await loadInvitation() }
            .refreshable { await loadInvitation() }
            .alert("已复制", isPresented: Binding(
                get: { copiedMessage != nil },
                set: { if !$0 { copiedMessage = nil } }
            )) {
                Button("好") { copiedMessage = nil }
            } message: {
                Text(copiedMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private func invitationBalance(_ value: APIInvitationMeResponse, code: String) -> some View {
        let shareURL = URL(string: value.shareURL ?? "https://idabuda.com/i/\(code)")!
        VStack(spacing: 10) {
            Text("还可以邀请")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(value.available)")
                .font(.system(size: 58, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.primaryColor)
            Text("位好友")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(code)
                .font(.title2.monospaced().weight(.semibold))
                .tracking(3)
                .padding(.top, 8)
            Text("长期邀请码")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusXL))

        ShareLink(
            item: shareURL,
            subject: Text("来自 i搭不搭 的邀请"),
            message: Text("我在 i搭不搭 等你，一起找合适的活动搭子。邀请码：\(code)")
        ) {
            Label("邀请微信好友", systemImage: "square.and.arrow.up")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(value.available > 0 ? AppTheme.primaryColor : Color.secondary)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
        }
        .disabled(value.available <= 0)

        HStack(spacing: 12) {
            copyButton(title: "复制链接", value: shareURL.absoluteString)
            copyButton(title: "复制邀请码", value: code)
        }

        VStack(alignment: .leading, spacing: 12) {
            Text("获得记录")
                .font(.headline)
            milestoneRow(
                title: "首次发布活动",
                reward: "+3",
                status: value.milestones["first_event_publish"]
            )
            milestoneRow(
                title: "首次成功匹配",
                reward: "+2",
                status: value.milestones["first_match"]
            )
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
    }

    private var earningGuide: some View {
        VStack(spacing: 18) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 42))
                .foregroundStyle(AppTheme.primaryColor)
            Text("在上海完成真实定位后获得邀请资格")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("首次发布活动可获得 3 次邀请，首次成功匹配再获得 2 次。定位只用于资格判断，不保存精确坐标。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                dataStore.locationManager.requestPermission()
                dataStore.locationManager.refreshLocation()
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    await loadInvitation()
                }
            } label: {
                Label("刷新上海定位资格", systemImage: "location.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.primaryColor)
        }
        .padding(24)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusXL))
    }

    private func copyButton(title: String, value: String) -> some View {
        Button {
            UIPasteboard.general.string = value
            copiedMessage = title
        } label: {
            Text(title)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .tint(AppTheme.primaryColor)
    }

    private func milestoneRow(title: String, reward: String, status: String?) -> some View {
        HStack {
            Image(systemName: status == "settled" ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(status == "settled" ? AppTheme.primaryColor : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.medium))
                if status == "pending_location" {
                    Text("等待上海定位确认")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
            Text(reward)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.primaryColor)
        }
    }

    @MainActor
    private func loadInvitation() async {
        isLoading = invitation == nil
        errorMessage = nil
        do {
            invitation = try await APIClient.shared.getMyInvitation()
        } catch {
            errorMessage = "暂时无法读取邀请信息，请稍后重试"
        }
        isLoading = false
    }
}

// MARK: - Edit Gallery Sheet

struct EditGalleryView: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                let completedEvents = dataStore.events.filter { $0.status == .completed }
                if completedEvents.isEmpty {
                    ContentUnavailableView(
                        "暂无已完成活动",
                        systemImage: "calendar.badge.checkmark",
                        description: Text("完成活动后可在此管理相册")
                    )
                } else {
                    ForEach(completedEvents) { event in
                        GalleryEventRow(event: event)
                            .environment(dataStore)
                    }
                }
            }
            .navigationTitle("管理相册")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct GalleryEventRow: View {
    let event: Event
    @Environment(DataStore.self) private var dataStore
    @State private var selectedPhotos: [PhotosPickerItem] = []

    private var galleryItem: GalleryItem? {
        dataStore.galleryItems.first(where: { $0.eventId == event.id })
    }

    private var isDisplayed: Bool {
        galleryItem?.isDisplayed ?? false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: AppTheme.activityTypeIcon(event.activityType))
                    .font(.title3)
                    .foregroundStyle(AppTheme.activityTypeColor(event.activityType))
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if let startTime = event.startTime {
                        Text(startTime.formatted(.dateTime.year().month().day()))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { isDisplayed },
                    set: { newValue in toggleDisplay(newValue) }
                ))
                .labelsHidden()
                .tint(AppTheme.primaryColor)
            }

            if isDisplayed, let item = galleryItem {
                photoSection(item)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func photoSection(_ item: GalleryItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(Array(item.photos.enumerated()), id: \.offset) { index, photoData in
                    if let uiImage = UIImage(data: photoData) {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 70, height: 70)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            Button {
                                removePhoto(at: index, from: item)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .shadow(radius: 2)
                            }
                            .offset(x: 4, y: -4)
                        }
                    }
                }

                if item.photos.count < 3 {
                    PhotosPicker(
                        selection: $selectedPhotos,
                        maxSelectionCount: 3 - item.photos.count,
                        matching: .images
                    ) {
                        VStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.title3)
                            Text("添加")
                                .font(.caption2)
                        }
                        .foregroundStyle(AppTheme.primaryColor)
                        .frame(width: 70, height: 70)
                        .background(AppTheme.primaryColor.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .onChange(of: selectedPhotos) { _, newValue in
                        Task { await loadPhotos(newValue, for: item) }
                    }
                }
            }

            Text("最多 3 张照片")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func toggleDisplay(_ show: Bool) {
        if show {
            if galleryItem == nil {
                let newItem = GalleryItem(from: event)
                dataStore.addGalleryItem(newItem)
            } else {
                var updated = galleryItem!
                updated.isDisplayed = true
                dataStore.updateGalleryItem(updated)
            }
        } else if var existing = galleryItem {
            existing.isDisplayed = false
            dataStore.updateGalleryItem(existing)
        }
    }

    private func removePhoto(at index: Int, from item: GalleryItem) {
        var updated = item
        updated.photos.remove(at: index)
        dataStore.updateGalleryItem(updated)
    }

    private func loadPhotos(_ pickerItems: [PhotosPickerItem], for item: GalleryItem) async {
        var updated = item
        for pickerItem in pickerItems {
            guard updated.photos.count < 3 else { break }
            if let data = try? await pickerItem.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data),
               let compressed = compressImage(uiImage) {
                updated.photos.append(compressed)
            }
        }
        await MainActor.run {
            dataStore.updateGalleryItem(updated)
            selectedPhotos = []
        }
    }

    private func compressImage(_ image: UIImage) -> Data? {
        let maxDimension: CGFloat = 600
        let size = image.size
        let scale: CGFloat
        if size.width > maxDimension || size.height > maxDimension {
            scale = maxDimension / max(size.width, size.height)
        } else {
            scale = 1.0
        }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.6)
    }
}

private struct EditMemoryView: View {
    let memory: AgentMemory
    @Binding var text: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("记忆内容", text: $text, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("编辑记忆")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave()
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
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
    @State private var gender = ""
    @State private var birthDate = EditProfileView.defaultBirthDate
    @State private var city = ""
    @State private var occupation = ""
    @State private var selectedInterests: Set<String> = []
    @State private var customInterests = ""
    @State private var welcomeDisturb = false
    @State private var profileEventVisibility = "partial"
    @State private var bio = ""
    @State private var isSaving = false

    private static let avatarOptions = [
        "😊", "😎", "🤗", "🥰", "😄", "🤓",
        "🦊", "🐱", "🐶", "🐼", "🦁", "🐨",
        "🌟", "🌈", "🔥", "💎", "🎵", "🎮",
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
    private static let eventVisibilityOptions: [(value: String, label: String, description: String)] = [
        ("hidden", "全部隐藏", "别人看不到你的过往活动"),
        ("partial", "部分隐藏", "只显示活动类型、月份和城市"),
        ("public", "全部能看", "显示完整标题、时间、地点和偏好"),
    ]
    private static let defaultBirthDate: Date = {
        AppLocale.chineseCalendar.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? .now
    }()
    private static let birthDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private var birthDateRange: ClosedRange<Date> {
        let calendar = AppLocale.chineseCalendar
        let start = calendar.date(from: DateComponents(year: 1970, month: 1, day: 1)) ?? .distantPast
        let end = calendar.date(from: DateComponents(year: 2010, month: 12, day: 31)) ?? .now
        return start...end
    }

    private var birthDateString: String {
        Self.birthDateFormatter.string(from: birthDate)
    }

    private var birthYear: Int {
        AppLocale.chineseCalendar.component(.year, from: birthDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("头像") {
                    AvatarPickerView(
                        imageData: $avatarImageData,
                        emoji: $avatarEmoji,
                        emojiOptions: Self.avatarOptions,
                        size: 88,
                        accentColor: AppTheme.primaryColor
                    )
                    .listRowBackground(Color.clear)
                }

                Section("昵称") {
                    TextField("昵称", text: $name)
                }

                Section("基础资料") {
                    VStack(spacing: 12) {
                        Text("性别")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        HStack(spacing: 12) {
                            genderButton(label: "男", value: "男", icon: "sun.max")
                            genderButton(label: "女", value: "女", icon: "moon.stars")
                        }
                    }
                    .listRowBackground(Color.clear)
                }

                Section {
                    DatePicker("出生日期", selection: $birthDate, in: birthDateRange, displayedComponents: .date)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .environment(\.locale, AppLocale.chinese)
                        .environment(\.calendar, AppLocale.chineseCalendar)
                        .frame(height: 150)

                    TextField("城市或常驻地点", text: $city)
                    TextField("工作时间常做的事", text: $occupation)
                }

                Section("兴趣") {
                    FlowLayout(spacing: 10) {
                        ForEach(Self.interestItems, id: \.0) { item in
                            interestChip(item.0, icon: item.1)
                        }
                    }
                    .listRowBackground(Color.clear)
                }

                Section {
                    TextField("补充其他爱好", text: $customInterests)

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
                }

                Section("简介") {
                    TextField("一句话简介", text: $bio)
                }

                Section("公开主页") {
                    Picker("过往活动可见性", selection: $profileEventVisibility) {
                        ForEach(Self.eventVisibilityOptions, id: \.value) { option in
                            Text(option.label).tag(option.value)
                        }
                    }

                    if let selectedOption = Self.eventVisibilityOptions.first(where: { $0.value == profileEventVisibility }) {
                        Text(selectedOption.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
                        .disabled(User.normalizedGender(gender) == nil || isSaving)
                }
            }
            .onAppear {
                avatarEmoji = dataStore.currentUser.avatarEmoji
                avatarImageData = dataStore.currentUser.avatarImageData
                name = dataStore.currentUser.name
                gender = User.normalizedGender(dataStore.currentUser.gender) ?? ""
                birthDate = Self.parseBirthDate(dataStore.currentUser.birthDate) ?? Self.defaultBirthDate
                city = dataStore.currentUser.city
                occupation = dataStore.currentUser.occupation
                selectedInterests = Set(dataStore.currentUser.interests)
                customInterests = dataStore.currentUser.customInterests
                welcomeDisturb = dataStore.currentUser.welcomeDisturb
                profileEventVisibility = dataStore.currentUser.profileEventVisibility
                bio = dataStore.currentUser.bio
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
        .buttonStyle(.plain)
    }

    private func save() {
        guard !isSaving else { return }
        guard let selectedGender = User.normalizedGender(gender) else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedCity = city.trimmingCharacters(in: .whitespaces)
        let trimmedOccupation = occupation.trimmingCharacters(in: .whitespaces)
        let trimmedCustomInterests = customInterests.trimmingCharacters(in: .whitespaces)
        let interests = Array(selectedInterests).sorted()
        isSaving = true

        Task {
            do {
                var data: [String: Any] = [
                    "gender": selectedGender,
                    "birth_year": birthYear,
                    "birth_date": birthDateString,
                    "bio": bio,
                    "city": trimmedCity,
                    "occupation": trimmedOccupation,
                    "interests": interests,
                    "custom_interests": trimmedCustomInterests,
                    "welcome_disturb": welcomeDisturb,
                    "profile_event_visibility": profileEventVisibility,
                ]
                if !trimmedName.isEmpty { data["name"] = trimmedName }
                let _ = try await APIClient.shared.updateMe(data: data)

                dataStore.currentUser.avatarEmoji = avatarEmoji
                dataStore.currentUser.avatarImageData = avatarImageData
                dataStore.currentUser.name = trimmedName.isEmpty ? dataStore.currentUser.name : trimmedName
                dataStore.currentUser.gender = selectedGender
                dataStore.currentUser.birthYear = birthYear
                dataStore.currentUser.birthDate = birthDateString
                dataStore.currentUser.city = trimmedCity
                dataStore.currentUser.occupation = trimmedOccupation
                dataStore.currentUser.interests = interests
                dataStore.currentUser.customInterests = trimmedCustomInterests
                dataStore.currentUser.welcomeDisturb = welcomeDisturb
                dataStore.currentUser.profileEventVisibility = profileEventVisibility
                dataStore.currentUser.bio = bio
                User.currentUser = dataStore.currentUser
                UserProfileStore().saveUser(dataStore.currentUser)
                isSaving = false
                dismiss()
                dataStore.showToast("资料已保存", type: .info)
            } catch {
                print("Sync profile to server error: \(error)")
                isSaving = false
                dataStore.showToast("资料同步失败，请稍后重试", type: .error)
            }
        }
    }

    private static func parseBirthDate(_ value: String) -> Date? {
        birthDateFormatter.date(from: value)
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
    @State private var isSaving = false

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
                                    .background(agentPersonality == p ? AppTheme.agentColor : AppTheme.systemBubbleColor)
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
                        .disabled(isSaving)
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
        guard !isSaving else { return }
        let trimmedName = agentName.trimmingCharacters(in: .whitespaces)
        let finalName = trimmedName.isEmpty ? "点点" : trimmedName
        isSaving = true

        Task {
            do {
                let data: [String: Any] = [
                    "name": finalName,
                    "emoji": agentEmoji,
                    "personality": agentPersonality,
                ]
                let _ = try await APIClient.shared.updateMyAgent(data: data)

                dataStore.currentUser.agentName = finalName
                dataStore.currentUser.agentEmoji = agentEmoji
                dataStore.currentUser.agentAvatarImageData = agentAvatarImageData
                dataStore.currentUser.agentPersonality = agentPersonality
                User.currentUser = dataStore.currentUser
                UserProfileStore().saveUser(dataStore.currentUser)
                isSaving = false
                dismiss()
                dataStore.showToast("Agent 已保存", type: .info)
            } catch {
                print("Sync agent to server error: \(error)")
                isSaving = false
                dataStore.showToast("Agent 同步失败，请稍后重试", type: .error)
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

private struct CompassMotif: View {
    var body: some View {
        Canvas { context, size in
            let color = AppTheme.primaryColor.opacity(0.12)
            let cx = size.width / 2
            let cy = size.height / 2
            let r = min(size.width, size.height) / 2

            let outerCircle = Path(ellipseIn: CGRect(x: cx - r * 0.92, y: cy - r * 0.92, width: r * 1.84, height: r * 1.84))
            context.stroke(outerCircle, with: .color(color), lineWidth: 1.4)

            let dashCircle = Path(ellipseIn: CGRect(x: cx - r * 0.82, y: cy - r * 0.82, width: r * 1.64, height: r * 1.64))
            let dashStyle = StrokeStyle(lineWidth: 1.2, dash: [1.2, 5.4])
            context.stroke(dashCircle, with: .color(color), style: dashStyle)

            let innerCircle = Path(ellipseIn: CGRect(x: cx - r * 0.46, y: cy - r * 0.46, width: r * 0.92, height: r * 0.92))
            context.stroke(innerCircle, with: .color(color), lineWidth: 1.4)

            var star = Path()
            let pts: [(CGFloat, CGFloat)] = [
                (0, -r * 0.82), (r * 0.1, -r * 0.1), (r * 0.82, 0), (r * 0.1, r * 0.1),
                (0, r * 0.82), (-r * 0.1, r * 0.1), (-r * 0.82, 0), (-r * 0.1, -r * 0.1)
            ]
            star.move(to: CGPoint(x: cx + pts[0].0, y: cy + pts[0].1))
            for i in 1..<pts.count {
                star.addLine(to: CGPoint(x: cx + pts[i].0, y: cy + pts[i].1))
            }
            star.closeSubpath()
            context.stroke(star, with: .color(color), lineWidth: 1.6)

            for i in 0..<8 {
                let angle = Double(i) * .pi / 4
                let dx = CGFloat(cos(angle))
                let dy = CGFloat(sin(angle))
                var tick = Path()
                tick.move(to: CGPoint(x: cx + dx * r * 0.48, y: cy + dy * r * 0.48))
                tick.addLine(to: CGPoint(x: cx + dx * r * 0.56, y: cy + dy * r * 0.56))
                context.stroke(tick, with: .color(color), lineWidth: 1)
            }

            let hubCircle = Path(ellipseIn: CGRect(x: cx - r * 0.13, y: cy - r * 0.13, width: r * 0.26, height: r * 0.26))
            context.stroke(hubCircle, with: .color(color), lineWidth: 1.2)

            let dot = Path(ellipseIn: CGRect(x: cx - r * 0.06, y: cy - r * 0.06, width: r * 0.12, height: r * 0.12))
            context.fill(dot, with: .color(color))
        }
        .allowsHitTesting(false)
    }
}
