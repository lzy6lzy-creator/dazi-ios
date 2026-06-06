import Foundation

struct GalleryItem: Identifiable, Codable, Sendable {
    let id: String
    var eventId: String
    var activityType: String
    var title: String
    var startTime: Date?
    var location: String
    var city: String
    var photos: [Data]
    var isDisplayed: Bool
    var addedAt: Date

    init(
        id: String = UUID().uuidString,
        eventId: String,
        activityType: String,
        title: String,
        startTime: Date? = nil,
        location: String = "",
        city: String = "",
        photos: [Data] = [],
        isDisplayed: Bool = true,
        addedAt: Date = .now
    ) {
        self.id = id
        self.eventId = eventId
        self.activityType = activityType
        self.title = title
        self.startTime = startTime
        self.location = location
        self.city = city
        self.photos = photos
        self.isDisplayed = isDisplayed
        self.addedAt = addedAt
    }

    init(from event: Event) {
        self.id = UUID().uuidString
        self.eventId = event.id
        self.activityType = event.activityType
        self.title = event.title
        self.startTime = event.startTime
        self.location = event.location
        self.city = event.city
        self.photos = []
        self.isDisplayed = true
        self.addedAt = .now
    }
}
