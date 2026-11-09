import XCTest

extension RoomHomeUITests {
    @MainActor
    func testTownMapDirectoryAndSelectedBagCarePreserveResources() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        tapAnimationControl("tabTown", in: app)
        waitForElement("townMapTitle", in: app)
        for marker in ["townHomeMarker", "townAdoptionMarker", "townCollectionButton"] {
            scrollCareerPage("townMapScroll", to: marker, in: app)
            XCTAssertTrue(element(marker, in: app).isHittable, "Map destinations must be real tappable controls.")
        }
        attachScreenshot(app, named: "Town — map destinations use the native collection and adoption flow")
        scrollCareerPage("townMapScroll", to: "townAdoptionMarker", in: app)
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
        scrollCareerPage("destinationScroll", to: "inventoryItem_litter", in: app)
        tapAnimationControl("inventoryItem_litter", in: app)
        waitForElement("useLitterButton", in: app)
        XCTAssertTrue(element("useFoodButton", in: app).exists,
                      "Stocked supplies keep their own inline use actions.")
        waitForObservedValue("inventoryFoodCount", "3", in: app)
        waitForObservedValue("inventoryLitterCount", "2", in: app)
        attachScreenshot(app, named: "Bag — selecting a supply row does not consume it")
        scrollCareerPage("destinationScroll", to: "useLitterButton", in: app)
        tapAnimationControl("useLitterButton", in: app)
        waitForElement("supplyPicker", in: app)
        XCTAssertFalse(element("supplyPickerConfirmButton", in: app).isEnabled)
        waitForObservedValue("supplyPickerStock_litter", "2", in: app)
        tapAnimationControl("supplyOption_litter", in: app)
        waitForObservedValue("supplyPickerStock_litter", "2", in: app)
        attachScreenshot(app, named: "Bag — chosen litter waits for explicit confirmation")
        tapAnimationControl("supplyPickerConfirmButton", in: app)
        XCTAssertTrue(element("supplyPicker", in: app).waitForNonExistence(timeout: 10))
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
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--town-day", "--town-reduce-motion"]
        launchAndEnterHome(app)
        // English has the widest availability badges and landmark names.
        tapAnimationControl("settingsButton", in: app)
        scrollCareerPage("settingsScroll", to: "languageOption_en", in: app)
        tapAnimationControl("languageOption_en", in: app)
        assertSettingsLanguageSelection("en", in: app)
        tapAnimationControl("tabTown", in: app)
        waitForElement("townMapScroll", in: app)
        waitForObservedValue("townPlaceDetail", "home", in: app)
        XCTAssertTrue(element("townHomeMarker", in: app).isHittable,
                      "The first visit must locate the player's home without a manual swipe.")
        scrollCareerPage("townMapScroll", to: "townHomeMarker", in: app)
        let places = ["townPlot_work", "townPlot_shop", "townPlot_plaza", "townPlot_board", "townPlot_market",
                      "townPlot_street", "townHomeMarker", "townHospitalMarker", "townAdoptionMarker",
                      "townPlot_cafe", "townPlot_lot1", "townPlot_lot2"]
        let canvas = element("townMapCanvas", in: app)
        let initialCanvas = canvas.frame
        XCTAssertGreaterThan(initialCanvas.height, element("townMapScroll", in: app).frame.height,
                             "The town is a vertically scrollable map, not a fixed twelve-card grid.")
        let frames = places.map { element($0, in: app).frame.offsetBy(dx: -initialCanvas.minX, dy: -initialCanvas.minY) }
        for id in places { XCTAssertTrue(element(id, in: app).exists) }
        attachScreenshot(app, named: "Town v2 — home district on the continuous map")
        tapAnimationControl("townLayer_neighbors", in: app)
        let filteredCanvas = canvas.frame
        for (index, id) in places.enumerated() {
            XCTAssertTrue(element(id, in: app).exists)
            let frame = element(id, in: app).frame.offsetBy(dx: -filteredCanvas.minX, dy: -filteredCanvas.minY)
            XCTAssertEqual(frame.minX, frames[index].minX, accuracy: 1, "Filtering must not rearrange map positions.")
            XCTAssertEqual(frame.minY, frames[index].minY, accuracy: 1, "Filtering must not rearrange map positions.")
        }
        tapAnimationControl("townLayer_all", in: app)
        for id in ["cafe", "lot1", "lot2"] {
            scrollCareerPage("townMapScroll", to: "townPlot_\(id)", in: app)
            tapAnimationControl("townPlot_\(id)", in: app)
            waitForObservedValue("townPlaceDetail", id, in: app)
            scrollCareerPage("townMapScroll", to: "townEnter_\(id)", in: app)
            XCTAssertFalse(element("townEnter_\(id)", in: app).isEnabled,
                           "Future places cannot open prototype-only gameplay or notification bookings.")
        }
        XCTAssertFalse(app.buttons["开放时提醒我"].exists)
        attachScreenshot(app, named: "Town v2 — southern reserved plots remain previews")
        tapAnimationControl("townMapFocusHome", in: app)
        waitForObservedValue("townPlaceDetail", "home", in: app)
        XCTAssertTrue(element("townHomeMarker", in: app).isHittable)
        for id in ["street", "market"] {
            scrollCareerPage("townMapScroll", to: "townPlot_\(id)", in: app)
            tapAnimationControl("townPlot_\(id)", in: app)
            waitForObservedValue("townPlaceDetail", id, in: app)
            XCTAssertTrue(element("townEnter_\(id)", in: app).isEnabled,
                          "The already released neighbors and market remain open.")
        }
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        waitForObservedValue("foodCount", "3", in: app)
    }

    @MainActor
    func testTownDestinationsRequireSelectingThenEnteringWithoutChangingResources() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        for (plot, place, enter, destination) in [
            ("townPlot_work", "work", "townEnter_work", "careerChooseJobButton"),
            ("townPlot_shop", "shop", "townEnter_shop", "shopCategory_supplies"),
            ("townHospitalMarker", "hospital", "townHospitalButton", "hospitalDirectoryScroll")
        ] {
            tapAnimationControl("tabTown", in: app)
            scrollCareerPage("townMapScroll", to: plot, in: app)
            tapAnimationControl(plot, in: app)
            XCTAssertTrue(element("townMapScroll", in: app).exists, "Choosing a plot only updates its detail panel.")
            scrollCareerPage("townMapScroll", to: enter, in: app)
            XCTAssertLessThanOrEqual(element(enter, in: app).frame.maxY,
                                    element("homeNavigationBar", in: app).frame.minY + 1,
                                    "A selected place's fixed action must stay above the bottom tabs.")
            tapAnimationControl(enter, in: app)
            waitForElement(destination, in: app)
            tapAnimationControl("tabTown", in: app)
            waitForObservedValue("townPlaceDetail", place, in: app)
            let marker = element(plot, in: app)
            let restored = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                marker.exists && marker.isHittable
                    && self.unobscuredScrollViewport(self.element("townMapScroll", in: app), in: app)
                        .insetBy(dx: -1, dy: -1).contains(marker.frame)
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 8), .completed,
                           "Returning from \(place) must preserve its selection and reveal its building without another swipe.")
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
        tapAnimationControl("homeUpgradeCelebrationDone", in: app)
        waitForObservedValue("adoptionAvailableNotice", "cat_002", in: app)
        tapAnimationControl("adoptionReminderDismiss", in: app)
        // The celebration returns home; follow the still-locked blue cat's room requirement again.
        openTownCollection(in: app)
        tapAnimationControl("catFilter_all", in: app)
        scrollCareerPage("catCollectionScroll", to: "catAdoption_cat_003", in: app)
        tapAnimationControl("catAdoption_cat_003", in: app)
        tapAnimationControl("catAdoptionRequirementAction", in: app)
        scrollCareerPage("homeUpgradeScroll", to: "homeUpgradeCurrentLevel", in: app)
        waitForObservedValue("homeUpgradeCurrentLevel", "2", in: app)
        scrollCareerPage("homeUpgradeScroll", to: "homeUpgradeAction", in: app)
        tapAnimationControl("homeUpgradeAction", in: app)
        tapAnimationControl("homeUpgradeConfirm", in: app)
        tapAnimationControl("homeUpgradeCelebrationDone", in: app)
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
