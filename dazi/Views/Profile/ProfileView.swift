import SwiftUI
import PhotosUI

struct ProfileView: View {
    @Environment(DataStore.self) private var dataStore
    @State private var showEditProfile = false
    @State private var showEditAgent = false
    @State private var editingMemory: AgentMemory?
    @State private var editMemoryText = ""
    @State private var showEditGallery = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileHeader
                    agentCard
                    statsCard
                    gallerySection
                    memorySection
                    aboutSection
                    logoutSection
                }
                .padding()
            }
            .background(AppTheme.backgroundColor)
            .navigationTitle("我的")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showEditProfile = true } label: {
                        Image(systemName: "pencil.line")
                            .font(.subheadline)
                    }
                }
            }
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

    private var gallerySection: some View {
        let displayedItems = dataStore.galleryItems.filter(\.isDisplayed)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundStyle(AppTheme.primaryColor)
                Text("过往事件相册")
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
    @State private var bio = ""

    private static let avatarOptions = [
        "😊", "😎", "🤗", "🥰", "😄", "🤓",
        "🦊", "🐱", "🐶", "🐼", "🦁", "🐨",
        "🌟", "🌈", "🔥", "💎", "🎵", "🎮",
    ]

    private static let genderOptions = ["男", "女", "暂时保密"]
    private static let interestOptions = [
        "电影", "徒步", "美食", "看展", "咖啡",
        "桌游", "摄影", "演出", "运动", "阅读",
        "旅行", "音乐", "烹饪", "骑行", "瑜伽",
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
                    Picker("性别", selection: $gender) {
                        ForEach(Self.genderOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)

                    DatePicker("出生日期", selection: $birthDate, in: birthDateRange, displayedComponents: .date)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .environment(\.locale, AppLocale.chinese)
                        .environment(\.calendar, AppLocale.chineseCalendar)
                        .frame(height: 150)

                    TextField("城市或常驻地点", text: $city)
                    TextField("职业", text: $occupation)
                }

                Section("兴趣") {
                    FlowLayout(spacing: 8) {
                        ForEach(Self.interestOptions, id: \.self) { interest in
                            interestChip(interest)
                        }
                    }
                    .listRowBackground(Color.clear)

                    TextField("补充其他爱好", text: $customInterests)

                    Toggle(isOn: $welcomeDisturb) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("欢迎打扰")
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
                gender = dataStore.currentUser.gender.isEmpty ? "暂时保密" : dataStore.currentUser.gender
                birthDate = Self.parseBirthDate(dataStore.currentUser.birthDate) ?? Self.defaultBirthDate
                city = dataStore.currentUser.city
                occupation = dataStore.currentUser.occupation
                selectedInterests = Set(dataStore.currentUser.interests)
                customInterests = dataStore.currentUser.customInterests
                welcomeDisturb = dataStore.currentUser.welcomeDisturb
                bio = dataStore.currentUser.bio
            }
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
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? AppTheme.primaryColor : Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedCity = city.trimmingCharacters(in: .whitespaces)
        let trimmedOccupation = occupation.trimmingCharacters(in: .whitespaces)
        let trimmedCustomInterests = customInterests.trimmingCharacters(in: .whitespaces)
        let interests = Array(selectedInterests).sorted()
        dataStore.currentUser.avatarEmoji = avatarEmoji
        dataStore.currentUser.avatarImageData = avatarImageData
        dataStore.currentUser.name = trimmedName.isEmpty ? dataStore.currentUser.name : trimmedName
        dataStore.currentUser.gender = gender
        dataStore.currentUser.birthYear = birthYear
        dataStore.currentUser.birthDate = birthDateString
        dataStore.currentUser.city = trimmedCity
        dataStore.currentUser.occupation = trimmedOccupation
        dataStore.currentUser.interests = interests
        dataStore.currentUser.customInterests = trimmedCustomInterests
        dataStore.currentUser.welcomeDisturb = welcomeDisturb
        dataStore.currentUser.bio = bio
        User.currentUser = dataStore.currentUser
        UserProfileStore().saveUser(dataStore.currentUser)
        dismiss()

        Task {
            do {
                var data: [String: Any] = [
                    "gender": gender,
                    "birth_year": birthYear,
                    "birth_date": birthDateString,
                    "bio": bio,
                    "city": trimmedCity,
                    "occupation": trimmedOccupation,
                    "interests": interests,
                    "custom_interests": trimmedCustomInterests,
                    "welcome_disturb": welcomeDisturb,
                ]
                if !trimmedName.isEmpty { data["name"] = trimmedName }
                let _ = try await APIClient.shared.updateMe(data: data)
                await MainActor.run {
                    dataStore.showToast("资料已保存", type: .info)
                }
            } catch {
                print("Sync profile to server error: \(error)")
                await MainActor.run {
                    dataStore.showToast("资料同步失败，请稍后重试", type: .error)
                }
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
