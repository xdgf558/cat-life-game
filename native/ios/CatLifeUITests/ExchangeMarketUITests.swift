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
        waitForElement("marketConfirmation", in: app)
        XCTAssertFalse(element("marketConfirmButton", in: app).isEnabled)
        attachScreenshot(app, named: "Market — advanced trade shows friendship lock")
        tapAnimationControl("marketCancelButton", in: app)

        scrollCareerPage("exchangeMarketScroll", to: "marketOffer_mira_food", in: app)
        tapAnimationControl("marketOffer_mira_food", in: app)
        waitForObservedValue("marketStock_food", "3", in: app)
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
        XCTAssertTrue(element("communityStageCompletionMessage", in: app).label.contains("+2"))
        attachScreenshot(app, named: "Market — stage reward excludes traded supplies")
        scrollPage("communityStageSuccessScroll", to: "communityStageSuccessDoneButton", allowDisabled: false, maximumDrags: 6, in: app)
        tapAnimationControl("communityStageSuccessDoneButton", in: app)
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
        waitForElement("exchangeMarketScroll", in: app)
        XCTAssertFalse(element("communityStageSuccess", in: app).exists, "The same stage must not be celebrated twice.")
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
            if !filters.frame.contains(mira.frame) {
                filters.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
                    .press(forDuration: 0.05,
                           thenDragTo: filters.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.5)),
                           withVelocity: .slow, thenHoldForDuration: 0.15)
            }
            XCTAssertTrue(filters.frame.contains(mira.frame), "Scroll the horizontal neighbor list before selecting its clipped chip.")
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
        attachScreenshot(app, named: "Market — failed save keeps original supplies")
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
