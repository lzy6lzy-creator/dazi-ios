import SwiftUI

struct PartnerProfileView: View {
    let partner: User
    @State private var profileData: APIUserResponse?
    @State private var isLoading = true
    @State private var loadFailed = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    avatarSection
                    infoSection
                    interestsSection
                    bioSection
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
                    Text(gender)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(AppTheme.primaryColor.opacity(0.1))
                        .clipShape(Capsule())
                }

                if let age = displayAge {
                    Text("\(age)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(AppTheme.secondaryColor.opacity(0.1))
                        .clipShape(Capsule())
                }

                if let city = displayCity, !city.isEmpty {
                    HStack(spacing: 2) {
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

    @ViewBuilder
    private var infoSection: some View {
        if let occupation = profileData?.occupation, !occupation.isEmpty {
            HStack {
                Image(systemName: "briefcase")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                Text(occupation)
                    .font(.subheadline)
                Spacer()
            }
            .padding(16)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
            .shadow(color: AppTheme.shadowColor, radius: AppTheme.shadowRadius, y: AppTheme.shadowY)
        }
    }

    @ViewBuilder
    private var interestsSection: some View {
        let interests = profileData?.interests ?? []
        if !interests.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "heart")
                        .foregroundStyle(AppTheme.primaryColor)
                    Text("兴趣")
                        .font(.headline)
                }

                FlowLayout(spacing: 6) {
                    ForEach(interests, id: \.self) { interest in
                        Text(interest)
                            .font(.caption2)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(AppTheme.agentColor.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(16)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
            .shadow(color: AppTheme.shadowColor, radius: AppTheme.shadowRadius, y: AppTheme.shadowY)
        }
    }

    @ViewBuilder
    private var bioSection: some View {
        let bio = profileData?.bio ?? partner.bio
        if !bio.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "text.quote")
                        .foregroundStyle(AppTheme.secondaryColor)
                    Text("简介")
                        .font(.headline)
                }
                Text(bio)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
            .shadow(color: AppTheme.shadowColor, radius: AppTheme.shadowRadius, y: AppTheme.shadowY)
        }
    }

    // MARK: - Computed Display Properties

    private var displayName: String {
        profileData?.name ?? partner.name
    }

    private var displayGender: String? {
        if let g = profileData?.gender, !g.isEmpty { return g }
        return partner.gender.isEmpty ? nil : partner.gender
    }

    private var displayAge: String? {
        let year = profileData?.birthYear ?? partner.birthYear
        guard year > 0 else { return nil }
        let currentYear = Calendar.current.component(.year, from: .now)
        let age = currentYear - year
        return age > 0 && age < 120 ? "\(age)" : nil
    }

    private var displayCity: String? {
        if let c = profileData?.city, !c.isEmpty { return c }
        return partner.city.isEmpty ? nil : partner.city
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
}
