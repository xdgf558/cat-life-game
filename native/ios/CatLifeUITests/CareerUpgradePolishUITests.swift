import XCTest

extension RoomHomeUITests {
    @MainActor
    func testSelectedNewCareersKeepNewBadgesWithoutStartingWorkOrResizingCards() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--career-level20-fixture"]
        launchAndEnterHome(app)
        openCareerHome(in: app)
        tapCareerControl("workGridNext", in: app)
        for id in ["job_pet_photographer", "job_pet_brand_designer"] {
            let identifier = "workJobTile_\(id)"
            scrollCareerPage("destinationScroll", to: identifier, in: app)
            let card = element(identifier, in: app)
            let originalSize = card.frame.size
            tapCareerControl(identifier, in: app)
            waitForObservedValue("selectedCareerName", id, in: app)
            XCTAssertTrue(card.isSelected)
            let badge = card.descendants(matching: .any).matching(identifier: "careerNewBadge_\(id)").firstMatch
            XCTAssertTrue((badge.exists && badge.label == "NEW") || card.label.contains("NEW"),
                          "The selected career must keep its NEW badge visible in the accessibility tree.")
            XCTAssertEqual(card.frame.width, originalSize.width, accuracy: 1)
            XCTAssertEqual(card.frame.height, originalSize.height, accuracy: 1)
            XCTAssertFalse(element("workCountdown", in: app).exists)
            attachScreenshot(app, named: "Handoff polish — selected \(id) keeps NEW and its checkmark")
        }
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        waitForObservedValue("foodCount", "3", in: app)
    }

    @MainActor
    func testUpstairsCelebrationSeparatesItsTitleFromTheTravelExplanation() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--home-floors-fixture"]
        launchAndEnterHome(app)
        tapAnimationControl("decorateButton", in: app)
        tapAnimationControl("homeUpgradeButton", in: app)
        scrollCareerPage("homeUpgradeScroll", to: "homeUpgradeAction", in: app)
        tapAnimationControl("homeUpgradeAction", in: app)
        tapAnimationControl("homeUpgradeConfirm", in: app)
        waitForElement("homeUpgradeCelebration", in: app)
        scrollCareerPage("homeUpgradeCelebrationScroll", to: "homeUpgradeUpperOpenedBody", in: app)
        waitForLabel("homeUpgradeUpperOpenedTitle", "二楼开放啦！", in: app)
        waitForLabel("homeUpgradeUpperOpenedBody", "点击楼梯前往二楼，两层可以分别布置。", in: app)
        let title = element("homeUpgradeUpperOpenedTitle", in: app)
        let explanation = element("homeUpgradeUpperOpenedBody", in: app)
        XCTAssertFalse(explanation.label.contains(title.label))
        XCTAssertTrue(app.frame.contains(title.frame) && app.frame.contains(explanation.frame))
        attachScreenshot(app, named: "Handoff polish — upstairs announcement has one title and a separate explanation")
        scrollCareerPage("homeUpgradeCelebrationScroll", to: "homeUpgradeCelebrationDone", in: app)
        tapAnimationControl("homeUpgradeCelebrationDone", in: app)
        tapAnimationControl("layoutCancelButton", in: app)
        waitForElement("homeFloor_upper", in: app)
    }
}
