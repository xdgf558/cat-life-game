import XCTest

extension RoomHomeUITests {
    @MainActor
    func testCatalogDesignReadyConfirmationSuccessAndBringHome() throws {
        continueAfterFailure = false
        let app = launchCatAdoptionFixture("--uitesting-blue-adoption-ready")
        openTownCollection(in: app)
        waitForObservedValue("catCollectionProgress", "2/5", in: app)
        waitForObservedValue("catFilter_all", "5", in: app)
        waitForObservedValue("catFilter_owned", "2", in: app)
        waitForObservedValue("catFilter_unowned", "3", in: app)
        XCTAssertTrue(element("tabTown", in: app).exists, "The collection stays inside Cat Town with persistent navigation.")
        attachScreenshot(app, named: "C1 — collection progress and adopted cards")
        tapAnimationControl("catFilter_unowned", in: app)
        waitForObservedValue("catAdoption_cat_003", "可以领养", in: app)
        attachScreenshot(app, named: "C2 — unadopted blue friend")
        tapAnimationControl("catAdoption_cat_003", in: app)
        waitForObservedValue("catAdoptionConditionsMet", "3/3", in: app)
        attachScreenshot(app, named: "C4 — all live adoption requirements met")
        tapAnimationControl("catAdoptionButton", in: app)
        waitForLabel("catAdoptionConfirmationTitle", "让蓝影加入小家？", in: app)
        waitForObservedValue("catAdoptionConfirmation", "cat_003:1000:600", in: app)
        attachScreenshot(app, named: "C5 — confirmation names the correct cat")
        tapAnimationControl("catAdoptionCancelButton", in: app)
        waitForObservedValue("catAdoptionGold", "1,000", in: app)
        confirmCatAdoption(in: app)
        waitForObservedValue("catAdoptionSuccess", "cat_003", in: app)
        waitForObservedValue("catAdoptionSuccessProgress", "3/5", in: app)
        XCTAssertEqual(app.buttons.matching(identifier: "catAdoptionBringHomeButton").count, 1,
                       "The success action must retain its own accessible identity.")
        XCTAssertEqual(app.buttons.matching(identifier: "catAdoptionLaterButton").count, 1)
        attachScreenshot(app, named: "C6 — successful blue adoption")
        tapAnimationControl("catAdoptionBringHomeButton", in: app)
        waitForObservedValue("homeCatName", "蓝影", in: app)
        waitForObservedValue("goldCount", "400", in: app)
        relaunchPreservingSave(app)
        waitForObservedValue("homeCatName", "蓝影", in: app)
        waitForObservedValue("goldCount", "400", in: app)
        openTownCollection(in: app)
        tapAnimationControl("catFilter_unowned", in: app)
        waitForObservedValue("catFilter_unowned", "2", in: app)
        waitForElement("catAdoption_cat_004", in: app)
        waitForElement("catAdoption_cat_005", in: app)
        XCTAssertFalse(element("catCollectionEmpty", in: app).exists)
        attachScreenshot(app, named: "C7 — higher-level friends remain after blue adoption")
        tapAnimationControl("catFilter_owned", in: app)
        XCTAssertTrue(element("catFilter_owned", in: app).isSelected)
        waitForObservedValue("catCount", "3", in: app)
    }

    @MainActor
    func testCatalogLockedConditionsOpenWorkAndRoomUpgrade() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        openTownCollection(in: app)
        tapAnimationControl("catFilter_unowned", in: app)
        waitForLabel("catAdoption_cat_004", "新伙伴", in: app, contains: true)
        tapAnimationControl("catAdoption_cat_004", in: app)
        waitForLabel("catAdoptionBadge", "新伙伴", in: app)
        XCTAssertFalse(element("catAdoptionButton", in: app).exists)
        tapAnimationControl("catAdoptionBackButton", in: app)
        tapAnimationControl("catAdoption_cat_003", in: app)
        waitForObservedValue("catAdoptionConditionsMet", "0/3", in: app)
        XCTAssertFalse(element("catAdoptionButton", in: app).exists)
        attachScreenshot(app, named: "C3 — locked blue adoption has useful next actions")
        tapAnimationControl("catAdoptionRequirementAction", in: app)
        waitForElement("playerExperience", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        openTownCollection(in: app)
        tapAnimationControl("catFilter_unowned", in: app)
        tapAnimationControl("catAdoption_cat_003", in: app)
        scrollCareerPage("catAdoptionScroll", to: "catAdoptionRoomRequirementAction", in: app)
        tapAnimationControl("catAdoptionRoomRequirementAction", in: app)
        waitForElement("homeUpgradeScroll", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        waitForObservedValue("foodCount", "3", in: app)
    }

    @MainActor
    func testAdoptionConfirmationUsesEachLanguageAndCorrectBlueName() throws {
        continueAfterFailure = false
        let app = launchCatAdoptionFixture("--uitesting-blue-adoption-ready")
        for (code, title) in [("zh-Hans", "让蓝影加入小家？"), ("zh-Hant", "讓藍影加入小家？"),
                              ("en", "Welcome Bluebell home?")] {
            if code != "zh-Hans" { selectCatTestLanguage(code, in: app) }
            openTownCollection(in: app)
            tapAnimationControl("catFilter_unowned", in: app)
            tapAnimationControl("catAdoption_cat_003", in: app)
            tapAnimationControl("catAdoptionButton", in: app)
            waitForLabel("catAdoptionConfirmationTitle", title, in: app)
            attachScreenshot(app, named: "C5 — localized confirmation \(code)")
            tapAnimationControl("catAdoptionCancelButton", in: app)
            tapAnimationControl("catAdoptionBackButton", in: app)
            tapAnimationControl("closeSheetButton", in: app)
            tapAnimationControl("tabHome", in: app)
            waitForObservedValue("goldCount", "1,000", in: app)
        }
    }

    @MainActor
    func testBlueCatCatalogAdoptionFiltersAndRelaunch() throws {
        continueAfterFailure = false
        let app = launchCatAdoptionFixture("--uitesting-blue-adoption-ready", extra: ["--cat-adoption-save-failure-once"])
        tapAnimationControl("tabTown", in: app)
        scrollCareerPage("townMapScroll", to: "townAdoptionMarker", in: app)
        tapAnimationControl("townAdoptionMarker", in: app)
        scrollCareerPage("townMapScroll", to: "townMeetCatButton", in: app)
        tapAnimationControl("townMeetCatButton", in: app)
        waitForElement("catFilter_unowned", in: app)
        XCTAssertTrue(element("catFilter_unowned", in: app).isSelected)
        waitForObservedValue("catCollectionProgress", "2/5", in: app)
        XCTAssertFalse(element("catProfile_cat_001", in: app).exists)
        XCTAssertFalse(element("catProfile_cat_002", in: app).exists)
        waitForObservedValue("catAdoption_cat_003", "可以领养", in: app)
        attachScreenshot(app, named: "Cat collection — adoption entry lists the remaining blue cat")
        tapAnimationControl("catAdoption_cat_003", in: app)
        waitForLabel("catAdoptionName", "蓝影", in: app)
        for identifier in ["catAdoptionPlayerRequirement", "catAdoptionRoomRequirement", "catAdoptionGoldRequirement"] {
            scrollCareerPage("catAdoptionScroll", to: identifier, in: app)
            waitForObservedValue(identifier, "已满足", in: app)
        }
        confirmCatAdoption(in: app)
        waitForCatSaveProbeRecovery(in: app)
        waitForObservedValue("catAdoptionHint", "failed", in: app)
        waitForObservedValue("catAdoptionGold", "1,000", in: app)
        confirmCatAdoption(in: app)
        openNewlyAdoptedProfile("cat_003", in: app)
        waitForObservedValue("catProfileScroll", "cat_003", in: app)
        waitForObservedValue("catProfileName", "蓝影", in: app)
        waitForObservedValue("catCompanionButton", "available", in: app)
        tapAnimationControl("catRenameButton", in: app)
        replaceCatName("蓝莓", replacing: "", in: app)
        saveCatName(in: app)
        waitForObservedValue("catNameStatus", "catName.saved", in: app)
        tapAnimationControl("catNameBackButton", in: app)
        scrollCareerPage("catProfileScroll", to: "catHealthButton", in: app)
        tapAnimationControl("catHealthButton", in: app)
        waitForObservedValue("hospitalDetailScroll", "cat_003", in: app)
        waitForLabel("hospitalCatName", "蓝莓", in: app)
        tapAnimationControl("catHealthBackButton", in: app)
        scrollCareerPage("catProfileScroll", to: "catCompanionButton", in: app)
        tapAnimationControl("catCompanionButton", in: app)
        waitForObservedValue("catCompanionButton", "active", in: app)
        tapAnimationControl("catProfileBackButton", in: app)
        waitForObservedValue("catCollectionProgress", "3/5", in: app)
        tapAnimationControl("catFilter_unowned", in: app)
        waitForObservedValue("catFilter_unowned", "2", in: app)
        XCTAssertFalse(element("catPageSummary", in: app).exists,
                       "A single page must not show redundant pagination.")
        waitForElement("catAdoption_cat_004", in: app)
        waitForElement("catAdoption_cat_005", in: app)
        XCTAssertFalse(element("catCollectionEmpty", in: app).exists)
        XCTAssertFalse(element("catAdoption_cat_003", in: app).exists)
        attachScreenshot(app, named: "Cat collection — later friends stay visible after blue adoption")
        tapAnimationControl("catFilter_owned", in: app)
        waitForObservedValue("catCount", "3", in: app)
        XCTAssertFalse(element("catPageSummary", in: app).exists,
                       "A single page must not show redundant pagination.")
        scrollCareerPage("catCollectionScroll", to: "catProfile_cat_003", in: app)
        waitForLabel("catProfile_cat_003", "蓝莓", in: app)
        tapAnimationControl("closeSheetButton", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", "400", in: app)
        waitForObservedValue("homeCatName", "蓝莓", in: app)
        attachScreenshot(app, named: "Blue companion — adopted renamed and selected without changing the room")
        relaunchPreservingSave(app)
        waitForObservedValue("goldCount", "400", in: app)
        waitForObservedValue("homeCatName", "蓝莓", in: app)
        openTownCollection(in: app)
        waitForObservedValue("catCollectionProgress", "3/5", in: app)
        tapAnimationControl("catFilter_unowned", in: app)
        waitForObservedValue("catFilter_unowned", "2", in: app)
        XCTAssertFalse(element("catCollectionEmpty", in: app).exists)
        tapAnimationControl("catFilter_owned", in: app)
        tapAnimationControl("catProfile_cat_001", in: app)
        waitForObservedValue("catProfileName", "小橘", in: app)
        scrollCareerPage("catProfileScroll", to: "catProfileSatiety", in: app)
        waitForObservedValue("catProfileSatiety", "35", in: app)
    }

    @MainActor
    func testCatAdoptionShowsLockedRequirementsInAllLanguagesWithoutCharging() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        for (code, title, name) in [("zh-Hans", "领养伙伴", "牛奶"),
                                    ("zh-Hant", "領養夥伴", "牛奶"), ("en", "Adopt a friend", "MooMoo")] {
            if code != "zh-Hans" { selectCatTestLanguage(code, in: app) }
            openTownCollection(in: app)
            waitForObservedValue("catCount", "1", in: app)
            tapAnimationControl("catAdoption_cat_002", in: app)
            waitForLabel("catCollectionTitle", title, in: app)
            XCTAssertTrue(app.staticTexts[name].firstMatch.exists)
            for identifier in ["catAdoptionPlayerRequirement", "catAdoptionRoomRequirement", "catAdoptionGoldRequirement"] {
                scrollCareerPage("catAdoptionScroll", to: identifier, in: app)
                waitForObservedValue(identifier, code == "en" ? "Not met" : (code == "zh-Hant" ? "尚未符合" : "未满足"), in: app)
            }
            XCTAssertFalse(element("catAdoptionButton", in: app).exists)
            XCTAssertTrue(element("catAdoptionRequirementAction", in: app).isEnabled)
            attachScreenshot(app, named: "Adoption — locked requirements in \(code)")
            tapAnimationControl("catAdoptionBackButton", in: app)
            scrollCareerPage("catCollectionScroll", to: "catFilter_unowned", in: app)
            tapAnimationControl("catFilter_unowned", in: app)
            waitForObservedValue("catCollectionProgress", "1/5", in: app)
            XCTAssertFalse(element("catProfile_cat_001", in: app).exists)
            tapAnimationControl("catAdoption_cat_003", in: app)
            waitForLabel("catAdoptionName", code == "en" ? "Bluebell" : (code == "zh-Hant" ? "藍影" : "蓝影"), in: app)
            for identifier in ["catAdoptionPlayerRequirement", "catAdoptionRoomRequirement", "catAdoptionGoldRequirement"] {
                scrollCareerPage("catAdoptionScroll", to: identifier, in: app)
                waitForObservedValue(identifier, code == "en" ? "Not met" : (code == "zh-Hant" ? "尚未符合" : "未满足"), in: app)
            }
            XCTAssertFalse(element("catAdoptionButton", in: app).exists)
            XCTAssertTrue(element("catAdoptionRequirementAction", in: app).isEnabled)
            attachScreenshot(app, named: "Blue adoption — independent requirements and localized identity in \(code)")
            tapAnimationControl("catAdoptionBackButton", in: app)
            tapAnimationControl("closeSheetButton", in: app)
            tapAnimationControl("tabHome", in: app)
            waitForObservedValue("goldCount", "200", in: app)
            waitForObservedValue("foodCount", "3", in: app)
        }
    }

    @MainActor
    func testAdoptionConfirmationSelectionRenameAndRelaunchPreserveBothCats() throws {
        continueAfterFailure = false
        let app = launchCatAdoptionFixture("--uitesting-adoption-ready")
        openTownCollection(in: app)
        waitForObservedValue("catCount", "1", in: app)
        tapAnimationControl("catAdoption_cat_002", in: app)
        scrollCareerPage("catAdoptionScroll", to: "catAdoptionButton", in: app)
        tapAnimationControl("catAdoptionButton", in: app)
        waitForLabel("catAdoptionConfirmationTitle", "让牛奶加入小家？", in: app)
        tapAnimationControl("catAdoptionCancelButton", in: app)
        waitForObservedValue("catAdoptionGold", "1,000", in: app)
        confirmCatAdoption(in: app)
        openNewlyAdoptedProfile("cat_002", in: app)
        waitForObservedValue("catProfileScroll", "cat_002", in: app)
        waitForObservedValue("catProfileName", "牛奶", in: app)
        waitForObservedValue("catCompanionButton", "available", in: app)
        attachScreenshot(app, named: "Adoption — new cow cat profile after successful purchase")
        tapAnimationControl("closeSheetButton", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", "700", in: app)
        waitForObservedValue("homeCatName", "小橘", in: app)
        openTownCollection(in: app)
        waitForObservedValue("catCount", "2", in: app)
        XCTAssertFalse(element("catAdoption_cat_002", in: app).exists)
        attachScreenshot(app, named: "Cats — orange and cow cards remain compact")
        tapAnimationControl("catProfile_cat_002", in: app)
        tapAnimationControl("catRenameButton", in: app)
        replaceCatName("奶糖🐾", replacing: "", in: app)
        saveCatName(in: app)
        waitForObservedValue("catNameStatus", "catName.saved", in: app)
        tapAnimationControl("catNameBackButton", in: app)
        scrollCareerPage("catProfileScroll", to: "catCompanionButton", in: app)
        tapAnimationControl("catCompanionButton", in: app)
        waitForObservedValue("catCompanionButton", "active", in: app)
        tapAnimationControl("closeSheetButton", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("homeCatName", "奶糖🐾", in: app)
        attachScreenshot(app, named: "Companion — cow cat selected in the room")
        relaunchPreservingSave(app)
        waitForObservedValue("homeCatName", "奶糖🐾", in: app)
        waitForObservedValue("goldCount", "700", in: app)
        openTownCollection(in: app)
        waitForObservedValue("catCount", "2", in: app)
        tapAnimationControl("catProfile_cat_001", in: app)
        waitForObservedValue("catProfileName", "小橘", in: app)
        scrollCareerPage("catProfileScroll", to: "catCompanionButton", in: app)
        tapAnimationControl("catCompanionButton", in: app)
        waitForObservedValue("catCompanionButton", "active", in: app)
        tapAnimationControl("closeSheetButton", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("homeCatName", "小橘", in: app)
        waitForObservedValue("goldCount", "700", in: app)
    }

    @MainActor
    func testCompanionCareChangesOnlySelectedCatAndSurvivesRelaunch() throws {
        continueAfterFailure = false
        let app = launchCatAdoptionFixture("--uitesting-adoption-owned")
        openTownCollection(in: app)
        tapAnimationControl("catProfile_cat_002", in: app)
        scrollCareerPage("catProfileScroll", to: "catCompanionButton", in: app)
        tapAnimationControl("catCompanionButton", in: app)
        waitForObservedValue("catCompanionButton", "active", in: app)
        tapAnimationControl("closeSheetButton", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("homeCatName", "牛奶", in: app)
        waitForObservedValue("catSatiety", "55", in: app)
        tapAnimationControl("feedButton", in: app)
        waitForObservedValue("foodCount", "2", in: app)
        waitForObservedValue("catSatiety", "80", in: app)
        openTownCollection(in: app)
        tapAnimationControl("catProfile_cat_001", in: app)
        scrollCareerPage("catProfileScroll", to: "catProfileSatiety", in: app)
        waitForObservedValue("catProfileSatiety", "35", in: app)
        scrollCareerPage("catProfileScroll", to: "catCompanionButton", in: app)
        tapAnimationControl("catCompanionButton", in: app)
        waitForObservedValue("catCompanionButton", "active", in: app)
        tapAnimationControl("closeSheetButton", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("homeCatName", "小橘", in: app)
        waitForObservedValue("catSatiety", "35", in: app)
        relaunchPreservingSave(app)
        waitForObservedValue("homeCatName", "小橘", in: app)
        openTownCollection(in: app)
        tapAnimationControl("catProfile_cat_002", in: app)
        scrollCareerPage("catProfileScroll", to: "catProfileSatiety", in: app)
        waitForObservedValue("catProfileSatiety", "80", in: app)
        attachScreenshot(app, named: "Companion — the other cat retains its own care after relaunch")
    }

    @MainActor
    func testFailedAdoptionAndCompanionSaveRemainRetryableWithoutDoubleCharge() throws {
        continueAfterFailure = false
        let app = launchCatAdoptionFixture("--uitesting-adoption-ready", extra: [
            "--cat-adoption-save-failure-once", "--cat-companion-save-failure-once"
        ])
        openTownCollection(in: app)
        tapAnimationControl("catAdoption_cat_002", in: app)
        confirmCatAdoption(in: app)
        waitForCatSaveProbeRecovery(in: app)
        waitForObservedValue("catAdoptionHint", "failed", in: app)
        waitForObservedValue("catAdoptionGold", "1,000", in: app)
        scrollCareerPage("catAdoptionScroll", to: "catAdoptionButton", in: app)
        XCTAssertTrue(element("catAdoptionButton", in: app).isEnabled)
        attachScreenshot(app, named: "Adoption — failed save keeps coins and offers retry")
        confirmCatAdoption(in: app)
        openNewlyAdoptedProfile("cat_002", in: app)
        waitForObservedValue("catProfileScroll", "cat_002", in: app)
        scrollCareerPage("catProfileScroll", to: "catCompanionButton", in: app)
        tapAnimationControl("catCompanionButton", in: app)
        waitForCatSaveProbeRecovery(in: app)
        waitForObservedValue("catCompanionHint", "failed", in: app)
        waitForObservedValue("catCompanionButton", "available", in: app)
        XCTAssertTrue(element("catCompanionButton", in: app).isEnabled)
        tapAnimationControl("closeSheetButton", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("homeCatName", "小橘", in: app)
        waitForObservedValue("goldCount", "700", in: app)
        openTownCollection(in: app)
        waitForObservedValue("catCount", "2", in: app)
        tapAnimationControl("catProfile_cat_002", in: app)
        scrollCareerPage("catProfileScroll", to: "catCompanionButton", in: app)
        tapAnimationControl("catCompanionButton", in: app)
        waitForObservedValue("catCompanionButton", "active", in: app)
        tapAnimationControl("closeSheetButton", in: app)
        tapAnimationControl("tabHome", in: app)
        relaunchPreservingSave(app)
        waitForObservedValue("homeCatName", "牛奶", in: app)
        waitForObservedValue("goldCount", "700", in: app)
    }

    @MainActor
    func testCowCatCompletesBowlMealPounceAndSupportedFurnitureRests() throws {
        try assertCompanionCompletesCareAndFurnitureRests(fixture: "--uitesting-adoption-owned", catID: "cat_002",
                                                         appearance: "cow", fedSatiety: "80")
    }

    @MainActor
    func testBlueCatCompletesBowlMealPounceAndSupportedFurnitureRests() throws {
        try assertCompanionCompletesCareAndFurnitureRests(fixture: "--uitesting-blue-adoption-owned", catID: "cat_003",
                                                         appearance: "blue", fedSatiety: "95")
    }

    @MainActor
    func testSiameseCatCompletesBowlMealPounceAndSupportedFurnitureRests() throws {
        try assertCompanionCompletesCareAndFurnitureRests(fixture: "--uitesting-siamese-owned", catID: "cat_004",
                                                         appearance: "siamese", fedSatiety: "95", expectedGold: "5,000")
    }

    @MainActor
    func testSilverCatCompletesBowlMealPounceAndSupportedFurnitureRests() throws {
        try assertCompanionCompletesCareAndFurnitureRests(fixture: "--uitesting-silver-owned", catID: "cat_005",
                                                         appearance: "silver", fedSatiety: "95", expectedGold: "5,000")
    }

    @MainActor
    private func assertCompanionCompletesCareAndFurnitureRests(fixture: String, catID: String, appearance: String,
                                                              fedSatiety: String, expectedGold: String = "1,000") throws {
        continueAfterFailure = false
        let app = launchCatAdoptionFixture(fixture, extra: ["--rest-test"])
        if appearance == "siamese" || appearance == "silver" {
            waitForElement("adoptionReminderDismiss", in: app)
            for _ in 0..<4 {
                guard element("adoptionReminderDismiss", in: app).waitForExistence(timeout: 1) else { break }
                tapAnimationControl("adoptionReminderDismiss", in: app)
            }
            XCTAssertFalse(element("adoptionReminderDismiss", in: app).exists)
        }
        let before = selectRoomCompanion(catID, appearance: appearance, in: app)
        tapAnimationControl("feedButton", in: app)
        _ = waitForFurniture(in: app, timeout: 35, description: "\(appearance) cat reaches the actual food surface") {
            $0.activeCatID == catID && $0.catAppearance == appearance && $0.phase == "feeding"
                && $0.foodContactSamples > before.foodContactSamples && $0.completedMeals == before.completedMeals
        }
        attachScreenshot(app, named: "\(appearance) cat — lowered mouth in contact with the bowl")
        let fed = waitForFurniture(in: app, timeout: 45, description: "\(appearance) cat completes one full meal and return path") {
            $0.phase == "idle" && $0.completedMeals == before.completedMeals + 1
        }
        XCTAssertEqual(fed.activeCatID, catID)
        XCTAssertEqual(fed.catAppearance, appearance)
        XCTAssertGreaterThan(fed.foodContactSamples, before.foodContactSamples)
        waitForObservedValue("catSatiety", fedSatiety, in: app)
        waitForObservedValue("foodCount", "2", in: app)

        let pounces = try XCTUnwrap(fed.completedPounces)
        tapAnimationControl("playButton", in: app)
        _ = waitForFurniture(in: app, timeout: 15, description: "\(appearance) cat begins the real play route") {
            $0.phase == "playing" && $0.carePlanning == false
        }
        attachScreenshot(app, named: "\(appearance) cat — approaching the toy for a pounce")
        let played = waitForFurniture(in: app, timeout: 40, description: "\(appearance) cat lands its pounce and returns safely") {
            $0.phase == "idle" && $0.completedPounces == pounces + 1
        }
        XCTAssertEqual(played.activeCatID, catID)
        XCTAssertEqual(played.completedMeals, fed.completedMeals)

        let worldWidth = try XCTUnwrap(played.worldWidth)
        let worldHeight = try XCTUnwrap(played.worldHeight)
        let viewportWidth = try XCTUnwrap(played.viewportWidth)
        let viewportHeight = try XCTUnwrap(played.viewportHeight)
        XCTAssertGreaterThan(viewportWidth, 0)
        XCTAssertGreaterThan(viewportHeight, 0)
        let fullRoomScale = max(worldWidth / viewportWidth, worldHeight / viewportHeight)
        XCTAssertGreaterThan(fullRoomScale, 1, "All companion fixtures use an expanded room.")
        tapAnimationControl("homeCareVisibilityButton", in: app)
        waitForObservedValue("homeCareVisibilityButton", "hidden", in: app)
        element("roomPinchSurface", in: app).pinch(withScale: 0.35, velocity: -1)
        let overview = waitForFurniture(in: app, description: "\(appearance) cat's expanded room fits on screen") {
            abs(($0.cameraScale ?? 1) - fullRoomScale) < 0.025 && $0.phase == "idle" && !$0.pending
        }
        XCTAssertEqual(try XCTUnwrap(overview.cameraX), worldWidth / 2, accuracy: 0.5)
        XCTAssertEqual(try XCTUnwrap(overview.cameraY), worldHeight / 2, accuracy: 0.5)
        for id in ["catBed", "floorCushion"] {
            let item = try XCTUnwrap(overview.items.first { $0.id == id })
            let touch = restFurnitureTouchPoint(item, cameraScale: overview.cameraScale ?? 1)
            XCTAssertTrue([item.x, item.y, Double(touch.dx), Double(touch.dy)].allSatisfy { $0 > 0 && $0 < 1 },
                          "\(id) and its actual touch point must be visible in the complete room.")
        }
        attachScreenshot(app, named: "\(appearance) cat — complete expanded room before furniture rests")

        for id in ["catBed", "floorCushion"] {
            let resting = try beginFurnitureRest(id, in: app)
            XCTAssertEqual(resting.activeCatID, catID)
            XCTAssertEqual(resting.catAppearance, appearance)
            attachScreenshot(app, named: "\(appearance) cat — paws and body supported on \(id)")
            let visual = try XCTUnwrap(resting.restVisualPoint)
            let wakeY = visual.y - 0.035 / (resting.cameraScale ?? 1)
            XCTAssertTrue([visual.x, visual.y, wakeY].allSatisfy { $0 > 0 && $0 < 1 },
                          "The resting cat and its wake-up touch point must remain visible.")
            element("roomScene", in: app)
                .coordinate(withNormalizedOffset: CGVector(dx: visual.x, dy: wakeY)).tap()
            let awake = waitForFurniture(in: app, timeout: 30, description: "\(appearance) cat steps down safely from \(id)") {
                $0.phase == "idle" && $0.restFurniture == nil && $0.restPhase == "none"
                    && $0.restExits == (resting.restExits ?? -1) + 1 && $0.savedRestSession == nil
            }
            XCTAssertGreaterThan(awake.stepDownSamples ?? -1, resting.stepDownSamples ?? -1)
            XCTAssertNil(awake.savedRestSession)
            XCTAssertEqual(awake.completedMeals, fed.completedMeals)
            attachScreenshot(app, named: "\(appearance) cat — safely back on the floor after \(id)")
        }
        tapAnimationControl("homeCareVisibilityButton", in: app)
        waitForObservedValue("homeCareVisibilityButton", "visible", in: app)
        waitForObservedValue("foodCount", "2", in: app)
        waitForObservedValue("goldCount", expectedGold, in: app)
        tapAnimationControl("tabInventory", in: app)
        waitForObservedValue("inventoryFoodCount", "2", in: app)
        waitForObservedValue("inventoryLitterCount", "2", in: app)
        waitForObservedValue("inventoryToyUses", "5", in: app)
        tapAnimationControl("tabHome", in: app)
        openTownCollection(in: app)
        tapAnimationControl("catProfile_cat_001", in: app)
        scrollCareerPage("catProfileScroll", to: "catProfileSatiety", in: app)
        waitForObservedValue("catProfileSatiety", "35", in: app)
        scrollCareerPage("catProfileScroll", to: "catProfileEnergy", in: app)
        waitForObservedValue("catProfileEnergy", "80", in: app)
    }

    @MainActor
    func testSwitchingCompanionCancelsOldCareAndRestWithoutReplayingCallbacks() throws {
        continueAfterFailure = false
        let app = launchCatAdoptionFixture("--uitesting-adoption-owned", extra: [
            "--rest-test", "--slow-care-planning-test"
        ])
        let before = selectRoomCompanion("cat_002", appearance: "cow", in: app)
        ensureHomeNavigationItemVisible("tabTown", in: app)
        let townTouch = element("tabTown", in: app).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        tapAnimationControl("feedButton", in: app)
        _ = waitForFurniture(in: app, timeout: 5, description: "cow feeding is still planning before the switch") {
            $0.phase == "feeding" && $0.carePlanning == true && $0.completedMeals == before.completedMeals
        }
        townTouch.tap()
        scrollCareerPage("townMapScroll", to: "townCollectionButton", in: app)
        tapAnimationControl("townCollectionButton", in: app)
        tapAnimationControl("catProfile_cat_001", in: app)
        scrollCareerPage("catProfileScroll", to: "catCompanionButton", in: app)
        tapAnimationControl("catCompanionButton", in: app)
        waitForObservedValue("catCompanionButton", "active", in: app)
        tapAnimationControl("closeSheetButton", in: app)
        tapAnimationControl("tabHome", in: app)
        let switched = waitForFurniture(in: app, description: "orange companion has no pending cow care") {
            $0.activeCatID == "cat_001" && $0.catAppearance == "orange" && $0.phase == "idle"
                && $0.carePlanning == false && $0.restFurniture == nil
        }
        XCTAssertEqual(switched.completedMeals, before.completedMeals)
        // The worker may finish between the observed planning frame and the
        // town tap; neither its queued result nor its animation may survive.
        waitForObservedValue("homeCatName", "小橘", in: app)
        waitForObservedValue("catSatiety", "35", in: app)
        waitForObservedValue("foodCount", "2", in: app)
        attachScreenshot(app, named: "Companion switch — orange cat does not inherit cow feeding")

        // A subsequent action must finish without replaying the cancelled
        // worker or charging another food portion after its result arrives.
        tapAnimationControl("cleanButton", in: app)
        _ = waitForFurniture(in: app, timeout: 10, description: "new companion starts its own clean response") {
            $0.phase == "cleaning"
        }
        let cleaned = waitForFurniture(in: app, timeout: 15, description: "new companion completes only its own action") {
            $0.phase == "idle" && $0.carePlanning == false
        }
        XCTAssertEqual(cleaned.completedMeals, before.completedMeals)
        XCTAssertEqual(cleaned.activeCatID, "cat_001")
        waitForObservedValue("foodCount", "2", in: app)

        _ = selectRoomCompanion("cat_002", appearance: "cow", in: app)
        waitForObservedValue("catSatiety", "80", in: app)
        let ready = furnitureState(in: app)
        let bed = try XCTUnwrap(ready.items.first { $0.id == "catBed" })
        ensureHomeNavigationItemVisible("tabTown", in: app)
        let restTownTouch = element("tabTown", in: app).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        element("roomScene", in: app).coordinate(withNormalizedOffset: restFurnitureTouchPoint(bed)).tap()
        let resting = waitForFurniture(in: app, timeout: 60, description: "cow rest session commits before the next switch") {
            $0.phase == "resting" && $0.restFurniture == "catBed" && $0.restSessionCommitted == true
                && $0.savedRestSession != nil
        }
        XCTAssertEqual(resting.activeCatID, "cat_002")
        let oldRestID = try XCTUnwrap(resting.savedRestSession)
        restTownTouch.tap()
        scrollCareerPage("townMapScroll", to: "townCollectionButton", in: app)
        tapAnimationControl("townCollectionButton", in: app)
        tapAnimationControl("catProfile_cat_001", in: app)
        scrollCareerPage("catProfileScroll", to: "catCompanionButton", in: app)
        tapAnimationControl("catCompanionButton", in: app)
        waitForObservedValue("catCompanionButton", "active", in: app)
        tapAnimationControl("closeSheetButton", in: app)
        tapAnimationControl("tabHome", in: app)
        let awake = waitForFurniture(in: app, timeout: 15, description: "switch clears the cow furniture session and old callbacks") {
            $0.activeCatID == "cat_001" && $0.phase == "idle" && $0.restFurniture == nil
                && $0.restPhase == "none" && $0.restSession == nil && $0.savedRestSession == nil
                && $0.carePlanning == false
        }
        XCTAssertNotEqual(awake.restSession, oldRestID)
        XCTAssertEqual(awake.catEnergy, 80)
        XCTAssertEqual(awake.completedMeals, before.completedMeals)
        attachScreenshot(app, named: "Companion switch — occupied bed and old rest session are cleared")
        let cowAgain = selectRoomCompanion("cat_002", appearance: "cow", in: app)
        XCTAssertNil(cowAgain.savedRestSession)
        XCTAssertNil(cowAgain.restSession)
        XCTAssertEqual(cowAgain.restPhase, "none")
        XCTAssertEqual(cowAgain.completedMeals, before.completedMeals)
        waitForObservedValue("foodCount", "2", in: app)
        tapAnimationControl("tabInventory", in: app)
        waitForObservedValue("inventoryLitterCount", "1", in: app)
        waitForObservedValue("inventoryToyUses", "6", in: app)
    }

    @MainActor
    private func selectRoomCompanion(_ id: String, appearance: String, in app: XCUIApplication) -> FurnitureState {
        openTownCollection(in: app)
        scrollCareerPage("catCollectionScroll", to: "catProfile_\(id)", in: app)
        tapAnimationControl("catProfile_\(id)", in: app)
        scrollCareerPage("catProfileScroll", to: "catCompanionButton", in: app)
        if element("catCompanionButton", in: app).value as? String != "active" {
            tapAnimationControl("catCompanionButton", in: app)
        }
        waitForObservedValue("catCompanionButton", "active", in: app)
        tapAnimationControl("closeSheetButton", in: app)
        tapAnimationControl("tabHome", in: app)
        return waitForFurniture(in: app, description: "selected \(appearance) companion appears idle") {
            $0.activeCatID == id && $0.catAppearance == appearance && $0.phase == "idle" && !$0.pending
        }
    }

    @MainActor
    private func launchCatAdoptionFixture(_ fixture: String, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + [fixture] + extra
        launchAndEnterHome(app)
        return app
    }

    @MainActor
    private func confirmCatAdoption(in app: XCUIApplication) {
        scrollCareerPage("catAdoptionScroll", to: "catAdoptionButton", in: app)
        tapAnimationControl("catAdoptionButton", in: app)
        waitForElement("catAdoptionConfirmation", in: app)
        scrollCareerPage("catAdoptionConfirmation", to: "catAdoptionConfirmButton", in: app)
        tapAnimationControl("catAdoptionConfirmButton", in: app)
    }

    @MainActor
    private func waitForCatSaveProbeRecovery(in app: XCUIApplication) {
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 8))
        // The one-shot failure lets the automatic probe restore saving and
        // close its alert. The probe must never replay a purchase or selection.
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: alert)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 8), .completed)
        if element("catAdoptionCancelButton", in: app).exists {
            waitForObservedValue("catAdoptionConfirmationHint", "failed", in: app)
            tapAnimationControl("catAdoptionCancelButton", in: app)
        }
    }

    @MainActor
    private func openNewlyAdoptedProfile(_ id: String, in app: XCUIApplication) {
        waitForObservedValue("catAdoptionSuccess", id, in: app)
        tapAnimationControl("catAdoptionLaterButton", in: app)
        XCTAssertTrue(element("catFilter_owned", in: app).isSelected)
        scrollCareerPage("catCollectionScroll", to: "catProfile_\(id)", in: app)
        tapAnimationControl("catProfile_\(id)", in: app)
    }
}
