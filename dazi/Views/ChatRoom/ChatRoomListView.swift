import SwiftUI

struct ChatRoomListView: View {
    @Environment(DataStore.self) private var dataStore
    @State private var navigateToRoomId: String?
    @State private var emptyStateAnimating = false

    var body: some View {
        NavigationStack {
            Group {
                if dataStore.chatRooms.isEmpty && dataStore.passiveMatchRequests.isEmpty {
                    emptyState
                } else {
                    roomList
                }
            }
            .background(AppTheme.backgroundColor)
            .navigationTitle("搭子聊天")
            .navigationDestination(item: $navigateToRoomId) { roomId in
                ChatRoomDetailView(roomId: roomId)
            }
            .onChange(of: dataStore.pendingChatRoomId) { _, newValue in
                if let roomId = newValue {
                    navigateToRoomId = roomId
                    dataStore.pendingChatRoomId = nil
                }
            }
            .onAppear {
                if let roomId = dataStore.pendingChatRoomId {
                    navigateToRoomId = roomId
                    dataStore.pendingChatRoomId = nil
                }
            }
        }
    }

    private var roomList: some View {
        List {
            if !dataStore.passiveMatchRequests.isEmpty {
                Section("待确认邀请") {
                    ForEach(dataStore.passiveMatchRequests) { request in
                        PassiveMatchRequestRow(
                            request: request,
                            onAccept: {
                                dataStore.respondPassiveMatchRequest(request.id, action: "accept")
                            },
                            onReject: {
                                dataStore.respondPassiveMatchRequest(request.id, action: "reject")
                            }
                        )
                    }
                }
            }

            if !negotiatingRooms.isEmpty {
                Section("AI 协商中") {
                    ForEach(negotiatingRooms) { room in
                        NavigationLink(destination: ChatRoomDetailView(roomId: room.id)) {
                            ChatRoomRow(room: room)
                        }
                    }
                }
            }

            if !matchedRooms.isEmpty {
                Section("已匹配聊天室") {
                    ForEach(matchedRooms) { room in
                        NavigationLink(destination: ChatRoomDetailView(roomId: room.id)) {
                            ChatRoomRow(room: room)
                        }
                    }
                }
            }

            if !closedRooms.isEmpty {
                Section("已结束") {
                    ForEach(closedRooms) { room in
                        NavigationLink(destination: ChatRoomDetailView(roomId: room.id)) {
                            ChatRoomRow(room: room)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            async let rooms: () = dataStore.fetchChatRoomsFromServer()
            async let requests: () = dataStore.fetchPassiveMatchRequestsFromServer()
            _ = await (rooms, requests)
        }
    }

    private var negotiatingRooms: [ChatRoom] {
        dataStore.chatRooms.filter { $0.isActive && $0.isNegotiating }
    }

    private var matchedRooms: [ChatRoom] {
        dataStore.chatRooms.filter { $0.isActive && !$0.isNegotiating }
    }

    private var closedRooms: [ChatRoom] {
        dataStore.chatRooms.filter { !$0.isActive }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.secondaryColor.opacity(0.5))
                .scaleEffect(emptyStateAnimating ? 1.08 : 1.0)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: emptyStateAnimating)
                .onAppear { emptyStateAnimating = true }

            Text("还没有聊天室")
                .font(.title3)
                .fontWeight(.medium)

            Text("当 AI 开始协商或活动匹配成功后，聊天室会自动出现")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PassiveMatchRequestRow: View {
    let request: PassiveMatchRequest
    let onAccept: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.title3)
                    .foregroundStyle(AppTheme.primaryColor)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.primaryColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMD))

                VStack(alignment: .leading, spacing: 4) {
                    Text(request.eventTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    Text("\(request.requesterName) 想和你搭这次活动")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if let similarity = request.similarity {
                    Text("\(Int(similarity * 100))%")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            if !request.message.isEmpty {
                Text(request.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 10) {
                Button(role: .destructive, action: onReject) {
                    Label("暂不", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(action: onAccept) {
                    Label("接受", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .padding(.vertical, 6)
    }
}

struct ChatRoomRow: View {
    let room: ChatRoom

    private var partnerName: String {
        room.participants.first(where: { !$0.isAgent && $0.id != User.currentUser.id })?.name ?? "搭子"
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                let partner = room.participants.first(where: { !$0.isAgent && $0.id != User.currentUser.id })
                AvatarView(
                    imageData: partner?.avatarImageData,
                    emoji: partner?.avatarEmoji ?? "🌸",
                    size: 50,
                    backgroundColor: room.isActive ? AppTheme.secondaryColor.opacity(0.15) : Color.gray.opacity(0.1)
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(room.displayTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    Spacer()

                    if let lastMsg = room.lastMessage {
                        Text(timeAgo(lastMsg.timestamp))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    if let lastMsg = room.lastMessage {
                        Text(lastMsg.role == .system ? lastMsg.content : "\(lastMsg.senderName): \(lastMsg.content)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if room.hasUnread {
                        Circle()
                            .fill(AppTheme.primaryColor)
                            .frame(width: 10, height: 10)
                    }

                    if room.isNegotiating {
                        Text("AI 协商中")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.agentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.agentColor.opacity(0.12))
                            .clipShape(Capsule())
                    }

                    if !room.isActive {
                        Text("已关闭")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date.now.timeIntervalSince(date)
        if interval < 60 { return "刚刚" }
        if interval < 3600 { return "\(Int(interval / 60))分钟前" }
        if interval < 86400 { return "\(Int(interval / 3600))小时前" }
        return "\(Int(interval / 86400))天前"
    }
}
