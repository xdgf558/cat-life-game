import XCTest

extension RoomHomeUITests {
    @MainActor
    func testShopFurnitureAndSupplyFiltersKeepDetailsAndResetWhenChangingCategory() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--shop-layout-fixture"]
        launchAndEnterHome(app)
        tapAnimationControl("tabShop", in: app)
        tapAnimationControl("shopFilter_standard", in: app)
        waitForObservedValue("shopResultCount", "3", in: app)
        XCTAssertFalse(element("shopItem_premiumFood", in: app).exists)
        waitForElement("shopItem_food", in: app)
        tapAnimationControl("shopFilter_premium", in: app)
        waitForObservedValue("shopResultCount", "2", in: app)
        waitForElement("shopItem_premiumFood", in: app)
        XCTAssertFalse(element("shopItem_food", in: app).exists)

        tapAnimationControl("shopCategory_furniture", in: app)
        XCTAssertTrue(element("shopFilter_all", in: app).isSelected)
        waitForObservedValue("shopResultCount", "6", in: app)
        waitForObservedValue("shopPageSummary", "1/1", in: app)
        scrollCareerPage("destinationScroll", to: "shopPageNext", in: app)
        XCTAssertFalse(element("shopPagePrevious", in: app).isEnabled)
        XCTAssertFalse(element("shopPageNext", in: app).isEnabled)
        scrollCareerPage("destinationScroll", to: "shopFilter_wall", in: app)
        tapAnimationControl("shopFilter_wall", in: app)
        waitForObservedValue("shopResultCount", "1", in: app)
        XCTAssertFalse(element("shopItem_oak_bookcase", in: app).exists)
        tapAnimationControl("shopItem_sunrise_art", in: app)
        waitForElement("shopDetailScroll", in: app)
        tapAnimationControl("shopDetailBackButton", in: app)
        XCTAssertTrue(element("shopFilter_wall", in: app).isSelected)
        tapAnimationControl("shopFilter_floor", in: app)
        waitForObservedValue("shopResultCount", "5", in: app)
        XCTAssertFalse(element("shopItem_sunrise_art", in: app).exists)
        attachScreenshot(app, named: "Shop browser — floor furniture keeps new and owned items together")

        selectBrowseFilter("premium", in: app)
        waitForObservedValue("shopResultCount", "0", in: app)
        waitForElement("shopEmptyFilter", in: app)
        attachScreenshot(app, named: "Shop browser — honest premium furniture empty state, no invented products")

        tapAnimationControl("shopCategory_equipment", in: app)
        waitForObservedValue("shopResultCount", "4", in: app)
        XCTAssertFalse(element("shopFilter_floor", in: app).exists)
        tapAnimationControl("shopCategory_furniture", in: app)
        XCTAssertTrue(element("shopFilter_all", in: app).isSelected)
        waitForObservedValue("shopResultCount", "6", in: app)
        waitForObservedValue("shopGoldCount", "455", in: app)
    }

    @MainActor
    func testAccessibleShopPagesReachEverySupplyResetFiltersAndReturnToProductTop() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--shop-layout-fixture",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        launchAndEnterHome(app)
        selectCatTestLanguage("en", in: app)
        tapAnimationControl("tabShop", in: app)
        scrollCareerPage("destinationScroll", to: "shopPageNext", in: app)
        waitForObservedValue("shopPageSummary", "1/3", in: app)
        XCTAssertFalse(element("shopPagePrevious", in: app).isEnabled)
        tapAnimationControl("shopPageNext", in: app)
        XCTAssertTrue(element("shopCategory_supplies", in: app).isHittable,
                      "Changing pages should return to the category and product controls.")
        XCTAssertFalse(element("shopItem_premiumFood", in: app).exists)
        scrollCareerPage("destinationScroll", to: "buyFoodButton", in: app)
        tapAnimationControl("buyFoodButton", in: app)
        waitForObservedValue("shopGoldCount", "435", in: app)
        scrollCareerPage("destinationScroll", to: "shopPageNext", in: app)
        waitForObservedValue("shopPageSummary", "2/3", in: app)
        tapAnimationControl("shopPageNext", in: app)
        scrollCareerPage("destinationScroll", to: "buyToyButton", in: app)
        XCTAssertTrue(element("buyToyButton", in: app).isHittable)
        scrollCareerPage("destinationScroll", to: "shopPageNext", in: app)
        waitForObservedValue("shopPageSummary", "3/3", in: app)
        XCTAssertFalse(element("shopPageNext", in: app).isEnabled)
        attachScreenshot(app, named: "Shop browser — English largest text bounded last page")
        selectBrowseFilter("standard", in: app)
        scrollCareerPage("destinationScroll", to: "shopPageNext", in: app)
        waitForObservedValue("shopPageSummary", "1/2", in: app)
        tapAnimationControl("shopPageNext", in: app)
        scrollCareerPage("destinationScroll", to: "shopCategory_equipment", in: app)
        tapAnimationControl("shopCategory_equipment", in: app)
        scrollCareerPage("destinationScroll", to: "shopPageNext", in: app)
        waitForObservedValue("shopPageSummary", "1/2", in: app)
        tapAnimationControl("shopPageNext", in: app)
        scrollCareerPage("destinationScroll", to: "shopQuickBuy_advanced_sneakers", in: app)
        XCTAssertTrue(element("shopQuickBuy_advanced_sneakers", in: app).isHittable)
    }

    @MainActor
    private func selectBrowseFilter(_ filter: String, in app: XCUIApplication) {
        scrollCareerPage("destinationScroll", to: "shopBrowseFilters", in: app)
        let target = element("shopFilter_\(filter)", in: app)
        for _ in 0..<4 {
            if app.frame.contains(target.frame) && target.isHittable { break }
            element("shopBrowseFilters", in: app).swipeLeft()
        }
        XCTAssertTrue(target.isHittable)
        target.tap()
    }
}
