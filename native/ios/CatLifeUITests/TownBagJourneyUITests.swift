import XCTest

extension RoomHomeUITests {
    @MainActor
    func testTownMapDirectoryAndSelectedBagCarePreserveResources() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        tapAnimationControl("tabTown", in: app)
        waitForElement("townMapTitle", in: app)
        for marker in ["townHomeMarker", "townAdoptionMarker", "townCatsMarker"] {
            XCTAssertTrue(element(marker, in: app).isHittable, "Map destinations must be real tappable controls.")
        }
        attachScreenshot(app, named: "Town — map destinations use the native collection and adoption flow")
        tapAnimationControl("townAdoptionMarker", in: app)
        scrollCareerPage("townMapScroll", to: "townMeetCatButton", in: app)
        tapAnimationControl("townMeetCatButton", in: app)
        waitForObservedValue("catAdoptionGold", "200", in: app)
        scrollCareerPage("catAdoptionScroll", to: "catAdoptionButton", in: app)
        XCTAssertFalse(element("catAdoptionButton", in: app).isEnabled)
        tapAnimationControl("closeSheetButton", in: app)
        waitForElement("townMapScroll", in: app)
        scrollCareerPage("townMapScroll", to: "townCatsMarker", in: app)
        tapAnimationControl("townCatsMarker", in: app)
        scrollCareerPage("townMapScroll", to: "townCollectionButton", in: app)
        tapAnimationControl("townCollectionButton", in: app)
        waitForObservedValue("catCount", "1", in: app)
        tapAnimationControl("catProfile_cat_001", in: app)
        waitForObservedValue("catProfileScroll", "cat_001", in: app)
        tapAnimationControl("closeSheetButton", in: app)
        tapAnimationControl("tabHome", in: app)
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
    func openTownCollection(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        tapAnimationControl("tabTown", in: app, file: file, line: line)
        scrollCareerPage("townMapScroll", to: "townCollectionButton", in: app, file: file, line: line)
        tapAnimationControl("townCollectionButton", in: app, file: file, line: line)
        waitForElement("catCollectionScroll", in: app, file: file, line: line)
    }
}
