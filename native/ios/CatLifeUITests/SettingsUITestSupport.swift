import XCTest

extension RoomHomeUITests {
    @MainActor
    func tapSettingsRootControl(_ identifier: String, in app: XCUIApplication,
                                file: StaticString = #filePath, line: UInt = #line) {
        waitForElement("settingsScroll", in: app, file: file, line: line)
        scrollPage("settingsScroll", to: identifier, allowDisabled: false, maximumDrags: 6, in: app,
                   file: file, line: line)
        tapAnimationControl(identifier, in: app, file: file, line: line)
    }

    @MainActor
    func assertFixedNavigationAvailable(in app: XCUIApplication,
                                        file: StaticString = #filePath, line: UInt = #line) {
        let bar = element("homeNavigationBar", in: app)
        XCTAssertTrue(bar.exists, file: file, line: line)
        for identifier in ["tabHome", "tabWork", "tabShop", "tabTown", "tabMore"] {
            let tab = element(identifier, in: app)
            XCTAssertTrue(tab.exists && tab.isEnabled && tab.isHittable,
                          "The embedded destination must retain its fixed \(identifier) entry.", file: file, line: line)
            XCTAssertTrue(bar.frame.contains(tab.frame),
                          "Every primary destination must fit in the fixed bar.", file: file, line: line)
        }
    }
}
