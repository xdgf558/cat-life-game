import XCTest

extension RoomHomeUITests {
    @MainActor
    func testTownMapDirectoryAndSelectedBagCarePreserveResources() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        tapAnimationControl("tabTown", in: app)
        waitForElement("townMapTitle", in: app)
        for marker in ["townHomeMarker", "townAdoptionMarker", "townCollectionButton"] {
            XCTAssertTrue(element(marker, in: app).isHittable, "Map destinations must be real tappable controls.")
        }
        attachScreenshot(app, named: "Town — map destinations use the native collection and adoption flow")
        tapAnimationControl("townAdoptionMarker", in: app)
        scrollCareerPage("townMapScroll", to: "townAdoptionCollectionButton", in: app)
        tapAnimationControl("townAdoptionCollectionButton", in: app)
        waitForElement("catFilter_owned", in: app)
        XCTAssertTrue(element("catFilter_owned", in: app).isSelected,
                      "Without an eligible offer, the map opens the adopted companions.")
        XCTAssertTrue(element("catProfile_cat_001", in: app).exists)
        XCTAssertFalse(element("catAdoption_cat_002", in: app).exists)
        XCTAssertTrue(element("tabTown", in: app).isSelected)
        tapAnimationControl("catFilter_all", in: app)
        tapAnimationControl("catAdoption_cat_002", in: app)
        waitForObservedValue("catAdoptionConditionsMet", "0/3", in: app)
        XCTAssertFalse(element("catAdoptionButton", in: app).exists)
        XCTAssertTrue(element("catAdoptionRequirementAction", in: app).isEnabled)
        tapAnimationControl("catAdoptionBackButton", in: app)
        waitForObservedValue("catCount", "1", in: app)
        tapAnimationControl("closeSheetButton", in: app)
        waitForElement("townMapScroll", in: app)
        scrollCareerPage("townMapScroll", to: "townCollectionButton", in: app)
        tapAnimationControl("townCollectionButton", in: app)
        waitForObservedValue("catCount", "1", in: app)
        tapAnimationControl("catProfile_cat_001", in: app)
        waitForObservedValue("catProfileScroll", "cat_001", in: app)
        tapAnimationControl("closeSheetButton", in: app)
        scrollCareerPage("townMapScroll", to: "townHomeMarker", in: app)
        tapAnimationControl("townHomeMarker", in: app)
        scrollCareerPage("townMapScroll", to: "townEnter_home", in: app)
        tapAnimationControl("townEnter_home", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        waitForObservedValue("foodCount", "3", in: app)

        tapAnimationControl("tabInventory", in: app)
        waitForObservedValue("inventoryFoodCount", "3", in: app)
        waitForObservedValue("inventoryLitterCount", "2", in: app)
        tapAnimationControl("inventoryItem_litter", in: app)
        waitForElement("useLitterButton", in: app)
        XCTAssertFalse(element("useFoodButton", in: app).exists)
        waitForObservedValue("inventoryFoodCount", "3", in: app)
        waitForObservedValue("inventoryLitterCount", "2", in: app)
        attachScreenshot(app, named: "Bag — selecting a tile changes the fixed action without consuming it")
        tapAnimationControl("useLitterButton", in: app)
        waitForElement("feedButton", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        waitForObservedValue("foodCount", "3", in: app)
        relaunchPreservingSave(app)
        tapAnimationControl("tabInventory", in: app)
        waitForObservedValue("inventoryFoodCount", "3", in: app)
        waitForObservedValue("inventoryLitterCount", "1", in: app)
        waitForObservedValue("inventoryToyUses", "0", in: app)
    }

    @MainActor
    func testTownPlotsKeepTheirLayoutAndFuturePlacesDoNotUnlockGameplay() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        // English has the widest availability badges and landmark names.
        tapAnimationControl("settingsButton", in: app)
        scrollCareerPage("settingsScroll", to: "languageOption_en", in: app)
        tapAnimationControl("languageOption_en", in: app)
        assertSettingsLanguageSelection("en", in: app)
        tapAnimationControl("tabTown", in: app)
        waitForElement("townMapScroll", in: app)
        let row = ["townPlot_street", "townHospitalMarker", "townPlot_cafe"]
        let frames = row.map { element($0, in: app).frame }
        attachScreenshot(app, named: "Town — cartoon buildings retain the twelve-place map")
        tapAnimationControl("townLayer_neighbors", in: app)
        for (index, id) in row.enumerated() {
            XCTAssertTrue(element(id, in: app).exists)
            XCTAssertEqual(element(id, in: app).frame, frames[index], "Filtering dims places without rearranging the map.")
        }
        tapAnimationControl("townLayer_all", in: app)
        for id in ["street", "cafe", "plaza", "board", "market", "lot1", "lot2"] {
            scrollCareerPage("townMapScroll", to: "townPlot_\(id)", in: app)
            tapAnimationControl("townPlot_\(id)", in: app)
            waitForObservedValue("townPlaceDetail", id, in: app)
            scrollCareerPage("townMapScroll", to: "townEnter_\(id)", in: app)
            XCTAssertFalse(element("townEnter_\(id)", in: app).isEnabled,
                           "Future places cannot open prototype-only gameplay or notification bookings.")
        }
        XCTAssertFalse(app.buttons["开放时提醒我"].exists)
        attachScreenshot(app, named: "Town — reserved plots remain previews without fake unlocks")
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        waitForObservedValue("foodCount", "3", in: app)
    }

    @MainActor
    func testTownDestinationsRequireSelectingThenEnteringWithoutChangingResources() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        for (plot, enter, destination) in [
            ("townPlot_work", "townEnter_work", "careerChooseJobButton"),
            ("townPlot_shop", "townEnter_shop", "shopCategory_supplies"),
            ("townHospitalMarker", "townHospitalButton", "hospitalDirectoryScroll")
        ] {
            tapAnimationControl("tabTown", in: app)
            scrollCareerPage("townMapScroll", to: plot, in: app)
            tapAnimationControl(plot, in: app)
            XCTAssertTrue(element("townMapScroll", in: app).exists, "Choosing a plot only updates its detail panel.")
            scrollCareerPage("townMapScroll", to: enter, in: app)
            tapAnimationControl(enter, in: app)
            waitForElement(destination, in: app)
        }
        tapAnimationControl("tabTown", in: app)
        tapAnimationControl("townCollectionButton", in: app)
        waitForObservedValue("catCount", "1", in: app)
        tapAnimationControl("closeSheetButton", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        waitForObservedValue("foodCount", "3", in: app)
    }

    @MainActor
    func testRoomUpgradeReminderOpensEligibleBlueCatAndDoesNotReplayAfterRelaunch() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--shop-upgrade-fixture"]
        launchAndEnterHome(app)
        openTownCollection(in: app)
        tapAnimationControl("catFilter_all", in: app)
        scrollCareerPage("catCollectionScroll", to: "catAdoption_cat_003", in: app)
        tapAnimationControl("catAdoption_cat_003", in: app)
        waitForObservedValue("catAdoptionConditionsMet", "2/3", in: app)
        tapAnimationControl("catAdoptionRequirementAction", in: app)
        waitForObservedValue("homeUpgradeCurrentLevel", "1", in: app)
        scrollCareerPage("homeUpgradeScroll", to: "homeUpgradeAction", in: app)
        tapAnimationControl("homeUpgradeAction", in: app)
        tapAnimationControl("homeUpgradeConfirm", in: app)
        waitForObservedValue("adoptionAvailableNotice", "cat_002", in: app)
        tapAnimationControl("adoptionReminderDismiss", in: app)
        scrollCareerPage("homeUpgradeScroll", to: "homeUpgradeCurrentLevel", in: app)
        waitForObservedValue("homeUpgradeCurrentLevel", "2", in: app)
        scrollCareerPage("homeUpgradeScroll", to: "homeUpgradeAction", in: app)
        tapAnimationControl("homeUpgradeAction", in: app)
        tapAnimationControl("homeUpgradeConfirm", in: app)
        waitForObservedValue("adoptionAvailableNotice", "cat_003", in: app)
        tapAnimationControl("adoptionReminderOpen", in: app)
        waitForLabel("catAdoptionName", "蓝影", in: app)
        waitForObservedValue("catAdoptionConditionsMet", "3/3", in: app)
        XCTAssertTrue(element("catAdoptionButton", in: app).isEnabled)
        XCTAssertTrue(element("tabTown", in: app).isSelected)
        attachScreenshot(app, named: "Town — room upgrade unlock reminder opens the real blue-cat offer")
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", "3,650", in: app)
        relaunchPreservingSave(app)
        waitForObservedValue("goldCount", "3,650", in: app)
        XCTAssertFalse(element("adoptionAvailableNotice", in: app).exists)
        openTownCollection(in: app)
        waitForObservedValue("catCount", "1", in: app)
        tapAnimationControl("catFilter_unowned", in: app)
        waitForObservedValue("catAdoption_cat_003", "可以领养", in: app)
    }

    @MainActor
    func openTownCollection(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        tapAnimationControl("tabTown", in: app, file: file, line: line)
        scrollCareerPage("townMapScroll", to: "townCollectionButton", in: app, file: file, line: line)
        tapAnimationControl("townCollectionButton", in: app, file: file, line: line)
        waitForElement("catCollectionScroll", in: app, file: file, line: line)
    }
}
