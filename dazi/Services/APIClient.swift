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
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, phone, gender, bio, interests, city, occupation
        case birthYear = "birth_year"
        case birthDate = "birth_date"
        case avatarUrl = "avatar_url"
        case customInterests = "custom_interests"
        case welcomeDisturb = "welcome_disturb"
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

// MARK: - Chat Room Response Types

struct APIChatRoomMemberResponse: Codable {
    let userId: String
    let name: String
    let role: String
    let emoji: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case avatarUrl = "avatar_url"
        case name, role, emoji
    }
}

struct APIChatRoomResponse: Codable {
    let id: String
    let eventTitle: String?
    let matchSummary: String?
    let isActive: Bool
    let createdAt: String
    let closedAt: String?
    let members: [APIChatRoomMemberResponse]
    let lastMessage: APIChatMessageResponse?

    enum CodingKeys: String, CodingKey {
        case id, members
        case eventTitle = "event_title"
        case matchSummary = "match_summary"
        case isActive = "is_active"
        case createdAt = "created_at"
        case closedAt = "closed_at"
        case lastMessage = "last_message"
    }
}

struct APIChatMessageResponse: Codable {
    let id: String
    let roomId: String
    let senderId: String
    let senderType: String
    let content: String
    let mentions: [String]?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, content, mentions
        case roomId = "room_id"
        case senderId = "sender_id"
        case senderType = "sender_type"
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
    let createdAt: String

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
        timeout: TimeInterval = 30
    ) async throws -> [String: Any] {
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
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
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

    func chatWithAgent(message: String) async throws -> APIAgentChatResponse {
        try await request(
            method: "POST",
            path: "/api/v1/agent/chat",
            body: ["message": message],
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
            if let minAge = answer.minAge, let maxAge = answer.maxAge {
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

    // MARK: - Events

    func createEvent(data: [String: Any]) async throws -> APIEventResponse {
        try await request(method: "POST", path: "/api/v1/events", body: data)
    }

    func getEvents() async throws -> [APIEventResponse] {
        try await request(method: "GET", path: "/api/v1/events")
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
