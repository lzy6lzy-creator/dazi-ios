import Foundation

enum MessageRole: String, Codable, Sendable {
    case user
    case agent
    case partner
    case partnerAgent
    case system
}

struct ClarificationOption: Identifiable, Codable, Sendable {
    let id: String
    let label: String
}

struct ClarificationQuestion: Identifiable, Codable, Sendable {
    let id: String
    let type: String
    let title: String
    let helperText: String?
    let category: String?
    let required: Bool
    let allowCustom: Bool
    let matchFilter: String?
    let options: [ClarificationOption]

    enum CodingKeys: String, CodingKey {
        case id, type, title, category, required, options
        case helperText = "helper_text"
        case allowCustom = "allow_custom"
        case matchFilter = "match_filter"
    }
}

struct ClarificationAnswerInput: Sendable {
    let questionId: String
    var optionIds: [String] = []
    var customText: String?
    var minAge: Int?
    var maxAge: Int?

    init(
        questionId: String,
        optionIds: [String] = [],
        customText: String? = nil,
        minAge: Int? = nil,
        maxAge: Int? = nil
    ) {
        self.questionId = questionId
        self.optionIds = optionIds
        self.customText = customText
        self.minAge = minAge
        self.maxAge = maxAge
    }
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
    var clarificationSessionId: String?
    var clarificationQuestions: [ClarificationQuestion]
    var clarificationSubmitted: Bool

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
        confirmButtonsTapped: Bool = false,
        clarificationSessionId: String? = nil,
        clarificationQuestions: [ClarificationQuestion] = [],
        clarificationSubmitted: Bool = false
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
        self.clarificationSessionId = clarificationSessionId
        self.clarificationQuestions = clarificationQuestions
        self.clarificationSubmitted = clarificationSubmitted
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

    static func agentMessage(
        _ content: String,
        clarificationSessionId: String? = nil,
        clarificationQuestions: [ClarificationQuestion] = []
    ) -> Message {
        let u = User.currentUser
        return Message(
            content: content,
            role: .agent,
            senderName: u.agentName,
            senderAvatar: u.agentEmoji,
            senderAvatarImageData: u.agentAvatarImageData,
            clarificationSessionId: clarificationSessionId,
            clarificationQuestions: clarificationQuestions
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
