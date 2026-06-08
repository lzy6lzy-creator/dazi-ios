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
    let value: ClarificationOptionValue?

    enum CodingKeys: String, CodingKey {
        case id, label, value
    }

    init(id: String, label: String, value: ClarificationOptionValue? = nil) {
        self.id = id
        self.label = label
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        label = try container.decode(String.self, forKey: .label)
        value = try? container.decode(ClarificationOptionValue.self, forKey: .value)
    }
}

struct ClarificationOptionValue: Codable, Sendable {
    let startTime: String?
    let endTime: String?
    let range: Int?

    enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case endTime = "end_time"
        case range
    }
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
    let defaultOptionIds: [String]

    enum CodingKeys: String, CodingKey {
        case id, type, title, category, required, options
        case helperText = "helper_text"
        case allowCustom = "allow_custom"
        case matchFilter = "match_filter"
        case defaultOptionIds = "default_option_ids"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "single_choice"
        title = try container.decode(String.self, forKey: .title)
        helperText = try container.decodeIfPresent(String.self, forKey: .helperText)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        required = try container.decodeIfPresent(Bool.self, forKey: .required) ?? false
        allowCustom = try container.decodeIfPresent(Bool.self, forKey: .allowCustom) ?? true
        matchFilter = try container.decodeIfPresent(String.self, forKey: .matchFilter)
        options = try container.decodeIfPresent([ClarificationOption].self, forKey: .options) ?? []
        defaultOptionIds = try container.decodeIfPresent([String].self, forKey: .defaultOptionIds) ?? []
    }
}

struct ClarificationAnswerInput: Sendable {
    let questionId: String
    var optionIds: [String] = []
    var customText: String?
    var customValue: [String: String]?
    var minAge: Int?
    var maxAge: Int?

    init(
        questionId: String,
        optionIds: [String] = [],
        customText: String? = nil,
        customValue: [String: String]? = nil,
        minAge: Int? = nil,
        maxAge: Int? = nil
    ) {
        self.questionId = questionId
        self.optionIds = optionIds
        self.customText = customText
        self.customValue = customValue
        self.minAge = minAge
        self.maxAge = maxAge
    }
}

struct Message: Identifiable, Codable, Sendable {
    static let publishingContent = "正在发布活动，请稍等"

    let id: String
    var content: String
    var role: MessageRole
    var senderName: String
    var senderUserId: String?
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
        senderUserId: String? = nil,
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
        self.senderUserId = senderUserId
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
            senderUserId: u.id,
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
