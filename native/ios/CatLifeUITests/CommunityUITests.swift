import XCTest

extension RoomHomeUITests {
    @MainActor
    func testNeighborVisitGiftRestockAndRelaunchKeepOneReward() throws {
        continueAfterFailure = false
        let app = launchCommunityFixture()
        openNeighbors(in: app)
        attachScreenshot(app, named: "Neighbors — four character cards")
        tapAnimationControl("neighborCard_neighbor_mira", in: app)
        waitForObservedValue("neighborFriendshipValue", "18", in: app)
        scrollCareerPage("neighborDetail_neighbor_mira", to: "neighborVisitButton", in: app)
        tapAnimationControl("neighborVisitButton", in: app)
        waitForElement("communityStageSuccess", in: app)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "拜访完成")).firstMatch.exists,
                       "The visible celebration must not also produce a visit toast.")
        attachScreenshot(app, named: "Neighbors — stage reward appears after the visit is saved")
        tapAnimationControl("communityStageSuccessDoneButton", in: app)
        waitForObservedValue("neighborFriendshipValue", "20", in: app)
        scrollCareerPage("neighborDetail_neighbor_mira", to: "neighborRewardsDisclosure", in: app)
        tapAnimationControl("neighborRewardsDisclosure", in: app)
        element("neighborDetail_neighbor_mira", in: app).swipeUp()
        tapAnimationControl("neighborVisitButton", in: app)
        waitForObservedValue("neighborFriendshipValue", "20", in: app)
        XCTAssertFalse(element("communityStageSuccess", in: app).exists)
        let visibleDialogue = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let dialogue = self.element("neighborDialogue", in: app)
            return dialogue.exists && dialogue.isHittable
                && self.unobscuredScrollViewport(self.element("neighborDetail_neighbor_mira", in: app), in: app).contains(dialogue.frame)
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [visibleDialogue], timeout: 8), .completed,
                       "A normal result must scroll into view even after browsing the rewards.")
        scrollCareerPage("neighborDetail_neighbor_mira", to: "neighborGiftButton", in: app)
        tapAnimationControl("neighborGiftButton", in: app)
        waitForObservedValue("communityGiftStock_flower", "2", in: app)
        attachScreenshot(app, named: "Neighbors — favorite gifts and daily limit")
        scrollCareerPage("communityGiftShelf", to: "selectCommunityGift_flower", in: app)
        tapAnimationControl("selectCommunityGift_flower", in: app)
        tapAnimationControl("confirmCommunityGiftButton", in: app)
        waitForElement("neighborDetail_neighbor_mira", in: app)
        waitForObservedValue("neighborFriendshipValue", "28", in: app)
        scrollCareerPage("neighborDetail_neighbor_mira", to: "neighborGiftButton", in: app)
        waitForLabel("neighborGiftButton", "今天已送礼", in: app, contains: true)
        scrollCareerPage("neighborDetail_neighbor_mira", to: "neighborRewardsDisclosure", in: app)
        tapAnimationControl("neighborRewardsDisclosure", in: app)
        attachScreenshot(app, named: "Neighbors — relationship reward recorded once")
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", "5,020", in: app)
        waitForObservedValue("foodCount", "4", in: app)

        tapAnimationControl("tabShop", in: app)
        tapAnimationControl("communityGiftEntry", in: app)
        waitForObservedValue("communityGiftStock_flower", "1", in: app)
        scrollCareerPage("communityGiftShelf", to: "buyCommunityGift_flower", in: app)
        tapAnimationControl("buyCommunityGift_flower", in: app)
        waitForObservedValue("communityGiftStock_flower", "2", in: app)
        waitForObservedValue("communityGiftBalance", "5,000", in: app)
        tapAnimationControl("tabHome", in: app)
        relaunchPreservingSave(app)
        waitForObservedValue("goldCount", "5,000", in: app)
        waitForObservedValue("foodCount", "4", in: app)
        openNeighbors(in: app)
        tapAnimationControl("neighborCard_neighbor_mira", in: app)
        waitForObservedValue("neighborFriendshipValue", "28", in: app)
        scrollCareerPage("neighborDetail_neighbor_mira", to: "neighborVisitButton", in: app)
        tapAnimationControl("neighborVisitButton", in: app)
        waitForObservedValue("neighborFriendshipValue", "28", in: app)
    }

    @MainActor
    func testNeighborsLocalizeAndGiftFailureStaysVisible() throws {
        continueAfterFailure = false
        let app = launchCommunityFixture()
        for (code, name) in [("zh-Hans", "米拉"), ("zh-Hant", "米拉"), ("en", "Mira")] {
            if code != "zh-Hans" { selectCatTestLanguage(code, in: app) }
            openNeighbors(in: app)
            waitForLabel("neighborCard_neighbor_mira", name, in: app, contains: true)
            tapAnimationControl("neighborCard_neighbor_mira", in: app)
            scrollCareerPage("neighborDetail_neighbor_mira", to: "neighborGiftButton", in: app)
            tapAnimationControl("neighborGiftButton", in: app)
            waitForElement("communityGiftShelf", in: app)
            XCTAssertFalse(element("communityGiftShelf", in: app).label.contains("community.gift"))
            attachScreenshot(app, named: "Neighbors — gift shelf \(code)")
            tapAnimationControl("communityGiftCloseButton", in: app)
            tapAnimationControl("tabHome", in: app)
        }
        app.terminate()
        app.launchArguments = arguments(reset: true) + ["--community-fixture", "--save-outage-test"]
        launchAndEnterHome(app)
        openNeighbors(in: app)
        tapAnimationControl("neighborCard_neighbor_mira", in: app)
        scrollCareerPage("neighborDetail_neighbor_mira", to: "neighborGiftButton", in: app)
        tapAnimationControl("neighborGiftButton", in: app)
        scrollCareerPage("communityGiftShelf", to: "selectCommunityGift_flower", in: app)
        tapAnimationControl("selectCommunityGift_flower", in: app)
        tapAnimationControl("confirmCommunityGiftButton", in: app)
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 8))
        attachScreenshot(app, named: "Neighbors — gift save failure is visible immediately")
        waitForObservedValue("communityGiftStock_flower", "2", in: app)
    }

    @MainActor
    func testBothNewCatsAdoptAtQuotedPricesAndPersistSelectedCompanion() throws {
        continueAfterFailure = false
        let app = launchCommunityFixture()
        for (id, name, gold) in [("cat_004", "可可", "4,100"), ("cat_005", "霜糖", "2,900")] {
            openTownCollection(in: app)
            tapAnimationControl("catFilter_unowned", in: app)
            scrollCareerPage("catCollectionScroll", to: "catAdoption_\(id)", in: app)
            tapAnimationControl("catAdoption_\(id)", in: app)
            waitForObservedValue("catAdoptionConditionsMet", "3/3", in: app)
            attachScreenshot(app, named: "New cats — \(id) adoption details")
            scrollCareerPage("catAdoptionScroll", to: "catAdoptionButton", in: app)
            tapAnimationControl("catAdoptionButton", in: app)
            scrollCareerPage("catAdoptionConfirmation", to: "catAdoptionConfirmButton", in: app)
            tapAnimationControl("catAdoptionConfirmButton", in: app)
            waitForObservedValue("catAdoptionSuccess", id, in: app)
            tapAnimationControl("catAdoptionBringHomeButton", in: app)
            waitForObservedValue("homeCatName", name, in: app)
            waitForObservedValue("goldCount", gold, in: app)
            attachScreenshot(app, named: "New cats — \(id) home companion")
        }
        relaunchPreservingSave(app)
        waitForObservedValue("homeCatName", "霜糖", in: app)
        waitForObservedValue("goldCount", "2,900", in: app)
        openTownCollection(in: app)
        waitForObservedValue("catCollectionProgress", "3/5", in: app)
    }

    @MainActor
    func testNeighborPagesSupportAccessibilityTextSize() throws {
        continueAfterFailure = false
        let app = launchCommunityFixture(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        openNeighbors(in: app)
        scrollCareerPage("communityDirectory", to: "neighborCard_neighbor_mira", in: app)
        tapAnimationControl("neighborCard_neighbor_mira", in: app)
        scrollCareerPage("neighborDetail_neighbor_mira", to: "neighborGiftButton", in: app)
        tapAnimationControl("neighborGiftButton", in: app)
        scrollCareerPage("communityGiftShelf", to: "selectCommunityGift_flower", in: app)
        tapAnimationControl("selectCommunityGift_flower", in: app)
        let confirm = element("confirmCommunityGiftButton", in: app)
        XCTAssertTrue(confirm.isHittable && app.frame.contains(confirm.frame))
        attachScreenshot(app, named: "Neighbors — accessible gift selection and fixed confirmation")
        tapAnimationControl("communityGiftCloseButton", in: app)
        tapAnimationControl("neighborBackButton", in: app)
        scrollCareerPage("communityDirectory", to: "communityGiftEntry", in: app)
        tapAnimationControl("communityGiftEntry", in: app)
        scrollCareerPage("communityGiftShelf", to: "buyCommunityGift_flower", in: app)
        XCTAssertTrue(element("buyCommunityGift_flower", in: app).isHittable)
        attachScreenshot(app, named: "Neighbors — accessible restocking and favorite neighbors")
    }

    @MainActor
    func testCommunityGiftSelectionCancellationAndEmptyStockRestockNeverAutoGive() throws {
        continueAfterFailure = false
        let app = launchCommunityFixture()
        openNeighbors(in: app)
        tapAnimationControl("neighborCard_neighbor_mira", in: app)
        tapAnimationControl("neighborGiftButton", in: app)
        waitForObservedValue("communityGiftStock_flower", "2", in: app)
        XCTAssertFalse(element("confirmCommunityGiftButton", in: app).isEnabled)
        scrollCareerPage("communityGiftShelf", to: "selectCommunityGift_flower", in: app)
        tapAnimationControl("selectCommunityGift_flower", in: app)
        XCTAssertTrue(element("confirmCommunityGiftButton", in: app).isEnabled)
        tapAnimationControl("communityGiftCloseButton", in: app)
        waitForObservedValue("neighborFriendshipValue", "18", in: app)
        tapAnimationControl("neighborGiftButton", in: app)
        waitForObservedValue("communityGiftStock_flower", "2", in: app)
        XCTAssertFalse(element("confirmCommunityGiftButton", in: app).isEnabled,
                       "Reopening the picker must require an explicit new selection.")
        scrollCareerPage("communityGiftShelf", to: "restockCommunityGift_dessert", in: app)
        tapAnimationControl("restockCommunityGift_dessert", in: app)
        scrollCareerPage("communityGiftShelf", to: "buyCommunityGift_dessert", in: app)
        waitForObservedValue("communityGiftStock_dessert", "0", in: app)
        tapAnimationControl("buyCommunityGift_dessert", in: app)
        waitForObservedValue("communityGiftStock_dessert", "1", in: app)
        waitForObservedValue("communityGiftBalance", "4,970", in: app)
        attachScreenshot(app, named: "Neighbors — restock buys one gift without giving it")
        tapAnimationControl("communityGiftRestockBackButton", in: app)
        scrollCareerPage("communityGiftShelf", to: "selectCommunityGift_dessert", in: app)
        waitForObservedValue("communityGiftStock_dessert", "1", in: app)
        XCTAssertFalse(element("confirmCommunityGiftButton", in: app).isEnabled)
        tapAnimationControl("selectCommunityGift_dessert", in: app)
        tapAnimationControl("communityGiftCloseButton", in: app)
        waitForObservedValue("neighborFriendshipValue", "18", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", "4,970", in: app)
        waitForObservedValue("foodCount", "3", in: app)
        relaunchPreservingSave(app)
        openNeighbors(in: app)
        tapAnimationControl("neighborCard_neighbor_mira", in: app)
        waitForObservedValue("neighborFriendshipValue", "18", in: app)
        tapAnimationControl("neighborGiftButton", in: app)
        scrollCareerPage("communityGiftShelf", to: "selectCommunityGift_dessert", in: app)
        waitForObservedValue("communityGiftStock_dessert", "1", in: app)
        waitForObservedValue("communityGiftStock_flower", "2", in: app)
    }

    @MainActor
    func testFiveCoatCollectionAndSecondPageReadyCompanionAreReachable() throws {
        continueAfterFailure = false
        let app = launchCommunityFixture()
        openTownCollection(in: app)
        waitForObservedValue("catCollectionProgress", "1/5", in: app)
        for appearance in ["orange", "cow", "blue", "siamese", "silver"] {
            waitForElement("catCollectionCoat_\(appearance)", in: app)
        }
        scrollCareerPage("catCollectionScroll", to: "catPageNext", in: app)
        waitForObservedValue("catPageSummary", "1/2", in: app)
        tapAnimationControl("catPageNext", in: app)
        waitForObservedValue("catPageSummary", "2/2", in: app)
        waitForLabel("catAdoption_cat_005", "可以领养", in: app, contains: true)
        XCTAssertFalse(element("catAdoption_cat_005", in: app).label.contains("新伙伴"),
                       "A ready cat's adoption status must take priority over its new-companion promotion.")
        XCTAssertFalse(element("catPageNext", in: app).isEnabled)
        attachScreenshot(app, named: "Collection — silver companion on the second page")
        tapAnimationControl("catAdoption_cat_005", in: app)
        waitForLabel("catAdoptionBadge", "可以领养", in: app)
        waitForObservedValue("catAdoptionConditionsMet", "3/3", in: app)
        attachScreenshot(app, named: "Collection — silver coat color and live adoption requirements")
        tapAnimationControl("catAdoptionBackButton", in: app)
        tapAnimationControl("catFilter_unowned", in: app)
        XCTAssertFalse(element("catPageSummary", in: app).exists,
                       "Four unowned cats fit one page without redundant pagination.")
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", "5,000", in: app)
    }

    @MainActor
    private func launchCommunityFixture(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--community-fixture"] + extra
        launchAndEnterHome(app)
        return app
    }

    @MainActor
    private func openNeighbors(in app: XCUIApplication) {
        tapAnimationControl("tabTown", in: app)
        scrollCareerPage("townMapScroll", to: "townPlot_street", in: app)
        tapAnimationControl("townPlot_street", in: app)
        scrollCareerPage("townMapScroll", to: "townEnter_street", in: app)
        tapAnimationControl("townEnter_street", in: app)
        waitForElement("communityDirectory", in: app)
        XCTAssertFalse(element("adoptionAvailableNotice", in: app).exists,
                       "Adoption reminders must leave the neighbor header and return control unobscured.")
    }
}
