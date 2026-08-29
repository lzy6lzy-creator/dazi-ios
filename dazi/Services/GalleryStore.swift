import Foundation

struct LegacyGalleryItem: Codable, Sendable {
    let id: String
    let eventId: String
    let activityType: String
    let title: String
    let startTime: Date?
    let location: String
    let city: String
    let photos: [Data]
    let isDisplayed: Bool
    let addedAt: Date
}

class GalleryStore {
    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("gallery_items.json")
    }

    func loadLegacyItems() -> [LegacyGalleryItem] {
        guard let data = try? Data(contentsOf: fileURL),
              let items = try? JSONDecoder().decode([LegacyGalleryItem].self, from: data)
        else { return [] }
        return items
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
