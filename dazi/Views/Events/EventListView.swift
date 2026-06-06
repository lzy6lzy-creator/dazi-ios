import SwiftUI

struct EventListView: View {
    @Environment(DataStore.self) private var dataStore
    @State private var emptyStateAnimating = false

    var body: some View {
        NavigationStack {
            Group {
                if dataStore.events.isEmpty {
                    emptyState
                } else {
                    eventList
                }
            }
            .background(AppTheme.backgroundColor)
            .navigationTitle("我的活动")
        }
    }

    private var eventList: some View {
        List {
            ForEach(dataStore.events) { event in
                NavigationLink(destination: EventDetailView(event: event)) {
                    EventCard(event: event)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if event.status == .pending {
                        Button(role: .destructive) {
                            dataStore.cancelEvent(event.id)
                        } label: {
                            Label("取消", systemImage: "xmark.circle")
                        }

                        Button {
                            dataStore.startEditEvent(event.id)
                        } label: {
                            Label("修改", systemImage: "pencil")
                        }
                        .tint(AppTheme.primaryColor)
                    }
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await dataStore.fetchEventsFromServer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.primaryColor.opacity(0.5))
                .scaleEffect(emptyStateAnimating ? 1.08 : 1.0)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: emptyStateAnimating)
                .onAppear { emptyStateAnimating = true }

            Text("还没有活动")
                .font(.title3)
                .fontWeight(.medium)

            Text("去和点点聊聊，告诉她你想做什么")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                dataStore.selectedTab = 0
            } label: {
                Text("找点点聊聊")
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(AppTheme.primaryColor)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EventCard: View {
    let event: Event

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: AppTheme.activityTypeIcon(event.activityType))
                    .font(.title2)
                    .foregroundStyle(AppTheme.activityTypeColor(event.activityType))
                    .frame(width: 44, height: 44)
                    .background(AppTheme.activityTypeColor(event.activityType).opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMD))

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    HStack(spacing: AppTheme.spacingXS) {
                        Circle()
                            .fill(AppTheme.activityTypeColor(event.activityType))
                            .frame(width: 6, height: 6)
                        Text(event.activityType)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                StatusBadge(status: event.status)
            }

            Divider()

            HStack(spacing: 16) {
                Label(formatDate(event.startTime), systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label(locationText, systemImage: "mappin")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
        .shadow(color: AppTheme.shadowColor, radius: AppTheme.shadowRadius, y: AppTheme.shadowY)
    }

    private var locationText: String {
        let parts = [event.city, event.location].filter { !$0.isEmpty }
        return parts.isEmpty ? "待定" : parts.joined(separator: " · ")
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "时间待定" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: date)
    }
}

struct StatusBadge: View {
    let status: EventStatus

    var body: some View {
        Text(status.rawValue)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(AppTheme.statusColor(for: status))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(AppTheme.statusColor(for: status).opacity(0.12))
            .clipShape(Capsule())
    }
}
