import XCTest

extension RoomHomeUITests {
    @MainActor
    func testTownMapPresentsBackgroundSaveFailureBeforeAutomaticRecovery() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--career-active-fixture", "--career-save-failure-once", "--audio-test"]
        launchAndEnterHome(app)
        tapAnimationControl("tabTown", in: app)
        waitForElement("townMapScroll", in: app)
        assertWorkCompletionSoundCount(0, in: app)

        // This shift finishes about 45 seconds after launch. Its one failed
        // settlement retries after two seconds, so observe the alert directly.
        let failure = app.alerts["这次操作还没有保存"]
        XCTAssertTrue(failure.waitForExistence(timeout: 55),
                      "Background save failure must be presented while the player stays on the map.")
        XCTAssertTrue(element("townMapScroll", in: app).exists)
        let recovered = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: failure)
        XCTAssertEqual(XCTWaiter.wait(for: [recovered], timeout: 8), .completed)
        XCTAssertFalse(element("saveStatusBanner", in: app).exists)
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", "360", in: app)
        assertWorkCompletionSoundCount(1, in: app)
        XCTAssertFalse(app.alerts.firstMatch.exists,
                       "Returning home must not present a delayed map error after saving has recovered.")
    }

    @MainActor
    func testTownMapAndCatProfileKeepOneSaveAlertOwnerAndPersistentRetry() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--save-outage-test"]
        launchAndEnterHome(app)
        tapAnimationControl("feedButton", in: app)
        dismissExpectedSaveFailure(in: app)

        tapAnimationControl("tabTown", in: app)
        waitForElement("townMapScroll", in: app)
        assertPersistentSaveRetryVisible(in: app)
        tapPersistentSaveRetry(in: app)
        dismissExpectedSaveFailure(in: app)
        assertPersistentSaveRetryVisible(in: app)

        let collection = element("townCollectionButton", in: app)
        let failureBanner = element("saveStatusBanner", in: app)
        XCTAssertTrue(collection.isHittable, "The persistent failure banner must leave the cat directory reachable.")
        XCTAssertGreaterThanOrEqual(collection.frame.minY, failureBanner.frame.maxY,
                                    "Map navigation belongs below the persistent failure banner, never underneath it.")
        openTownCollection(in: app)
        tapAnimationControl("catProfile_cat_001", in: app)
        waitForObservedValue("catProfileScroll", "cat_001", in: app)
        assertPersistentSaveRetryVisible(in: app)
        tapPersistentSaveRetry(in: app)
        dismissExpectedSaveFailure(in: app)
        assertPersistentSaveRetryVisible(in: app)
        tapPersistentSaveRetry(in: app)
        dismissExpectedSaveFailure(in: app)
        assertPersistentSaveRetryVisible(in: app)
        attachScreenshot(app, named: "Save recovery — cat profile retains its own retry after dismissing the alert")

        tapAnimationControl("closeSheetButton", in: app)
        waitForElement("townMapScroll", in: app)
        XCTAssertFalse(app.alerts.firstMatch.exists,
                       "Closing the cat profile must not reveal a duplicate map alert underneath it.")
        assertPersistentSaveRetryVisible(in: app)
        tapPersistentSaveRetry(in: app)
        dismissExpectedSaveFailure(in: app)
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("foodCount", "3", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        assertPersistentSaveRetryVisible(in: app)
    }

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
        scrollCareerPage("destinationScroll", to: "buyFoodButton", in: app)
        tapAnimationControl("buyFoodButton", in: app)
        dismissExpectedSaveFailure(in: app)
        waitForObservedValue("shopGoldCount", "200", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("foodCount", "3", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        assertPersistentSaveRetryVisible(in: app)
        assertRoomFrame(roomFrame, in: app, context: "after another explicitly requested save fails")

        // The lasting entry must attempt storage again; it must not disappear
        // or claim success while the same injected outage is still active.
        tapPersistentSaveRetry(in: app)
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
        XCTAssertEqual(app.alerts.count, 1, "Only the visible page should own the save alert.", file: file, line: line)
        XCTAssertTrue(alert.staticTexts["这次操作还没有保存"].exists, file: file, line: line)
        alert.buttons["完成"].tap()
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: alert)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed, file: file, line: line)
    }

    @MainActor
    private func tapPersistentSaveRetry(in app: XCUIApplication,
                                       file: StaticString = #filePath, line: UInt = #line) {
        assertPersistentSaveRetryVisible(in: app, file: file, line: line)?.tap()
    }

    @MainActor
    @discardableResult
    private func assertPersistentSaveRetryVisible(in app: XCUIApplication,
                                                  file: StaticString = #filePath, line: UInt = #line) -> XCUIElement? {
        waitForElement("saveStatusBanner", in: app, file: file, line: line)
        // The sheet and its covered parent both remain in the accessibility tree.
        let retries = app.buttons.matching(identifier: "saveStatusRetryButton")
        let available = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            retries.allElementsBoundByIndex.contains { $0.isEnabled && $0.isHittable }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [available], timeout: 8), .completed,
                       "Dismissing an alert must leave a usable save retry entry.", file: file, line: line)
        return retries.allElementsBoundByIndex.first { $0.isEnabled && $0.isHittable }
    }
}
