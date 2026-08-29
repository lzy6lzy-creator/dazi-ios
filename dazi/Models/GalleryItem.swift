import Foundation

struct GalleryItem: Identifiable, Sendable {
    let id: String
    var eventId: String
    var activityType: String
    var title: String
    var startTime: Date?
    var location: String
    var photoURLs: [String]
    var isDisplayed: Bool
    var addedAt: Date

    init(from api: APIGalleryItemResponse) {
        id = api.id
        eventId = api.eventId
        activityType = api.activityType
        title = api.title
        startTime = api.startTime.flatMap(Self.parseDate)
        location = api.location ?? ""
        photoURLs = api.photoUrls
        isDisplayed = api.isDisplayed
        addedAt = Self.parseDate(api.addedAt) ?? .now
    }

    private static func parseDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}
