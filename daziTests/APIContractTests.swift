import XCTest
@testable import dazi

@MainActor
final class APIContractTests: XCTestCase {
    func testGalleryDecodingKeepsVisibilityAndFractionalDates() throws {
        let payload = #"{"id":"gallery","event_id":"event","activity_type":"电影","title":"电影记录","start_time":"2026-08-31T14:00:00.000+08:00","location":"上海","photo_urls":["/api/v1/gallery/media/photo.jpg"],"is_displayed":false,"added_at":"2026-08-31T10:00:00Z"}"#
        let response = try JSONDecoder().decode(APIGalleryItemResponse.self, from: Data(payload.utf8))
        let item = GalleryItem(from: response)
        XCTAssertNotNil(item.startTime)
        XCTAssertFalse(item.isDisplayed)
        XCTAssertEqual(item.photoURLs, ["/api/v1/gallery/media/photo.jpg"])
    }

    func testEventDecodesLocationWithoutCityAndKeepsTimeWindow() throws {
        let payload = #"{"id":"event","user_id":"user","title":"电影","activity_type":"电影","start_time":"2026-08-31T14:00:00.000+08:00","end_time":"2026-08-31T16:00:00+08:00","location":"徐汇区","status":"matched","created_at":"2026-08-31T10:00:00Z"}"#
        let response = try JSONDecoder().decode(APIEventResponse.self, from: Data(payload.utf8))
        let event = Event(from: response)
        XCTAssertEqual(event.location, "徐汇区")
        XCTAssertEqual(event.city, "")
        XCTAssertEqual(event.status, .matched)
        XCTAssertEqual(try XCTUnwrap(event.endTime).timeIntervalSince(try XCTUnwrap(event.startTime)), 7200)
    }

    func testLegacyRoomDefaultsRemainDecodable() throws {
        let payload = #"{"id":"room","is_active":true,"created_at":"2026-08-31T10:00:00Z","members":[]}"#
        let response = try JSONDecoder().decode(APIChatRoomResponse.self, from: Data(payload.utf8))
        XCTAssertEqual(response.phase, "matched")
        XCTAssertFalse(response.isAnonymous)
        XCTAssertFalse(response.hasUnread)
    }

    func testPrivateMessageRecipientIsPreserved() throws {
        let payload = #"{"id":"message","room_id":"room","sender_id":"sender","sender_type":"agent","content":"私密回复","visibility":"private_to_agent","recipient_user_id":"recipient","created_at":"2026-08-31T10:00:00Z"}"#
        let response = try JSONDecoder().decode(APIChatMessageResponse.self, from: Data(payload.utf8))
        XCTAssertEqual(response.visibility, "private_to_agent")
        XCTAssertEqual(response.recipientUserId, "recipient")
    }

    func testServerAndLegacyStatusNamesMapConsistently() {
        XCTAssertEqual(EventStatus.fromServer("matched"), .matched)
        XCTAssertEqual(EventStatus.fromServer("已匹配"), .matched)
        XCTAssertEqual(EventStatus.fromServer("unknown"), .pending)
    }
}
