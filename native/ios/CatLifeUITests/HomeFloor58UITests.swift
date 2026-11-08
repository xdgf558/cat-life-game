import XCTest

extension RoomHomeUITests {
    @MainActor
    func testUpgradeCelebrationStairsIndependentFloorAndPersistedFurniture() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--home-floors-fixture", "--furniture-test"]
        launchAndEnterHome(app)
        _ = waitForFurniture(in: app, description: "expanded room ready") { $0.phase == "idle" && !$0.pending }
        XCTAssertFalse(element("homeStairsButton", in: app).exists)
        tapAnimationControl("decorateButton", in: app)
        tapAnimationControl("homeUpgradeButton", in: app)
        scrollCareerPage("homeUpgradeScroll", to: "homeUpgradeAction", in: app)
        tapAnimationControl("homeUpgradeAction", in: app)
        tapAnimationControl("homeUpgradeConfirm", in: app)
        waitForElement("homeUpgradeCelebration", in: app)
        attachScreenshot(app, named: "Home 58 — level 6 opens upstairs")
        tapAnimationControl("homeUpgradeCelebrationDone", in: app)
        tapAnimationControl("layoutCancelButton", in: app)
        waitForElement("homeStairsButton", in: app)
        tapAnimationControl("homeStairsButton", in: app)
        waitForObservedValue("homeStairsButton", "2F · 二楼", in: app)
        _ = waitForFurniture(in: app, description: "upstairs ready") { $0.phase == "idle" && !$0.pending }
        let needBubble = element("catNeedBubble", in: app)
        let stairs = element("homeStairsButton", in: app)
        let separated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            needBubble.exists && stairs.exists && needBubble.isHittable && stairs.isHittable
                && needBubble.frame.width > 0 && needBubble.frame.height > 0
                && app.frame.contains(needBubble.frame) && !needBubble.frame.intersects(stairs.frame)
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [separated], timeout: 8), .completed,
                       "The visible cat need bubble must stay clear of the stair button. Bubble: \(needBubble.frame), stairs: \(stairs.frame)")
        attachScreenshot(app, named: "Home 58 — separate empty upstairs and stair landing")
        tapAnimationControl("decorateButton", in: app)
        XCTAssertFalse(element("homeStairsButton", in: app).isEnabled)
        tapAnimationControl("layoutStored_upstairsPlant", in: app)
        _ = waitForFurniture(in: app, description: "upstairs plant placed") { !$0.pending && $0.items.contains { $0.id == "upstairsPlant" } }
        tapAnimationControl("layoutDoneButton", in: app)
        _ = waitForFurniture(in: app, description: "upstairs saved") { $0.phase == "idle" && !$0.pending }
        attachScreenshot(app, named: "Home 58 — upstairs furniture saved independently")
        tapAnimationControl("feedButton", in: app)
        let fed = waitForFurniture(in: app, timeout: 60, description: "cat eats at the upstairs bowl") {
            $0.phase == "idle" && $0.completedMeals == 1 && $0.foodContactSamples > 0
        }
        XCTAssertEqual(fed.foodContactViolations, 0)
        XCTAssertEqual(fed.violations, 0)
        tapAnimationControl("homeStairsButton", in: app)
        waitForObservedValue("homeStairsButton", "1F · 一楼", in: app)
        _ = waitForFurniture(in: app, description: "downstairs preserved") { $0.phase == "idle" && !$0.pending }
        app.terminate()
        app.launchArguments = arguments(reset: false) + ["--furniture-test"]
        launchAndEnterHome(app)
        tapAnimationControl("homeStairsButton", in: app)
        waitForObservedValue("homeStairsButton", "2F · 二楼", in: app)
        _ = waitForFurniture(in: app, description: "upstairs cold launch") { $0.phase == "idle" && !$0.pending && $0.items.contains { $0.id == "upstairsPlant" } }
        attachScreenshot(app, named: "Home 58 — upstairs after cold launch")
        tapAnimationControl("tabTown", in: app)
        attachScreenshot(app, named: "Home 58 — refreshed town map icons")
    }
}
