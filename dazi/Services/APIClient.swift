import Foundation

// MARK: - API Configuration

enum APIConfig {
    // 内部 TestFlight 临时入口；ICP备案完成后切回 https://idabuda.com。
    static let baseURL = "http://47.103.127.95"
}

// MARK: - API Errors

enum APIError: Error, LocalizedError {
    case invalidURL
    case unauthorized
    case serverError(Int, String)
    case decodingError(String)
    case networkError(String)
    case noToken

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .unauthorized: return "Unauthorized - please login again"
        case .serverError(let code, let msg): return "Server error (\(code)): \(msg)"
        case .decodingError(let msg): return "Decoding error: \(msg)"
        case .networkError(let msg): return "Network error: \(msg)"
        case .noToken: return "No auth token available"
        }
    }
}

// MARK: - API Response Types

struct AuthTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let userId: String
    let isNewUser: Bool?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case userId = "user_id"
        case isNewUser = "is_new_user"
    }
}

struct APIUserResponse: Codable {
    let id: String
    let name: String
    let phone: String?
    let gender: String?
    let birthYear: Int?
    let birthDate: String?
    let bio: String?
    let avatarUrl: String?
    let interests: [String]?
    let city: String?
    let occupation: String?
    let customInterests: String?
    let welcomeDisturb: Bool?
    let profileEventVisibility: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, phone, gender, bio, interests, city, occupation
        case birthYear = "birth_year"
        case birthDate = "birth_date"
        case avatarUrl = "avatar_url"
        case customInterests = "custom_interests"
        case welcomeDisturb = "welcome_disturb"
        case profileEventVisibility = "profile_event_visibility"
        case createdAt = "created_at"
    }
}

struct APIPublicProfileEventResponse: Codable {
    let id: String
    let title: String
    let activityType: String
    let detailLevel: String
    let timeLabel: String?
    let startTime: String?
    let endTime: String?
    let location: String?
    let city: String?
    let description: String?
    let preferences: [String]?
    let constraints: [String]?
    let status: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, title, location, city, description, preferences, constraints, status
        case activityType = "activity_type"
        case detailLevel = "detail_level"
        case timeLabel = "time_label"
        case startTime = "start_time"
        case endTime = "end_time"
        case createdAt = "created_at"
    }
}

struct APIPublicUserProfileResponse: Codable {
    let id: String
    let name: String
    let gender: String?
    let birthYear: Int?
    let birthDate: String?
    let bio: String?
    let avatarUrl: String?
    let interests: [String]?
    let city: String?
    let occupation: String?
    let customInterests: String?
    let welcomeDisturb: Bool?
    let profileEventVisibility: String?
    let pastEvents: [APIPublicProfileEventResponse]?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, gender, bio, interests, city, occupation
        case birthYear = "birth_year"
        case birthDate = "birth_date"
        case avatarUrl = "avatar_url"
        case customInterests = "custom_interests"
        case welcomeDisturb = "welcome_disturb"
        case profileEventVisibility = "profile_event_visibility"
        case pastEvents = "past_events"
        case createdAt = "created_at"
    }
}

struct APIAgentResponse: Codable {
    let id: String
    let userId: String
    let name: String
    let emoji: String?
    let avatarUrl: String?
    let personality: String?

    enum CodingKeys: String, CodingKey {
        case id, name, emoji, personality
        case userId = "user_id"
        case avatarUrl = "avatar_url"
    }
}

struct APIAgentChatResponse: Codable {
    let reply: String
    let eventReady: Bool
    let eventId: String?
    let eventDraftPending: Bool?
    let clarificationPending: Bool?
    let clarificationSessionId: String?
    let clarificationQuestions: [ClarificationQuestion]?

    enum CodingKeys: String, CodingKey {
        case reply
        case eventReady = "event_ready"
        case eventId = "event_id"
        case eventDraftPending = "event_draft_pending"
        case clarificationPending = "clarification_pending"
        case clarificationSessionId = "clarification_session_id"
        case clarificationQuestions = "clarification_questions"
    }
}

struct AgentStreamEvent: Sendable {
    let event: String
    let data: Data
}

struct SSEParser {
    private var currentEvent: String?
    private var dataLines: [String] = []

    mutating func feed(line: String) -> AgentStreamEvent? {
        if line.isEmpty {
            return flush()
        }
        if line.hasPrefix("event:") {
            let pendingEvent = flush()
            currentEvent = String(line.dropFirst("event:".count))
                .trimmingCharacters(in: .whitespaces)
            return pendingEvent
        } else if line.hasPrefix("data:") {
            dataLines.append(
                String(line.dropFirst("data:".count))
                    .trimmingCharacters(in: .whitespaces)
            )
        }
        return nil
    }

    mutating func finish() -> AgentStreamEvent? {
        flush()
    }

    private mutating func flush() -> AgentStreamEvent? {
        guard let currentEvent else { return nil }
        let dataText = dataLines.joined(separator: "\n")
        self.currentEvent = nil
        self.dataLines = []
        return AgentStreamEvent(event: currentEvent, data: Data(dataText.utf8))
    }
}

struct AgentDeltaPayload: Decodable {
    let text: String
}

struct AgentClarifyPayload: Decodable {
    let sessionId: String
    let questions: [ClarificationQuestion]

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case questions
    }
}

struct AgentClarifyQuestionDeltaPayload: Decodable {
    let sessionId: String
    let question: ClarificationQuestion

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case question
    }
}

struct AgentDraftReadyPayload: Decodable {
    let eventDraftPending: Bool

    enum CodingKeys: String, CodingKey {
        case eventDraftPending = "event_draft_pending"
    }
}

struct AgentEventReadyPayload: Decodable {
    let eventReady: Bool
    let eventId: String?

    enum CodingKeys: String, CodingKey {
        case eventReady = "event_ready"
        case eventId = "event_id"
    }
}

struct AgentErrorPayload: Decodable {
    let message: String
}

struct APIAgentHistoryMessage: Codable {
    let id: String
    let role: String
    let content: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, role, content
        case createdAt = "created_at"
    }
}

struct APIEventResponse: Codable {
    let id: String
    let userId: String
    let title: String
    let activityType: String
    let startTime: String?
    let endTime: String?
    let location: String?
    let city: String?
    let preferences: [String]?
    let constraints: [String]?
    let status: String
    let matchScore: Double?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, title, location, city, preferences, constraints, status
        case userId = "user_id"
        case activityType = "activity_type"
        case startTime = "start_time"
        case endTime = "end_time"
        case matchScore = "match_score"
        case createdAt = "created_at"
    }
}

struct APIPlazaEventResponse: Codable {
    let id: String
    let title: String
    let activityType: String
    let startTime: String?
    let endTime: String?
    let location: String?
    let city: String?
    let preferences: [String]?
    let constraints: [String]?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, title, location, city, preferences, constraints
        case activityType = "activity_type"
        case startTime = "start_time"
        case endTime = "end_time"
        case createdAt = "created_at"
    }
}

// MARK: - Chat Room Response Types

struct APIChatRoomMemberResponse: Codable {
    let userId: String
    let name: String
    let role: String
    let emoji: String?
    let avatarUrl: String?
    let gender: String?
    let birthYear: Int?
    let birthDate: String?
    let bio: String?
    let city: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case avatarUrl = "avatar_url"
        case birthYear = "birth_year"
        case birthDate = "birth_date"
        case name, role, emoji
        case gender, bio, city
    }
}

struct APIChatRoomResponse: Codable {
    let id: String
    let eventIdA: String?
    let eventIdB: String?
    let eventTitle: String?
    let matchSummary: String?
    let agentDialogue: String?
    let phase: String
    let a2aCandidateRank: Int?
    let a2aResult: String?
    let isAnonymous: Bool
    let isActive: Bool
    let createdAt: String
    let closedAt: String?
    let members: [APIChatRoomMemberResponse]
    let lastMessage: APIChatMessageResponse?
    let hasUnread: Bool

    enum CodingKeys: String, CodingKey {
        case id, members
        case eventIdA = "event_id_a"
        case eventIdB = "event_id_b"
        case eventTitle = "event_title"
        case matchSummary = "match_summary"
        case agentDialogue = "agent_dialogue"
        case phase
        case a2aCandidateRank = "a2a_candidate_rank"
        case a2aResult = "a2a_result"
        case isAnonymous = "is_anonymous"
        case isActive = "is_active"
        case createdAt = "created_at"
        case closedAt = "closed_at"
        case lastMessage = "last_message"
        case hasUnread = "has_unread"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        eventIdA = try container.decodeIfPresent(String.self, forKey: .eventIdA)
        eventIdB = try container.decodeIfPresent(String.self, forKey: .eventIdB)
        eventTitle = try container.decodeIfPresent(String.self, forKey: .eventTitle)
        matchSummary = try container.decodeIfPresent(String.self, forKey: .matchSummary)
        agentDialogue = try container.decodeIfPresent(String.self, forKey: .agentDialogue)
        phase = try container.decodeIfPresent(String.self, forKey: .phase) ?? "matched"
        a2aCandidateRank = try container.decodeIfPresent(Int.self, forKey: .a2aCandidateRank)
        a2aResult = try container.decodeIfPresent(String.self, forKey: .a2aResult)
        isAnonymous = try container.decodeIfPresent(Bool.self, forKey: .isAnonymous) ?? false
        isActive = try container.decode(Bool.self, forKey: .isActive)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        closedAt = try container.decodeIfPresent(String.self, forKey: .closedAt)
        members = try container.decode([APIChatRoomMemberResponse].self, forKey: .members)
        lastMessage = try container.decodeIfPresent(APIChatMessageResponse.self, forKey: .lastMessage)
        hasUnread = try container.decodeIfPresent(Bool.self, forKey: .hasUnread) ?? false
    }
}

struct APIChatMessageResponse: Codable {
    let id: String
    let roomId: String
    let senderId: String
    let senderType: String
    let content: String
    let mentions: [String]?
    let visibility: String?
    let recipientUserId: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, content, mentions, visibility
        case roomId = "room_id"
        case senderId = "sender_id"
        case senderType = "sender_type"
        case recipientUserId = "recipient_user_id"
        case createdAt = "created_at"
    }
}

struct APIPassiveMatchRequestResponse: Codable {
    let id: String
    let eventId: String
    let eventTitle: String
    let requesterName: String
    let targetUserId: String
    let status: String
    let similarity: Double?
    let message: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, status, similarity, message
        case eventId = "event_id"
        case eventTitle = "event_title"
        case requesterName = "requester_name"
        case targetUserId = "target_user_id"
        case createdAt = "created_at"
    }
}

struct APIMemoryResponse: Codable {
    let id: String
    let type: String
    let content: String
    let confidence: Double
    let source: String
    let key: String?
    let category: String?
    let status: String?
    let occurrenceCount: Int?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, type, content, confidence, source, key, category, status
        case occurrenceCount = "occurrence_count"
        case createdAt = "created_at"
    }
}

// MARK: - API Client

final class APIClient {
    static let shared = APIClient()

    private let session = URLSession.shared
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    private init() {}

    // MARK: - Token Management

    private var accessToken: String? {
        get { UserDefaults.standard.string(forKey: "dazi_access_token") }
        set { UserDefaults.standard.set(newValue, forKey: "dazi_access_token") }
    }

    private var refreshToken: String? {
        get { UserDefaults.standard.string(forKey: "dazi_refresh_token") }
        set { UserDefaults.standard.set(newValue, forKey: "dazi_refresh_token") }
    }

    var serverUserId: String? {
        get { UserDefaults.standard.string(forKey: "dazi_server_user_id") }
        set { UserDefaults.standard.set(newValue, forKey: "dazi_server_user_id") }
    }

    var isLoggedIn: Bool {
        accessToken != nil
    }

    func saveTokens(_ response: AuthTokenResponse) {
        accessToken = response.accessToken
        refreshToken = response.refreshToken
        serverUserId = response.userId
        NotificationService.shared.registerStoredRemoteDeviceTokenIfAvailable()
    }

    func clearTokens() {
        accessToken = nil
        refreshToken = nil
        serverUserId = nil
    }

    // MARK: - Generic Request

    private func request<T: Decodable>(
        method: String,
        path: String,
        body: [String: Any]? = nil,
        authenticated: Bool = true,
        timeout: TimeInterval = 30
    ) async throws -> T {
        guard let url = URL(string: "\(APIConfig.baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = timeout

        if authenticated {
            guard let token = accessToken else { throw APIError.noToken }
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: req)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("Invalid response")
        }

        if httpResponse.statusCode == 401 {
            // Try token refresh
            if authenticated, let _ = refreshToken {
                try await doRefreshToken()
                // Retry once
                var retryReq = req
                retryReq.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
                let (retryData, retryResp) = try await session.data(for: retryReq)
                guard let retryHttp = retryResp as? HTTPURLResponse, retryHttp.statusCode == 200 else {
                    throw APIError.unauthorized
                }
                return try decoder.decode(T.self, from: retryData)
            }
            throw APIError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(httpResponse.statusCode, errorBody)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError("\(error)")
        }
    }

    /// Fire-and-forget request that returns a simple dictionary
    private func requestDict(
        method: String,
        path: String,
        body: [String: Any]? = nil,
        authenticated: Bool = true,
        timeout: TimeInterval = 30,
        authTokenOverride: String? = nil
    ) async throws -> [String: Any] {
        guard let url = URL(string: "\(APIConfig.baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = timeout

        if authenticated {
            guard let token = authTokenOverride ?? accessToken else { throw APIError.noToken }
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: req)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("Invalid response")
        }

        if httpResponse.statusCode == 401 {
            // Try token refresh
            if authenticated, let _ = refreshToken {
                try await doRefreshToken()
                var retryReq = req
                retryReq.setValue(
                    "Bearer \(accessToken ?? authTokenOverride ?? "")",
                    forHTTPHeaderField: "Authorization"
                )
                let (retryData, retryResp) = try await session.data(for: retryReq)
                guard let retryHttp = retryResp as? HTTPURLResponse else {
                    throw APIError.networkError("Invalid response")
                }
                guard (200...299).contains(retryHttp.statusCode) else {
                    let retryErrorBody = String(data: retryData, encoding: .utf8) ?? "Unknown"
                    throw APIError.serverError(retryHttp.statusCode, retryErrorBody)
                }
                return (try? JSONSerialization.jsonObject(with: retryData) as? [String: Any]) ?? [:]
            }
            throw APIError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
            throw APIError.serverError(code, errorBody)
        }

        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private func doRefreshToken() async throws {
        guard let rt = refreshToken else { throw APIError.noToken }
        let result: AuthTokenResponse = try await request(
            method: "POST",
            path: "/api/v1/auth/refresh",
            body: ["refresh_token": rt],
            authenticated: false
        )
        saveTokens(result)
        // Token 刷新后重连 WebSocket（使用新 token）
        WebSocketService.shared.connect()
    }

    // MARK: - Auth

    func sendVerificationCode(phone: String) async throws -> [String: Any] {
        try await requestDict(
            method: "POST",
            path: "/api/v1/auth/send-code",
            body: ["phone": phone],
            authenticated: false
        )
    }

    func login(phone: String, code: String) async throws -> AuthTokenResponse {
        let result: AuthTokenResponse = try await request(
            method: "POST",
            path: "/api/v1/auth/login",
            body: ["phone": phone, "code": code],
            authenticated: false
        )
        saveTokens(result)
        return result
    }

    // MARK: - User

    func getMe() async throws -> APIUserResponse {
        try await request(method: "GET", path: "/api/v1/users/me")
    }

    func updateMe(data: [String: Any]) async throws -> APIUserResponse {
        try await request(method: "PUT", path: "/api/v1/users/me", body: data)
    }

    // MARK: - Notifications

    func registerPushDeviceToken(token: String, environment: String) async throws {
        _ = try await requestDict(
            method: "POST",
            path: "/api/v1/notifications/device-token",
            body: [
                "token": token,
                "platform": "ios",
                "environment": environment,
            ]
        )
    }

    func unregisterPushDeviceToken(token: String, environment: String, authTokenOverride: String? = nil) async throws {
        _ = try await requestDict(
            method: "DELETE",
            path: "/api/v1/notifications/device-token",
            body: [
                "token": token,
                "platform": "ios",
                "environment": environment,
            ],
            authTokenOverride: authTokenOverride
        )
    }

    func unregisterPushDeviceTokenBeforeClearingAuth(token: String, environment: String) {
        guard let capturedAccessToken = accessToken else { return }
        Task {
            do {
                try await unregisterPushDeviceToken(
                    token: token,
                    environment: environment,
                    authTokenOverride: capturedAccessToken
                )
            } catch {
                print("[Notification] Unregister remote token error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Agent

    func getMyAgent() async throws -> APIAgentResponse {
        try await request(method: "GET", path: "/api/v1/agents/me")
    }

    func updateMyAgent(data: [String: Any]) async throws -> APIAgentResponse {
        try await request(method: "PUT", path: "/api/v1/agents/me", body: data)
    }

    func getMyMemories() async throws -> [APIMemoryResponse] {
        try await request(method: "GET", path: "/api/v1/agents/me/memories")
    }

    func updateMemory(id: String, content: String) async throws -> APIMemoryResponse {
        try await request(
            method: "PATCH",
            path: "/api/v1/agents/me/memories/\(id)",
            body: ["content": content]
        )
    }

    func deleteMemory(id: String) async throws {
        let _: [String: Bool] = try await request(
            method: "DELETE",
            path: "/api/v1/agents/me/memories/\(id)"
        )
    }

    // MARK: - Agent Chat

    private func streamRequest(
        path: String,
        body: [String: Any],
        onEvent: @escaping (AgentStreamEvent) async -> Void
    ) async throws {
        guard let url = URL(string: APIConfig.baseURL + path) else {
            throw APIError.invalidURL
        }
        guard let token = accessToken else {
            throw APIError.noToken
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError("Invalid response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.serverError(http.statusCode, "Stream request failed")
        }

        var parser = SSEParser()
        for try await line in bytes.lines {
            if let event = parser.feed(line: line) {
                await onEvent(event)
            }
        }
        if let event = parser.finish() {
            await onEvent(event)
        }
    }

    func streamAgentChat(
        message: String,
        currentLocation: String? = nil,
        onEvent: @escaping (AgentStreamEvent) async -> Void
    ) async throws {
        var body: [String: Any] = ["message": message]
        if let currentLocation, !currentLocation.isEmpty {
            body["current_location"] = currentLocation
        }
        try await streamRequest(
            path: "/api/v1/agent/chat/stream",
            body: body,
            onEvent: onEvent
        )
    }

    func chatWithAgent(message: String, currentLocation: String? = nil) async throws -> APIAgentChatResponse {
        var body: [String: Any] = ["message": message]
        if let currentLocation, !currentLocation.isEmpty {
            body["current_location"] = currentLocation
        }
        return try await request(
            method: "POST",
            path: "/api/v1/agent/chat",
            body: body,
            timeout: 120
        )
    }

    func getAgentHistory(limit: Int = 50) async throws -> [APIAgentHistoryMessage] {
        try await request(method: "GET", path: "/api/v1/agent/history?limit=\(limit)")
    }

    func fetchPendingClarification() async throws -> APIAgentChatResponse {
        try await request(method: "GET", path: "/api/v1/agent/clarification/pending")
    }

    func submitClarificationAnswers(
        sessionId: String,
        answers: [ClarificationAnswerInput],
        freeText: String?
    ) async throws -> APIAgentChatResponse {
        var bodyAnswers: [[String: Any]] = []
        for answer in answers {
            var item: [String: Any] = ["question_id": answer.questionId]
            if !answer.optionIds.isEmpty {
                item["option_ids"] = answer.optionIds
            }
            if let customValue = answer.customValue, !customValue.isEmpty {
                item["custom_value"] = customValue
            } else if let minAge = answer.minAge, let maxAge = answer.maxAge {
                item["custom_value"] = ["min_age": minAge, "max_age": maxAge]
            } else if let customText = answer.customText?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !customText.isEmpty {
                item["custom_value"] = customText
            }
            if item.count > 1 {
                bodyAnswers.append(item)
            }
        }

        var body: [String: Any] = [
            "clarification_session_id": sessionId,
            "answers": bodyAnswers,
        ]
        if let freeText = freeText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !freeText.isEmpty {
            body["free_text"] = freeText
        }
        return try await request(
            method: "POST",
            path: "/api/v1/agent/clarification/answer",
            body: body,
            timeout: 120
        )
    }

    func streamClarificationAnswers(
        sessionId: String,
        answers: [ClarificationAnswerInput],
        freeText: String?,
        onEvent: @escaping (AgentStreamEvent) async -> Void
    ) async throws {
        var bodyAnswers: [[String: Any]] = []
        for answer in answers {
            var item: [String: Any] = ["question_id": answer.questionId]
            if !answer.optionIds.isEmpty {
                item["option_ids"] = answer.optionIds
            }
            if let customValue = answer.customValue, !customValue.isEmpty {
                item["custom_value"] = customValue
            } else if let minAge = answer.minAge, let maxAge = answer.maxAge {
                item["custom_value"] = ["min_age": minAge, "max_age": maxAge]
            } else if let customText = answer.customText?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !customText.isEmpty {
                item["custom_value"] = customText
            }
            if item.count > 1 {
                bodyAnswers.append(item)
            }
        }

        var body: [String: Any] = [
            "clarification_session_id": sessionId,
            "answers": bodyAnswers,
        ]
        if let freeText = freeText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !freeText.isEmpty {
            body["free_text"] = freeText
        }
        try await streamRequest(
            path: "/api/v1/agent/clarification/answer/stream",
            body: body,
            onEvent: onEvent
        )
    }

    // MARK: - Events

    func createEvent(data: [String: Any]) async throws -> APIEventResponse {
        try await request(method: "POST", path: "/api/v1/events", body: data)
    }

    func getEvents() async throws -> [APIEventResponse] {
        try await request(method: "GET", path: "/api/v1/events")
    }

    func getPlazaEvents() async throws -> [APIPlazaEventResponse] {
        try await request(method: "GET", path: "/api/v1/events/plaza")
    }

    func getEvent(id: String) async throws -> APIEventResponse {
        try await request(method: "GET", path: "/api/v1/events/\(id)")
    }

    func updateEvent(id: String, data: [String: Any]) async throws -> APIEventResponse {
        try await request(method: "PUT", path: "/api/v1/events/\(id)", body: data)
    }

    func cancelEvent(id: String) async throws -> [String: Any] {
        try await requestDict(method: "DELETE", path: "/api/v1/events/\(id)")
    }

    /// Start editing an event via agent chat - returns agent's reply with current event info
    func startEditEvent(id: String) async throws -> APIAgentChatResponse {
        try await request(method: "POST", path: "/api/v1/agent/edit-event/\(id)")
    }

    // MARK: - Chat Rooms

    func getChatRooms() async throws -> [APIChatRoomResponse] {
        try await request(method: "GET", path: "/api/v1/chat/rooms")
    }

    func getRoomMessages(roomId: String, limit: Int = 50) async throws -> [APIChatMessageResponse] {
        try await request(method: "GET", path: "/api/v1/chat/rooms/\(roomId)/messages?limit=\(limit)")
    }

    func markRoomAsRead(roomId: String) async throws {
        _ = try await requestDict(method: "POST", path: "/api/v1/chat/rooms/\(roomId)/read")
    }

    func sendRoomMessage(roomId: String, content: String, mentions: [String]? = nil) async throws -> APIChatMessageResponse {
        var body: [String: Any] = ["content": content]
        if let mentions, !mentions.isEmpty {
            body["mentions"] = mentions
        }
        return try await request(method: "POST", path: "/api/v1/chat/rooms/\(roomId)/messages", body: body)
    }

    func getMatchRequests() async throws -> [APIPassiveMatchRequestResponse] {
        try await request(method: "GET", path: "/api/v1/chat/match-requests")
    }

    func respondMatchRequest(id: String, action: String) async throws -> [String: Any] {
        try await requestDict(
            method: "POST",
            path: "/api/v1/chat/match-requests/\(id)/respond",
            body: ["action": action]
        )
    }

    // MARK: - Vote

    func submitRoomVote(roomId: String, vote: String) async throws {
        _ = try await requestDict(method: "POST", path: "/api/v1/chat/rooms/\(roomId)/vote", body: ["vote": vote])
    }

    func fetchVoteStatus(roomId: String) async throws -> VoteStatus {
        try await request(method: "GET", path: "/api/v1/chat/rooms/\(roomId)/vote-status")
    }

    func getUserProfile(userId: String) async throws -> APIPublicUserProfileResponse {
        try await request(method: "GET", path: "/api/v1/users/\(userId)/profile")
    }
}

// MARK: - Vote Status

struct VoteStatus: Codable {
    let myVote: String?
    let partnerVote: String?
    let result: String?

    enum CodingKeys: String, CodingKey {
        case myVote = "my_vote"
        case partnerVote = "partner_vote"
        case result
    }
}
