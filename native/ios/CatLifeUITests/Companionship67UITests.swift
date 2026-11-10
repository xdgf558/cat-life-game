import XCTest

extension RoomHomeUITests {
    @MainActor
    func testCompanionship67PinnedGuideCanFoldChangeAndPersistWithoutSpending() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--uitesting-siamese-owned", "--furniture-test"]
        launchAndEnterHome(app)
        let startingGold = try XCTUnwrap(observedHomeValue("goldCount", in: app))
        _ = waitForFurniture(in: app, description: "the healthy adopted companion is ready", matching: {
            $0.phase == "idle" && !$0.pending && $0.activeCatID == "cat_004"
        })
        try openCurrentCatProfile(in: app)
        try chooseCompanionship67Guide("littleCorner", labels: ["给它留个舒服的位置"], in: app)
        waitForObservedValue("habitPinnedGuide", "littleCorner|expanded", in: app)
        XCTAssertFalse(element("catMemory_littleCorner", in: app).exists,
                       "Pinning is guidance and must not manufacture an undiscovered memory.")
        tapAnimationControl("closeSheetButton", in: app)
        dismissCompanionship67AdoptionReminders(in: app)
        waitForObservedValue("habitPinnedPrompt", "littleCorner|expanded", in: app)
        assertCompanionship67PromptClearsHUD(in: app)
        attachScreenshot(app, named: "Companionship 67 — one optional pinned hint on Home")
        tapAnimationControl("habitPinnedHintToggle", in: app)
        waitForObservedValue("habitPinnedPrompt", "littleCorner|collapsed", in: app)
        app.terminate()
        app.launchArguments = arguments(reset: false) + ["--uitesting-siamese-owned", "--furniture-test"]
        launchAndEnterHome(app)
        let reopenedGold = try XCTUnwrap(observedHomeValue("goldCount", in: app))
        XCTAssertEqual(reopenedGold, startingGold)
        dismissCompanionship67AdoptionReminders(in: app)
        waitForObservedValue("habitPinnedPrompt", "littleCorner|collapsed", in: app)
        attachScreenshot(app, named: "Companionship 67 — the folded hint survives cold launch")
        try openCurrentCatProfile(in: app)
        try chooseCompanionship67Guide("settledAfterMove", labels: ["换个地方看看"], in: app)
        waitForObservedValue("habitPinnedGuide", "settledAfterMove|expanded", in: app)
        XCTAssertFalse(element("catMemory_settledAfterMove", in: app).exists)
        tapAnimationControl("closeSheetButton", in: app)
        dismissCompanionship67AdoptionReminders(in: app)
        waitForObservedValue("habitPinnedPrompt", "settledAfterMove|expanded", in: app)
        try openCurrentCatProfile(in: app)
        scrollCareerPage("catProfileScroll", to: "habitGuideMenu", in: app)
        tapAnimationControl("habitGuideMenu", in: app)
        let unpin = app.buttons.matching(NSPredicate(format: "identifier == %@ OR label == %@", "habitUnpin", "取消置顶")).firstMatch
        XCTAssertTrue(unpin.waitForExistence(timeout: 5)); unpin.tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element("habitPinnedGuide", in: app))
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 8), .completed)
        tapAnimationControl("closeSheetButton", in: app)
        XCTAssertFalse(element("habitPinnedPrompt", in: app).exists)
        waitForObservedValue("goldCount", startingGold, in: app)
        waitForObservedValue("foodCount", "3", in: app)
        tapAnimationControl("tabInventory", in: app)
        waitForObservedValue("inventoryFoodCount", "3", in: app)
        waitForObservedValue("inventoryLitterCount", "2", in: app)
        waitForObservedValue("inventoryToyUses", "6", in: app)
    }

    @MainActor
    func testCompanionship67PinnedGuideSupportsThreeLanguagesAtLargestType() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        for (language, locale, label) in [("zh-Hans", "zh_CN", "换个地方看看"),
                                          ("zh-Hant", "zh_TW", "換個地方看看"),
                                          ("en", "en_US", "Explore a new spot")] {
            app.terminate()
            app.launchArguments = ["--ui-testing", "--skip-onboarding", "--reset-ui-test-save", "--uitesting-siamese-owned", "--furniture-test",
                "-AppleLanguages", "(\(language))", "-AppleLocale", locale, "--animation-test", "--reduce-motion-test",
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
            launchAndEnterHome(app)
            let startingGold = try XCTUnwrap(observedHomeValue("goldCount", in: app))
            openCompanionship67ProfileFromTown(in: app)
            try chooseCompanionship67Guide("settledAfterMove", labels: [label], in: app)
            waitForObservedValue("habitPinnedGuide", "settledAfterMove|expanded", in: app)
            attachScreenshot(app, named: "Companionship 67 — \(language), largest-type companion hint selection")
            tapAnimationControl("closeSheetButton", in: app)
            tapAnimationControl("tabHome", in: app)
            dismissCompanionship67AdoptionReminders(in: app)
            waitForObservedValue("habitPinnedPrompt", "settledAfterMove|expanded", in: app)
            assertCompanionship67PromptClearsHUD(title: label, in: app)
            attachScreenshot(app, named: "Companionship 67 — \(language), largest-type hint stays inside the stage")
            tapAnimationControl("habitPinnedHintToggle", in: app)
            waitForObservedValue("habitPinnedPrompt", "settledAfterMove|collapsed", in: app)
            waitForObservedValue("goldCount", startingGold, in: app)
            waitForObservedValue("foodCount", "3", in: app)
        }
    }

    @MainActor
    private func dismissCompanionship67AdoptionReminders(in app: XCUIApplication) {
        for _ in 0..<4 {
            let dismiss = element("adoptionReminderDismiss", in: app)
            guard dismiss.waitForExistence(timeout: 1) else { break }
            XCTAssertFalse(element("habitPinnedPrompt", in: app).exists,
                           "A visible adoption banner must have priority over the pinned hint.")
            tapAnimationControl("adoptionReminderDismiss", in: app)
        }
        XCTAssertFalse(element("adoptionAvailableNotice", in: app).exists)
    }

    @MainActor
    private func openCompanionship67ProfileFromTown(in app: XCUIApplication) {
        tapAnimationControl("tabTown", in: app)
        tapAnimationControl("townCollectionButton", in: app)
        waitForElement("catCollectionScroll", in: app)
        scrollCareerPage("catCollectionScroll", to: "catFilter_owned", in: app)
        tapAnimationControl("catFilter_owned", in: app)
        scrollCareerPage("catCollectionScroll", to: "catProfile_cat_004", in: app)
        tapAnimationControl("catProfile_cat_004", in: app)
        waitForObservedValue("catProfileScroll", "cat_004", in: app)
    }

    @MainActor
    private func chooseCompanionship67Guide(_ memory: String, labels: [String], in app: XCUIApplication) throws {
        scrollPage("catProfileScroll", to: "habitGuideMenu", allowDisabled: false, maximumDrags: 16, in: app)
        tapAnimationControl("habitGuideMenu", in: app)
        let option = app.buttons.matching(NSPredicate(format: "identifier == %@ OR label IN %@", "habitPin_" + memory, labels)).firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 5)); option.tap()
    }

    @MainActor
    private func assertCompanionship67PromptClearsHUD(title: String? = nil, in app: XCUIApplication) {
        let prompt = element("habitRoomPromptScroll", in: app).frame
        XCTAssertTrue(element("roomStage63", in: app).frame.contains(prompt))
        let toggle = element("habitPinnedHintToggle", in: app)
        XCTAssertTrue(toggle.exists && toggle.isHittable)
        XCTAssertTrue(prompt.contains(toggle.frame), "The entire title and fold button must remain in the visible hint viewport.")
        if let title { XCTAssertTrue(toggle.label.contains(title)) }
        let adoption = element("adoptionAvailableNotice", in: app)
        if adoption.exists { XCTAssertFalse(prompt.intersects(adoption.frame), "The adoption banner must not cover the hint title.") }
        for identifier in ["homeNamePlaque", "homeResourceCapsule", "homeMyCatsButton", "homeDecorateButton",
                           "homeCareBar63", "roomViewControls", "homeNavigationBar"] {
            let control = element(identifier, in: app)
            if control.exists { XCTAssertFalse(prompt.intersects(control.frame), "The hint must leave \(identifier) clear.") }
        }
    }
}
