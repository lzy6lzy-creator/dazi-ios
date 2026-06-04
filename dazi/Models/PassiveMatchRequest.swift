import Foundation

struct PassiveMatchRequest: Identifiable, Codable, Sendable {
    let id: String
    let eventId: String
    let eventTitle: String
    let requesterName: String
    let targetUserId: String
    var status: String
    let similarity: Double?
    let message: String
    let createdAt: Date

    init(from api: APIPassiveMatchRequestResponse) {
        self.id = api.id
        self.eventId = api.eventId
        self.eventTitle = api.eventTitle
        self.requesterName = api.requesterName
        self.targetUserId = api.targetUserId
        self.status = api.status
        self.similarity = api.similarity
        self.message = api.message ?? ""
        self.createdAt = Self.parseDate(api.createdAt) ?? .now
    }

    private static func parseDate(_ str: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = formatter.date(from: str) { return d }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: str)
    }
}
