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
    private let notifications = NotificationService.shared
    private var notifiedRoomCreationIds: Set<String> = []

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
        notifications.unregisterStoredRemoteDeviceTokenBeforeLogout()
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
        pendingChatRoomId = nil
        notifiedRoomCreationIds = []
        notifications.updateBadge(0)
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
                        birthDate: apiUser.birthDate ?? "",
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
        let pendingMessageId = pendingClarificationMessageId
        let initialAgentContent = shouldShowPublishingIndicator(for: text)
            ? Message.publishingContent
            : ""
        let userMsg = Message.userMessage(text)
        agentMessages.append(userMsg)

        let typing = Message.typingIndicator()
        agentMessages.append(typing)

        Task {
            if let pendingMessageId {
                await submitClarificationViaBackend(
                    messageId: pendingMessageId,
                    answers: [],
                    freeText: text
                )
            } else {
                await sendMessageViaBackend(text, initialAgentContent: initialAgentContent)
            }
        }
    }

    /// Agent chat via backend API (protects API key)
    private func sendMessageViaBackend(_ text: String, initialAgentContent: String = "") async {
        let agentMessage = Message.agentMessage(initialAgentContent)
        await MainActor.run {
            removeTypingIndicator()
            agentMessages.append(agentMessage)
        }

        do {
            let currentLocation = locationManager.hasLocation ? locationManager.promptLocationDescription : nil
            try await api.streamAgentChat(
                message: text,
                currentLocation: currentLocation
            ) { [weak self] event in
                await MainActor.run {
                    self?.applyAgentStreamEvent(event, to: agentMessage.id)
                }
            }

        } catch {
            print("Backend chat error: \(error)")
            await MainActor.run {
                if let idx = agentMessages.firstIndex(where: { $0.id == agentMessage.id }),
                   shouldReplaceFailedStreamMessage(agentMessages[idx]) {
                    agentMessages[idx].content = "抱歉，\(userFriendlyError(error))，请稍后重试~"
                } else {
                    showToast(userFriendlyError(error), type: .error)
                }
            }
        }
    }

    func submitClarification(
        messageId: String,
        answers: [ClarificationAnswerInput],
        freeText: String?
    ) {
        guard let idx = agentMessages.firstIndex(where: { $0.id == messageId }) else { return }

        agentMessages[idx].clarificationSubmitted = true

        let typing = Message.typingIndicator()
        agentMessages.append(typing)

        Task {
            await submitClarificationViaBackend(
                messageId: messageId,
                answers: answers,
                freeText: freeText
            )
        }
    }

    private func submitClarificationViaBackend(
        messageId: String,
        answers: [ClarificationAnswerInput],
        freeText: String?
    ) async {
        guard let idx = agentMessages.firstIndex(where: { $0.id == messageId }),
              let sessionId = agentMessages[idx].clarificationSessionId
        else {
            removeTypingIndicator()
            return
        }

        agentMessages[idx].clarificationSubmitted = true

        let agentMessage = Message.agentMessage("")
        await MainActor.run {
            removeTypingIndicator()
            agentMessages.append(agentMessage)
        }

        do {
            try await api.streamClarificationAnswers(
                sessionId: sessionId,
                answers: answers,
                freeText: freeText
            ) { [weak self] event in
                await MainActor.run {
                    self?.applyAgentStreamEvent(event, to: agentMessage.id)
                }
            }
        } catch {
            await MainActor.run {
                if let currentIndex = agentMessages.firstIndex(where: { $0.id == messageId }) {
                    agentMessages[currentIndex].clarificationSubmitted = false
                }
                if let idx = agentMessages.firstIndex(where: { $0.id == agentMessage.id }),
                   agentMessages[idx].content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    agentMessages.remove(at: idx)
                }
                showToast(userFriendlyError(error), type: .error)
            }
        }
    }

    /// 从服务器拉取事件详情，更新本地记录
    private func refreshEventFromServer(eventId: String) async {
        do {
            let apiEvent = try await api.getEvent(id: eventId)
            let event = Event(from: apiEvent)
            await MainActor.run {
                if let idx = events.firstIndex(where: { $0.id == eventId }) {
                    events[idx] = event
                } else {
                    events.insert(event, at: 0)
                }
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
        let optimisticMessageId = msg.id
        chatRooms[idx].messages.append(msg)

        // 检测 @agent
        let agents = chatRooms[idx].participants.filter { $0.isAgent }
        let mentionedAgentNames = agents.filter { agent in
            text.contains("@\(agent.name)") || text.contains("@agent")
        }.map(\.name)

        Task {
            do {
                // 通过后端 API 发送消息
                let apiMessage = try await api.sendRoomMessage(
                    roomId: roomId,
                    content: text,
                    mentions: mentionedAgentNames.isEmpty ? nil : mentionedAgentNames
                )

                await MainActor.run {
                    replaceOptimisticRoomMessage(
                        roomId: roomId,
                        optimisticMessageId: optimisticMessageId,
                        with: apiMessage
                    )
                }
            } catch {
                print("Send room message error: \(error)")
                await MainActor.run {
                    if let i = chatRooms.firstIndex(where: { $0.id == roomId }) {
                        chatRooms[i].messages.removeAll { $0.id == optimisticMessageId }
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
                for apiMsg in apiMessages {
                    let message = makeRoomMessage(from: apiMsg, roomIndex: idx)
                    mergeRoomMessage(message, inRoomAt: idx)
                }
            }
        } catch {
            print("Fetch room messages error: \(error)")
        }
    }

    private func replaceOptimisticRoomMessage(
        roomId: String,
        optimisticMessageId: String,
        with apiMessage: APIChatMessageResponse
    ) {
        guard let idx = chatRooms.firstIndex(where: { $0.id == roomId }) else { return }
        let message = makeRoomMessage(from: apiMessage, roomIndex: idx)
        mergeRoomMessage(message, inRoomAt: idx, replacingLocalId: optimisticMessageId)
    }

    private func mergeRoomMessage(
        _ message: Message,
        inRoomAt roomIndex: Int,
        replacingLocalId localId: String? = nil
    ) {
        if let localId, localId != message.id {
            chatRooms[roomIndex].messages.removeAll { $0.id == localId }
        }

        if let existingIndex = chatRooms[roomIndex].messages.firstIndex(where: { $0.id == message.id }) {
            chatRooms[roomIndex].messages[existingIndex] = message
        } else {
            chatRooms[roomIndex].messages.append(message)
        }
    }

    private func makeRoomMessage(from apiMsg: APIChatMessageResponse, roomIndex: Int) -> Message {
        let role: MessageRole = switch apiMsg.senderType {
        case "agent": .agent
        case "system": .system
        default: apiMsg.senderId == currentUser.id ? .user : .partner
        }
        let senderId = apiMsg.senderType == "agent" ? "agent_\(apiMsg.senderId)" : apiMsg.senderId
        let sender = chatRooms[roomIndex].participants.first(where: { $0.id == senderId })
        return Message(
            id: apiMsg.id,
            content: apiMsg.content,
            role: role,
            senderName: sender?.name ?? (role == .system ? "系统" : "用户"),
            senderAvatar: sender?.avatarEmoji ?? "😊",
            senderAvatarImageData: sender?.avatarImageData,
            timestamp: parseAgentHistoryDate(apiMsg.createdAt)
        )
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
                notifications.updateBadge(unreadChatCount)
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
        agentMessages = [agentGreetingMessage()]
        notifications.requestAuthorizationIfNeeded()
        notifications.registerStoredRemoteDeviceTokenIfAvailable()

        // 从服务器拉取数据
        Task {
            await fetchAgentHistoryFromServer()
            await fetchAllFromServer()
            await restorePendingClarificationFromServer()
        }

        // 启动 WebSocket 实时连接
        setupWebSocket()

        // 启动低频轮询作为 fallback（WebSocket 断连时仍可同步）
        startPolling()
    }

    private func agentGreetingMessage() -> Message {
        let interestsHint = currentUser.interests.isEmpty
            ? "比如周末想看电影、找人一起徒步、想吃顿好的~"
            : "比如\(currentUser.interests.prefix(3).joined(separator: "、"))？"
        return Message(
            content: "你好\(currentUser.name)！我是\(currentUser.agentName)，你的专属搭子经纪人。\n\n告诉我你想做什么活动，我来帮你找到最合适的搭子！\(interestsHint)",
            role: .agent,
            senderName: currentUser.agentName,
            senderAvatar: currentUser.agentEmoji,
            senderAvatarImageData: currentUser.agentAvatarImageData
        )
    }

    private func fetchAgentHistoryFromServer() async {
        do {
            let history = try await api.getAgentHistory()
            let restored = history.compactMap { makeAgentHistoryMessage(from: $0) }
            guard !restored.isEmpty else { return }
            await MainActor.run {
                agentMessages = restored
            }
        } catch {
            print("Fetch agent history error: \(error)")
        }
    }

    private func makeAgentHistoryMessage(from apiMessage: APIAgentHistoryMessage) -> Message? {
        let content = apiMessage.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return nil }
        let role: MessageRole
        let senderName: String
        let senderAvatar: String
        let senderAvatarImageData: Data?
        switch apiMessage.role.lowercased() {
        case "user":
            role = .user
            senderName = currentUser.name
            senderAvatar = currentUser.avatarEmoji
            senderAvatarImageData = currentUser.avatarImageData
        case "assistant", "agent":
            role = .agent
            senderName = currentUser.agentName
            senderAvatar = currentUser.agentEmoji
            senderAvatarImageData = currentUser.agentAvatarImageData
        default:
            role = .system
            senderName = "系统"
            senderAvatar = "ℹ️"
            senderAvatarImageData = nil
        }
        return Message(
            id: apiMessage.id,
            content: content,
            role: role,
            senderName: senderName,
            senderAvatar: senderAvatar,
            senderAvatarImageData: senderAvatarImageData,
            timestamp: parseAgentHistoryDate(apiMessage.createdAt)
        )
    }

    private func parseAgentHistoryDate(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value) ?? .now
    }

    private var pendingClarificationMessageId: String? {
        agentMessages.last(where: {
            !$0.clarificationSubmitted
            && $0.clarificationSessionId != nil
            && !$0.clarificationQuestions.isEmpty
        })?.id
    }

    private func shouldShowPublishingIndicator(for text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard ["确认", "确认发布", "ok", "okay"].contains(normalized) else {
            return false
        }
        return agentMessages.contains {
            $0.showConfirmButtons && ($0.confirmButtonsTapped || !$0.clarificationSubmitted)
        }
    }

    private func appendAgentResponse(_ response: APIAgentChatResponse) {
        var agentMsg = Message.agentMessage(
            response.reply,
            clarificationSessionId: response.clarificationSessionId,
            clarificationQuestions: response.clarificationQuestions ?? []
        )
        if response.eventDraftPending == true && response.clarificationPending != true {
            agentMsg.showConfirmButtons = true
        }
        agentMessages.append(agentMsg)
    }

    private func applyAgentStreamEvent(_ event: AgentStreamEvent, to messageId: String) {
        let decoder = JSONDecoder()
        switch event.event {
        case "reply_delta", "draft_delta":
            guard let payload = try? decoder.decode(AgentDeltaPayload.self, from: event.data),
                  let idx = agentMessages.firstIndex(where: { $0.id == messageId })
            else { return }
            if agentMessages[idx].content == Message.publishingContent {
                agentMessages[idx].content = payload.text
            } else {
                agentMessages[idx].content += payload.text
            }

        case "clarify":
            guard let payload = try? decoder.decode(AgentClarifyPayload.self, from: event.data),
                  let idx = agentMessages.firstIndex(where: { $0.id == messageId })
            else { return }
            agentMessages[idx].clarificationSessionId = payload.sessionId
            agentMessages[idx].clarificationQuestions = payload.questions
            agentMessages[idx].showConfirmButtons = false

        case "clarify_question_delta":
            guard let payload = try? decoder.decode(AgentClarifyQuestionDeltaPayload.self, from: event.data),
                  let idx = agentMessages.firstIndex(where: { $0.id == messageId })
            else { return }
            agentMessages[idx].clarificationSessionId = payload.sessionId
            if let existingIndex = agentMessages[idx].clarificationQuestions.firstIndex(where: { $0.id == payload.question.id }) {
                agentMessages[idx].clarificationQuestions[existingIndex] = payload.question
            } else {
                agentMessages[idx].clarificationQuestions.append(payload.question)
            }
            agentMessages[idx].showConfirmButtons = false

        case "draft_ready":
            guard let payload = try? decoder.decode(AgentDraftReadyPayload.self, from: event.data),
                  payload.eventDraftPending,
                  let idx = agentMessages.firstIndex(where: { $0.id == messageId })
            else { return }
            agentMessages[idx].showConfirmButtons = true

        case "event_ready":
            guard let payload = try? decoder.decode(AgentEventReadyPayload.self, from: event.data),
                  payload.eventReady,
                  let eventId = payload.eventId
            else { return }
            handleAgentEventReady(eventId: eventId, messageId: messageId)

        case "error":
            if let payload = try? decoder.decode(AgentErrorPayload.self, from: event.data) {
                if let idx = agentMessages.firstIndex(where: { $0.id == messageId }),
                   shouldReplaceFailedStreamMessage(agentMessages[idx]) {
                    agentMessages[idx].content = payload.message
                } else {
                    showToast(payload.message, type: .error)
                }
            }

        default:
            break
        }
    }

    private func handleAgentEventReady(eventId: String, messageId: String) {
        clearDraftConfirmationState()
        let isEditing = events.contains(where: { $0.id == eventId })
        if isEditing {
            Task {
                await refreshEventFromServer(eventId: eventId)
            }
            updateAgentMessage(messageId, fallback: "活动已更新！继续为你寻找合适的搭子~")
            return
        }

        Task {
            await refreshEventFromServer(eventId: eventId)
        }
        updateAgentMessage(messageId, fallback: "活动已发布，正在为你寻找合适的搭子，请耐心等待！")
        appendAgentSessionDividerIfNeeded()
    }

    private func updateAgentMessage(_ messageId: String, fallback: String) {
        if let idx = agentMessages.firstIndex(where: { $0.id == messageId }) {
            agentMessages[idx].content = fallback
        } else {
            agentMessages.append(Message.agentMessage(fallback))
        }
    }

    private func appendAgentSessionDividerIfNeeded() {
        let text = "活动已发布。下面为你开启新的对话。"
        if agentMessages.last?.role == .system && agentMessages.last?.content == text {
            return
        }
        agentMessages.append(Message.systemMessage(text))
    }

    private func clearDraftConfirmationState() {
        for idx in agentMessages.indices where agentMessages[idx].showConfirmButtons {
            agentMessages[idx].showConfirmButtons = false
            agentMessages[idx].confirmButtonsTapped = true
        }
    }

    private func shouldReplaceFailedStreamMessage(_ message: Message) -> Bool {
        message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || message.content == Message.publishingContent
    }

    private func restorePendingClarificationFromServer() async {
        do {
            let response = try await api.fetchPendingClarification()
            guard response.clarificationPending == true,
                  let sessionId = response.clarificationSessionId,
                  let questions = response.clarificationQuestions,
                  !questions.isEmpty
            else { return }

            await MainActor.run {
                guard !agentMessages.contains(where: { $0.clarificationSessionId == sessionId }) else { return }
                let reply = response.reply.isEmpty
                    ? "我先帮你确认几个会影响匹配的小问题。"
                    : response.reply
                let message = Message.agentMessage(
                    reply,
                    clarificationSessionId: sessionId,
                    clarificationQuestions: questions
                )
                agentMessages.append(message)
            }
        } catch {
            print("Fetch pending clarification error: \(error)")
        }
    }

    // MARK: - WebSocket

    private func setupWebSocket() {
        ws.onNewMessage = { [weak self] roomId, payload in
            self?.handleWSNewMessage(roomId: roomId, payload: payload)
        }
        ws.onEventUpdate = { [weak self] eventId, status in
            self?.handleWSEventUpdate(eventId: eventId, status: status)
        }
        ws.onRoomCreated = { [weak self] roomData in
            self?.handleWSRoomCreated(roomData: roomData)
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
            Task {
                await fetchChatRoomsFromServer()
                await MainActor.run {
                    guard let roomIndex = chatRooms.firstIndex(where: { $0.id == roomId }) else { return }
                    notifyNewRoomMessage(roomIndex: roomIndex, payload: payload)
                }
            }
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

        let shouldNotify = selectedTab != 2 || pendingChatRoomId != roomId
        if shouldNotify {
            chatRooms[idx].hasUnread = true
            unreadChatCount = chatRooms.filter(\.hasUnread).count
            notifications.updateBadge(unreadChatCount)
            notifyNewRoomMessage(roomIndex: idx, payload: payload)
        }
    }

    private func handleWSRoomCreated(roomData: [String: Any]) {
        let roomId = roomData["id"] as? String ?? roomData["room_id"] as? String

        Task {
            await fetchChatRoomsFromServer()
            await MainActor.run {
                guard let roomId,
                      !notifiedRoomCreationIds.contains(roomId),
                      let idx = chatRooms.firstIndex(where: { $0.id == roomId })
                else { return }

                notifiedRoomCreationIds.insert(roomId)
                chatRooms[idx].hasUnread = true
                unreadChatCount = chatRooms.filter(\.hasUnread).count
                notifications.updateBadge(unreadChatCount)
                notifications.notifyRoomCreated(
                    roomTitle: chatRooms[idx].displayTitle,
                    roomId: roomId
                )
            }
        }
    }

    private func notifyNewRoomMessage(roomIndex: Int, payload: WSMessagePayload) {
        guard chatRooms.indices.contains(roomIndex) else { return }
        let room = chatRooms[roomIndex]
        let senderId = payload.senderType == "agent" ? "agent_\(payload.senderId)" : payload.senderId
        let sender = room.participants.first(where: { $0.id == senderId })
        let senderName: String
        switch payload.senderType {
        case "agent":
            senderName = sender?.name ?? "AI"
        case "system":
            senderName = "系统"
        default:
            senderName = sender?.name ?? "搭子"
        }

        notifications.notifyNewMessage(
            roomTitle: room.displayTitle,
            senderName: senderName,
            content: payload.content,
            roomId: payload.roomId,
            messageId: payload.id
        )
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
                    applyLocalAvatars(to: &room)
                    // 保留已加载的本地消息
                    if let old = oldRooms.first(where: { $0.id == room.id }) {
                        room.messages = old.messages
                        room.hasUnread = old.hasUnread
                    }
                    return room
                }
                unreadChatCount = chatRooms.filter(\.hasUnread).count
                notifications.updateBadge(unreadChatCount)
            }
        } catch {
            print("Fetch chat rooms error: \(error)")
        }
    }

    private func applyLocalAvatars(to room: inout ChatRoom) {
        for index in room.participants.indices {
            if room.participants[index].id == currentUser.id {
                room.participants[index].avatarEmoji = currentUser.avatarEmoji
                room.participants[index].avatarImageData = currentUser.avatarImageData
            } else if room.participants[index].id == "agent_\(currentUser.id)" {
                room.participants[index].name = currentUser.agentName
                room.participants[index].avatarEmoji = currentUser.agentEmoji
                room.participants[index].avatarImageData = currentUser.agentAvatarImageData
            }
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

    func updateMemory(_ memory: AgentMemory, content: String) {
        Task {
            do {
                let updated = try await api.updateMemory(id: memory.id, content: content)
                await MainActor.run {
                    if let index = memories.firstIndex(where: { $0.id == memory.id }) {
                        memories[index] = AgentMemory(from: updated)
                    }
                    showToast("记忆已更新", type: .info)
                }
            } catch {
                await MainActor.run {
                    showToast(userFriendlyError(error), type: .error)
                }
            }
        }
    }

    func deleteMemory(_ memory: AgentMemory) {
        Task {
            do {
                try await api.deleteMemory(id: memory.id)
                await MainActor.run {
                    memories.removeAll { $0.id == memory.id }
                    showToast("记忆已删除", type: .info)
                }
            } catch {
                await MainActor.run {
                    showToast(userFriendlyError(error), type: .error)
                }
            }
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
