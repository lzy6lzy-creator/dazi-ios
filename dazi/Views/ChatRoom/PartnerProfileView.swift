import SwiftUI

struct PartnerProfileView: View {
    let partner: User
    @State private var profileData: APIPublicUserProfileResponse?
    @State private var isLoading = true
    @State private var loadFailed = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    avatarSection

                    if isLoading {
                        loadingSection
                    } else if loadFailed {
                        loadFailedSection
                    }

                    infoSection
                    interestsSection
                    customInterestsSection
                    disturbSection
                    bioSection
                    joinedSection
                    pastEventsSection
                }
                .padding()
            }
            .background(AppTheme.backgroundColor)
            .navigationTitle("搭子资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .task { await loadProfile() }
        }
    }

    private var avatarSection: some View {
        VStack(spacing: 12) {
            AvatarView(
                imageData: partner.avatarImageData,
                emoji: partner.avatarEmoji,
                size: 88,
                backgroundColor: AppTheme.primaryColor.opacity(0.1)
            )

            Text(displayName)
                .font(.title2)
                .fontWeight(.bold)

            HStack(spacing: 8) {
                if let gender = displayGender, !gender.isEmpty {
                    profileChip(text: gender, tint: AppTheme.primaryColor)
                }

                if let age = displayAge {
                    profileChip(text: "\(age)岁", tint: AppTheme.secondaryColor)
                }

                if let city = displayCity, !city.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "mappin")
                            .font(.system(size: 9))
                        Text(city)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusXL))
        .shadow(color: AppTheme.shadowColor, radius: AppTheme.shadowRadius, y: AppTheme.shadowY)
    }

    private var loadingSection: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("正在加载公开资料")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
    }

    private var loadFailedSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            Text("公开资料加载失败，已显示聊天室内资料")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(14)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
    }

    @ViewBuilder
    private var infoSection: some View {
        if let occupation = displayOccupation, !occupation.isEmpty {
            profileInfoCard(icon: "briefcase", title: "职业", value: occupation)
        }
    }

    @ViewBuilder
    private var interestsSection: some View {
        let interests = profileData?.interests ?? partner.interests
        if !interests.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle(icon: "heart", title: "兴趣", tint: AppTheme.primaryColor)

                FlowLayout(spacing: 6) {
                    ForEach(interests, id: \.self) { interest in
                        Text(interest)
                            .font(.caption2)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(AppTheme.agentColor.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .profileCardStyle()
        }
    }

    @ViewBuilder
    private var customInterestsSection: some View {
        let customInterests = (profileData?.customInterests ?? partner.customInterests)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !customInterests.isEmpty {
            profileInfoCard(icon: "sparkles", title: "补充兴趣", value: customInterests)
        }
    }

    @ViewBuilder
    private var disturbSection: some View {
        if profileData != nil || partner.welcomeDisturb {
            let enabled = profileData?.welcomeDisturb ?? partner.welcomeDisturb
            profileInfoCard(
                icon: enabled ? "bell.badge" : "bell.slash",
                title: "欢迎打扰",
                value: enabled ? "已开启，平时也可以被合适活动邀请" : "未开启，只在发布活动时参与匹配"
            )
        }
    }

    @ViewBuilder
    private var bioSection: some View {
        let bio = (profileData?.bio ?? partner.bio).trimmingCharacters(in: .whitespacesAndNewlines)
        if !bio.isEmpty {
            profileInfoCard(icon: "text.quote", title: "简介", value: bio)
        }
    }

    @ViewBuilder
    private var joinedSection: some View {
        if let createdAt = profileData?.createdAt,
           let text = formattedDate(createdAt, dateFormat: "yyyy年M月") {
            profileInfoCard(icon: "calendar.badge.clock", title: "加入时间", value: text)
        }
    }

    @ViewBuilder
    private var pastEventsSection: some View {
        if let profileData {
            let profileEventVisibility = profileData.profileEventVisibility ?? "partial"
            let pastEvents = profileData.pastEvents ?? []

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    sectionTitle(icon: "photo.on.rectangle.angled", title: "过往活动", tint: AppTheme.primaryColor)
                    Spacer()
                    Text(visibilityLabel(profileEventVisibility))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.systemBubbleColor)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }

                if profileEventVisibility == "hidden" {
                    emptyEventText("对方已隐藏过往活动")
                } else if pastEvents.isEmpty {
                    emptyEventText("还没有可展示的过往活动")
                } else {
                    VStack(spacing: 10) {
                        ForEach(pastEvents, id: \.id) { event in
                            pastEventRow(event)
                        }
                    }
                }
            }
            .profileCardStyle()
        }
    }

    private func pastEventRow(_ event: APIPublicProfileEventResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: AppTheme.activityTypeIcon(event.activityType))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.activityTypeColor(event.activityType))
                    .frame(width: 26, height: 26)
                    .background(AppTheme.activityTypeColor(event.activityType).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        if let timeText = eventTimeText(event) {
                            eventMeta(icon: "clock", text: timeText)
                        }
                        if let location = event.location, !location.isEmpty {
                            eventMeta(icon: "mappin", text: location)
                        }
                    }
                }

                Spacer()
            }

            if event.detailLevel == "public" {
                if let description = event.description?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                let chips = (event.preferences ?? []) + (event.constraints ?? [])
                if !chips.isEmpty {
                    FlowLayout(spacing: 5) {
                        ForEach(chips, id: \.self) { chip in
                            Text(chip)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppTheme.systemBubbleColor)
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(AppTheme.systemBubbleColor.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func profileChip(text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func sectionTitle(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(title)
                .font(.headline)
        }
    }

    private func profileInfoCard(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .profileCardStyle()
    }

    private func emptyEventText(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
    }

    private func eventMeta(icon: String, text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
            Text(text)
                .lineLimit(1)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func eventTimeText(_ event: APIPublicProfileEventResponse) -> String? {
        if let timeLabel = event.timeLabel, !timeLabel.isEmpty {
            return timeLabel
        }
        return formattedDate(event.startTime, dateFormat: "M月d日 HH:mm")
    }

    private func visibilityLabel(_ value: String) -> String {
        switch value {
        case "hidden": return "全部隐藏"
        case "public": return "全部能看"
        default: return "部分隐藏"
        }
    }

    // MARK: - Computed Display Properties

    private var displayName: String {
        profileData?.name ?? partner.name
    }

    private var displayGender: String? {
        if let gender = profileData?.gender, !gender.isEmpty { return gender }
        return partner.gender.isEmpty ? nil : partner.gender
    }

    private var displayAge: Int? {
        if let birthDate = profileData?.birthDate ?? (partner.birthDate.isEmpty ? nil : partner.birthDate),
           let date = parseBirthDate(birthDate) {
            return age(from: date)
        }

        let year = profileData?.birthYear ?? partner.birthYear
        guard year > 0 else { return nil }
        let currentYear = Calendar.current.component(.year, from: .now)
        let value = currentYear - year
        return value > 0 && value < 120 ? value : nil
    }

    private var displayCity: String? {
        if let city = profileData?.city, !city.isEmpty { return city }
        return partner.city.isEmpty ? nil : partner.city
    }

    private var displayOccupation: String? {
        if let occupation = profileData?.occupation, !occupation.isEmpty { return occupation }
        return partner.occupation.isEmpty ? nil : partner.occupation
    }

    // MARK: - Data Loading

    private func loadProfile() async {
        do {
            let data = try await APIClient.shared.getUserProfile(userId: partner.id)
            await MainActor.run {
                profileData = data
                isLoading = false
            }
        } catch {
            await MainActor.run {
                loadFailed = true
                isLoading = false
            }
        }
    }

    private func parseBirthDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private func age(from date: Date) -> Int? {
        var value = Calendar.current.component(.year, from: .now) - Calendar.current.component(.year, from: date)
        let birthComponents = Calendar.current.dateComponents([.month, .day], from: date)
        let todayComponents = Calendar.current.dateComponents([.month, .day], from: .now)
        if let birthMonth = birthComponents.month,
           let birthDay = birthComponents.day,
           let todayMonth = todayComponents.month,
           let todayDay = todayComponents.day,
           todayMonth < birthMonth || (todayMonth == birthMonth && todayDay < birthDay) {
            value -= 1
        }
        return value > 0 && value < 120 ? value : nil
    }

    private func formattedDate(_ value: String?, dateFormat: String) -> String? {
        guard let value else { return nil }
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = parser.date(from: value)
        if date == nil {
            parser.formatOptions = [.withInternetDateTime]
            date = parser.date(from: value)
        }
        guard let date else { return nil }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = dateFormat
        return formatter.string(from: date)
    }
}

private extension View {
    func profileCardStyle() -> some View {
        self
            .padding(16)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
            .shadow(color: AppTheme.shadowColor, radius: AppTheme.shadowRadius, y: AppTheme.shadowY)
    }
}
