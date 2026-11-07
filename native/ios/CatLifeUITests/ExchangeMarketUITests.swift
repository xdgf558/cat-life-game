import XCTest

extension RoomHomeUITests {
    @MainActor
    func testExchangePreviewCancelSaveAndRelaunchKeepSupplies() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--community-fixture"]
        launchAndEnterHome(app)
        openExchangeMarket(in: app)
        waitForObservedValue("marketPage", "1/2", in: app)
        scrollCareerPage("exchangeMarketScroll", to: "marketOffer_mira_feast", in: app)
        tapAnimationControl("marketOffer_mira_feast", in: app)
        waitForObservedValue("neighborFriendshipValue", "18", in: app)
        XCTAssertFalse(element("marketConfirmation", in: app).exists,
                       "A friendship-locked offer takes the player to that neighbor, without opening an unusable confirmation.")
        attachScreenshot(app, named: "Market — locked offer opens its neighbor")
        tapAnimationControl("neighborBackButton", in: app)

        scrollCareerPage("exchangeMarketScroll", to: "marketOffer_mira_food", in: app)
        tapAnimationControl("marketOffer_mira_food", in: app)
        waitForObservedValue("marketStock_food", "3", in: app)
        waitForObservedValue("marketBagAfter_food", "1", in: app)
        waitForObservedValue("marketStock_premiumFood", "0", in: app)
        waitForObservedValue("marketBagAfter_premiumFood", "1", in: app)
        scrollPage("marketConfirmation", to: "marketFriendshipPreview", allowDisabled: false, maximumDrags: 6, in: app)
        waitForObservedValue("marketFriendshipPreview", "18:20", in: app)
        tapAnimationControl("marketCancelButton", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("foodCount", "3", in: app)

        openExchangeMarket(in: app)
        scrollCareerPage("exchangeMarketScroll", to: "marketOffer_mira_food", in: app)
        tapAnimationControl("marketOffer_mira_food", in: app)
        attachScreenshot(app, named: "Market — give and receive before confirming")
        tapAnimationControl("marketConfirmButton", in: app)
        waitForObservedValue("communityStageSuccess", "neighbor_mira:2", in: app)
        waitForObservedValue("communityStageRewards", "20:1:0:0", in: app)
        waitForObservedValue("marketReceived_premiumFood", "1", in: app)
        waitForObservedValue("marketResultFriendship", "2:20", in: app)
        attachScreenshot(app, named: "Market — stage reward excludes traded supplies")
        tapAnimationControl("marketResultContinue", in: app)
        XCTAssertTrue(element("marketResult", in: app).waitForNonExistence(timeout: 5))
        waitForElement("exchangeMarketScroll", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("foodCount", "3", in: app) // Two basic servings (including stage reward) plus one premium serving.
        waitForObservedValue("goldCount", "5,020", in: app)
        relaunchPreservingSave(app)
        waitForObservedValue("foodCount", "3", in: app)
        openExchangeMarket(in: app)
        scrollCareerPage("exchangeMarketScroll", to: "marketOffer_mira_food", in: app)
        tapAnimationControl("marketOffer_mira_food", in: app)
        waitForObservedValue("marketStock_food", "2", in: app)
        waitForObservedValue("marketRemaining", "1/2", in: app)
        XCTAssertTrue(element("marketConfirmButton", in: app).isEnabled)
        tapAnimationControl("marketCancelButton", in: app)
        tapAnimationControl("marketBackButton", in: app)
        tapAnimationControl("townPlot_street", in: app)
        scrollCareerPage("townMapScroll", to: "townEnter_street", in: app)
        tapAnimationControl("townEnter_street", in: app)
        tapAnimationControl("neighborCard_neighbor_mira", in: app)
        scrollCareerPage("neighborDetail_neighbor_mira", to: "neighborExchangeButton", in: app)
        tapAnimationControl("neighborExchangeButton", in: app)
        waitForElement("exchangeMarketScroll", in: app)
        XCTAssertFalse(element("marketPage", in: app).exists, "The neighbor entry opens their two offers directly.")
        scrollCareerPage("exchangeMarketScroll", to: "marketOffer_mira_food", in: app)
        XCTAssertTrue(element("marketOffer_mira_food", in: app).exists)
        tapAnimationControl("marketOffer_mira_food", in: app)
        tapAnimationControl("marketConfirmButton", in: app)
        waitForElement("marketResult", in: app)
        waitForObservedValue("marketResultFriendship", "2:22", in: app)
        XCTAssertFalse(element("communityStageSuccess", in: app).exists, "The same stage must not be celebrated twice.")
        tapAnimationControl("marketResultContinue", in: app)
        XCTAssertFalse(element("marketOffer_mira_food", in: app).isEnabled,
                       "The neighbor's two daily exchanges are exhausted even across the two market entry paths.")
        tapAnimationControl("marketBagButton", in: app)
        waitForObservedValue("inventoryPremiumFoodCount", "2", in: app)
        waitForObservedValue("inventoryFoodCount", "0", in: app)
    }

    @MainActor
    func testMarketNeighborNavigationCannotBuildAReturnLoop() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--community-fixture"]
        launchAndEnterHome(app)
        openExchangeMarket(in: app)
        scrollCareerPage("exchangeMarketScroll", to: "marketOffer_mira_feast", in: app)
        tapAnimationControl("marketOffer_mira_feast", in: app)
        waitForElement("neighborDetail_neighbor_mira", in: app)
        XCTAssertFalse(element("neighborExchangeButton", in: app).exists,
                       "A neighbor reached from the market must not push another market.")
        tapAnimationControl("neighborBackButton", in: app)
        waitForElement("exchangeMarketScroll", in: app)
        tapAnimationControl("marketBackButton", in: app)
        waitForElement("townMapScroll", in: app)

        tapAnimationControl("townPlot_street", in: app)
        scrollCareerPage("townMapScroll", to: "townEnter_street", in: app)
        tapAnimationControl("townEnter_street", in: app)
        tapAnimationControl("neighborCard_neighbor_mira", in: app)
        scrollCareerPage("neighborDetail_neighbor_mira", to: "neighborExchangeButton", in: app)
        tapAnimationControl("neighborExchangeButton", in: app)
        waitForElement("exchangeMarketScroll", in: app)
        scrollCareerPage("exchangeMarketScroll", to: "marketOffer_mira_feast", in: app)
        tapAnimationControl("marketOffer_mira_feast", in: app)
        waitForElement("neighborDetail_neighbor_mira", in: app)
        XCTAssertFalse(element("neighborExchangeButton", in: app).exists,
                       "The market entered from a neighbor must also terminate the forward navigation chain.")
        tapAnimationControl("neighborBackButton", in: app)
        waitForElement("exchangeMarketScroll", in: app)
        tapAnimationControl("marketBackButton", in: app)
        scrollCareerPage("neighborDetail_neighbor_mira", to: "neighborExchangeButton", in: app)
        XCTAssertTrue(element("neighborExchangeButton", in: app).isHittable,
                      "Returning restores the original neighbor's exchange entry.")
        tapAnimationControl("neighborBackButton", in: app)
        waitForElement("communityDirectory", in: app)
        tapAnimationControl("communityBackButton", in: app)
        waitForElement("townMapScroll", in: app)
        attachScreenshot(app, named: "Market — both entry paths return to town without a navigation loop")
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", "5,000", in: app)
        waitForObservedValue("foodCount", "3", in: app)
    }

    @MainActor
    func testExchangeFiltersPaginationLanguagesAndLargeType() throws {
        verifyExchangeLanguagesAtLargestType(["zh-Hans", "zh-Hant", "en"])
    }

    @MainActor
    func testExchangeEnglishAtLargestType() throws {
        verifyExchangeLanguagesAtLargestType(["en"])
    }

    @MainActor
    private func verifyExchangeLanguagesAtLargestType(_ languages: [String]) {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--community-fixture",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        launchAndEnterHome(app)
        for language in languages {
            if language != "zh-Hans" { selectCatTestLanguage(language, in: app) }
            openExchangeMarket(in: app)
            waitForObservedValue("marketPage", "1/4", in: app)
            for page in 2...4 {
                tapAnimationControl("marketNextPage", in: app)
                waitForObservedValue("marketPage", "\(page)/4", in: app)
            }
            // The longest English AX page is 2,615 pt in a 362 pt viewport;
            // allow its full travel without changing visibility or hit testing.
            scrollPage("exchangeMarketScroll", to: "marketOffer_grace_care", allowDisabled: true,
                       maximumDrags: 14, in: app)
            XCTAssertTrue(element("marketOffer_grace_care", in: app).isHittable)
            attachScreenshot(app, named: "Market — two offers per page at accessibility size \(language)")
            for page in stride(from: 3, through: 1, by: -1) {
                tapAnimationControl("marketPreviousPage", in: app)
                waitForObservedValue("marketPage", "\(page)/4", in: app)
            }
            scrollCareerPage("exchangeMarketScroll", to: "marketFilters", in: app)
            let filters = element("marketFilters", in: app)
            let mira = element("marketFilter_neighbor_mira", in: app)
            for _ in 0..<8 {
                let viewport = filters.frame.intersection(app.frame)
                let target = mira.frame
                if viewport.contains(target) && mira.isHittable { break }
                let movingLeft = target.maxX > viewport.maxX
                let overflow = movingLeft ? target.maxX - viewport.maxX : viewport.minX - target.minX
                let distance = min(0.6, max(0.1, (overflow + 12) / max(1, viewport.width)))
                let start: CGFloat = movingLeft ? 0.85 : 0.15
                filters.coordinate(withNormalizedOffset: CGVector(dx: start, dy: 0.5))
                    .press(forDuration: 0.05,
                           thenDragTo: filters.coordinate(withNormalizedOffset: CGVector(dx: start + (movingLeft ? -distance : distance), dy: 0.5)),
                           withVelocity: .slow, thenHoldForDuration: 0.15)
            }
            XCTAssertTrue(filters.frame.intersection(app.frame).contains(mira.frame),
                          "Scroll the horizontal neighbor list until the complete avatar/name/count chip is visible.")
            XCTAssertTrue(mira.isHittable, "The fully visible neighbor filter must also accept a tap.")
            tapAnimationControl("marketFilter_neighbor_mira", in: app)
            XCTAssertFalse(element("marketPage", in: app).exists)
            scrollCareerPage("exchangeMarketScroll", to: "marketOffer_mira_food", in: app)
            tapAnimationControl("marketOffer_mira_food", in: app)
            waitForElement("marketConfirmButton", in: app)
            XCTAssertFalse(element("marketConfirmButton", in: app).label.contains("market."))
            XCTAssertTrue(element("marketConfirmButton", in: app).isHittable)
            XCTAssertLessThan(element("marketConfirmationBar", in: app).frame.height, app.frame.height * 0.3,
                              "Fixed actions must leave space to read the trade at the largest text size.")
            attachScreenshot(app, named: "Market — translated confirmation \(language)")
            tapAnimationControl("marketCancelButton", in: app)
            tapAnimationControl("tabHome", in: app)
            waitForObservedValue("foodCount", "3", in: app)
        }
    }

    @MainActor
    func testExchangeSaveFailureReportsImmediatelyWithoutUsingSupplies() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--community-fixture", "--save-outage-test"]
        launchAndEnterHome(app)
        openExchangeMarket(in: app)
        scrollCareerPage("exchangeMarketScroll", to: "marketOffer_mira_food", in: app)
        tapAnimationControl("marketOffer_mira_food", in: app)
        tapAnimationControl("marketConfirmButton", in: app)
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 8))
        waitForObservedValue("marketStock_food", "3", in: app)
        XCTAssertFalse(element("marketResult", in: app).exists)
        attachScreenshot(app, named: "Market — failed save keeps original supplies")
        app.alerts.firstMatch.buttons["完成"].tap()
        waitForElement("marketFailure", in: app)
        waitForElement("marketConfirmation", in: app)
        waitForElement("saveStatusRetryButton", in: app)
        waitForObservedValue("marketRemaining", "2/2", in: app)
        tapAnimationControl("marketCancelButton", in: app)
        waitForElement("exchangeMarketScroll", in: app)
    }

    @MainActor
    func testExchangeMissingGiftOpensRestockAndResultCanOpenBag() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--community-fixture"]
        launchAndEnterHome(app)
        openExchangeMarket(in: app)
        tapAnimationControl("marketNextPage", in: app)
        scrollCareerPage("exchangeMarketScroll", to: "marketOffer_grace_pantry", in: app)
        tapAnimationControl("marketOffer_grace_pantry", in: app)
        waitForElement("communityGiftShelf", in: app)
        waitForObservedValue("communityGiftStock_cat_snack", "0", in: app)
        scrollCareerPage("communityGiftShelf", to: "buyCommunityGift_cat_snack", in: app)
        tapAnimationControl("buyCommunityGift_cat_snack", in: app)
        waitForObservedValue("communityGiftStock_cat_snack", "1", in: app)
        tapAnimationControl("communityGiftCloseButton", in: app)
        waitForObservedValue("marketPage", "2/2", in: app)
        scrollCareerPage("exchangeMarketScroll", to: "marketOffer_grace_pantry", in: app)
        tapAnimationControl("marketOffer_grace_pantry", in: app)
        waitForObservedValue("marketStock_cat_snack", "1", in: app)
        waitForObservedValue("marketBagAfter_cat_snack", "0", in: app)
        waitForObservedValue("marketBagAfter_food", "5", in: app)
        tapAnimationControl("marketConfirmButton", in: app)
        waitForObservedValue("marketReceived_food", "2", in: app)
        waitForObservedValue("marketResultFriendship", "2:2", in: app)
        XCTAssertFalse(element("communityStageSuccess", in: app).exists)
        tapAnimationControl("marketResultBag", in: app)
        waitForObservedValue("inventoryFoodCount", "5", in: app)
    }

    @MainActor
    private func openExchangeMarket(in app: XCUIApplication) {
        tapAnimationControl("tabTown", in: app)
        tapAnimationControl("townPlot_market", in: app)
        scrollCareerPage("townMapScroll", to: "townEnter_market", in: app)
        tapAnimationControl("townEnter_market", in: app)
        waitForElement("exchangeMarketScroll", in: app)
    }
}
