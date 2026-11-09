import XCTest

extension RoomHomeUITests {
    @MainActor
    func testTownEventReplyMilestoneAndRelaunchKeepOneReward() throws {
        continueAfterFailure = false
        let app = launchTownEventFixture()
        openNoticeBoard(app, fromMap: true)
        let before = try townEventValue(app)
        XCTAssertEqual(before.count, 6)
        attachScreenshot(app, named: "Town events — today's neighbor request")
        tapAnimationControl("townEventOpenToday", in: app)
        waitForElement("townEventDetail", in: app)
        scrollCareerPage("townEventDetail", to: "townEventChoice_help", in: app)
        attachScreenshot(app, named: "Town events — two choices with explicit costs")
        tapAnimationControl("townEventChoice_help", in: app)
        waitForObservedValue("townEventLetter", before.event, in: app)
        waitForElement("townEventActualRewards", in: app)
        XCTAssertFalse(element("townEventChoice_supply", in: app).exists)
        attachScreenshot(app, named: "Town events — saved reply and actual rewards")
        tapAnimationControl("townEventBackButton", in: app)
        XCTAssertEqual(try townEventValue(app).count, 7)
        tapAnimationControl("townBoardTab_letters", in: app)
        let letters = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "townLetter_"))
        XCTAssertTrue(letters.firstMatch.waitForExistence(timeout: 8))
        XCTAssertGreaterThan(letters.count, 0)
        XCTAssertLessThanOrEqual(letters.count, 4)
        attachScreenshot(app, named: "Town events — paged replies")
        tapAnimationControl("townBoardTab_memento", in: app)
        scrollCareerPage("townBoardScroll", to: "townEventClaim_town_memory_7", in: app)
        tapAnimationControl("townEventClaim_town_memory_7", in: app)
        waitForObservedValue("townEventMilestone_town_memory_7", "claimed", in: app)
        attachScreenshot(app, named: "Town events — keepsake claimed after seven participations")
        tapAnimationControl("tabMore", in: app)
        tapAnimationControl("tabInventory", in: app)
        tapAnimationControl("inventoryFurnitureTab", in: app)
        scrollCareerPage("destinationScroll", to: "inventoryFurniture_town-event-memory", in: app)
        waitForLabel("inventoryFurniture_town-event-memory", "猫町邻里纪念画", in: app, contains: true)
        attachScreenshot(app, named: "Town events — keepsake available in furniture bag")

        app.terminate()
        app.launchArguments = arguments(reset: false) + ["--town-events-fixture"]
        launchAndEnterHome(app)
        openNoticeBoard(app)
        XCTAssertEqual(try townEventValue(app).count, 7)
        XCTAssertFalse(element("townEventOpenToday", in: app).exists)
        tapAnimationControl("townBoardTab_memento", in: app)
        scrollCareerPage("townBoardScroll", to: "townEventMilestone_town_memory_7", in: app)
        waitForObservedValue("townEventMilestone_town_memory_7", "claimed", in: app)
        XCTAssertFalse(element("townEventClaim_town_memory_7", in: app).exists)
    }

    @MainActor
    func testTownEventLanguagesAndSaveFailureKeepChoiceAvailable() throws {
        continueAfterFailure = false
        let app = launchTownEventFixture()
        for (code, title) in [("zh-Hans", "猫町留言板"), ("zh-Hant", "貓町留言板"), ("en", "Cat Town noticeboard")] {
            if code != "zh-Hans" { selectCatTestLanguage(code, in: app) }
            openNoticeBoard(app)
            waitForLabel("townBoardBackButton", code == "en" ? "Cats" : code == "zh-Hant" ? "貓町" : "猫町", in: app, contains: true)
            XCTAssertTrue(app.staticTexts[title].firstMatch.exists)
            tapAnimationControl("townEventOpenToday", in: app)
            scrollCareerPage("townEventDetail", to: "townEventChoice_supply", in: app)
            let choices = [element("townEventChoice_help", in: app), element("townEventChoice_supply", in: app)]
            for choice in choices {
                XCTAssertFalse(choice.label.contains("townEvents."))
                XCTAssertFalse(choice.label.contains("supply."))
            }
            attachScreenshot(app, named: "Town events — localized choices \(code)")
            tapAnimationControl("tabHome", in: app)
        }
        app.terminate()
        app.launchArguments = arguments(reset: true) + ["--town-events-fixture", "--save-outage-test"]
        launchAndEnterHome(app)
        openNoticeBoard(app)
        let before = try townEventValue(app)
        tapAnimationControl("townEventOpenToday", in: app)
        scrollCareerPage("townEventDetail", to: "townEventChoice_help", in: app)
        tapAnimationControl("townEventChoice_help", in: app)
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 8))
        XCTAssertFalse(element("townEventLetter", in: app).exists)
        attachScreenshot(app, named: "Town events — save failure retains the event and original rewards")
        app.terminate()
        app.launchArguments = arguments(reset: false) + ["--town-events-fixture"]
        launchAndEnterHome(app)
        openNoticeBoard(app)
        XCTAssertEqual(try townEventValue(app).count, before.count)
        tapAnimationControl("townEventOpenToday", in: app)
        scrollCareerPage("townEventDetail", to: "townEventChoice_help", in: app)
        tapAnimationControl("townEventChoice_help", in: app)
        waitForObservedValue("townEventLetter", before.event, in: app)
        attachScreenshot(app, named: "Town events — localized reply after a successful retry")
    }

    @MainActor
    func testTownEventAccessibilityTextKeepsRepliesPagedAndChoicesReachable() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--town-events-fixture",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        launchAndEnterHome(app)
        openNoticeBoard(app)
        tapAnimationControl("townBoardTab_letters", in: app)
        let letters = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "townLetter_"))
        XCTAssertTrue(letters.firstMatch.waitForExistence(timeout: 8))
        XCTAssertGreaterThan(letters.count, 0)
        XCTAssertLessThanOrEqual(letters.count, 2)
        attachScreenshot(app, named: "Town events — two replies per page at accessibility text size")
        tapAnimationControl("townBoardTab_today", in: app)
        scrollCareerPage("townBoardScroll", to: "townEventOpenToday", in: app)
        tapAnimationControl("townEventOpenToday", in: app)
        let choice = element("townEventChoice_help", in: app)
        for _ in 0..<8 {
            if choice.isHittable { break }
            element("townEventDetail", in: app).swipeUp()
        }
        XCTAssertTrue(choice.isHittable)
        attachScreenshot(app, named: "Town events — accessible choice remains reachable")
        choice.tap()
        waitForElement("townEventLetter", in: app)
    }

    @MainActor
    private func launchTownEventFixture() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--town-events-fixture"]
        launchAndEnterHome(app)
        return app
    }

    @MainActor
    private func openNoticeBoard(_ app: XCUIApplication, fromMap: Bool = false) {
        tapAnimationControl("tabTown", in: app)
        if fromMap {
            scrollCareerPage("townMapScroll", to: "townPlot_board", in: app)
            tapAnimationControl("townPlot_board", in: app)
            waitForObservedValue("townPlaceDetail", "board", in: app)
            tapAnimationControl("townEnter_board", in: app)
        } else { tapAnimationControl("townCommunityPreviewButton", in: app) }
        waitForElement("townBoardScroll", in: app)
    }

    @MainActor
    private func townEventValue(_ app: XCUIApplication) throws -> (event: String, day: String, count: Int) {
        let card = element("townEventToday", in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        let pieces = try XCTUnwrap(card.value as? String).components(separatedBy: "|")
        XCTAssertEqual(pieces.count, 3)
        return (try XCTUnwrap(pieces.first), pieces[1], try XCTUnwrap(Int(pieces[2])))
    }
}
