import Foundation

enum MemoryType: String, Codable, Sendable {
    case preference
    case constraint
    case behavior
    case feedback
}

struct AgentMemory: Identifiable, Codable, Sendable {
    let id: String
    var userId: String
    var type: MemoryType
    var content: String
    var confidence: Double
    var source: String
    var timestamp: Date

    init(
        id: String = UUID().uuidString,
        userId: String,
        type: MemoryType,
        content: String,
        confidence: Double = 0.5,
        source: String = "conversation",
        timestamp: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.type = type
        self.content = content
        self.confidence = confidence
        self.source = source
        self.timestamp = timestamp
    }

    /// 从服务器 API 响应初始化
    init(from api: APIMemoryResponse) {
        self.id = api.id
        self.userId = User.currentUser.id
        self.type = MemoryType(rawValue: api.type) ?? .preference
        self.content = api.content
        self.confidence = api.confidence
        self.source = api.source
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.timestamp = formatter.date(from: api.createdAt) ?? .now
    }
}
