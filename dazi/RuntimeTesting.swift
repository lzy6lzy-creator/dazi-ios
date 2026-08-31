#if DEBUG
import Foundation

enum RuntimeTesting {
    static var isUITesting: Bool {
        ProcessInfo.processInfo.environment["DAZI_UI_TESTING"] == "1"
    }

    static var isTesting: Bool {
        isUITesting || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    static func seedActivities(in store: DataStore) {
        let now = Date(timeIntervalSince1970: 1788134400)
        store.events = [
            Event(
                id: "ui-mine", userId: "ui-user", activityType: "电影",
                title: "测试我的活动", description: "", startTime: now,
                endTime: now.addingTimeInterval(7200), location: "上海",
                preferences: [], constraints: [], status: .pending, createdAt: now
            ),
        ]
        store.plazaEvents = [
            PlazaEvent(from: APIPlazaEventResponse(
                id: "ui-plaza", title: "测试广场活动", activityType: "运动",
                startTime: "2026-08-31T14:00:00+08:00", endTime: "2026-08-31T16:00:00+08:00",
                location: "徐汇区", city: nil, preferences: [], constraints: [],
                createdAt: "2026-08-31T10:00:00+08:00"
            )),
        ]
    }
}
#endif
