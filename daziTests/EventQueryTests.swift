import XCTest
@testable import dazi

@MainActor
final class EventQueryTests: XCTestCase {
    private let now = ISO8601DateFormatter().date(from: "2026-08-31T10:00:00+08:00")!

    private func event(_ id: String, start: Date?, status: EventStatus = .pending) -> Event {
        Event(
            id: id, userId: "test-user", activityType: "电影", title: id,
            description: "", startTime: start, endTime: start?.addingTimeInterval(7200),
            location: "上海", preferences: [], constraints: [], status: status, createdAt: now
        )
    }

    private func query(_ sort: EventSortOption = .smart, date: EventDateFilter = .all, status: EventStatusFilter = .all) -> EventListQuery {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return EventListQuery(statusFilter: status, dateFilter: date, sortOption: sort, now: now, calendar: calendar)
    }

    func testAscendingTimeLeavesUnscheduledEventsLast() {
        let events = [event("none", start: nil), event("late", start: now.addingTimeInterval(3600)), event("early", start: now)]
        XCTAssertEqual(query(.startAsc).apply(to: events).map(\.id), ["early", "late", "none"])
    }

    func testDescendingTimeLeavesUnscheduledEventsLast() {
        let events = [event("none", start: nil), event("late", start: now.addingTimeInterval(3600)), event("early", start: now)]
        XCTAssertEqual(query(.startDesc).apply(to: events).map(\.id), ["late", "early", "none"])
    }

    func testSmartSortingPutsClosedEventsAfterOpenOnes() {
        let events = [event("closed", start: now, status: .completed), event("pending", start: nil)]
        XCTAssertEqual(query().apply(to: events).map(\.id), ["pending", "closed"])
    }

    func testStatusFilterDoesNotIncludeOtherStates() {
        let events = [event("matched", start: now, status: .matched), event("pending", start: now)]
        XCTAssertEqual(query(status: .matched).apply(to: events).map(\.id), ["matched"])
    }

    func testChineseWeekStartsMondayAndEndsSunday() {
        let sundayBefore = ISO8601DateFormatter().date(from: "2026-08-30T20:00:00+08:00")!
        let sundayAfter = ISO8601DateFormatter().date(from: "2026-09-06T20:00:00+08:00")!
        let events = [event("previous-week", start: sundayBefore), event("monday", start: now), event("sunday", start: sundayAfter)]
        XCTAssertEqual(query(.startAsc, date: .thisWeek).apply(to: events).map(\.id), ["monday", "sunday"])
    }

    func testTodayUsesShanghaiCalendarDay() {
        let localMidnight = ISO8601DateFormatter().date(from: "2026-08-30T16:00:00Z")!
        let events = [event("today", start: localMidnight), event("yesterday", start: localMidnight.addingTimeInterval(-1))]
        XCTAssertEqual(query(date: .today).apply(to: events).map(\.id), ["today"])
    }
}
