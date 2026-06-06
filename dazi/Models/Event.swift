import Foundation

enum EventStatus: String, Codable, Sendable {
    case pending = "等待匹配"
    case matching = "匹配中"
    case matched = "已匹配"
    case active = "进行中"
    case completed = "已完成"
    case cancelled = "已取消"

    var color: String {
        switch self {
        case .pending: return "orange"
        case .matching: return "blue"
        case .matched: return "green"
        case .active: return "purple"
        case .completed: return "gray"
        case .cancelled: return "red"
        }
    }

    /// 从服务器英文状态映射
    static func fromServer(_ s: String) -> EventStatus {
        switch s {
        case "pending": return .pending
        case "matching": return .matching
        case "matched": return .matched
        case "active": return .active
        case "completed": return .completed
        case "cancelled": return .cancelled
        default: return .pending
        }
    }
}

struct Event: Identifiable, Codable, Sendable {
    let id: String
    var userId: String
    var activityType: String
    var title: String
    var description: String
    var startTime: Date?
    var endTime: Date?
    var location: String
    var city: String
    var preferences: [String]
    var constraints: [String]
    var status: EventStatus
    var matchedUserId: String?
    var chatRoomId: String?
    var createdAt: Date

    var statusColor: String { status.color }

    init(
        id: String,
        userId: String,
        activityType: String,
        title: String,
        description: String,
        startTime: Date?,
        endTime: Date?,
        location: String,
        city: String = "",
        preferences: [String],
        constraints: [String],
        status: EventStatus,
        matchedUserId: String? = nil,
        chatRoomId: String? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.userId = userId
        self.activityType = activityType
        self.title = title
        self.description = description
        self.startTime = startTime
        self.endTime = endTime
        self.location = location
        self.city = city
        self.preferences = preferences
        self.constraints = constraints
        self.status = status
        self.matchedUserId = matchedUserId
        self.chatRoomId = chatRoomId
        self.createdAt = createdAt
    }

    /// 从服务器 API 响应初始化
    init(from api: APIEventResponse) {
        self.id = api.id
        self.userId = api.userId
        self.activityType = api.activityType
        self.title = api.title
        self.description = ""
        self.startTime = Self.parseDate(api.startTime)
        self.endTime = Self.parseDate(api.endTime)
        self.location = api.location ?? ""
        self.city = api.city ?? ""
        self.preferences = api.preferences ?? []
        self.constraints = api.constraints ?? []
        self.status = EventStatus.fromServer(api.status)
        self.matchedUserId = nil
        self.chatRoomId = nil
        self.createdAt = Self.parseDate(api.createdAt) ?? .now
    }

    private static func parseDate(_ str: String?) -> Date? {
        guard let str else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = formatter.date(from: str) { return d }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: str)
    }
}
