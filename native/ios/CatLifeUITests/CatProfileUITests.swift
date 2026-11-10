import XCTest

extension RoomHomeUITests {
    @MainActor
    func testCatCollectionPagesAndIndividualNamesPreserveOtherCatsAndHome() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--cat-collection-fixture"]
        launchAndEnterHome(app)
        let room = element("roomScene", in: app).frame
        openTownCollection(in: app)
        waitForObservedValue("catCount", "9", in: app)
        waitForObservedValue("catCollectionProgress", "1/5", in: app)
        assertCatPage([1, 2, 3, 4], page: "1/3", in: app)
        XCTAssertFalse(element("catProfileSatiety", in: app).exists)
        attachScreenshot(app, named: "Cats — compact first page with four individual cards")
        scrollCareerPage("catCollectionScroll", to: "catPageNext", in: app)
        tapAnimationControl("catPageNext", in: app)
        assertCatPage([5, 6, 7, 8], page: "2/3", in: app)
        scrollCareerPage("catCollectionScroll", to: "catProfile_cat_006", in: app)
        tapAnimationControl("catProfile_cat_006", in: app)
        waitForObservedValue("catProfileScroll", "cat_006", in: app)
        waitForObservedValue("catProfileName", "猫咪6", in: app)
        for (id, value) in [("catProfileSatiety", "66"), ("catProfileCleanliness", "76"), ("catProfileMood", "86"),
                            ("catProfileIntimacy", "16"), ("catProfileEnergy", "56"), ("catProfileHealth", "96")] {
            scrollCareerPage("catProfileScroll", to: id, in: app)
            waitForObservedValue(id, value, in: app)
        }
        scrollCareerPage("catProfileScroll", to: "catRenameButton", in: app)
        tapAnimationControl("catRenameButton", in: app)
        replaceCatName("团子🐾", replacing: "", in: app)
        saveCatName(in: app)
        waitForObservedValue("catNameStatus", "catName.saved", in: app)
        tapAnimationControl("catNameBackButton", in: app)
        waitForObservedValue("catProfileName", "团子🐾", in: app)
        attachScreenshot(app, named: "Cats — selected cat has independent name and live attributes")
        tapAnimationControl("catProfileBackButton", in: app)
        assertCatPage([5, 6, 7, 8], page: "2/3", in: app)
        waitForLabel("catProfile_cat_006", "团子🐾", in: app)
        waitForLabel("catProfile_cat_005", "猫咪5", in: app)
        scrollCareerPage("catCollectionScroll", to: "catPageNext", in: app)
        tapAnimationControl("catPageNext", in: app)
        assertCatPage([9], page: "3/3", in: app)
        XCTAssertFalse(element("catPageNext", in: app).isEnabled)
        scrollCareerPage("catCollectionScroll", to: "catFilter_unowned", in: app)
        tapAnimationControl("catFilter_unowned", in: app)
        waitForElement("catCollectionEmpty", in: app)
        XCTAssertFalse(element("catPageSummary", in: app).exists)
        tapAnimationControl("catFilter_owned", in: app)
        assertCatPage([1, 2, 3, 4], page: "1/3", in: app)
        scrollCareerPage("catCollectionScroll", to: "catFilter_all", in: app)
        tapAnimationControl("catFilter_all", in: app)
        tapAnimationControl("closeSheetButton", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("homeCatName", "小橘", in: app)
        waitForObservedValue("foodCount", "3", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        assertRoomFrame(room, in: app, context: "renaming a different cat")
        relaunchPreservingSave(app)
        openTownCollection(in: app)
        assertCatPage([1, 2, 3, 4], page: "1/3", in: app)
        scrollCareerPage("catCollectionScroll", to: "catPageNext", in: app)
        tapAnimationControl("catPageNext", in: app)
        waitForLabel("catProfile_cat_006", "团子🐾", in: app)
        tapAnimationControl("closeSheetButton", in: app)
        tapAnimationControl("tabHome", in: app)
        try openCurrentCatProfile(in: app)
        waitForObservedValue("catProfileScroll", "cat_001", in: app)
        waitForObservedValue("catProfileName", "小橘", in: app)
    }

    @MainActor
    func testCatRenameValidationCancellationLanguagesAndResetPersist() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        try openCurrentCatProfile(in: app)
        waitForObservedValue("catProfileScroll", "cat_001", in: app)
        tapAnimationControl("catRenameButton", in: app)
        let name = "橘子的午后与星光伙伴🐾🏡"
        XCTAssertEqual(name.count, 12)
        replaceCatName(name, replacing: "", in: app)
        saveCatName(in: app)
        waitForObservedValue("catNameStatus", "catName.saved", in: app)
        attachScreenshot(app, named: "Cat name — twelve visible characters including emoji saved")
        tapAnimationControl("catNameBackButton", in: app)
        waitForObservedValue("catProfileName", name, in: app)
        tapAnimationControl("closeSheetButton", in: app)
        waitForObservedValue("homeCatName", name, in: app)
        relaunchPreservingSave(app)
        waitForObservedValue("homeCatName", name, in: app)
        try openCurrentCatProfile(in: app)
        tapAnimationControl("catRenameButton", in: app)
        replaceCatName("ABCDEFGHIJKLM", replacing: name, in: app)
        waitForObservedValue("catNameValidation", "invalid", in: app)
        scrollCareerPage("catNameScroll", to: "catNameSaveButton", in: app)
        XCTAssertFalse(element("catNameSaveButton", in: app).isEnabled)
        tapAnimationControl("catNameBackButton", in: app)
        waitForObservedValue("catProfileName", name, in: app)
        tapAnimationControl("catRenameButton", in: app)
        replaceCatName("   ", replacing: name, in: app)
        waitForObservedValue("catNameValidation", "invalid", in: app)
        tapAnimationControl("catNameBackButton", in: app)
        tapAnimationControl("catRenameButton", in: app)
        replaceCatName("小橘", replacing: name, in: app)
        saveCatName(in: app)
        waitForObservedValue("catNameStatus", "catName.saved", in: app)
        tapAnimationControl("closeSheetButton", in: app)
        for (code, title) in [("zh-Hant", "貓咪名字"), ("en", "Cat name")] {
            selectCatTestLanguage(code, in: app)
            waitForObservedValue("homeCatName", "小橘", in: app)
            try openCurrentCatProfile(in: app)
            waitForObservedValue("catProfileName", "小橘", in: app)
            tapAnimationControl("catRenameButton", in: app)
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 8))
            waitForObservedValue("catNameField", "小橘", in: app)
            attachScreenshot(app, named: "Cat name — custom default spelling stays literal in \(code)")
            tapAnimationControl("closeSheetButton", in: app)
        }
        try openCurrentCatProfile(in: app)
        tapAnimationControl("catRenameButton", in: app)
        replaceCatName("Unsaved🐈", replacing: "小橘", in: app)
        tapAnimationControl("catNameBackButton", in: app)
        waitForObservedValue("catProfileName", "小橘", in: app)
        tapAnimationControl("catRenameButton", in: app)
        waitForObservedValue("catNameField", "小橘", in: app)
        scrollCareerPage("catNameScroll", to: "catNameResetButton", in: app)
        tapAnimationControl("catNameResetButton", in: app)
        waitForObservedValue("catNameStatus", "catName.resetDone", in: app)
        waitForLabel("catNamePreview", "Sunny", in: app)
        tapAnimationControl("closeSheetButton", in: app)
        waitForObservedValue("homeCatName", "Sunny", in: app)
        relaunchPreservingSave(app)
        waitForObservedValue("homeCatName", "Sunny", in: app)
        waitForObservedValue("foodCount", "3", in: app)
        waitForObservedValue("goldCount", "200", in: app)
    }

    @MainActor
    func testFailedCatRenameKeepsDraftAndSavedNameUntilManualRetry() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--cat-name-save-failure-once"]
        launchAndEnterHome(app)
        try openCurrentCatProfile(in: app)
        tapAnimationControl("catRenameButton", in: app)
        replaceCatName("Mochi🐈", replacing: "", in: app)
        saveCatName(in: app)
        waitForObservedValue("catNameStatus", "catName.saveFailed", in: app)
        waitForObservedValue("catNameField", "Mochi🐈", in: app)
        XCTAssertTrue(element("catNameSaveButton", in: app).isEnabled)
        attachScreenshot(app, named: "Cat name — failed write keeps draft and offers retry")
        tapAnimationControl("catNameBackButton", in: app)
        waitForObservedValue("catProfileName", "小橘", in: app)
        tapAnimationControl("catRenameButton", in: app)
        replaceCatName("Mochi🐈", replacing: "", in: app)
        saveCatName(in: app)
        waitForObservedValue("catNameStatus", "catName.saved", in: app)
        tapAnimationControl("closeSheetButton", in: app)
        waitForObservedValue("homeCatName", "Mochi🐈", in: app)
        relaunchPreservingSave(app)
        waitForObservedValue("homeCatName", "Mochi🐈", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        waitForObservedValue("foodCount", "3", in: app)
    }

    @MainActor
    private func assertCatPage(_ indices: [Int], page: String, in app: XCUIApplication) {
        waitForObservedValue("catPageSummary", page, in: app)
        for index in 1...9 {
            let card = element(String(format: "catProfile_cat_%03d", index), in: app)
            XCTAssertEqual(card.exists, indices.contains(index))
            if indices.contains(index) {
                scrollCareerPage("catCollectionScroll", to: String(format: "catProfile_cat_%03d", index), in: app)
                let viewport = unobscuredScrollViewport(element("catCollectionScroll", in: app), in: app)
                XCTAssertTrue(card.isHittable)
                XCTAssertTrue(viewport.contains(card.frame), "Every card on the four-item page must be fully reachable.")
            }
        }
    }

    @MainActor
    func replaceCatName(_ text: String, replacing previous: String, in app: XCUIApplication) {
        scrollCareerPage("catNameScroll", to: "catNameField", in: app)
        let field = element("catNameField", in: app)
        tapAnimationControl("catNameField", in: app)
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 8))
        if !previous.isEmpty { field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count)) }
        field.typeText(text)
        waitForObservedValue("catNameField", text, in: app)
        field.typeText("\n")
        let hidden = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.keyboards.firstMatch)
        XCTAssertEqual(XCTWaiter.wait(for: [hidden], timeout: 8), .completed)
    }

    @MainActor
    func saveCatName(in app: XCUIApplication) {
        scrollCareerPage("catNameScroll", to: "catNameSaveButton", in: app)
        tapAnimationControl("catNameSaveButton", in: app)
    }

    @MainActor
    func selectCatTestLanguage(_ code: String, in app: XCUIApplication) {
        tapAnimationControl("settingsButton", in: app)
        tapSettingsRootControl("languageOption_\(code)", in: app)
        waitForObservedValue("languageOption_\(code)", "selected", in: app)
        tapAnimationControl("tabHome", in: app)
    }
}
