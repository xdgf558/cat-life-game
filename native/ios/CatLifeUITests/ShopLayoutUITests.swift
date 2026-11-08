import XCTest

extension RoomHomeUITests {
    @MainActor
    func testEnglishLargeShopButtonsAlignMixedPriceAndLevelLockWithoutLosingAccessibleLabel() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--shop-layout-fixture", "--shop-layout-level2",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXXXL"]
        launchAndEnterHome(app)
        selectCatTestLanguage("en", in: app)
        tapAnimationControl("tabShop", in: app)
        selectShopLayoutCategory("equipment", in: app)
        assertAlignedShopPurchases("advanced_cap", "advanced_jacket", in: app)
        XCTAssertTrue(element("shopQuickBuy_advanced_cap", in: app).isEnabled)
        XCTAssertFalse(element("shopQuickBuy_advanced_jacket", in: app).isEnabled)
        waitForLabel("shopQuickBuy_advanced_jacket", "Unlock at Lv 3", in: app, contains: true)
        attachScreenshot(app, named: "Shop 57 — English largest standard text aligns price and level lock")
    }

    @MainActor
    func testShopCardPurchaseRowsStayAlignedAcrossDescriptionsOwnershipAndBalance() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--shop-layout-fixture"]
        launchAndEnterHome(app)
        tapAnimationControl("tabShop", in: app)
        selectShopLayoutCategory("equipment", in: app)
        assertAlignedShopPurchases("advanced_cap", "advanced_jacket", in: app)
        XCTAssertTrue(element("shopQuickBuy_advanced_cap", in: app).isEnabled)
        XCTAssertFalse(element("shopQuickBuy_advanced_jacket", in: app).isEnabled)
        assertAlignedShopPurchases("advanced_sneakers", "advanced_charm", in: app)
        attachScreenshot(app, named: "Shop 57 — compact equipment, mixed available and insufficient gold")

        selectShopLayoutCategory("furniture", in: app)
        assertAlignedShopPurchases("round_side_table", "sunrise_art", in: app)
        attachScreenshot(app, named: "Shop 57 — aligned furniture with different description lengths")
        assertAlignedShopPurchases("potted_plant", "cozy_cushion", in: app)
        attachScreenshot(app, named: "Shop 57 — owned furniture badge does not move the price button")
        scrollCareerPage("destinationScroll", to: "shopItem_potted_plant", in: app)
        tapAnimationControl("shopItem_potted_plant", in: app)
        waitForObservedValue("shopOwned_potted_plant", "1", in: app)
        tapAnimationControl("shopDetailBackButton", in: app)
        scrollCareerPage("destinationScroll", to: "shopItem_round_side_table", in: app)
        tapAnimationControl("shopItem_round_side_table", in: app)
        XCTAssertTrue(app.staticTexts["小巧的木边桌，圆润边角和下层书架让角落更温馨。可左右转向。"].waitForExistence(timeout: 8),
                      "Compact summaries must retain the complete description in product details.")
        tapAnimationControl("shopDetailBackButton", in: app)

        selectShopLayoutCategory("equipment", in: app)
        scrollCareerPage("destinationScroll", to: "shopQuickBuy_advanced_cap", in: app)
        tapAnimationControl("shopQuickBuy_advanced_cap", in: app)
        waitForObservedValue("shopGoldCount", "95", in: app)
        XCTAssertFalse(element("shopDetailScroll", in: app).exists, "Quick buy must remain a one-tap purchase.")
        assertAlignedShopPurchases("advanced_cap", "advanced_jacket", in: app)
        XCTAssertFalse(element("shopQuickBuy_advanced_cap", in: app).isEnabled)
        waitForLabel("shopQuickBuy_advanced_cap", "已拥有", in: app, contains: true)
        attachScreenshot(app, named: "Shop 57 — prices stay aligned after equipment ownership changes")
        relaunchPreservingSave(app)
        tapAnimationControl("tabShop", in: app)
        selectShopLayoutCategory("equipment", in: app)
        waitForObservedValue("shopGoldCount", "95", in: app)
        XCTAssertFalse(element("shopQuickBuy_advanced_cap", in: app).isEnabled)
    }

    @MainActor
    func testShopCardsSupportTraditionalChineseLocksAndEnglishAccessibilityText() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true)
        launchAndEnterHome(app)
        selectCatTestLanguage("zh-Hant", in: app)
        tapAnimationControl("tabShop", in: app)
        selectShopLayoutCategory("equipment", in: app)
        assertAlignedShopPurchases("advanced_cap", "advanced_jacket", in: app)
        XCTAssertFalse(element("shopQuickBuy_advanced_cap", in: app).isEnabled)
        XCTAssertFalse(element("shopQuickBuy_advanced_jacket", in: app).isEnabled)
        attachScreenshot(app, named: "Shop 57 — Traditional Chinese level-locked cards")
        selectShopLayoutCategory("furniture", in: app)
        assertAlignedShopPurchases("round_side_table", "sunrise_art", in: app)

        app.terminate()
        app.launchArguments = arguments(reset: true) + ["--shop-layout-fixture",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        launchAndEnterHome(app)
        selectCatTestLanguage("en", in: app)
        tapAnimationControl("tabShop", in: app)
        selectShopLayoutCategory("equipment", in: app)
        assertAccessibleShopPurchase("advanced_cap", in: app)
        attachScreenshot(app, named: "Shop 57 — English largest text keeps full-width equipment purchase")
        tapAnimationControl("shopQuickBuy_advanced_cap", in: app)
        waitForObservedValue("shopGoldCount", "95", in: app)
        assertAccessibleShopPurchase("advanced_jacket", in: app)
        XCTAssertFalse(element("shopQuickBuy_advanced_jacket", in: app).isEnabled)
        selectShopLayoutCategory("furniture", in: app)
        scrollCareerPage("destinationScroll", to: "shopPageNext", in: app)
        tapAnimationControl("shopPageNext", in: app)
        assertAccessibleShopPurchase("round_side_table", in: app)
        attachScreenshot(app, named: "Shop 57 — English largest text furniture remains scrollable")
    }

    @MainActor
    private func selectShopLayoutCategory(_ category: String, in app: XCUIApplication) {
        let identifier = "shopCategory_\(category)"
        scrollCareerPage("destinationScroll", to: identifier, in: app)
        tapAnimationControl(identifier, in: app)
    }

    @MainActor
    private func assertAlignedShopPurchases(_ left: String, _ right: String, in app: XCUIApplication,
                                           file: StaticString = #filePath, line: UInt = #line) {
        let leftID = "shopQuickBuy_\(left)"
        let rightID = "shopQuickBuy_\(right)"
        scrollCareerPage("destinationScroll", to: leftID, in: app, file: file, line: line)
        waitForElement(rightID, in: app, file: file, line: line)
        let lhs = element(leftID, in: app).frame
        let rhs = element(rightID, in: app).frame
        XCTAssertEqual(lhs.minY, rhs.minY, accuracy: 1, "The same row must share a purchase baseline.", file: file, line: line)
        XCTAssertEqual(lhs.maxY, rhs.maxY, accuracy: 1, file: file, line: line)
        XCTAssertEqual(lhs.width, rhs.width, accuracy: 1, file: file, line: line)
        XCTAssertGreaterThanOrEqual(lhs.height, 44, file: file, line: line)
        XCTAssertLessThan(lhs.maxX, rhs.minX, file: file, line: line)
        XCTAssertTrue(app.frame.contains(lhs) && app.frame.contains(rhs), file: file, line: line)
    }

    @MainActor
    private func assertAccessibleShopPurchase(_ product: String, in app: XCUIApplication,
                                             file: StaticString = #filePath, line: UInt = #line) {
        let identifier = "shopQuickBuy_\(product)"
        scrollCareerPage("destinationScroll", to: identifier, in: app, file: file, line: line)
        let button = element(identifier, in: app)
        XCTAssertTrue(button.isHittable, file: file, line: line)
        XCTAssertTrue(app.frame.contains(button.frame), file: file, line: line)
        XCTAssertGreaterThan(button.frame.width, app.frame.width * 0.65,
                             "Accessibility sizes should give each product its own row.", file: file, line: line)
        XCTAssertGreaterThanOrEqual(button.frame.height, 44, file: file, line: line)
    }
}
