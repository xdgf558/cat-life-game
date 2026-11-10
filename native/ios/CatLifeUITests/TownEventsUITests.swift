import XCTest

extension RoomHomeUITests {
    @MainActor
    func testTownEventReplyMilestoneAndRelaunchKeepOneReward() throws {
        continueAfterFailure = false
        let app = launchTownEventFixture()
        openNoticeBoard(app, fromMap: true)
        let before = try townEventValue(app)
        XCTAssertEqual(before.count, 6)
        let stamina = element("townBoardStamina", in: app).value as? String
        tapAnimationControl("townBoardTab_memento", in: app)
        waitForObservedValue("townEventMilestone_town_memory_7", "locked", in: app)
        XCTAssertFalse(element("townEventClaim_town_memory_7", in: app).isEnabled)
        attachScreenshot(app, named: "Handoff E8 — locked keepsake and real non-consecutive participation progress")
        tapAnimationControl("townBoardTab_today", in: app)
        XCTAssertFalse(element("townEventConfirmButton", in: app).isEnabled)
        attachScreenshot(app, named: "Handoff E1 — pinned invitation, two choices, unselected confirmation")
        scrollCareerPage("townEventDetail", to: "townEventChoice_help", in: app)
        tapAnimationControl("townEventChoice_help", in: app)
        XCTAssertTrue(element("townEventChoice_help", in: app).isSelected)
        XCTAssertEqual(element("townBoardStamina", in: app).value as? String, stamina)
        XCTAssertEqual(try townEventValue(app).count, before.count, "Selecting must not consume or complete anything.")
        XCTAssertFalse(element("townEventLetter", in: app).exists)
        attachScreenshot(app, named: "Handoff E2 — selected card, still no spending")
        tapAnimationControl("townEventConfirmButton", in: app)
        waitForObservedValue("townEventLetter", before.event, in: app)
        waitForElement("townEventActualRewards", in: app)
        attachScreenshot(app, named: "Handoff E5 — saved reply, signature and actual delivered rewards")
        tapAnimationControl("townEventBackButton", in: app)
        XCTAssertEqual(try townEventValue(app).count, 7)
        XCTAssertFalse(element("townEventConfirmButton", in: app).exists)
        waitForElement("townEventTodayLetter", in: app)
        attachScreenshot(app, named: "Handoff E6 — participation stamp and reread entry")
        tapAnimationControl("townBoardTab_letters", in: app)
        let letters = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "townLetter_"))
        XCTAssertTrue(letters.firstMatch.waitForExistence(timeout: 8))
        XCTAssertGreaterThan(letters.count, 0); XCTAssertLessThanOrEqual(letters.count, 4)
        attachScreenshot(app, named: "Handoff E7 — envelope cards and paged letters")
        scrollCareerPage("townBoardScroll", to: "townLettersNext", in: app)
        tapAnimationControl("townLettersNext", in: app)
        waitForObservedValue("townLettersPage", "2/2", in: app)
        XCTAssertFalse(element("townLettersNext", in: app).isEnabled)
        tapAnimationControl("townBoardTab_memento", in: app)
        scrollCareerPage("townBoardScroll", to: "townEventClaim_town_memory_7", in: app)
        attachScreenshot(app, named: "Handoff E9 — seven paw stamps, keepsake ready")
        tapAnimationControl("townEventClaim_town_memory_7", in: app)
        waitForObservedValue("townEventMilestone_town_memory_7", "claimed", in: app)
        tapAnimationControl("townEventArrangeMemento", in: app)
        waitForObservedValue("layoutTrayToggle", "expanded", in: app)
        waitForElement("layoutStored_town-event-memory", in: app)
        attachScreenshot(app, named: "Handoff — claimed keepsake opens the real furniture tray without placing it")
        tapAnimationControl("layoutCancelButton", in: app)
        tapAnimationControl("tabMore", in: app); tapAnimationControl("tabInventory", in: app)
        tapAnimationControl("inventoryFurnitureTab", in: app)
        scrollCareerPage("destinationScroll", to: "inventoryFurniture_town-event-memory", in: app)
        waitForLabel("inventoryFurniture_town-event-memory", "猫町邻里纪念画", in: app, contains: true)
        app.terminate()
        app.launchArguments = arguments(reset: false) + ["--town-events-fixture"]
        launchAndEnterHome(app)
        openNoticeBoard(app)
        XCTAssertEqual(try townEventValue(app).count, 7)
        XCTAssertFalse(element("townEventChoice_help", in: app).exists)
        tapAnimationControl("townBoardTab_memento", in: app)
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
            scrollCareerPage("townEventDetail", to: "townEventChoice_supply", in: app)
            for id in ["help", "supply"] {
                let label = element("townEventChoice_\(id)", in: app).label
                XCTAssertFalse(label.contains("townEvents.")); XCTAssertFalse(label.contains("supply."))
            }
            tapAnimationControl("townEventChoice_supply", in: app)
            XCTAssertTrue(element("townEventConfirmButton", in: app).isEnabled)
            attachScreenshot(app, named: "Handoff — localized choice confirmation \(code)")
            tapAnimationControl("tabHome", in: app)
        }
        app.terminate()
        app.launchArguments = arguments(reset: true) + ["--town-events-fixture", "--save-outage-test"]
        launchAndEnterHome(app); openNoticeBoard(app)
        let before = try townEventValue(app)
        scrollCareerPage("townEventDetail", to: "townEventChoice_help", in: app)
        tapAnimationControl("townEventChoice_help", in: app)
        tapAnimationControl("townEventConfirmButton", in: app)
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 8))
        XCTAssertFalse(element("townEventLetter", in: app).exists)
        attachScreenshot(app, named: "Handoff — save failure never reveals a reply or spends resources")
        app.terminate()
        app.launchArguments = arguments(reset: false) + ["--town-events-fixture"]
        launchAndEnterHome(app); openNoticeBoard(app)
        XCTAssertEqual(try townEventValue(app).count, before.count)
        scrollCareerPage("townEventDetail", to: "townEventChoice_help", in: app)
        tapAnimationControl("townEventChoice_help", in: app); tapAnimationControl("townEventConfirmButton", in: app)
        waitForObservedValue("townEventLetter", before.event, in: app)
    }

    @MainActor
    func testTownEventAccessibilityTextKeepsRepliesPagedAndChoicesReachable() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--town-events-fixture",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        launchAndEnterHome(app); openNoticeBoard(app)
        tapAnimationControl("townBoardTab_letters", in: app)
        let letters = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "townLetter_"))
        XCTAssertTrue(letters.firstMatch.waitForExistence(timeout: 8)); XCTAssertLessThanOrEqual(letters.count, 2)
        attachScreenshot(app, named: "Handoff — accessibility text keeps two replies per page")
        tapAnimationControl("townBoardTab_today", in: app)
        let choice = element("townEventChoice_help", in: app)
        scrollCareerPage("townEventDetail", to: "townEventChoice_help", in: app)
        XCTAssertTrue(choice.isHittable); choice.tap()
        XCTAssertTrue(element("townEventConfirmButton", in: app).isHittable)
        attachScreenshot(app, named: "Handoff — large text leaves the deliberate confirmation reachable")
        tapAnimationControl("townEventConfirmButton", in: app)
        waitForElement("townEventLetter", in: app)
    }

    @MainActor
    func testTownUnavailableChoiceExplainsAlternativeAndCannotBeSelected() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--town-events-fixture", "--town-events-no-stamina"]
        launchAndEnterHome(app); openNoticeBoard(app)
        let before = try townEventValue(app)
        waitForObservedValue("townBoardStamina", "0", in: app)
        scrollCareerPage("townEventDetail", to: "townEventChoice_help", in: app)
        tapAnimationControl("townEventChoice_help", in: app)
        XCTAssertFalse(element("townEventChoice_help", in: app).isSelected)
        XCTAssertFalse(element("townEventConfirmButton", in: app).isEnabled)
        XCTAssertEqual(try townEventValue(app).count, before.count)
        attachScreenshot(app, named: "Handoff E3 — unavailable help explains the supply alternative")
        scrollCareerPage("townEventDetail", to: "townEventChoice_supply", in: app)
        tapAnimationControl("townEventChoice_supply", in: app)
        tapAnimationControl("townEventConfirmButton", in: app)
        waitForElement("townEventLetter", in: app)
    }

    @MainActor private func launchTownEventFixture() -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = arguments(reset: true) + ["--town-events-fixture"]
        launchAndEnterHome(app); return app
    }
    @MainActor private func openNoticeBoard(_ app: XCUIApplication, fromMap: Bool = false) {
        tapAnimationControl("tabTown", in: app)
        if fromMap {
            scrollCareerPage("townMapScroll", to: "townPlot_board", in: app)
            tapAnimationControl("townPlot_board", in: app); waitForObservedValue("townPlaceDetail", "board", in: app)
            tapAnimationControl("townEnter_board", in: app)
        } else { tapAnimationControl("townCommunityPreviewButton", in: app) }
        waitForElement("townBoardTab_today", in: app)
    }
    @MainActor private func townEventValue(_ app: XCUIApplication) throws -> (event: String, day: String, count: Int) {
        let card = element("townEventToday", in: app); XCTAssertTrue(card.waitForExistence(timeout: 8))
        let pieces = try XCTUnwrap(card.value as? String).components(separatedBy: "|")
        XCTAssertEqual(pieces.count, 3)
        return (try XCTUnwrap(pieces.first), pieces[1], try XCTUnwrap(Int(pieces[2])))
    }
}
