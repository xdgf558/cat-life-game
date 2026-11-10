import XCTest

extension RoomHomeUITests {
    @MainActor
    func testHabitTwoNaturalCushionRestsConfirmPreferenceAndPersistMemories() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--rest-test"]
        launchAndEnterHome(app)
        _ = try beginFurnitureRest("floorCushion", in: app)
        waitForElement("habitCornerOffer", in: app, timeout: 20)
        tapAnimationControl("habitCornerLater", in: app)
        _ = waitForFurniture(in: app, description: "first observation ends naturally",
                             matching: { $0.phase == "idle" && $0.restPhase == "none" && !$0.pending })
        _ = try beginFurnitureRest("floorCushion", in: app)
        waitForElement("habitCornerOffer", in: app, timeout: 20)
        tapAnimationControl("habitCornerKeep", in: app)
        try openCurrentCatProfile(in: app)
        scrollCareerPage("catProfileScroll", to: "habitRestProgress", in: app)
        waitForObservedValue("habitRestProgress", "2/2", in: app)
        scrollCareerPage("catProfileScroll", to: "catMemory_favoriteRest", in: app)
        XCTAssertTrue(element("catMemory_favoriteRest", in: app).isHittable)
        XCTAssertFalse(element("catMemory_firstResponse", in: app).exists, "Rest must not invent a play response.")
        attachScreenshot(app, named: "Habits 63 — two naturally completed cushion observations")
        tapAnimationControl("closeSheetButton", in: app)
        assertRestSuppliesUnchanged(in: app)
        _ = relaunchRestHome(app)
        try openCurrentCatProfile(in: app)
        scrollCareerPage("catProfileScroll", to: "habitRestProgress", in: app)
        waitForObservedValue("habitRestProgress", "2/2", in: app)
        scrollCareerPage("catProfileScroll", to: "catMemory_littleCorner", in: app)
        XCTAssertTrue(element("catMemory_littleCorner", in: app).isHittable)
        attachScreenshot(app, named: "Habits 63 — rest preference and corner memories survive a cold launch")
    }

    @MainActor
    func testHabitFreeTutorialAndStarterCornerNeedNoPurchase() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--rest-test"]
        launchAndEnterHome(app, keepsHabitIntro: true)
        waitForElement("habitIntroBanner", in: app)
        assertHabitPromptClearsHUD("habitIntroBanner", in: app)
        attachScreenshot(app, named: "Habits 63 — optional first-play prompt")
        tapAnimationControl("habitIntroPlay", in: app)
        completeHabitTutorial(in: app)
        waitForObservedValue("habitPlayProgress", "1/2", in: app)
        XCTAssertFalse(element("catMemory_favoritePlay", in: app).exists)
        scrollCareerPage("playTogetherScroll", to: "catMemory_firstResponse", in: app)
        attachScreenshot(app, named: "Habits 63 — first response without a purchase")
        tapAnimationControl("playTogetherFinishButton", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        waitForObservedValue("foodCount", "3", in: app)
        _ = waitForFurniture(in: app, description: "room resumes after free play", matching: { $0.phase == "idle" && !$0.pending })
        _ = try beginFurnitureRest("catBed", in: app)
        waitForElement("habitCornerOffer", in: app, timeout: 20)
        assertHabitPromptClearsHUD("habitCornerOffer", in: app)
        attachScreenshot(app, named: "Habits 63 — a nonpreferred bed is still a valid corner")
        tapAnimationControl("habitCornerKeep", in: app)
        try openCurrentCatProfile(in: app)
        scrollCareerPage("catProfileScroll", to: "catMemory_littleCorner", in: app)
        XCTAssertTrue(element("catMemory_firstResponse", in: app).exists)
        attachScreenshot(app, named: "Habits 63 — two memories with starter furniture")
        tapAnimationControl("closeSheetButton", in: app)
        tapAnimationControl("tabHome", in: app)
        openHabitPlay(in: app)
        waitForElement("buyToyButton", in: app)
        waitForObservedValue("shopGoldCount", "200", in: app)
        XCTAssertFalse(element("playTogetherStage", in: app).exists, "A second free tutorial must not be granted.")
        scrollCareerPage("destinationScroll", to: "buyToyButton", in: app)
        tapAnimationControl("buyToyButton", in: app)
        waitForObservedValue("shopGoldCount", "165", in: app)
        tapAnimationControl("tabHome", in: app)
        _ = waitForFurniture(in: app, description: "room is ready for ordinary paid play", matching: { $0.phase == "idle" && !$0.pending })
        openHabitPlay(in: app)
        tapAnimationControl("playTogether_moveAndPause", in: app)
        waitForHabitStage(in: app, matching: { $0.hasPrefix("satisfied|1|1") })
        attachScreenshot(app, named: "Habits 63 — paid pause produces one complete response")
        XCUIDevice.shared.press(.home)
        waitForAppBackground(in: app)
        app.activate()
        waitForElement("playTogetherResult", in: app)
        XCTAssertFalse(element("playTogetherStage", in: app).exists, "Foreground return shows a result, never a paused play scene.")
        waitForObservedValue("playTogetherToyCost", "1", in: app)
        waitForObservedValue("habitPlayProgress", "2/2", in: app)
        scrollCareerPage("playTogetherScroll", to: "catMemory_favoritePlay", in: app)
        tapAnimationControl("playTogetherFinishButton", in: app)
        tapAnimationControl("tabInventory", in: app)
        waitForObservedValue("inventoryToyUses", "5", in: app)
        relaunchPreservingSave(app)
        tapAnimationControl("tabInventory", in: app)
        waitForObservedValue("inventoryToyUses", "5", in: app)
    }

    @MainActor
    func testHabitObservationModeHidesConclusionsUntilContinue() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        tapAnimationControl("settingsButton", in: app)
        tapSettingsRootControl("settingsHabitStudyRow", in: app)
        tapAnimationControl("habitStudyToggle", in: app)
        tapAnimationControl("tabHome", in: app)
        openHabitPlay(in: app)
        completeHabitTutorial(in: app, study: true)
        XCTAssertFalse(element("catHabitsSection", in: app).exists)
        XCTAssertFalse(element("catMemory_firstResponse", in: app).exists)
        attachScreenshot(app, named: "Habits 63 — ask the player before revealing conclusions")
        tapAnimationControl("playTogetherContinue", in: app)
        waitForElement("playTogetherResult", in: app)
        waitForObservedValue("habitPlayProgress", "1/2", in: app)
        tapAnimationControl("playTogetherFinishButton", in: app)
        tapAnimationControl("settingsButton", in: app)
        tapSettingsRootControl("settingsHabitStudyRow", in: app)
        scrollCareerPage("habitStudyScroll", to: "habitStudyClear", in: app)
        XCTAssertTrue(element("habitStudyExport", in: app).exists)
        attachScreenshot(app, named: "Habits 63 — optional device-only observation settings")
    }

    @MainActor
    func testHabitRealHorizontalDragAndPauseEarnTheSameFreeTutorialMemory() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        openHabitPlay(in: app)
        waitForElement("playTogetherStage", in: app)
        let stage = element("playTogetherStage", in: app)
        let start = stage.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5))
        let end = stage.coordinate(withNormalizedOffset: CGVector(dx: 0.70, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: XCUIGestureVelocity(rawValue: 35), thenHoldForDuration: 0.9)
        waitForElement("playTogetherResult", in: app, timeout: 15)
        waitForObservedValue("habitPlayProgress", "1/2", in: app)
        scrollCareerPage("playTogetherScroll", to: "catMemory_firstResponse", in: app)
        XCTAssertTrue(element("catMemory_firstResponse", in: app).isHittable)
        attachScreenshot(app, named: "Habits 63 — real drag, pause and a saved first-response memory")
        tapAnimationControl("playTogetherFinishButton", in: app)
        tapAnimationControl("tabInventory", in: app)
        waitForObservedValue("inventoryToyUses", "0", in: app)
    }

    @MainActor
    func testHabitAllFiveCatsKeepTheirOwnResponsesAndCosts() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--shared-home-test", "--rest-test"]
        launchAndEnterHome(app)
        for (index, id) in ["cat_001", "cat_002", "cat_003", "cat_004", "cat_005"].enumerated() {
            if index > 0 {
                tapAnimationControl("homeMyCatsButton", in: app)
                scrollCareerPage("sharedHomeDirectory", to: "sharedHomeSelect_\(id)", in: app)
                tapAnimationControl("sharedHomeSelect_\(id)", in: app)
                waitForObservedValue("homeMyCatsButton", id, in: app)
            }
            _ = waitForFurniture(in: app, description: "\(id) is ready for play", matching: { $0.phase == "idle" && !$0.pending })
            openHabitPlay(in: app)
            let slowPreferred = id == "cat_002" || id == "cat_003"
            let comparison = slowPreferred ? "moveAndPause" : "slowMove"
            let matching = slowPreferred ? "slowMove" : "moveAndPause"
            tapAnimationControl("playTogether_\(comparison)", in: app)
            waitForHabitStage(in: app, matching: { $0.hasPrefix("waiting|0|") && $0.split(separator: "|").last == "1" })
            tapAnimationControl("playTogether_\(matching)", in: app)
            waitForHabitStage(in: app, allowsCompletedResult: true, matching: { $0.contains("|1|") && $0.split(separator: "|").last == "2" })
            if index > 0 && !element("playTogetherResult", in: app).exists { tapAnimationControl("playTogetherFinishButton", in: app) }
            waitForElement("playTogetherResult", in: app)
            waitForObservedValue("playTogetherResult", "\(id)|2|\(index == 0 ? 0 : 1)", in: app)
            waitForObservedValue("habitPlayProgress", "1/2", in: app)
            XCTAssertFalse(element("catMemory_favoritePlay", in: app).exists)
            attachScreenshot(app, named: "Habits 63 — \(id) saved one comparison and one complete response")
            tapAnimationControl("playTogetherFinishButton", in: app)
        }
        tapAnimationControl("tabInventory", in: app)
        waitForObservedValue("inventoryToyUses", "8", in: app, timeout: 10)
        attachScreenshot(app, named: "Habits 63 — one tutorial plus four single-charge sessions")
    }

    @MainActor
    func testHabitTapControlsAndMemoriesSupportThreeLanguagesAtLargestType() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        for (language, locale, title) in [("zh-Hans", "zh_CN", "一起玩"), ("zh-Hant", "zh_TW", "一起玩"), ("en", "en_US", "Play Together")] {
            app.terminate()
            app.launchArguments = ["--ui-testing", "--skip-onboarding", "--reset-ui-test-save",
                "-AppleLanguages", "(\(language))", "-AppleLocale", locale, "--reduce-motion-test",
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
            launchAndEnterHome(app)
            openHabitPlay(in: app)
            waitForElement("playTogether_slowMove", in: app)
            waitForLabel("playTogether_slowMove", language == "en" ? "Move slowly" : language == "zh-Hant" ? "慢慢移動" : "慢慢移动", in: app)
            XCTAssertTrue(app.staticTexts[title].exists)
            completeHabitTutorial(in: app)
            scrollCareerPage("playTogetherScroll", to: "catMemory_firstResponse", in: app)
            XCTAssertTrue(element("catMemory_firstResponse", in: app).isHittable)
            attachScreenshot(app, named: "Habits 63 — \(language), maximum accessibility text, reduced motion")
            tapAnimationControl("playTogetherFinishButton", in: app)
        }
    }

    @MainActor
    private func completeHabitTutorial(in app: XCUIApplication, study: Bool = false) {
        waitForElement("playTogetherStage", in: app)
        scrollCareerPage("playTogetherScroll", to: "playTogether_slowMove", in: app)
        tapAnimationControl("playTogether_slowMove", in: app)
        waitForObservedValue("playTogetherTutorialHint", "1", in: app, timeout: 7)
        XCTAssertTrue((element("playTogetherStage", in: app).value as? String)?.contains("|0|0") == true,
                      "The orange cat watches a slow move without pouncing or charging.")
        scrollCareerPage("playTogetherScroll", to: "playTogether_moveAndPause", in: app)
        tapAnimationControl("playTogether_moveAndPause", in: app)
        waitForElement(study ? "playTogetherContinue" : "playTogetherResult", in: app, timeout: 12)
    }

    @MainActor
    private func openHabitPlay(in app: XCUIApplication) {
        tapAnimationControl("playButton", in: app)
        let choice = app.buttons.matching(NSPredicate(format: "identifier == %@ OR label IN %@",
            "playTogetherChoice", ["一起玩", "Play Together"])).firstMatch
        XCTAssertTrue(choice.waitForExistence(timeout: 5))
        choice.tap()
    }

    @MainActor
    private func assertHabitPromptClearsHUD(_ identifier: String, in app: XCUIApplication) {
        XCTAssertTrue(element(identifier, in: app).exists)
        let prompt = element("habitRoomPromptScroll", in: app).frame
        XCTAssertTrue(element("roomStage63", in: app).frame.contains(prompt),
                      "The visible prompt viewport must stay inside the room stage even when its content scrolls.")
        for id in ["homeNamePlaque", "homeResourceCapsule", "homeMyCatsButton", "homeDecorateButton",
                   "homeCareBar63", "roomViewControls", "homeNavigationBar"] {
            let control = element(id, in: app)
            if control.exists { XCTAssertFalse(prompt.intersects(control.frame), "The prompt cannot cover \(id).") }
        }
    }

    @MainActor
    private func waitForHabitStage(in app: XCUIApplication, allowsCompletedResult: Bool = false,
                                  matching condition: @escaping (String) -> Bool) {
        let stage = element("playTogetherStage", in: app)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            if stage.exists && condition(stage.value as? String ?? "") { return true }
            let result = self.element("playTogetherResult", in: app)
            return allowsCompletedResult && result.exists
                && (result.value as? String)?.split(separator: "|").dropFirst().first == "2"
                && self.element("catMemory_firstResponse", in: app).exists
        }, object: stage)
        let result = XCTWaiter.wait(for: [ready], timeout: 10)
        if result != .completed {
            attachScreenshot(app, named: "Habits 63 — response observation failure")
            let attachment = XCTAttachment(string: app.debugDescription)
            attachment.name = "Habits 63 — response hierarchy"; attachment.lifetime = .keepAlways; add(attachment)
        }
        XCTAssertEqual(result, .completed, "Stage value: \(stage.exists ? String(describing: stage.value) : "no stage; result shown: \(element("playTogetherResult", in: app).exists)")")
    }
}
