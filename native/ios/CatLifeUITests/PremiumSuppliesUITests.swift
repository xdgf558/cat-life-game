import XCTest

extension RoomHomeUITests {
    @MainActor
    func testPremiumSuppliesBuyChooseUseAndPersist() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--community-fixture"]
        launchAndEnterHome(app)
        tapAnimationControl("tabShop", in: app)
        scrollCareerPage("destinationScroll", to: "buyPremiumFoodButton", in: app)
        tapAnimationControl("buyPremiumFoodButton", in: app)
        waitForObservedValue("shopGoldCount", "4,960", in: app)
        scrollCareerPage("destinationScroll", to: "buyPremiumLitterButton", in: app)
        tapAnimationControl("buyPremiumLitterButton", in: app)
        waitForObservedValue("shopGoldCount", "4,915", in: app)
        attachScreenshot(app, named: "Premium supplies — separate shop offers")
        tapAnimationControl("tabInventory", in: app)
        waitForObservedValue("inventoryPremiumFoodCount", "1", in: app)
        waitForObservedValue("inventoryPremiumLitterCount", "1", in: app)
        tapAnimationControl("inventoryItem_premiumFood", in: app)
        attachScreenshot(app, named: "Premium supplies — choose food in backpack")
        tapAnimationControl("usePremiumFoodButton", in: app)
        waitForElement("supplyPicker", in: app)
        XCTAssertFalse(element("supplyPickerConfirmButton", in: app).isEnabled)
        tapAnimationControl("supplyOption_premiumFood", in: app)
        tapAnimationControl("supplyPickerConfirmButton", in: app)
        XCTAssertTrue(element("supplyPicker", in: app).waitForNonExistence(timeout: 10))
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("foodCount", "3", in: app)
        tapAnimationControl("tabInventory", in: app)
        waitForObservedValue("inventoryPremiumFoodCount", "0", in: app)
        tapAnimationControl("inventoryItem_premiumLitter", in: app)
        tapAnimationControl("usePremiumLitterButton", in: app)
        waitForElement("supplyPicker", in: app)
        tapAnimationControl("supplyOption_premiumLitter", in: app)
        tapAnimationControl("supplyPickerConfirmButton", in: app)
        XCTAssertTrue(element("supplyPicker", in: app).waitForNonExistence(timeout: 10))
        tapAnimationControl("tabInventory", in: app)
        waitForObservedValue("inventoryPremiumLitterCount", "0", in: app)
        waitForObservedValue("inventoryLitterCount", "2", in: app)
        tapAnimationControl("tabHome", in: app)
        relaunchPreservingSave(app)
        tapAnimationControl("tabInventory", in: app)
        waitForObservedValue("inventoryPremiumFoodCount", "0", in: app)
        waitForObservedValue("inventoryPremiumLitterCount", "0", in: app)
        waitForObservedValue("inventoryFoodCount", "3", in: app)
    }
}
