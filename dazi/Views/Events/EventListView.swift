import SwiftUI

struct EventListView: View {
    @Environment(DataStore.self) private var dataStore
    @State private var emptyStateAnimating = false
    @State private var listScope: EventListScope = .mine
    @State private var statusFilter: EventStatusFilter = .all
    @State private var dateFilter: EventDateFilter = .all
    @State private var sortOption: EventSortOption = .smart

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                scopePicker

                switch listScope {
                case .mine:
                    if dataStore.events.isEmpty {
                        emptyState
                    } else {
                        eventList
                    }
                case .plaza:
                    plazaList
                }
            }
            .background(AppTheme.backgroundColor)
            .navigationTitle("活动")
            .onChange(of: listScope) { _, newValue in
                if newValue == .plaza && dataStore.plazaEvents.isEmpty {
                    Task {
                        await dataStore.fetchPlazaEventsFromServer()
                    }
                }
            }
        }
    }

    private var scopePicker: some View {
        Picker("活动范围", selection: $listScope) {
            Text("我的活动").tag(EventListScope.mine)
            Text("活动广场").tag(EventListScope.plaza)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var eventList: some View {
        VStack(spacing: 0) {
            filterBar

            if visibleEvents.isEmpty {
                filteredEmptyState
            } else {
                List {
                    ForEach(visibleEvents) { event in
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
        }
    }

    private var plazaList: some View {
        Group {
            if dataStore.plazaEvents.isEmpty {
                plazaEmptyState
            } else {
                List {
                    ForEach(dataStore.plazaEvents) { event in
                        PlazaEventCard(event: event)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await dataStore.fetchPlazaEventsFromServer()
                }
            }
        }
    }

    private var visibleEvents: [Event] {
        EventListQuery(
            statusFilter: statusFilter,
            dateFilter: dateFilter,
            sortOption: sortOption,
            now: .now
        ).apply(to: dataStore.events)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                statusMenu
                dateMenu
                sortMenu
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(AppTheme.backgroundColor)
    }

    private var statusMenu: some View {
        Menu {
            Picker("状态", selection: $statusFilter) {
                ForEach(EventStatusFilter.allCases) { option in
                    Label(option.title, systemImage: option.icon).tag(option)
                }
            }
        } label: {
            filterChip(icon: statusFilter.icon, title: statusFilter.title)
        }
    }

    private var dateMenu: some View {
        Menu {
            Picker("时间", selection: $dateFilter) {
                ForEach(EventDateFilter.allCases) { option in
                    Label(option.title, systemImage: option.icon).tag(option)
                }
            }
        } label: {
            filterChip(icon: dateFilter.icon, title: dateFilter.title)
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("排序", selection: $sortOption) {
                ForEach(EventSortOption.allCases) { option in
                    Label(option.title, systemImage: option.icon).tag(option)
                }
            }
        } label: {
            filterChip(icon: sortOption.icon, title: sortOption.title)
        }
    }

    private func filterChip(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
            Image(systemName: "chevron.down")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var filteredEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 42))
                .foregroundStyle(.secondary.opacity(0.55))
            Text("没有符合条件的活动")
                .font(.headline)
            Button("清除筛选") {
                statusFilter = .all
                dateFilter = .all
                sortOption = .smart
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(AppTheme.primaryColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private var plazaEmptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.secondaryColor.opacity(0.55))
            Text("广场暂时没有待匹配活动")
                .font(.headline)
            Text("等有人发布新的待匹配活动后，会匿名出现在这里")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await dataStore.fetchPlazaEventsFromServer()
        }
    }
}

enum EventListScope: Hashable {
    case mine
    case plaza
}

enum EventStatusFilter: Hashable, CaseIterable, Identifiable {
    case all
    case pending
    case matching
    case matched
    case active
    case completed
    case cancelled

    var id: Self { self }

    var title: String {
        switch self {
        case .all: return "全部状态"
        case .pending: return "等待匹配"
        case .matching: return "匹配中"
        case .matched: return "已匹配"
        case .active: return "进行中"
        case .completed: return "已完成"
        case .cancelled: return "已取消"
        }
    }

    var icon: String {
        switch self {
        case .all: return "tray.full"
        case .pending: return "clock.badge.questionmark"
        case .matching: return "arrow.triangle.branch"
        case .matched: return "person.2"
        case .active: return "bolt"
        case .completed: return "checkmark.circle"
        case .cancelled: return "xmark.circle"
        }
    }

    var status: EventStatus? {
        switch self {
        case .all: return nil
        case .pending: return .pending
        case .matching: return .matching
        case .matched: return .matched
        case .active: return .active
        case .completed: return .completed
        case .cancelled: return .cancelled
        }
    }
}

enum EventDateFilter: Hashable, CaseIterable, Identifiable {
    case all
    case today
    case upcoming
    case thisWeek
    case past

    var id: Self { self }

    var title: String {
        switch self {
        case .all: return "全部时间"
        case .today: return "今天"
        case .upcoming: return "未来"
        case .thisWeek: return "本周"
        case .past: return "过去"
        }
    }

    var icon: String {
        switch self {
        case .all: return "calendar"
        case .today: return "sun.max"
        case .upcoming: return "calendar.badge.clock"
        case .thisWeek: return "calendar.day.timeline.left"
        case .past: return "clock.arrow.circlepath"
        }
    }

    func contains(_ event: Event, now: Date, calendar: Calendar) -> Bool {
        switch self {
        case .all:
            return true
        case .today:
            guard let start = event.startTime else { return false }
            return calendar.isDate(start, inSameDayAs: now)
        case .upcoming:
            guard let start = event.startTime else { return true }
            return start >= calendar.startOfDay(for: now)
        case .thisWeek:
            guard let start = event.startTime,
                  let interval = calendar.dateInterval(of: .weekOfYear, for: now) else {
                return false
            }
            return interval.contains(start)
        case .past:
            guard let start = event.startTime else { return false }
            return start < calendar.startOfDay(for: now)
        }
    }
}

enum EventSortOption: Hashable, CaseIterable, Identifiable {
    case smart
    case startAsc
    case startDesc
    case createdDesc
    case status

    var id: Self { self }

    var title: String {
        switch self {
        case .smart: return "默认排序"
        case .startAsc: return "时间最近"
        case .startDesc: return "时间最远"
        case .createdDesc: return "最新创建"
        case .status: return "状态优先"
        }
    }

    var icon: String {
        switch self {
        case .smart: return "sparkles"
        case .startAsc: return "arrow.up.forward"
        case .startDesc: return "arrow.down.forward"
        case .createdDesc: return "plus.circle"
        case .status: return "flag"
        }
    }
}

struct EventListQuery {
    var statusFilter: EventStatusFilter
    var dateFilter: EventDateFilter
    var sortOption: EventSortOption
    var now: Date
    var calendar: Calendar = Calendar(identifier: .gregorian)

    func apply(to events: [Event]) -> [Event] {
        var calendar = calendar
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.firstWeekday = 2

        return events
            .filter { event in
                if let selectedStatus = statusFilter.status, event.status != selectedStatus {
                    return false
                }
                return dateFilter.contains(event, now: now, calendar: calendar)
            }
            .sorted { lhs, rhs in
                compare(lhs, rhs, calendar: calendar)
            }
    }

    private func compare(_ lhs: Event, _ rhs: Event, calendar: Calendar) -> Bool {
        switch sortOption {
        case .smart:
            let leftRank = smartRank(lhs, now: now, calendar: calendar)
            let rightRank = smartRank(rhs, now: now, calendar: calendar)
            if leftRank != rightRank { return leftRank < rightRank }
            return earlierStart(lhs, rhs)
        case .startAsc:
            return earlierStart(lhs, rhs)
        case .startDesc:
            return laterStart(lhs, rhs)
        case .createdDesc:
            return lhs.createdAt > rhs.createdAt
        case .status:
            let leftRank = statusRank(lhs.status)
            let rightRank = statusRank(rhs.status)
            if leftRank != rightRank { return leftRank < rightRank }
            return earlierStart(lhs, rhs)
        }
    }

    private func earlierStart(_ lhs: Event, _ rhs: Event) -> Bool {
        switch (lhs.startTime, rhs.startTime) {
        case let (left?, right?): return left < right
        case (_?, nil): return true
        case (nil, _?): return false
        case (nil, nil): return lhs.createdAt > rhs.createdAt
        }
    }

    private func laterStart(_ lhs: Event, _ rhs: Event) -> Bool {
        switch (lhs.startTime, rhs.startTime) {
        case let (left?, right?): return left > right
        case (_?, nil): return true
        case (nil, _?): return false
        case (nil, nil): return lhs.createdAt > rhs.createdAt
        }
    }

    private func smartRank(_ event: Event, now: Date, calendar: Calendar) -> Int {
        if event.status == .cancelled || event.status == .completed {
            return 3
        }
        guard let start = event.startTime else {
            return 1
        }
        return start < calendar.startOfDay(for: now) ? 2 : 0
    }

    private func statusRank(_ status: EventStatus) -> Int {
        switch status {
        case .pending: return 0
        case .matching: return 1
        case .matched: return 2
        case .active: return 3
        case .completed: return 4
        case .cancelled: return 5
        }
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

struct PlazaEventCard: View {
    let event: PlazaEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: AppTheme.activityTypeIcon(event.activityType))
                    .font(.title2)
                    .foregroundStyle(AppTheme.activityTypeColor(event.activityType))
                    .frame(width: 44, height: 44)
                    .background(AppTheme.activityTypeColor(event.activityType).opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMD))

                VStack(alignment: .leading, spacing: 5) {
                    Text(event.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Label("匿名发布", systemImage: "person.crop.circle.badge.questionmark")
                        Text(event.activityType)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 16) {
                Label(formatDate(event.startTime), systemImage: "clock")
                Label(locationText, systemImage: "mappin")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            tagRows
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
        .shadow(color: AppTheme.shadowColor, radius: AppTheme.shadowRadius, y: AppTheme.shadowY)
    }

    private var tagRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !event.preferences.isEmpty {
                tagLine(title: "偏好", values: event.preferences)
            }
            if !event.constraints.isEmpty {
                tagLine(title: "约束", values: event.constraints)
            }
        }
    }

    private func tagLine(title: String, values: [String]) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .leading)

            FlowTagLine(values: Array(values.prefix(4)))
        }
    }

    private var locationText: String {
        let parts = [event.city, event.location].filter { !$0.isEmpty }
        return parts.isEmpty ? "地点待定" : parts.joined(separator: " · ")
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "时间待定" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: date)
    }
}

struct FlowTagLine: View {
    let values: [String]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                tags
            }

            VStack(alignment: .leading, spacing: 6) {
                tags
            }
        }
    }

    private var tags: some View {
        ForEach(values, id: \.self) { value in
            Text(value)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(AppTheme.primaryColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.primaryColor.opacity(0.1))
                .clipShape(Capsule())
        }
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
