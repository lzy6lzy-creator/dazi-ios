import Foundation

struct User: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var name: String
    var avatarSymbol: String
    var avatarEmoji: String
    var avatarImageData: Data?
    var city: String
    var bio: String
    var isAgent: Bool
    var gender: String
    var birthYear: Int
    var birthDate: String
    var interests: [String]
    var occupation: String
    var customInterests: String
    var welcomeDisturb: Bool
    var profileEventVisibility: String

    var agentName: String
    var agentEmoji: String
    var agentAvatarImageData: Data?
    var agentPersonality: String

    init(
        id: String,
        name: String,
        avatarSymbol: String = "person.circle.fill",
        avatarEmoji: String = "😊",
        avatarImageData: Data? = nil,
        city: String = "",
        bio: String = "",
        isAgent: Bool = false,
        gender: String = "",
        birthYear: Int = 0,
        birthDate: String = "",
        interests: [String] = [],
        occupation: String = "",
        customInterests: String = "",
        welcomeDisturb: Bool = false,
        profileEventVisibility: String = "partial",
        agentName: String = "点点",
        agentEmoji: String = "🤖",
        agentAvatarImageData: Data? = nil,
        agentPersonality: String = "贴心、有趣"
    ) {
        self.id = id
        self.name = name
        self.avatarSymbol = avatarSymbol
        self.avatarEmoji = avatarEmoji
        self.avatarImageData = avatarImageData
        self.city = city
        self.bio = bio
        self.isAgent = isAgent
        self.gender = gender
        self.birthYear = birthYear
        self.birthDate = birthDate
        self.interests = interests
        self.occupation = occupation
        self.customInterests = customInterests
        self.welcomeDisturb = welcomeDisturb
        self.profileEventVisibility = profileEventVisibility
        self.agentName = agentName
        self.agentEmoji = agentEmoji
        self.agentAvatarImageData = agentAvatarImageData
        self.agentPersonality = agentPersonality
    }

    static let placeholder = User(
        id: "user_unregistered",
        name: "新用户"
    )

    nonisolated(unsafe) static var currentUser: User = .placeholder

    /// Build an agent User instance from the current user's agent settings
    var myAgent: User {
        User(
            id: "agent_\(id)",
            name: agentName,
            avatarSymbol: "sparkles",
            avatarEmoji: agentEmoji,
            avatarImageData: agentAvatarImageData,
            bio: agentPersonality,
            isAgent: true
        )
    }

    var age: Int? {
        if let date = Self.parseBirthDate(birthDate) {
            var value = Calendar.current.component(.year, from: .now) - Calendar.current.component(.year, from: date)
            let birthComponents = Calendar.current.dateComponents([.month, .day], from: date)
            let todayComponents = Calendar.current.dateComponents([.month, .day], from: .now)
            if let birthMonth = birthComponents.month,
               let birthDay = birthComponents.day,
               let todayMonth = todayComponents.month,
               let todayDay = todayComponents.day,
               todayMonth < birthMonth || (todayMonth == birthMonth && todayDay < birthDay) {
                value -= 1
            }
            return max(value, 0)
        }
        if birthYear > 0 {
            return max(Calendar.current.component(.year, from: .now) - birthYear, 0)
        }
        return nil
    }

    private static func parseBirthDate(_ value: String) -> Date? {
        guard !value.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

}
