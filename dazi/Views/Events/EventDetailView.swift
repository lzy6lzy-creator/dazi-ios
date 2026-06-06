import SwiftUI

struct EventDetailView: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(\.dismiss) private var dismiss
    let event: Event
    @State private var showFeedback = false
    @State private var showCancelConfirm = false

    private var matchedPartner: User? {
        if let room = dataStore.chatRooms.first(where: { $0.eventId == event.id }) {
            return room.participants.first(where: { !$0.isAgent && $0.id != dataStore.currentUser.id })
        }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerCard
                detailsCard

                if !event.preferences.isEmpty || !event.constraints.isEmpty {
                    preferencesCard
                }

                if event.status == .matched || event.status == .active {
                    matchCard
                }

                if event.status == .pending {
                    pendingActionButtons
                }

                if event.status == .matched || event.status == .active {
                    goToChatButton
                }

                if event.status == .active || event.status == .matched {
                    endEventButton
                }
            }
            .padding()
        }
        .background(AppTheme.backgroundColor)
        .navigationTitle(event.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showFeedback) {
            EventFeedbackView(eventId: event.id)
        }
        .alert("确定取消活动？", isPresented: $showCancelConfirm) {
            Button("取消活动", role: .destructive) {
                dataStore.cancelEvent(event.id)
                dismiss()
            }
            Button("再想想", role: .cancel) {}
        } message: {
            Text("取消后活动将不再参与匹配")
        }
    }

    private var headerCard: some View {
        VStack(spacing: 16) {
            Image(systemName: AppTheme.activityTypeIcon(event.activityType))
                .font(.system(size: 40))
                .foregroundStyle(.white)
                .frame(width: 80, height: 80)
                .background(AppTheme.activityTypeColor(event.activityType))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusXL))

            Text(event.title)
                .font(.title2)
                .fontWeight(.bold)

            StatusBadge(status: event.status)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusXL))
        .shadow(color: AppTheme.shadowColor, radius: AppTheme.shadowRadius, y: AppTheme.shadowY)
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("活动详情")
                .font(.headline)

            HStack {
                DetailRow(icon: "tag", title: "类型", value: event.activityType)
                Circle()
                    .fill(AppTheme.activityTypeColor(event.activityType))
                    .frame(width: 8, height: 8)
            }
            DetailRow(icon: "clock", title: "开始时间", value: formatDate(event.startTime))
            DetailRow(icon: "clock.badge.checkmark", title: "结束时间", value: formatDate(event.endTime))
            if !event.city.isEmpty {
                DetailRow(icon: "building.2", title: "城市", value: event.city)
            }
            DetailRow(icon: "mappin.and.ellipse", title: "地点", value: event.location.isEmpty ? "待定" : event.location)
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
        .shadow(color: AppTheme.shadowColor, radius: AppTheme.shadowRadius, y: AppTheme.shadowY)
    }

    private var preferencesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("偏好 & 要求")
                .font(.headline)

            if !event.preferences.isEmpty {
                ForEach(event.preferences, id: \.self) { pref in
                    Label(pref, systemImage: "heart")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if !event.constraints.isEmpty {
                ForEach(event.constraints, id: \.self) { constraint in
                    Label(constraint, systemImage: "xmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(.red.opacity(0.7))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
        .shadow(color: AppTheme.shadowColor, radius: AppTheme.shadowRadius, y: AppTheme.shadowY)
    }

    private var pendingActionButtons: some View {
        VStack(spacing: 12) {
            Button {
                dataStore.startEditEvent(event.id)
                dismiss()
            } label: {
                Label("修改活动", systemImage: "pencil.line")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.primaryColor)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
            }
            .buttonStyle(PrimaryButtonStyle())

            Button {
                showCancelConfirm = true
            } label: {
                Label("取消活动", systemImage: "xmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.red.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMD))
                    .overlay(RoundedRectangle(cornerRadius: AppTheme.radiusMD).stroke(Color.red.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    private var matchCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(AppTheme.secondaryColor)
                Text("已匹配搭子")
                    .font(.headline)
            }

            HStack(spacing: 12) {
                AvatarView(
                    imageData: matchedPartner?.avatarImageData,
                    emoji: matchedPartner?.avatarEmoji ?? "🌸",
                    size: 44,
                    backgroundColor: AppTheme.secondaryColor.opacity(0.15)
                )

                VStack(alignment: .leading) {
                    Text(matchedPartner?.name ?? "搭子")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(matchedPartner?.bio ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
        .shadow(color: AppTheme.shadowColor, radius: AppTheme.shadowRadius, y: AppTheme.shadowY)
    }

    private var goToChatButton: some View {
        Button {
            if let room = dataStore.chatRooms.first(where: { $0.eventId == event.id }) {
                dataStore.pendingChatRoomId = room.id
                dataStore.selectedTab = 2
                dataStore.markRoomAsRead(room.id)
                dismiss()
            }
        } label: {
            Label("进入聊天室", systemImage: "bubble.left.and.bubble.right.fill")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.secondaryColor)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
        }
        .buttonStyle(PrimaryButtonStyle())
    }

    private var endEventButton: some View {
        Button {
            showFeedback = true
        } label: {
            Label("结束活动并评价", systemImage: "checkmark.circle")
                .font(.headline)
                .foregroundStyle(AppTheme.primaryColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.primaryColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
        }
        .buttonStyle(SecondaryButtonStyle())
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "待定" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE HH:mm"
        return formatter.string(from: date)
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(AppTheme.primaryColor)
                .frame(width: 24)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
        }
    }
}
