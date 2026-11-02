import XCTest

extension RoomHomeUITests {
    @MainActor
    func testPlayerNavigationPortraitFollowsSelectionAndRelaunch() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        assertKnownHomeViewportBaseline(in: app)
        ensureHomeNavigationItemVisible("tabPlayer", in: app)
        waitForObservedValue("tabPlayer", "还没有选择形象", in: app)
        let barFrame = element("homeNavigationBar", in: app).frame
        let playerTabSize = element("tabPlayer", in: app).frame.size
        let contentWidth = element("settingsButton", in: app).frame.maxX
            - element("tabHome", in: app).frame.minX
        attachScreenshot(app, named: "Player navigation — unselected fallback on the real home bar")

        let names = ["晴日男生", "森系男生", "书卷男生", "晴日女生", "森系女生", "书卷女生"]
        for (id, name) in zip(playerMaleAvatarIDs + playerFemaleAvatarIDs, names) {
            openPlayerProfile(in: app)
            tapProfileControl("profileChooseAvatar", in: app)
            tapProfilePageControl("avatarSelect_\(id)", scroll: "avatarPickerScroll", in: app)
            scrollCareerPage("avatarPickerScroll", to: "avatarSelectedID", in: app)
            waitForObservedValue("avatarSelectedID", id, in: app)
            tapAnimationControl("profileBackButton", in: app)
            assertProfileValue("profileAvatarName", id, in: app)
            tapAnimationControl("closeSheetButton", in: app)

            // Inspect the actual home entry after the sheet closes. The
            // portrait inside the profile cannot prove this bug is fixed.
            assertPlayerNavigationPortrait(name, barFrame: barFrame, tabSize: playerTabSize,
                                              contentWidth: contentWidth, in: app)
            assertKnownHomeViewportBaseline(in: app)
            attachScreenshot(app, named: "Player navigation — home portrait \(id)")
        }

        relaunchPreservingSave(app)
        assertPlayerNavigationPortrait("书卷女生", barFrame: barFrame, tabSize: playerTabSize,
                                          contentWidth: contentWidth, in: app)
        assertKnownHomeViewportBaseline(in: app)
        attachScreenshot(app, named: "Player navigation — female_scholarly retained after cold launch")
        // The last selected portrait must still open the same profile.
        openPlayerProfile(in: app)
        assertProfileValue("profileAvatarName", "female_scholarly", in: app)
        tapAnimationControl("closeSheetButton", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        waitForObservedValue("foodCount", "3", in: app)
    }

    @MainActor
    func testPlayerAvatarsAndFreeEquipmentPersistAcrossRelaunch() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        assertKnownHomeViewportBaseline(in: app)
        openPlayerProfile(in: app)
        assertProfileValue("profileAvatarName", "none", in: app)
        for (id, value) in [("profileLevel", "1"), ("profileExp", "0"),
                            ("profileStamina", "80"), ("profileMood", "80"),
                            ("profileGold", "200"), ("profileCompletedWork", "0"),
                            ("profileEquippedCount", "0")] {
            assertProfileValue(id, value, in: app)
        }
        tapProfileControl("profileChooseAvatar", in: app)
        tapProfilePageControl("avatarFilterMale", scroll: "avatarPickerScroll", in: app)
        for id in playerMaleAvatarIDs {
            scrollCareerPage("avatarPickerScroll", to: "avatarSelect_\(id)", in: app)
            XCTAssertTrue(element("avatarSelect_\(id)", in: app).isEnabled)
            XCTAssertTrue(element("avatarSelect_\(id)", in: app).isHittable)
            attachScreenshot(app, named: "Player artwork — visible card \(id)")
        }
        for id in playerFemaleAvatarIDs { XCTAssertFalse(element("avatarSelect_\(id)", in: app).exists) }
        tapProfilePageControl("avatarSelect_male_sunny", scroll: "avatarPickerScroll", in: app)
        scrollCareerPage("avatarPickerScroll", to: "avatarSelectedID", in: app)
        waitForObservedValue("avatarSelectedID", "male_sunny", in: app)
        attachScreenshot(app, named: "Player — three male appearances with a saved selection")
        tapProfilePageControl("avatarFilterFemale", scroll: "avatarPickerScroll", in: app)
        for id in playerFemaleAvatarIDs {
            scrollCareerPage("avatarPickerScroll", to: "avatarSelect_\(id)", in: app)
            XCTAssertTrue(element("avatarSelect_\(id)", in: app).isEnabled)
            XCTAssertTrue(element("avatarSelect_\(id)", in: app).isHittable)
            attachScreenshot(app, named: "Player artwork — visible card \(id)")
        }
        for id in playerMaleAvatarIDs { XCTAssertFalse(element("avatarSelect_\(id)", in: app).exists) }
        tapProfilePageControl("avatarSelect_female_scholarly", scroll: "avatarPickerScroll", in: app)
        scrollCareerPage("avatarPickerScroll", to: "avatarSelectedID", in: app)
        waitForObservedValue("avatarSelectedID", "female_scholarly", in: app)
        attachScreenshot(app, named: "Player — three female appearances with a saved selection")
        tapProfilePageControl("avatarFilterAll", scroll: "avatarPickerScroll", in: app)
        for id in playerMaleAvatarIDs + playerFemaleAvatarIDs {
            scrollCareerPage("avatarPickerScroll", to: "avatarSelect_\(id)", in: app)
            XCTAssertTrue(element("avatarSelect_\(id)", in: app).isHittable)
        }
        tapAnimationControl("profileBackButton", in: app)
        assertProfileValue("profileAvatarName", "female_scholarly", in: app)
        // Frame the complete portrait for artwork review after returning from
        // the picker, which restores the profile's previous scroll position.
        scrollCareerPage("profileScroll", to: "profileStatus", in: app)
        attachScreenshot(app, named: "Player artwork — selected female_scholarly profile portrait")
        assertProfileValue("profileStamina", "80", in: app)
        assertProfileValue("profileMood", "80", in: app)
        tapProfileControl("profileEquipAllButton", in: app)
        assertProfileValue("profileEquippedCount", "4", in: app)
        assertProfileBonuses(duration: 15, stamina: 15, mood: 20, in: app)
        for (slot, item) in playerStarterEquipment {
            assertProfileValue("equipmentSlot_\(slot)", item, in: app)
        }
        attachScreenshot(app, named: "Player — the free starter set occupies four distinct slots")
        tapProfileControl("equipmentSlot_head", in: app)
        waitForObservedValue("equippedItem_head", "starter_cap", in: app)
        tapProfilePageControl("unequipSlot_head", scroll: "equipmentScroll", in: app)
        waitForObservedValue("equippedItem_head", "none", in: app)
        // Removing an item must keep it available to wear again, without buying it.
        scrollCareerPage("equipmentScroll", to: "equipItem_starter_cap", in: app)
        XCTAssertTrue(element("equipItem_starter_cap", in: app).isEnabled)
        tapAnimationControl("profileBackButton", in: app)
        assertProfileValue("profileEquippedCount", "3", in: app)
        assertProfileBonuses(duration: 15, stamina: 15, mood: 0, in: app)
        tapAnimationControl("closeSheetButton", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        relaunchPreservingSave(app)
        openPlayerProfile(in: app)
        assertProfileValue("profileAvatarName", "female_scholarly", in: app)
        assertProfileValue("profileEquippedCount", "3", in: app)
        assertProfileValue("equipmentSlot_head", "none", in: app)
        tapProfileControl("equipmentSlot_head", in: app)
        tapProfilePageControl("equipItem_starter_cap", scroll: "equipmentScroll", in: app)
        waitForObservedValue("equippedItem_head", "starter_cap", in: app)
        tapAnimationControl("profileBackButton", in: app)
        assertProfileValue("profileEquippedCount", "4", in: app)
        assertProfileValue("profileGold", "200", in: app)
        tapAnimationControl("closeSheetButton", in: app)
        waitForObservedValue("foodCount", "3", in: app)
        assertKnownHomeViewportBaseline(in: app)
    }

    @MainActor
    func testEquippedWorkKeepsCapturedTermsAndSettlesOnce() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--career-level10-fixture"]
        launchAndEnterHome(app)
        openPlayerProfile(in: app)
        tapProfileControl("profileEquipAllButton", in: app)
        assertProfileValue("profileEquippedCount", "4", in: app)
        tapAnimationControl("closeSheetButton", in: app)
        openCareerHome(in: app)
        tapCareerControl("careerChooseJobButton", in: app)
        scrollCareerPage("careerJobsScroll", to: "careerSelect_job_cat_cafe_manager", in: app)
        tapAnimationControl("careerSelect_job_cat_cafe_manager", in: app)
        assertWorkQuote(duration: 1530, stamina: 43, mood: 16, in: app)
        attachScreenshot(app, named: "Equipment — actual cafe preview includes duration and cost reductions")
        tapCareerControl("startWorkButton", in: app)
        scrollRecoveryCard(to: "activeWorkDurationSeconds", in: app)
        waitForObservedValue("activeWorkDurationSeconds", "1530", in: app)
        try assertVisibleTimerChanges("workCountdown", increasing: false, upperBound: 1530, in: app,
                                      context: "the equipped cafe shift uses its captured duration")
        tapAnimationControl("closeSheetButton", in: app)
        openPlayerProfile(in: app)
        assertProfileValue("profileStatus", "working", in: app)
        assertProfileValue("profileStamina", "57", in: app)
        assertProfileValue("profileMood", "84", in: app)
        tapProfileControl("equipmentSlot_feet", in: app)
        tapProfilePageControl("unequipSlot_feet", scroll: "equipmentScroll", in: app)
        waitForObservedValue("equippedItem_feet", "none", in: app)
        tapAnimationControl("profileBackButton", in: app)
        assertProfileValue("profileDurationBonus", "5", in: app)
        tapAnimationControl("closeSheetButton", in: app)
        openCareerHome(in: app)
        assertWorkQuote(duration: 1530, stamina: 43, mood: 16, in: app)
        waitForObservedValue("activeWorkDurationSeconds", "1530", in: app)
        tapAnimationControl("closeSheetButton", in: app)
        relaunchPreservingSave(app)
        openCareerHome(in: app)
        scrollRecoveryCard(to: "activeWorkDurationSeconds", in: app)
        waitForObservedValue("activeWorkDurationSeconds", "1530", in: app)
        assertWorkQuote(duration: 1530, stamina: 43, mood: 16, in: app)
        tapAnimationControl("closeSheetButton", in: app)
        openPlayerProfile(in: app)
        assertProfileValue("profileEquippedCount", "3", in: app)
        assertProfileValue("equipmentSlot_feet", "none", in: app)
        assertProfileValue("profileStamina", "57", in: app)
        assertProfileValue("profileMood", "84", in: app)
        assertProfileValue("profileGold", "200", in: app)
        tapAnimationControl("closeSheetButton", in: app)

        // A separate real persisted flyer shift has 45 seconds left. The
        // fixture uses the same Core startWork path and captured 102-second
        // quote; no accelerated clock or direct reward mutation is involved.
        app.terminate()
        app.launchArguments = arguments(reset: true) + ["--player-equipped-active-fixture"]
        launchAndEnterHome(app)
        openCareerHome(in: app)
        waitForObservedValue("activeWorkDurationSeconds", "102", in: app)
        try assertVisibleTimerChanges("workCountdown", increasing: false, upperBound: 45, in: app,
                                      context: "a saved equipped flyer shift resumes")
        let remaining = try XCTUnwrap(displayedTimerSeconds(element("workCountdown", in: app).label))
        let expectedCompletion = Date().addingTimeInterval(TimeInterval(remaining + 2))
        XCUIDevice.shared.press(.home)
        waitForAppBackground(in: app)
        let deadline = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in Date() >= expectedCompletion }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [deadline], timeout: TimeInterval(remaining + 6)), .completed)
        app.activate()
        waitForElement("workResultID", in: app, timeout: 15)
        let resultID = try assertCareerResult(job: "job_flyer", gold: 60, experience: 22,
                                             levelBefore: 1, levelAfter: 1, expAfter: 22, in: app)
        attachScreenshot(app, named: "Equipment — discounted work pays its unchanged gold and experience once")
        closeCareerResult(in: app)
        assertWorkQuote(duration: 102, stamina: 9, mood: 4, in: app)
        tapAnimationControl("closeSheetButton", in: app)
        waitForObservedValue("goldCount", "260", in: app)
        openPlayerProfile(in: app)
        assertProfileValue("profileStamina", "71", in: app)
        assertProfileValue("profileMood", "76", in: app)
        assertProfileValue("profileCompletedWork", "1", in: app)
        assertProfileValue("profileExp", "22", in: app)
        tapAnimationControl("closeSheetButton", in: app)
        app.terminate()
        app.launchArguments = arguments(reset: false) + ["--player-equipped-active-fixture"]
        launchAndEnterHome(app)
        waitForObservedValue("goldCount", "260", in: app)
        openCareerHome(in: app)
        waitForObservedValue("playerExperience", "22", in: app)
        openCareerResult(in: app)
        waitForObservedValue("workResultID", resultID, in: app)
        closeCareerResult(in: app)
        tapAnimationControl("closeSheetButton", in: app)
        waitForObservedValue("goldCount", "260", in: app)
        assertKnownHomeViewportBaseline(in: app)
    }

    @MainActor
    func testPlayerProfileAndEquipmentTranslateInAllThreeLanguages() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        openPlayerProfile(in: app)
        tapProfileControl("profileChooseAvatar", in: app)
        tapProfilePageControl("avatarSelect_female_sunny", scroll: "avatarPickerScroll", in: app)
        scrollCareerPage("avatarPickerScroll", to: "avatarSelectedID", in: app)
        waitForObservedValue("avatarSelectedID", "female_sunny", in: app)
        tapAnimationControl("profileBackButton", in: app)
        tapProfileControl("profileEquipAllButton", in: app)
        assertProfileValue("profileEquippedCount", "4", in: app)
        tapAnimationControl("closeSheetButton", in: app)
        let languages: [(code: String, title: String, appearances: String, avatarNames: [String], slots: [String], cap: String)] = [
            ("en", "My profile", "My appearance",
             ["Sunny · Male", "Forest · Male", "Bookish · Male", "Sunny · Female", "Forest · Female", "Bookish · Female"],
             ["Headwear", "Tops", "Footwear", "Accessories"], "Easygoing cap"),
            ("zh-Hant", "我的檔案", "我的形象",
             ["晴日男生", "森系男生", "書卷男生", "晴日女生", "森系女生", "書卷女生"],
             ["帽子", "上衣", "鞋子", "掛飾"], "輕便鴨舌帽"),
            ("zh-Hans", "我的档案", "我的形象",
             ["晴日男生", "森系男生", "书卷男生", "晴日女生", "森系女生", "书卷女生"],
             ["帽子", "上衣", "鞋子", "挂饰"], "轻便鸭舌帽")
        ]
        for language in languages {
            tapAnimationControl("settingsButton", in: app)
            tapAnimationControl("settingsLanguageRow", in: app)
            tapAnimationControl("languageOption_\(language.code)", in: app)
            assertSettingsLanguageSelection(language.code, in: app)
            tapAnimationControl("settingsBackButton", in: app)
            tapAnimationControl("settingsCloseButton", in: app)
            openPlayerProfile(in: app)
            XCTAssertTrue(app.navigationBars[language.title].waitForExistence(timeout: 8))
            assertProfileValue("profileAvatarName", "female_sunny", in: app)
            waitForLabel("profileAvatarName", language.avatarNames[3], in: app)
            attachScreenshot(app, named: "Player — translated profile portrait in \(language.code)")
            tapProfileControl("profileChooseAvatar", in: app)
            XCTAssertTrue(app.navigationBars[language.appearances].waitForExistence(timeout: 8))
            for (id, name) in zip(playerMaleAvatarIDs + playerFemaleAvatarIDs, language.avatarNames) {
                scrollCareerPage("avatarPickerScroll", to: "avatarSelect_\(id)", in: app)
                waitForLabel("avatarSelect_\(id)", name, in: app)
            }
            attachScreenshot(app, named: "Player — translated six-appearance gallery in \(language.code)")
            tapAnimationControl("profileBackButton", in: app)
            for ((slot, item), label) in zip(playerStarterEquipment, language.slots) {
                assertProfileValue("equipmentSlot_\(slot)", item, in: app)
                waitForLabel("equipmentSlot_\(slot)", label, in: app)
            }
            assertProfileBonuses(duration: 15, stamina: 15, mood: 20, in: app)
            attachScreenshot(app, named: "Player — actual equipment bonuses in \(language.code)")
            tapProfileControl("equipmentSlot_head", in: app)
            XCTAssertTrue(app.navigationBars[language.slots[0]].waitForExistence(timeout: 8))
            waitForLabel("equippedItem_head", language.cap, in: app)
            waitForObservedValue("equippedItem_head", "starter_cap", in: app)
            scrollCareerPage("equipmentScroll", to: "unequipSlot_head", in: app)
            attachScreenshot(app, named: "Player — translated equipped item and removal action in \(language.code)")
            tapAnimationControl("profileBackButton", in: app)
            tapAnimationControl("closeSheetButton", in: app)
            waitForObservedValue("goldCount", "200", in: app)
            assertKnownHomeViewportBaseline(in: app)
        }
    }

    private var playerMaleAvatarIDs: [String] { ["male_sunny", "male_forest", "male_scholarly"] }

    private var playerFemaleAvatarIDs: [String] { ["female_sunny", "female_forest", "female_scholarly"] }

    @MainActor
    private func assertPlayerNavigationPortrait(_ name: String, barFrame: CGRect,
                                                 tabSize: CGSize, contentWidth: CGFloat,
                                                 in app: XCUIApplication,
                                                 file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(element("profileScroll", in: app).exists,
                       "Check the home portrait only after closing the player sheet.", file: file, line: line)
        ensureHomeNavigationItemVisible("tabPlayer", in: app, file: file, line: line)
        waitForObservedValue("tabPlayer", name, in: app, file: file, line: line)
        let bar = element("homeNavigationBar", in: app)
        let tab = element("tabPlayer", in: app)
        XCTAssertTrue(homeNavigationItemIsFullyVisible("tabPlayer", in: app), file: file, line: line)
        XCTAssertTrue(tab.isEnabled, file: file, line: line)
        XCTAssertTrue(element("feedButton", in: app).isHittable, file: file, line: line)
        XCTAssertTrue(bar.descendants(matching: .button).matching(identifier: "tabPlayer").firstMatch.exists,
                      "The selected portrait must remain the real bottom navigation entry.", file: file, line: line)
        XCTAssertEqual(bar.frame, barFrame,
                       "Changing a portrait must not resize or move the horizontal bar.", file: file, line: line)
        XCTAssertEqual(tab.frame.size, tabSize,
                       "The portrait must keep the original player button hit area.", file: file, line: line)
        let currentWidth = element("settingsButton", in: app).frame.maxX
            - element("tabHome", in: app).frame.minX
        XCTAssertEqual(currentWidth, contentWidth, accuracy: 0.5,
                       "Changing a portrait must not change the eight-item scroll range.", file: file, line: line)
    }

    @MainActor
    private func assertProfileBonuses(duration: Int, stamina: Int, mood: Int,
                                       in app: XCUIApplication,
                                       file: StaticString = #filePath, line: UInt = #line) {
        for (identifier, value) in [("profileDurationBonus", duration),
                                    ("profileStaminaBonus", stamina), ("profileMoodBonus", mood)] {
            assertProfileValue(identifier, "\(value)", in: app, file: file, line: line)
        }
    }
}
