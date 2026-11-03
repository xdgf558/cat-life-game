import XCTest

extension RoomHomeUITests {
    @MainActor
    func testCatAdoptionShowsLockedRequirementsInAllLanguagesWithoutCharging() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        for (code, title, name) in [("zh-Hans", "领养伙伴", "牛奶"),
                                    ("zh-Hant", "領養夥伴", "牛奶"), ("en", "Adopt a friend", "MooMoo")] {
            if code != "zh-Hans" { selectCatTestLanguage(code, in: app) }
            tapAnimationControl("tabTown", in: app)
            waitForObservedValue("catCount", "1", in: app)
            tapAnimationControl("catAdoption_cat_002", in: app)
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 8))
            XCTAssertTrue(app.staticTexts[name].firstMatch.exists)
            for identifier in ["catAdoptionPlayerRequirement", "catAdoptionRoomRequirement", "catAdoptionGoldRequirement"] {
                scrollCareerPage("catAdoptionScroll", to: identifier, in: app)
                waitForObservedValue(identifier, code == "en" ? "Not met" : (code == "zh-Hant" ? "尚未符合" : "未满足"), in: app)
            }
            scrollCareerPage("catAdoptionScroll", to: "catAdoptionButton", in: app)
            XCTAssertFalse(element("catAdoptionButton", in: app).isEnabled)
            attachScreenshot(app, named: "Adoption — locked requirements in \(code)")
            tapAnimationControl("closeSheetButton", in: app)
            waitForObservedValue("goldCount", "200", in: app)
            waitForObservedValue("foodCount", "3", in: app)
        }
    }

    @MainActor
    func testAdoptionConfirmationSelectionRenameAndRelaunchPreserveBothCats() throws {
        continueAfterFailure = false
        let app = launchCatAdoptionFixture("--uitesting-adoption-ready")
        tapAnimationControl("tabTown", in: app)
        waitForObservedValue("catCount", "1", in: app)
        tapAnimationControl("catAdoption_cat_002", in: app)
        scrollCareerPage("catAdoptionScroll", to: "catAdoptionButton", in: app)
        tapAnimationControl("catAdoptionButton", in: app)
        let cancel = app.alerts.buttons["取消"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 8))
        cancel.tap()
        waitForObservedValue("catAdoptionGold", "1,000", in: app)
        confirmCatAdoption(in: app)
        waitForObservedValue("catProfileScroll", "cat_002", in: app)
        waitForObservedValue("catProfileName", "牛奶", in: app)
        waitForObservedValue("catCompanionButton", "available", in: app)
        attachScreenshot(app, named: "Adoption — new cow cat profile after successful purchase")
        tapAnimationControl("closeSheetButton", in: app)
        waitForObservedValue("goldCount", "700", in: app)
        waitForObservedValue("homeCatName", "小橘", in: app)
        tapAnimationControl("tabTown", in: app)
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
        waitForObservedValue("homeCatName", "奶糖🐾", in: app)
        attachScreenshot(app, named: "Companion — cow cat selected in the room")
        relaunchPreservingSave(app)
        waitForObservedValue("homeCatName", "奶糖🐾", in: app)
        waitForObservedValue("goldCount", "700", in: app)
        tapAnimationControl("tabTown", in: app)
        waitForObservedValue("catCount", "2", in: app)
        tapAnimationControl("catProfile_cat_001", in: app)
        waitForObservedValue("catProfileName", "小橘", in: app)
        scrollCareerPage("catProfileScroll", to: "catCompanionButton", in: app)
        tapAnimationControl("catCompanionButton", in: app)
        waitForObservedValue("catCompanionButton", "active", in: app)
        tapAnimationControl("closeSheetButton", in: app)
        waitForObservedValue("homeCatName", "小橘", in: app)
        waitForObservedValue("goldCount", "700", in: app)
    }

    @MainActor
    func testCompanionCareChangesOnlySelectedCatAndSurvivesRelaunch() throws {
        continueAfterFailure = false
        let app = launchCatAdoptionFixture("--uitesting-adoption-owned")
        tapAnimationControl("tabTown", in: app)
        tapAnimationControl("catProfile_cat_002", in: app)
        scrollCareerPage("catProfileScroll", to: "catCompanionButton", in: app)
        tapAnimationControl("catCompanionButton", in: app)
        waitForObservedValue("catCompanionButton", "active", in: app)
        tapAnimationControl("closeSheetButton", in: app)
        waitForObservedValue("homeCatName", "牛奶", in: app)
        waitForObservedValue("catSatiety", "55", in: app)
        tapAnimationControl("feedButton", in: app)
        waitForObservedValue("foodCount", "2", in: app)
        waitForObservedValue("catSatiety", "80", in: app)
        tapAnimationControl("tabTown", in: app)
        tapAnimationControl("catProfile_cat_001", in: app)
        scrollCareerPage("catProfileScroll", to: "catProfileSatiety", in: app)
        waitForObservedValue("catProfileSatiety", "35", in: app)
        scrollCareerPage("catProfileScroll", to: "catCompanionButton", in: app)
        tapAnimationControl("catCompanionButton", in: app)
        waitForObservedValue("catCompanionButton", "active", in: app)
        tapAnimationControl("closeSheetButton", in: app)
        waitForObservedValue("homeCatName", "小橘", in: app)
        waitForObservedValue("catSatiety", "35", in: app)
        relaunchPreservingSave(app)
        waitForObservedValue("homeCatName", "小橘", in: app)
        tapAnimationControl("tabTown", in: app)
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
        tapAnimationControl("tabTown", in: app)
        tapAnimationControl("catAdoption_cat_002", in: app)
        confirmCatAdoption(in: app)
        waitForCatSaveProbeRecovery(in: app)
        waitForObservedValue("catAdoptionHint", "failed", in: app)
        waitForObservedValue("catAdoptionGold", "1,000", in: app)
        scrollCareerPage("catAdoptionScroll", to: "catAdoptionButton", in: app)
        XCTAssertTrue(element("catAdoptionButton", in: app).isEnabled)
        attachScreenshot(app, named: "Adoption — failed save keeps coins and offers retry")
        confirmCatAdoption(in: app)
        waitForObservedValue("catProfileScroll", "cat_002", in: app)
        scrollCareerPage("catProfileScroll", to: "catCompanionButton", in: app)
        tapAnimationControl("catCompanionButton", in: app)
        waitForCatSaveProbeRecovery(in: app)
        waitForObservedValue("catCompanionHint", "failed", in: app)
        waitForObservedValue("catCompanionButton", "available", in: app)
        XCTAssertTrue(element("catCompanionButton", in: app).isEnabled)
        tapAnimationControl("closeSheetButton", in: app)
        waitForObservedValue("homeCatName", "小橘", in: app)
        waitForObservedValue("goldCount", "700", in: app)
        tapAnimationControl("tabTown", in: app)
        waitForObservedValue("catCount", "2", in: app)
        tapAnimationControl("catProfile_cat_002", in: app)
        scrollCareerPage("catProfileScroll", to: "catCompanionButton", in: app)
        tapAnimationControl("catCompanionButton", in: app)
        waitForObservedValue("catCompanionButton", "active", in: app)
        tapAnimationControl("closeSheetButton", in: app)
        relaunchPreservingSave(app)
        waitForObservedValue("homeCatName", "牛奶", in: app)
        waitForObservedValue("goldCount", "700", in: app)
    }

    @MainActor
    func testCowCatCompletesBowlMealPounceAndSupportedFurnitureRests() throws {
        continueAfterFailure = false
        let app = launchCatAdoptionFixture("--uitesting-adoption-owned", extra: ["--rest-test"])
        let before = selectRoomCompanion("cat_002", appearance: "cow", in: app)
        tapAnimationControl("feedButton", in: app)
        _ = waitForFurniture(in: app, timeout: 35, description: "cow cat reaches the actual food surface") {
            $0.activeCatID == "cat_002" && $0.catAppearance == "cow" && $0.phase == "feeding"
                && $0.foodContactSamples > before.foodContactSamples && $0.completedMeals == before.completedMeals
        }
        attachScreenshot(app, named: "Cow cat — lowered mouth in contact with the bowl")
        let fed = waitForFurniture(in: app, timeout: 45, description: "cow cat completes one full meal and return path") {
            $0.phase == "idle" && $0.completedMeals == before.completedMeals + 1
        }
        XCTAssertEqual(fed.activeCatID, "cat_002")
        XCTAssertEqual(fed.catAppearance, "cow")
        XCTAssertGreaterThan(fed.foodContactSamples, before.foodContactSamples)
        waitForObservedValue("catSatiety", "80", in: app)
        waitForObservedValue("foodCount", "2", in: app)

        let pounces = try XCTUnwrap(fed.completedPounces)
        tapAnimationControl("playButton", in: app)
        _ = waitForFurniture(in: app, timeout: 15, description: "cow cat begins the real play route") {
            $0.phase == "playing" && $0.carePlanning == false
        }
        attachScreenshot(app, named: "Cow cat — approaching the toy for a pounce")
        let played = waitForFurniture(in: app, timeout: 40, description: "cow cat lands its pounce and returns safely") {
            $0.phase == "idle" && $0.completedPounces == pounces + 1
        }
        XCTAssertEqual(played.activeCatID, "cat_002")
        XCTAssertEqual(played.completedMeals, fed.completedMeals)

        for id in ["catBed", "floorCushion"] {
            let resting = try beginFurnitureRest(id, in: app)
            XCTAssertEqual(resting.activeCatID, "cat_002")
            XCTAssertEqual(resting.catAppearance, "cow")
            attachScreenshot(app, named: "Cow cat — paws and body supported on \(id)")
            let visual = try XCTUnwrap(resting.restVisualPoint)
            element("roomScene", in: app)
                .coordinate(withNormalizedOffset: CGVector(dx: visual.x, dy: visual.y - 0.035)).tap()
            let awake = waitForFurniture(in: app, timeout: 30, description: "cow cat steps down safely from \(id)") {
                $0.phase == "idle" && $0.restFurniture == nil && $0.restPhase == "none"
                    && $0.restExits == (resting.restExits ?? -1) + 1 && $0.savedRestSession == nil
            }
            XCTAssertGreaterThan(awake.stepDownSamples ?? -1, resting.stepDownSamples ?? -1)
            XCTAssertNil(awake.savedRestSession)
            XCTAssertEqual(awake.completedMeals, fed.completedMeals)
            attachScreenshot(app, named: "Cow cat — safely back on the floor after \(id)")
        }
        waitForObservedValue("foodCount", "2", in: app)
        waitForObservedValue("goldCount", "1,000", in: app)
        tapAnimationControl("tabInventory", in: app)
        waitForObservedValue("inventoryFoodCount", "2", in: app)
        waitForObservedValue("inventoryLitterCount", "2", in: app)
        waitForObservedValue("inventoryToyUses", "5", in: app)
        tapAnimationControl("closeSheetButton", in: app)
        tapAnimationControl("tabTown", in: app)
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
        tapAnimationControl("catProfile_cat_001", in: app)
        scrollCareerPage("catProfileScroll", to: "catCompanionButton", in: app)
        tapAnimationControl("catCompanionButton", in: app)
        waitForObservedValue("catCompanionButton", "active", in: app)
        tapAnimationControl("closeSheetButton", in: app)
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
        tapAnimationControl("catProfile_cat_001", in: app)
        scrollCareerPage("catProfileScroll", to: "catCompanionButton", in: app)
        tapAnimationControl("catCompanionButton", in: app)
        waitForObservedValue("catCompanionButton", "active", in: app)
        tapAnimationControl("closeSheetButton", in: app)
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
        tapAnimationControl("tabTown", in: app)
        tapAnimationControl("catProfile_\(id)", in: app)
        scrollCareerPage("catProfileScroll", to: "catCompanionButton", in: app)
        tapAnimationControl("catCompanionButton", in: app)
        waitForObservedValue("catCompanionButton", "active", in: app)
        tapAnimationControl("closeSheetButton", in: app)
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
        let confirmation = app.alerts.buttons["确认领养"].firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 8))
        confirmation.tap()
    }

    @MainActor
    private func waitForCatSaveProbeRecovery(in app: XCUIApplication) {
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 8))
        // The one-shot failure lets the automatic probe restore saving and
        // close its alert. The probe must never replay a purchase or selection.
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: alert)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 8), .completed)
    }
}
