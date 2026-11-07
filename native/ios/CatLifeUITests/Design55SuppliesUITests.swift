import XCTest

extension RoomHomeUITests {
    @MainActor
    func testSupplyGroupsAndEnglishAccessiblePurchaseToBagChoice() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--community-fixture"]
        launchAndEnterHome(app)
        tapAnimationControl("tabShop", in: app)
        waitForObservedValue("shopGoldCount", "5,000", in: app)
        attachScreenshot(app, named: "Supplies — normal shop premium and everyday groups")
        for identifier in ["buyPremiumFoodButton", "buyPremiumLitterButton"] {
            scrollCareerPage("destinationScroll", to: identifier, in: app)
            tapAnimationControl(identifier, in: app)
        }
        waitForObservedValue("shopGoldCount", "4,915", in: app)
        scrollCareerPage("destinationScroll", to: "buyFoodButton", in: app)
        attachScreenshot(app, named: "Supplies — normal shop everyday supplies")
        tapAnimationControl("tabInventory", in: app)
        waitForObservedValue("inventoryPremiumFoodCount", "1", in: app)
        waitForObservedValue("inventoryPremiumLitterCount", "1", in: app)
        attachScreenshot(app, named: "Supplies — normal backpack premium group")
        scrollCareerPage("destinationScroll", to: "inventoryItem_litter", in: app)
        attachScreenshot(app, named: "Supplies — normal backpack everyday group")

        app.terminate()
        app.launchArguments = arguments(reset: true) + ["--community-fixture",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        launchAndEnterHome(app)
        selectCatTestLanguage("en", in: app)
        tapAnimationControl("tabShop", in: app)
        for (identifier, gold) in [("buyPremiumFoodButton", "4,960"), ("buyPremiumLitterButton", "4,915")] {
            scrollCareerPage("destinationScroll", to: identifier, in: app)
            XCTAssertTrue(element(identifier, in: app).isEnabled && element(identifier, in: app).isHittable)
            tapAnimationControl(identifier, in: app)
            waitForObservedValue("shopGoldCount", gold, in: app)
        }
        attachScreenshot(app, named: "Supplies — English accessible shop purchase")
        tapAnimationControl("tabInventory", in: app)
        waitForObservedValue("inventoryPremiumFoodCount", "1", in: app)
        waitForObservedValue("inventoryPremiumLitterCount", "1", in: app)
        scrollCareerPage("destinationScroll", to: "usePremiumFoodButton", in: app)
        XCTAssertTrue(element("usePremiumFoodButton", in: app).isHittable)
        attachScreenshot(app, named: "Supplies — English accessible backpack use entry")
        tapAnimationControl("usePremiumFoodButton", in: app)
        waitForElement("supplyPicker", in: app)
        XCTAssertFalse(element("supplyPickerConfirmButton", in: app).isEnabled)
        waitForObservedValue("supplyPickerStock_premiumFood", "1", in: app)
        tapAnimationControl("supplyPickerCancelButton", in: app)
        waitForObservedValue("inventoryPremiumFoodCount", "1", in: app)
        waitForObservedValue("inventoryPremiumLitterCount", "1", in: app)
        waitForObservedValue("inventoryFoodCount", "3", in: app)
    }

    @MainActor
    func testPremiumOnlyHomeCareRequiresChoiceAndKeepsCancelledSupplies() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--premium-only-fixture"]
        launchAndEnterHome(app)
        waitForObservedValue("foodCount", "2", in: app)
        waitForObservedValue("goldCount", "5,000", in: app)
        attachScreenshot(app, named: "Supplies — premium-only home offers a choice")

        tapAnimationControl("feedButton", in: app)
        waitForElement("supplyPicker", in: app)
        waitForObservedValue("supplyPickerStock_food", "0", in: app)
        waitForObservedValue("supplyPickerStock_premiumFood", "2", in: app)
        XCTAssertFalse(element("supplyPickerConfirmButton", in: app).isEnabled)
        attachScreenshot(app, named: "Supplies — no automatic premium selection")
        tapAnimationControl("supplyPickerCancelButton", in: app)
        XCTAssertTrue(element("supplyPicker", in: app).waitForNonExistence(timeout: 8))
        waitForObservedValue("foodCount", "2", in: app)
        waitForObservedValue("goldCount", "5,000", in: app)

        tapAnimationControl("feedButton", in: app)
        waitForElement("supplyPicker", in: app)
        XCTAssertFalse(element("supplyPickerConfirmButton", in: app).isEnabled,
                       "Reopening the picker must not silently retain a premium choice.")
        tapAnimationControl("supplyOption_premiumFood", in: app)
        XCTAssertTrue(element("supplyPickerConfirmButton", in: app).isEnabled)
        waitForObservedValue("supplyPickerStock_premiumFood", "2", in: app)
        waitForObservedValue("supplyPickerServings", "1", in: app)
        attachScreenshot(app, named: "Supplies — premium choice shows explicit consumption")
        tapAnimationControl("supplyPickerConfirmButton", in: app)
        XCTAssertTrue(element("supplyPicker", in: app).waitForNonExistence(timeout: 10))
        waitForObservedValue("foodCount", "1", in: app)

        tapAnimationControl("cleanButton", in: app)
        waitForElement("supplyPicker", in: app)
        XCTAssertFalse(element("supplyPickerConfirmButton", in: app).isEnabled)
        waitForObservedValue("supplyPickerStock_litter", "0", in: app)
        waitForObservedValue("supplyPickerStock_premiumLitter", "2", in: app)
        tapAnimationControl("supplyOption_premiumLitter", in: app)
        tapAnimationControl("supplyPickerConfirmButton", in: app)
        XCTAssertTrue(element("supplyPicker", in: app).waitForNonExistence(timeout: 10))
        waitForObservedValue("goldCount", "5,000", in: app)

        relaunchPreservingSave(app)
        tapAnimationControl("tabInventory", in: app)
        waitForObservedValue("inventoryPremiumFoodCount", "1", in: app)
        waitForObservedValue("inventoryPremiumLitterCount", "1", in: app)
        scrollCareerPage("destinationScroll", to: "inventoryFoodCount", in: app)
        waitForObservedValue("inventoryFoodCount", "0", in: app)
        scrollCareerPage("destinationScroll", to: "inventoryLitterCount", in: app)
        waitForObservedValue("inventoryLitterCount", "0", in: app)
    }

    @MainActor
    func testSupplyPickerFailedSaveKeepsChoiceStockAndVisibleError() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--premium-only-fixture", "--save-outage-test"]
        launchAndEnterHome(app)
        tapAnimationControl("feedButton", in: app)
        waitForElement("supplyPicker", in: app)
        tapAnimationControl("supplyOption_premiumFood", in: app)
        tapAnimationControl("supplyPickerConfirmButton", in: app)
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 8))
        XCTAssertEqual(app.alerts.count, 1)
        XCTAssertTrue(alert.staticTexts["这次操作还没有保存"].exists)
        alert.buttons["完成"].tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 8))
        waitForElement("supplyPicker", in: app)
        waitForElement("supplyPickerFailure", in: app)
        waitForObservedValue("supplyPickerStock_premiumFood", "2", in: app)
        XCTAssertTrue(element("supplyPickerConfirmButton", in: app).isEnabled)
        attachScreenshot(app, named: "Supplies — failed save leaves choice and supplies intact")
        tapAnimationControl("supplyPickerCancelButton", in: app)
        waitForObservedValue("foodCount", "2", in: app)
        relaunchPreservingSave(app)
        waitForObservedValue("foodCount", "2", in: app)
        waitForObservedValue("goldCount", "5,000", in: app)
    }

    @MainActor
    func testSupplyPickerEnglishAtLargestAccessibilityText() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--premium-only-fixture",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        launchAndEnterHome(app)
        selectCatTestLanguage("en", in: app)
        tapAnimationControl("feedButton", in: app)
        waitForElement("supplyPicker", in: app)
        let confirm = element("supplyPickerConfirmButton", in: app)
        XCTAssertEqual(confirm.label, "Choose a supply first")
        XCTAssertFalse(confirm.isEnabled)
        scrollCareerPage("supplyPicker", to: "supplyOption_premiumFood", in: app)
        tapAnimationControl("supplyOption_premiumFood", in: app)
        XCTAssertTrue(confirm.isEnabled && confirm.isHittable)
        XCTAssertFalse(confirm.label.contains("supply."))
        XCTAssertLessThanOrEqual(confirm.frame.maxY, app.frame.maxY)
        XCTAssertGreaterThanOrEqual(confirm.frame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(confirm.frame.maxX, app.frame.maxX)
        attachScreenshot(app, named: "Supplies — English picker at largest accessibility text")
        scrollCareerPage("supplyPicker", to: "supplyPickerCancelButton", in: app)
        tapAnimationControl("supplyPickerCancelButton", in: app)
        waitForObservedValue("foodCount", "2", in: app)
    }
}
