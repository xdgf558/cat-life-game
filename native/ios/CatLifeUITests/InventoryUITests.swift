import XCTest

extension RoomHomeUITests {
    @MainActor
    func testInventoryFoodUsePersistsAcrossRelaunch() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        XCTAssertTrue(element("tabInventory", in: app).label.contains("背包"),
                      "The inventory must have a visible, named home navigation entry.")
        tapAnimationControl("tabInventory", in: app)
        waitForObservedValue("inventoryFoodCount", "3", in: app)
        waitForObservedValue("inventoryLitterCount", "2", in: app)
        waitForObservedValue("inventoryToyUses", "0", in: app)
        attachScreenshot(app, named: "Inventory — real starting supplies and empty toy stock")

        bringIntoView("useFoodButton", in: app)
        tapAnimationControl("useFoodButton", in: app)
        waitForInventoryClosed("inventoryFoodCount", in: app)
        waitForObservedValue("foodCount", "2", in: app)
        waitForObservedValue("catSatiety", "60", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        attachScreenshot(app, named: "Inventory — food use returns to the room and consumes one portion")

        tapAnimationControl("tabInventory", in: app)
        waitForObservedValue("inventoryFoodCount", "2", in: app)
        waitForObservedValue("inventoryLitterCount", "2", in: app)
        tapAnimationControl("closeSheetButton", in: app)
        relaunchPreservingSave(app)
        tapAnimationControl("tabInventory", in: app)
        waitForObservedValue("inventoryFoodCount", "2", in: app)
        waitForObservedValue("inventoryLitterCount", "2", in: app)
        waitForObservedValue("inventoryToyUses", "0", in: app)
        attachScreenshot(app, named: "Inventory — used food count survives a cold launch")
    }

    @MainActor
    func testInventoryToyPurchaseAndUseCountsRemainingUses() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        tapAnimationControl("tabInventory", in: app)
        waitForObservedValue("inventoryToyUses", "0", in: app)
        bringIntoView("useToyButton", in: app)
        XCTAssertTrue(element("useToyButton", in: app).exists,
                      "An empty toy row must remain visible in the inventory.")
        XCTAssertFalse(element("useToyButton", in: app).isEnabled,
                       "A toy with zero remaining uses cannot be consumed.")

        bringIntoView("inventoryShopButton", in: app)
        tapAnimationControl("inventoryShopButton", in: app)
        waitForElement("buyToyButton", in: app)
        bringIntoView("buyToyButton", in: app)
        tapAnimationControl("buyToyButton", in: app)
        waitForObservedValue("shopGoldCount", "165", in: app)
        tapAnimationControl("closeSheetButton", in: app)
        waitForObservedValue("goldCount", "165", in: app)

        tapAnimationControl("tabInventory", in: app)
        // One wand supplies six play uses. The backpack must not label this as
        // six purchased wands or retain the empty stock from the previous visit.
        waitForObservedValue("inventoryToyUses", "6", in: app)
        waitForObservedValue("inventoryFoodCount", "3", in: app)
        bringIntoView("useToyButton", in: app)
        attachScreenshot(app, named: "Inventory — purchased toy supplies six remaining uses")
        tapAnimationControl("useToyButton", in: app)
        waitForInventoryClosed("inventoryToyUses", in: app)
        waitForObservedValue("goldCount", "165", in: app)

        tapAnimationControl("tabInventory", in: app)
        waitForObservedValue("inventoryToyUses", "5", in: app)
        waitForObservedValue("inventoryFoodCount", "3", in: app)
        waitForObservedValue("inventoryLitterCount", "2", in: app)
        bringIntoView("inventoryToyUses", in: app)
        attachScreenshot(app, named: "Inventory — one play use consumed without changing other supplies")
    }

    @MainActor
    private func waitForInventoryClosed(_ inventoryIdentifier: String, in app: XCUIApplication,
                                       file: StaticString = #filePath, line: UInt = #line) {
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"),
                                                   object: element(inventoryIdentifier, in: app))
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 8), .completed,
                       "Using a supply must dismiss the backpack so its room response is visible.",
                       file: file, line: line)
        let roomReady = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND hittable == true"),
            object: element("feedButton", in: app))
        XCTAssertEqual(XCTWaiter.wait(for: [roomReady], timeout: 8), .completed,
                       "The room care controls must be available after using an inventory item.",
                       file: file, line: line)
    }
}
