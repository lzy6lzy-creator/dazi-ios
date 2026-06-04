import Foundation

class UserProfileStore {
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let isRegistered = "dazi_is_registered"
        static let userId = "dazi_user_id"
        static let userName = "dazi_user_name"
        static let userAvatarEmoji = "dazi_user_avatar_emoji"
        static let userAvatarImageData = "dazi_user_avatar_image_data"
        static let userCity = "dazi_user_city"
        static let userBio = "dazi_user_bio"
        static let userGender = "dazi_user_gender"
        static let userBirthYear = "dazi_user_birth_year"
        static let userInterests = "dazi_user_interests"
        static let agentName = "dazi_agent_name"
        static let agentEmoji = "dazi_agent_emoji"
        static let agentAvatarImageData = "dazi_agent_avatar_image_data"
        static let agentPersonality = "dazi_agent_personality"
    }

    var isRegistered: Bool {
        defaults.bool(forKey: Keys.isRegistered)
    }

    func loadUser() -> User? {
        guard isRegistered,
              let id = defaults.string(forKey: Keys.userId),
              let name = defaults.string(forKey: Keys.userName)
        else { return nil }

        return User(
            id: id,
            name: name,
            avatarEmoji: defaults.string(forKey: Keys.userAvatarEmoji) ?? "😊",
            avatarImageData: defaults.data(forKey: Keys.userAvatarImageData),
            city: defaults.string(forKey: Keys.userCity) ?? "",
            bio: defaults.string(forKey: Keys.userBio) ?? "",
            gender: defaults.string(forKey: Keys.userGender) ?? "",
            birthYear: defaults.integer(forKey: Keys.userBirthYear),
            interests: defaults.stringArray(forKey: Keys.userInterests) ?? [],
            agentName: defaults.string(forKey: Keys.agentName) ?? "点点",
            agentEmoji: defaults.string(forKey: Keys.agentEmoji) ?? "🤖",
            agentAvatarImageData: defaults.data(forKey: Keys.agentAvatarImageData),
            agentPersonality: defaults.string(forKey: Keys.agentPersonality) ?? "贴心、有趣"
        )
    }

    func saveUser(_ user: User) {
        defaults.set(true, forKey: Keys.isRegistered)
        defaults.set(user.id, forKey: Keys.userId)
        defaults.set(user.name, forKey: Keys.userName)
        defaults.set(user.avatarEmoji, forKey: Keys.userAvatarEmoji)
        defaults.set(user.avatarImageData, forKey: Keys.userAvatarImageData)
        defaults.set(user.city, forKey: Keys.userCity)
        defaults.set(user.bio, forKey: Keys.userBio)
        defaults.set(user.gender, forKey: Keys.userGender)
        defaults.set(user.birthYear, forKey: Keys.userBirthYear)
        defaults.set(user.interests, forKey: Keys.userInterests)
        defaults.set(user.agentName, forKey: Keys.agentName)
        defaults.set(user.agentEmoji, forKey: Keys.agentEmoji)
        defaults.set(user.agentAvatarImageData, forKey: Keys.agentAvatarImageData)
        defaults.set(user.agentPersonality, forKey: Keys.agentPersonality)
    }

    func clearUser() {
        let allKeys = [
            Keys.isRegistered, Keys.userId, Keys.userName, Keys.userAvatarEmoji,
            Keys.userAvatarImageData,
            Keys.userCity, Keys.userBio, Keys.userGender, Keys.userBirthYear,
            Keys.userInterests, Keys.agentName, Keys.agentEmoji,
            Keys.agentAvatarImageData, Keys.agentPersonality,
        ]
        for key in allKeys {
            defaults.removeObject(forKey: key)
        }
    }
}
