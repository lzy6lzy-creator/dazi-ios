import Foundation

struct ChatRoom: Identifiable, Codable, Sendable {
    let id: String
    var eventId: String
    var eventIds: [String]
    var eventTitle: String
    var participants: [User]
    var matchSummary: String
    var agentDialogueLog: String
    var isActive: Bool
    var createdAt: Date
    var closedAt: Date?
    var messages: [Message]
    var hasUnread: Bool

    init(
        id: String,
        eventId: String,
        eventIds: [String] = [],
        eventTitle: String,
        participants: [User],
        matchSummary: String,
        agentDialogueLog: String = "",
        isActive: Bool,
        createdAt: Date,
        closedAt: Date? = nil,
        messages: [Message],
        hasUnread: Bool
    ) {
        self.id = id
        self.eventId = eventId
        self.eventIds = eventIds.isEmpty && !eventId.isEmpty ? [eventId] : eventIds
        self.eventTitle = eventTitle
        self.participants = participants
        self.matchSummary = matchSummary
        self.agentDialogueLog = agentDialogueLog
        self.isActive = isActive
        self.createdAt = createdAt
        self.closedAt = closedAt
        self.messages = messages
        self.hasUnread = hasUnread
    }

    var lastMessage: Message? {
        messages.last
    }

    /// 从服务器 API 响应初始化
    init(from api: APIChatRoomResponse) {
        self.id = api.id
        self.eventIds = [api.eventIdA, api.eventIdB].compactMap { $0 }
        self.eventId = eventIds.first ?? ""
        self.eventTitle = api.eventTitle ?? "活动"
        self.participants = api.members.map { member in
            User(
                id: member.role == "agent" ? "agent_\(member.userId)" : member.userId,
                name: member.name,
                avatarEmoji: member.avatarUrl ?? member.emoji ?? (member.role == "agent" ? "🤖" : "😊"),
                city: member.city ?? "",
                bio: member.bio ?? "",
                isAgent: member.role == "agent",
                gender: member.gender ?? "",
                birthYear: member.birthYear ?? 0,
                birthDate: member.birthDate ?? ""
            )
        }
        self.matchSummary = api.matchSummary ?? ""
        self.agentDialogueLog = api.agentDialogue ?? ""
        self.isActive = api.isActive
        self.createdAt = Self.parseDate(api.createdAt) ?? .now
        self.closedAt = api.closedAt.flatMap { Self.parseDate($0) }
        self.messages = []
        self.hasUnread = api.hasUnread
    }

    private static func parseDate(_ str: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = formatter.date(from: str) { return d }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: str)
    }

    var displayTitle: String {
        let userNames = participants.filter { !$0.isAgent && $0.id != User.currentUser.id }
        if let partner = userNames.first {
            return "\(eventTitle) - \(partner.name)"
        }
        return eventTitle
    }

    func containsEvent(_ eventId: String) -> Bool {
        self.eventId == eventId || eventIds.contains(eventId)
    }
}
