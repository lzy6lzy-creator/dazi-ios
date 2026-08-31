import XCTest

@MainActor
final class ActivityUITests: XCTestCase {
    private func launch() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["DAZI_UI_TESTING"] = "1"
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.segmentedControls["eventScope"].waitForExistence(timeout: 10))
        return app
    }

    func testHorizontalSwipesSwitchBothActivityPages() {
        let app = launch()
        let scope = app.segmentedControls["eventScope"]
        XCTAssertTrue(scope.buttons["我的活动"].isSelected)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.7))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.7)))
        let selected = NSPredicate(format: "selected == true")
        expectation(for: selected, evaluatedWith: scope.buttons["活动广场"])
        waitForExpectations(timeout: 5)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.7))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.7)))
        expectation(for: selected, evaluatedWith: scope.buttons["我的活动"])
        waitForExpectations(timeout: 5)
    }

    func testStatusFilterCanBeCleared() {
        let app = launch()
        app.buttons["eventStatusFilter"].tap()
        app.buttons["已取消"].tap()
        XCTAssertTrue(app.staticTexts["没有符合条件的活动"].waitForExistence(timeout: 5))
        app.buttons["清除筛选"].tap()
        XCTAssertTrue(app.staticTexts["测试我的活动"].waitForExistence(timeout: 5))
    }
}
