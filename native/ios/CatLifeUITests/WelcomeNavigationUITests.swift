import XCTest

extension RoomHomeUITests {
    @MainActor
    func testWelcomePreparationSurvivesRepeatedColdLaunches() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        for attempt in 0..<6 {
            app.launchArguments = arguments(reset: attempt == 0)
            launchAndEnterHome(app)
            waitForObservedValue("goldCount", "200", in: app)
            waitForObservedValue("foodCount", "3", in: app)
            XCTAssertFalse(element("welcomeLoading", in: app).exists)
            app.terminate()
        }
    }

    @MainActor
    func testFixedHomeNavigationIgnoresSwipesAndKeepsRoomStable() throws {
        continueAfterFailure = false
        let app = launchNavigationHome()
        assertKnownHomeViewportBaseline(in: app)
        let roomFrame = element("roomScene", in: app).frame
        let before = navigationState(in: app)
        let fixed = ["tabHome", "tabWork", "tabShop", "tabTown", "tabMore"]
        let bar = element("homeNavigationBar", in: app)
        let originalFrames = fixed.map { element($0, in: app).frame }
        for id in fixed { XCTAssertTrue(homeNavigationItemIsFullyVisible(id, in: app)) }
        attachScreenshot(app, named: "Navigation — five fixed destinations visible together")
        for swipeLeft in [true, false] {
            if swipeLeft { bar.swipeLeft() } else { bar.swipeRight() }
            for (id, expected) in zip(fixed, originalFrames) {
                let actual = element(id, in: app).frame
                XCTAssertEqual(actual.minX, expected.minX, accuracy: 0.5)
                XCTAssertEqual(actual.minY, expected.minY, accuracy: 0.5)
                XCTAssertEqual(actual.width, expected.width, accuracy: 0.5)
                XCTAssertTrue(homeNavigationItemIsFullyVisible(id, in: app))
            }
            XCTAssertTrue(element("tabHome", in: app).isSelected,
                          "Dragging over the fixed bar must not activate a destination.")
            for id in fixed.dropFirst() { XCTAssertFalse(element(id, in: app).isSelected) }
            assertNavigationSwipeStayedHome(in: app)
            assertRoomFrame(roomFrame, in: app, context: "after swiping over the fixed bottom bar")
        }
        tapAnimationControl("tabMore", in: app)
        waitForElement("moreMenu", in: app)
        XCTAssertTrue(element("tabMore", in: app).isSelected)
        for id in ["tabInventory", "tabPlayer", "decorateButton", "settingsButton"] {
            XCTAssertTrue(element(id, in: app).isHittable)
        }
        attachScreenshot(app, named: "Navigation — More opens four utilities above the fixed bar")
        tapAnimationControl("tabMore", in: app)
        let menuClosed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"),
                                                   object: element("moreMenu", in: app))
        XCTAssertEqual(XCTWaiter.wait(for: [menuClosed], timeout: 5), .completed)
        assertNavigationSwipeStayedHome(in: app)
        assertRoomFrame(roomFrame, in: app, context: "after opening and closing More")
        assertHomeControlRows(in: app, stage: "five fixed bottom entries")
        verifyHomeNavigationTabs(in: app, roomFrame: roomFrame)
        let after = waitForNavigationPhase("idle", in: app, timeout: 8)
        XCTAssertEqual(after.bowl.dx, before.bowl.dx, accuracy: 0.005)
        XCTAssertEqual(after.bowl.dy, before.bowl.dy, accuracy: 0.005)
        XCTAssertEqual(after.completedMeals, before.completedMeals)
        waitForObservedValue("catSatiety", "35", in: app)
        attachScreenshot(app, named: "Navigation — fixed destinations and utilities return to unchanged room")
    }

    @MainActor
    func testWelcomeEntryPreservesProgressAcrossRelaunch() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true)
        app.launch()
        assertWelcomeReady(in: app)
        attachScreenshot(app, named: "Welcome — ready and waiting for the user's Enter action")
        tapAnimationControl("welcomeEnterButton", in: app)
        waitForElement("feedButton", in: app)
        XCTAssertFalse(element("welcomeScreen", in: app).exists)
        assertKnownHomeViewportBaseline(in: app)
        let roomFrame = element("roomScene", in: app).frame
        let savedBowl = bowlPosition(in: app)
        buyFoodForHomeNameProgressCheck(in: app)
        assertRoomFrame(roomFrame, in: app, context: "after entering through Welcome and purchasing food")

        XCUIDevice.shared.press(.home)
        let backgrounded = XCTNSPredicateExpectation(predicate: NSPredicate { object, _ in
            guard let application = object as? XCUIApplication else { return false }
            return application.state == .runningBackground || application.state == .runningBackgroundSuspended
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [backgrounded], timeout: 8), .completed,
                       "The app must really leave the foreground before testing activation.")
        app.activate()
        waitForElement("feedButton", in: app)
        XCTAssertFalse(element("welcomeScreen", in: app).exists,
                       "Returning to the same process must keep the user inside their home.")
        assertHomeNamePreservedProgress(bowl: savedBowl, in: app)
        assertRoomFrame(roomFrame, in: app, context: "after backgrounding and reactivating the entered home")

        app.terminate()
        app.launchArguments = arguments(reset: false)
        app.launch()
        assertWelcomeReady(in: app)
        attachScreenshot(app, named: "Welcome — cold launch waits for Enter without resetting saved progress")
        tapAnimationControl("welcomeEnterButton", in: app)
        waitForElement("feedButton", in: app)
        assertKnownHomeViewportBaseline(in: app)
        assertHomeNamePreservedProgress(bowl: savedBowl, in: app)
        assertRoomFrame(roomFrame, in: app, context: "after cold launch and a second explicit welcome entry")
        attachScreenshot(app, named: "Welcome — entered home restores four food and 180 gold")
    }

    @MainActor
    func testWelcomeCannotEnterUntilTheRealSaveLoadFinishes() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--welcome-hold-load"]
        app.launch()
        waitForElement("welcomeScreen", in: app)
        waitForElement("welcomeLoading", in: app)
        waitForObservedValue("welcomeProgress", "0%", in: app)
        waitForLabel("welcomeTitle", "打工养猫日记", in: app)
        waitForElement("welcomeHero", in: app)
        waitForElement("welcomeEnterButton", in: app)
        XCTAssertFalse(element("welcomeEnterButton", in: app).isEnabled,
                       "Enter must stay disabled while the real save load is still held.")
        XCTAssertFalse(element("roomScene", in: app).exists)
        XCTAssertFalse(element("feedButton", in: app).exists)
        XCTAssertFalse(element("tabHome", in: app).exists)
        XCTAssertFalse(element("welcomeRetryButton", in: app).exists,
                       "A load still in progress is not a load failure.")
        attachScreenshot(app, named: "Welcome — held real load disables Enter without revealing the room")

        waitForObservedValue("welcomeProgress", "0%", in: app)
        XCTAssertFalse(element("welcomeEnterButton", in: app).isEnabled,
                       "The bar must not advance on a timer while the real load is held.")
        tapAnimationControl("welcomeReleaseLoadButton", in: app)
        assertWelcomeReady(in: app)
        XCTAssertFalse(element("welcomeLoading", in: app).exists)
        attachScreenshot(app, named: "Welcome — completed real load still waits for an explicit Enter tap")
        tapAnimationControl("welcomeEnterButton", in: app)
        waitForElement("feedButton", in: app)
        XCTAssertFalse(element("welcomeScreen", in: app).exists)
        waitForObservedValue("foodCount", "3", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        waitForObservedValue("catSatiety", "35", in: app)
        assertKnownHomeViewportBaseline(in: app)
        attachScreenshot(app, named: "Welcome — released load enters the real saved room")
    }

    @MainActor
    private func assertWelcomeReady(in app: XCUIApplication,
                                     file: StaticString = #filePath, line: UInt = #line) {
        waitForElement("welcomeScreen", in: app, file: file, line: line)
        waitForWelcomeEntryReady(in: app, file: file, line: line)
        waitForLabel("welcomeTitle", "打工养猫日记", in: app, file: file, line: line)
        waitForLabel("welcomeEnterButton", "进入小家", in: app, file: file, line: line)
        waitForElement("welcomeHero", in: app, file: file, line: line)
        waitForElement("welcomeNotice", in: app, file: file, line: line)
        waitForObservedValue("welcomeVersion", "0.13.2 (48)", in: app, file: file, line: line)
        waitForObservedValue("welcomeProgress", "100%", in: app, file: file, line: line)
        // This may be a real offline-work or recovery notice, so assert that
        // it is readable without replacing it with a fixed ready message.
        XCTAssertFalse(element("welcomeNotice", in: app).label.isEmpty, file: file, line: line)
        let hero = element("welcomeHero", in: app).frame
        XCTAssertGreaterThan(hero.width, 0, file: file, line: line)
        XCTAssertGreaterThan(hero.height, 0, file: file, line: line)
        XCTAssertTrue(app.frame.intersects(hero), "The welcome artwork must be on screen.", file: file, line: line)
        XCTAssertFalse(element("welcomeLoading", in: app).exists, file: file, line: line)
        XCTAssertFalse(element("welcomeRetryButton", in: app).exists, file: file, line: line)
        XCTAssertFalse(element("roomScene", in: app).exists,
                       "Completing the save load must not automatically open the room.", file: file, line: line)
        XCTAssertFalse(element("feedButton", in: app).exists, file: file, line: line)
        XCTAssertFalse(element("tabHome", in: app).exists, file: file, line: line)
        XCTAssertTrue(element("welcomeScreen", in: app).exists,
                      "The ready page must remain until the explicit Enter tap.", file: file, line: line)
    }

    @MainActor
    private func assertNavigationSwipeStayedHome(in app: XCUIApplication,
                                                 file: StaticString = #filePath, line: UInt = #line) {
        _ = waitForNavigationPhase("idle", in: app, timeout: 8, file: file, line: line)
        XCTAssertFalse(element("moreMenu", in: app).exists, file: file, line: line)
        for id in ["destinationScroll", "profileScroll", "settingsScroll", "townMapScroll"] {
            XCTAssertFalse(element(id, in: app).exists, file: file, line: line)
        }
        XCTAssertFalse(element("layoutCancelButton", in: app).exists, file: file, line: line)
        XCTAssertTrue(element("feedButton", in: app).isHittable, file: file, line: line)
        waitForObservedValue("foodCount", "3", in: app, file: file, line: line)
        waitForObservedValue("goldCount", "200", in: app, file: file, line: line)
    }
}
