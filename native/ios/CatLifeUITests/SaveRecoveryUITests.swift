import XCTest

extension RoomHomeUITests {
    @MainActor
    func testPersistentSaveFailureRemainsRetryableWithoutChargingFailedActions() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--save-outage-test"]
        launchAndEnterHome(app)
        waitForObservedValue("foodCount", "3", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        waitForObservedValue("catSatiety", "35", in: app)
        let roomFrame = element("roomScene", in: app).frame

        tapAnimationControl("feedButton", in: app)
        dismissExpectedSaveFailure(in: app)
        assertPersistentSaveRetryVisible(in: app)
        waitForObservedValue("foodCount", "3", in: app)
        waitForObservedValue("catSatiety", "35", in: app)
        assertRoomFrame(roomFrame, in: app, context: "after the first save failure banner appears")
        attachScreenshot(app, named: "Save recovery — failed feeding retains supplies and a persistent retry entry")

        // A new explicit purchase must report its own failure even after the
        // first alert was dismissed. Neither intent can publish or charge early.
        tapAnimationControl("tabShop", in: app)
        waitForElement("buyFoodButton", in: app)
        tapAnimationControl("buyFoodButton", in: app)
        dismissExpectedSaveFailure(in: app)
        waitForObservedValue("shopGoldCount", "200", in: app)
        tapAnimationControl("closeSheetButton", in: app)
        waitForObservedValue("foodCount", "3", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        assertPersistentSaveRetryVisible(in: app)
        assertRoomFrame(roomFrame, in: app, context: "after another explicitly requested save fails")

        // The lasting entry must attempt storage again; it must not disappear
        // or claim success while the same injected outage is still active.
        tapAnimationControl("saveStatusRetryButton", in: app)
        dismissExpectedSaveFailure(in: app)
        assertPersistentSaveRetryVisible(in: app)
        waitForObservedValue("foodCount", "3", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        waitForObservedValue("catSatiety", "35", in: app)
        assertRoomFrame(roomFrame, in: app, context: "after an explicit retry still cannot save")
        attachScreenshot(app, named: "Save recovery — persistent retry still reports the active outage")

        // The fault belongs only to this process's explicit test argument.
        // Preserve the same isolated save while launching without the outage.
        app.terminate()
        app.launchArguments = arguments(reset: false)
        launchAndEnterHome(app)
        waitForObservedValue("foodCount", "3", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        waitForObservedValue("catSatiety", "35", in: app)
        XCTAssertFalse(element("saveStatusBanner", in: app).exists)
        assertRoomFrame(roomFrame, in: app, context: "after recovering the unchanged durable save")

        tapAnimationControl("feedButton", in: app)
        waitForObservedValue("foodCount", "2", in: app)
        waitForObservedValue("catSatiety", "60", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        XCTAssertFalse(app.alerts.firstMatch.exists)
        XCTAssertFalse(element("saveStatusBanner", in: app).exists)
        attachScreenshot(app, named: "Save recovery — a new feeding commits normally after storage recovers")
    }

    @MainActor
    private func dismissExpectedSaveFailure(in app: XCUIApplication,
                                            file: StaticString = #filePath, line: UInt = #line) {
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 8),
                      "Each explicit failed action must present a fresh error.", file: file, line: line)
        XCTAssertTrue(alert.staticTexts["这次操作还没有保存"].exists, file: file, line: line)
        alert.buttons["完成"].tap()
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: alert)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed, file: file, line: line)
    }

    @MainActor
    private func assertPersistentSaveRetryVisible(in app: XCUIApplication,
                                                  file: StaticString = #filePath, line: UInt = #line) {
        waitForElement("saveStatusBanner", in: app, file: file, line: line)
        let retry = element("saveStatusRetryButton", in: app)
        let available = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND enabled == true AND hittable == true"), object: retry)
        XCTAssertEqual(XCTWaiter.wait(for: [available], timeout: 8), .completed,
                       "Dismissing an alert must leave a usable save retry entry.", file: file, line: line)
    }
}
