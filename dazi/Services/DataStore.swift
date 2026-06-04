import Foundation
import SwiftUI

@Observable
class DataStore {
    var currentUser: User = .placeholder
    var isRegistered: Bool = false
    var agentMessages: [Message] = []
    var events: [Event] = []
    var chatRooms: [ChatRoom] = []
    var passiveMatchRequests: [PassiveMatchRequest] = []
    var memories: [AgentMemory] = []
    var selectedTab: Int = 0
    var unreadChatCount: Int = 0
    var pendingChatRoomId: String?

    // MARK: - Toast
    var currentToast: ToastItem?
    private var toastTask: Task<Void, Never>?
    private var pollingTask: Task<Void, Never>?

    let locationManager = LocationManager()
    private let profileStore = UserProfileStore()
    private let api = APIClient.shared
    private let ws = WebSocketService.shared

    init() {
        if let savedUser = profileStore.loadUser() {
            currentUser = savedUser
            User.currentUser = savedUser
            isRegistered = true
            // 延迟加载数据，避免阻塞 app 启动
            DispatchQueue.main.async { [self] in
                loadInitialData()
            }
        }
    }

    func logout() {
        pollingTask?.cancel()
        pollingTask = nil
        ws.disconnect()
        profileStore.clearUser()
        api.clearTokens()
        isRegistered = false
        currentUser = .placeholder
        User.currentUser = .placeholder
        agentMessages = []
        events = []
        chatRooms = []
        passiveMatchRequests = []
        memories = []
        selectedTab = 0
        unreadChatCount = 0
    }

    // MARK: - Returning User Login

    /// 老用户登录：从服务器拉取 profile，恢复本地状态
    func loginAsReturningUser() {
        Task {
            do {
                let apiUser = try await api.getMe()
                let apiAgent = try await api.getMyAgent()

                await MainActor.run {
                    let user = User(
                        id: apiUser.id,
                        name: apiUser.name,
                        city: apiUser.city ?? "",
                        bio: apiUser.bio ?? "",
                        gender: apiUser.gender ?? "",
                        birthYear: apiUser.birthYear ?? 0,
                        interests: apiUser.interests ?? [],
                        occupation: apiUser.occupation ?? "",
                        customInterests: apiUser.customInterests ?? "",
                        welcomeDisturb: apiUser.welcomeDisturb ?? false,
                        agentName: apiAgent.name,
                        agentEmoji: apiAgent.emoji ?? "🤖",
                        agentPersonality: apiAgent.personality ?? "贴心、有趣"
                    )
                    currentUser = user
                    User.currentUser = user
                    profileStore.saveUser(user)
                    isRegistered = true
                    loadInitialData()
                }
            } catch {
                print("Load profile from server error: \(error)")
                // 回退到登录
                await MainActor.run {
                    api.clearTokens()
                    isRegistered = false
                }
            }
        }
    }

    // MARK: - Agent Chat (用户对话模式)

    func sendMessageToAgent(_ text: String) {
        let userMsg = Message.userMessage(text)
        agentMessages.append(userMsg)

        let typing = Message.typingIndicator()
        agentMessages.append(typing)

        Task {
            await sendMessageViaBackend(text)
        }
    }

    /// Agent chat via backend API (protects API key)
    private func sendMessageViaBackend(_ text: String) async {
        do {
            let chatResponse = try await api.chatWithAgent(message: text)

            removeTypingIndicator()

            var agentMsg = Message.agentMessage(chatResponse.reply)
            if chatResponse.eventDraftPending == true {
                agentMsg.showConfirmButtons = true
            }
            agentMessages.append(agentMsg)

            // 后端已创建或更新事件
            if chatResponse.eventReady, let eventId = chatResponse.eventId {
                let isEditing = events.contains(where: { $0.id == eventId })

                if isEditing {
                    // 编辑模式：刷新已有事件
                    Task {
                        await refreshEventFromServer(eventId: eventId)
                    }
                    let updateMsg = Message.agentMessage("活动已更新！继续为你寻找合适的搭子~")
                    agentMessages.append(updateMsg)
                } else {
                    // 新建模式：创建本地记录
                    let event = Event(
                        id: eventId,
                        userId: currentUser.id,
                        activityType: "其他",
                        title: "新活动",
                        description: "",
                        startTime: .now,
                        endTime: .now,
                        location: "",
                        preferences: [],
                        constraints: [],
                        status: .pending,
                        matchedUserId: nil,
                        chatRoomId: nil,
                        createdAt: .now
                    )
                    events.insert(event, at: 0)

                    // 从服务器拉取完整事件信息
                    Task {
                        await refreshEventFromServer(eventId: eventId)
                    }

                    let publishMsg = Message.agentMessage("活动已发布，正在为你寻找合适的搭子，请耐心等待！")
                    agentMessages.append(publishMsg)
                }
            }

        } catch {
            removeTypingIndicator()
            print("Backend chat error: \(error)")
            let errorMsg = Message.agentMessage("抱歉，暂时无法连接服务器，请检查网络后重试~")
            agentMessages.append(errorMsg)
        }
    }

    /// 从服务器拉取事件详情，更新本地记录
    private func refreshEventFromServer(eventId: String) async {
        do {
            let apiEvent = try await api.getEvent(id: eventId)
            if let idx = events.firstIndex(where: { $0.id == eventId }) {
                events[idx].title = apiEvent.title
                events[idx].activityType = apiEvent.activityType
                events[idx].location = apiEvent.location ?? ""
                events[idx].preferences = apiEvent.preferences ?? []
                events[idx].constraints = apiEvent.constraints ?? []
            }
        } catch {
            print("Failed to refresh event from server: \(error)")
        }
    }

    // MARK: - ChatRoom Messages

    func sendMessageInRoom(_ roomId: String, text: String) {
        guard let idx = chatRooms.firstIndex(where: { $0.id == roomId }) else { return }

        // 乐观地先在本地显示用户消息
        let msg = Message.userMessage(text)
        chatRooms[idx].messages.append(msg)

        // 检测 @agent
        let agents = chatRooms[idx].participants.filter { $0.isAgent }
        let mentionedAgentNames = agents.filter { agent in
            text.contains("@\(agent.name)") || text.contains("@agent")
        }.map(\.name)

        Task {
            do {
                // 通过后端 API 发送消息
                let _ = try await api.sendRoomMessage(
                    roomId: roomId,
                    content: text,
                    mentions: mentionedAgentNames.isEmpty ? nil : mentionedAgentNames
                )

                // Agent 回复会通过 WebSocket 实时推送，无需轮询
            } catch {
                print("Send room message error: \(error)")
                await MainActor.run {
                    if let i = chatRooms.firstIndex(where: { $0.id == roomId }) {
                        let errorMsg = Message.systemMessage("消息发送失败，请重试")
                        chatRooms[i].messages.append(errorMsg)
                    }
                }
            }
        }
    }

    /// 从服务器拉取聊天室消息，合并到本地
    func fetchRoomMessages(roomId: String) async {
        do {
            let apiMessages = try await api.getRoomMessages(roomId: roomId)
            await MainActor.run {
                guard let idx = chatRooms.firstIndex(where: { $0.id == roomId }) else { return }
                let existingIds = Set(chatRooms[idx].messages.map(\.id))
                for apiMsg in apiMessages {
                    if !existingIds.contains(apiMsg.id) {
                        let role: MessageRole = switch apiMsg.senderType {
                        case "agent": .agent
                        case "system": .system
                        default: apiMsg.senderId == currentUser.id ? .user : .partner
                        }
                        // 查找发送者信息（agent 消息用 "agent_" 前缀匹配）
                        let senderId = apiMsg.senderType == "agent" ? "agent_\(apiMsg.senderId)" : apiMsg.senderId
                        let sender = chatRooms[idx].participants.first(where: { $0.id == senderId })
                        let message = Message(
                            id: apiMsg.id,
                            content: apiMsg.content,
                            role: role,
                            senderName: sender?.name ?? (role == .system ? "系统" : "用户"),
                            senderAvatar: sender?.avatarEmoji ?? "😊",
                            senderAvatarImageData: sender?.avatarImageData
                        )
                        chatRooms[idx].messages.append(message)
                    }
                }
            }
        } catch {
            print("Fetch room messages error: \(error)")
        }
    }

    // MARK: - Event Feedback

    func submitFeedback(eventId: String, rating: Int, comment: String) {
        if let idx = events.firstIndex(where: { $0.id == eventId }) {
            events[idx].status = .completed
        }

        if let roomIdx = chatRooms.firstIndex(where: { $0.eventId == eventId }) {
            chatRooms[roomIdx].isActive = false
            chatRooms[roomIdx].closedAt = .now
            let closeMsg = Message.systemMessage("活动已结束，聊天室已关闭。感谢参与！")
            chatRooms[roomIdx].messages.append(closeMsg)
        }

        // Feedback进入hidden memory (memory设计.md 2.5 + prd.md 7.4)
        if !comment.isEmpty {
            let memory = AgentMemory(
                userId: currentUser.id,
                type: .feedback,
                content: comment,
                confidence: 0.8,
                source: "event_feedback"
            )
            memories.append(memory)
        }
    }

    // MARK: - Event Cancel & Edit

    /// 取消一个 pending 状态的事件
    func cancelEvent(_ eventId: String) {
        Task {
            do {
                let _ = try await api.cancelEvent(id: eventId)
                await MainActor.run {
                    if let idx = events.firstIndex(where: { $0.id == eventId }) {
                        events[idx].status = .cancelled
                    }
                    showToast("活动已取消", type: .info)
                }
            } catch {
                await MainActor.run {
                    showToast(userFriendlyError(error), type: .error)
                }
            }
        }
    }

    /// 发起编辑事件：将事件信息带回到 Agent 对话，进入编辑模式
    func startEditEvent(_ eventId: String) {
        guard let event = events.first(where: { $0.id == eventId }) else { return }

        // 添加一条用户消息表示要编辑
        let userMsg = Message.userMessage("我想修改活动「\(event.title)」")
        agentMessages.append(userMsg)

        let typing = Message.typingIndicator()
        agentMessages.append(typing)

        // 切换到聊天 tab
        selectedTab = 0

        Task {
            do {
                let chatResponse = try await api.startEditEvent(id: eventId)

                await MainActor.run {
                    removeTypingIndicator()
                    var agentMsg = Message.agentMessage(chatResponse.reply)
                    if chatResponse.eventDraftPending == true {
                        agentMsg.showConfirmButtons = true
                    }
                    agentMessages.append(agentMsg)
                }
            } catch {
                await MainActor.run {
                    removeTypingIndicator()
                    showToast(userFriendlyError(error), type: .error)
                    let errorMsg = Message.agentMessage("抱歉，暂时无法编辑活动，请稍后再试。")
                    agentMessages.append(errorMsg)
                }
            }
        }
    }

    func markRoomAsRead(_ roomId: String) {
        if let idx = chatRooms.firstIndex(where: { $0.id == roomId }) {
            if chatRooms[idx].hasUnread {
                chatRooms[idx].hasUnread = false
                unreadChatCount = max(0, unreadChatCount - 1)
            }
        }
    }

    // MARK: - Toast

    @MainActor
    func showToast(_ message: String, type: ToastItem.ToastType = .info, duration: TimeInterval = 3.0) {
        toastTask?.cancel()
        currentToast = ToastItem(message: message, type: type, duration: duration)
        toastTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            if !Task.isCancelled {
                currentToast = nil
            }
        }
    }

    @MainActor
    func dismissToast() {
        toastTask?.cancel()
        currentToast = nil
    }

    /// Format an error into a user-friendly Chinese message
    private func userFriendlyError(_ error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .networkError:
                return "无法连接服务器，请检查网络"
            case .unauthorized:
                return "登录已过期，请重新注册"
            case .serverError(let code, _):
                return "服务器错误 (\(code))，请稍后重试"
            case .noToken:
                return "未登录，请重新注册"
            default:
                return apiError.errorDescription ?? "未知错误"
            }
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "没有网络连接"
            case .timedOut:
                return "连接超时，服务器可能未启动"
            case .cannotConnectToHost, .cannotFindHost:
                return "无法连接服务器，请检查服务器是否运行"
            default:
                return "网络错误: \(urlError.localizedDescription)"
            }
        }
        return error.localizedDescription
    }

    // MARK: - Helpers

    private func removeTypingIndicator() {
        if let typingIndex = agentMessages.firstIndex(where: { $0.isTyping }) {
            agentMessages.remove(at: typingIndex)
        }
    }

    // MARK: - Initial Data

    func loadInitialData() {
        let userName = currentUser.name
        let agName = currentUser.agentName
        let interestsHint = currentUser.interests.isEmpty
            ? "比如周末想看电影、找人一起徒步、想吃顿好的~"
            : "比如\(currentUser.interests.prefix(3).joined(separator: "、"))？"

        let greeting = Message(
            content: "你好\(userName)！我是\(agName)，你的专属搭子经纪人。\n\n告诉我你想做什么活动，我来帮你找到最合适的搭子！\(interestsHint)",
            role: .agent,
            senderName: agName,
            senderAvatar: currentUser.agentEmoji,
            senderAvatarImageData: currentUser.agentAvatarImageData
        )
        agentMessages = [greeting]

        // 从服务器拉取数据
        Task {
            await fetchAllFromServer()
        }

        // 启动 WebSocket 实时连接
        setupWebSocket()

        // 启动低频轮询作为 fallback（WebSocket 断连时仍可同步）
        startPolling()
    }

    // MARK: - WebSocket

    private func setupWebSocket() {
        ws.onNewMessage = { [weak self] roomId, payload in
            self?.handleWSNewMessage(roomId: roomId, payload: payload)
        }
        ws.onEventUpdate = { [weak self] eventId, status in
            self?.handleWSEventUpdate(eventId: eventId, status: status)
        }
        ws.onRoomCreated = { [weak self] _ in
            // 新聊天室创建，拉取最新列表
            Task { [weak self] in
                await self?.fetchChatRoomsFromServer()
            }
        }
        ws.onMatchRequestCreated = { [weak self] _ in
            Task { [weak self] in
                await self?.fetchPassiveMatchRequestsFromServer()
            }
        }
        ws.connect()
    }

    private func handleWSNewMessage(roomId: String, payload: WSMessagePayload) {
        guard let idx = chatRooms.firstIndex(where: { $0.id == roomId }) else {
            // 未知聊天室，拉取列表
            Task { await fetchChatRoomsFromServer() }
            return
        }

        // 去重：如果消息已存在则跳过
        guard !chatRooms[idx].messages.contains(where: { $0.id == payload.id }) else { return }

        // 跳过自己发的消息（已通过乐观更新显示）
        if payload.senderType == "user" && payload.senderId == currentUser.id { return }

        let role: MessageRole = switch payload.senderType {
        case "agent": .agent
        case "system": .system
        default: payload.senderId == currentUser.id ? .user : .partner
        }

        // agent 消息用 "agent_" 前缀匹配 participants
        let senderId = payload.senderType == "agent" ? "agent_\(payload.senderId)" : payload.senderId
        let sender = chatRooms[idx].participants.first(where: { $0.id == senderId })
        let message = Message(
            id: payload.id,
            content: payload.content,
            role: role,
            senderName: sender?.name ?? (role == .system ? "系统" : "用户"),
            senderAvatar: sender?.avatarEmoji ?? "😊",
            senderAvatarImageData: sender?.avatarImageData
        )
        chatRooms[idx].messages.append(message)

        // 标记未读（如果不在当前聊天室）
        if selectedTab != 2 || pendingChatRoomId != roomId {
            chatRooms[idx].hasUnread = true
            unreadChatCount = chatRooms.filter(\.hasUnread).count
        }
    }

    private func handleWSEventUpdate(eventId: String, status: String) {
        if let idx = events.firstIndex(where: { $0.id == eventId }) {
            if let newStatus = EventStatus(rawValue: status) {
                events[idx].status = newStatus
            }
        }
        // 匹配成功时拉取最新聊天室
        if status == "matched" || status == "active" {
            Task { await fetchChatRoomsFromServer() }
        }
    }

    // MARK: - Server Data Sync

    func fetchAllFromServer() async {
        async let e: () = fetchEventsFromServer()
        async let c: () = fetchChatRoomsFromServer()
        async let m: () = fetchMemoriesFromServer()
        async let r: () = fetchPassiveMatchRequestsFromServer()
        _ = await (e, c, m, r)
    }

    func fetchEventsFromServer() async {
        do {
            let apiEvents = try await api.getEvents()
            await MainActor.run {
                events = apiEvents.map { Event(from: $0) }
            }
        } catch {
            print("Fetch events error: \(error)")
        }
    }

    func fetchChatRoomsFromServer() async {
        do {
            let apiRooms = try await api.getChatRooms()
            await MainActor.run {
                let oldRooms = chatRooms
                chatRooms = apiRooms.map { apiRoom in
                    var room = ChatRoom(from: apiRoom)
                    // 保留已加载的本地消息
                    if let old = oldRooms.first(where: { $0.id == room.id }) {
                        room.messages = old.messages
                        room.hasUnread = old.hasUnread
                    }
                    return room
                }
                unreadChatCount = chatRooms.filter(\.hasUnread).count
            }
        } catch {
            print("Fetch chat rooms error: \(error)")
        }
    }

    func fetchPassiveMatchRequestsFromServer() async {
        do {
            let apiRequests = try await api.getMatchRequests()
            await MainActor.run {
                passiveMatchRequests = apiRequests
                    .map { PassiveMatchRequest(from: $0) }
                    .filter { $0.status == "pending" }
            }
        } catch {
            print("Fetch passive match requests error: \(error)")
        }
    }

    func respondPassiveMatchRequest(_ requestId: String, action: String) {
        Task {
            do {
                let _ = try await api.respondMatchRequest(id: requestId, action: action)
                await MainActor.run {
                    passiveMatchRequests.removeAll { $0.id == requestId }
                    showToast(action == "accept" ? "已接受邀请，聊天室已创建" : "已暂不接受", type: .info)
                }
                if action == "accept" {
                    await fetchChatRoomsFromServer()
                    await fetchEventsFromServer()
                }
            } catch {
                await MainActor.run {
                    showToast(userFriendlyError(error), type: .error)
                }
            }
        }
    }

    func fetchMemoriesFromServer() async {
        do {
            let apiMemories = try await api.getMyMemories()
            await MainActor.run {
                memories = apiMemories.map { AgentMemory(from: $0) }
            }
        } catch {
            print("Fetch memories error: \(error)")
        }
    }

    // MARK: - Polling

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                // WebSocket 提供实时更新，轮询仅作为 fallback（120 秒）
                try? await Task.sleep(for: .seconds(120))
                guard !Task.isCancelled else { break }
                await fetchEventsFromServer()
                await fetchChatRoomsFromServer()
                await fetchPassiveMatchRequestsFromServer()
            }
        }
    }
}
