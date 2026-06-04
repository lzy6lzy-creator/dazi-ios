import Foundation

enum MessageRole: String, Codable, Sendable {
    case user
    case agent
    case partner
    case partnerAgent
    case system
}

struct Message: Identifiable, Codable, Sendable {
    let id: String
    var content: String
    var role: MessageRole
    var senderName: String
    var senderAvatar: String
    var senderAvatarImageData: Data?
    var timestamp: Date
    var isTyping: Bool
    var showConfirmButtons: Bool
    var confirmButtonsTapped: Bool

    init(
        id: String = UUID().uuidString,
        content: String,
        role: MessageRole,
        senderName: String,
        senderAvatar: String = "",
        senderAvatarImageData: Data? = nil,
        timestamp: Date = .now,
        isTyping: Bool = false,
        showConfirmButtons: Bool = false,
        confirmButtonsTapped: Bool = false
    ) {
        self.id = id
        self.content = content
        self.role = role
        self.senderName = senderName
        self.senderAvatar = senderAvatar
        self.senderAvatarImageData = senderAvatarImageData
        self.timestamp = timestamp
        self.isTyping = isTyping
        self.showConfirmButtons = showConfirmButtons
        self.confirmButtonsTapped = confirmButtonsTapped
    }

    static func userMessage(_ content: String) -> Message {
        let u = User.currentUser
        return Message(
            content: content,
            role: .user,
            senderName: u.name,
            senderAvatar: u.avatarEmoji,
            senderAvatarImageData: u.avatarImageData
        )
    }

    static func agentMessage(_ content: String) -> Message {
        let u = User.currentUser
        return Message(
            content: content,
            role: .agent,
            senderName: u.agentName,
            senderAvatar: u.agentEmoji,
            senderAvatarImageData: u.agentAvatarImageData
        )
    }

    static func systemMessage(_ content: String) -> Message {
        Message(
            content: content,
            role: .system,
            senderName: "系统",
            senderAvatar: "ℹ️"
        )
    }

    static func typingIndicator() -> Message {
        let u = User.currentUser
        return Message(
            content: "",
            role: .agent,
            senderName: u.agentName,
            senderAvatar: u.agentEmoji,
            senderAvatarImageData: u.agentAvatarImageData,
            isTyping: true
        )
    }
}
