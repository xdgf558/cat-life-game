import XCTest

extension RoomHomeUITests {
    @MainActor
    func testFullGroundFloorPurchaseOffersUpstairsAndSelectsNewFurniture() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--home-full-ground-fixture", "--furniture-test"]
        launchAndEnterHome(app)
        _ = waitForFurniture(in: app, description: "full downstairs ready") { $0.phase == "idle" && !$0.pending }
        tapAnimationControl("tabShop", in: app)
        tapAnimationControl("shopCategory_furniture", in: app)
        tapAnimationControl("shopItem_oak_bookcase", in: app)
        scrollCareerPage("shopDetailScroll", to: "shopBuy_oak_bookcase", in: app)
        tapAnimationControl("shopBuy_oak_bookcase", in: app)
        waitForElement("furniturePurchaseBanner", in: app)
        waitForLabel("shopDecoratePurchaseButton", "前往二楼布置", in: app)
        XCTAssertTrue(app.staticTexts["这一层已满，二楼还有 24 个家具位置。"].exists)
        attachScreenshot(app, named: "Purchase — downstairs full offers free upstairs space")
        tapAnimationControl("shopDecoratePurchaseButton", in: app)
        XCTAssertFalse(element("homeFloor_ground", in: app).exists, "Floor travel is unavailable while arranging the purchase.")
        waitForLabel("selectedFurnitureName", "橡木矮书架", in: app, contains: true)
        let stored = element("layoutStored_shop_oak_bookcase_1", in: app)
        XCTAssertTrue(stored.isSelected)
        XCTAssertFalse(element("homeUpgradeCurrentLevel", in: app).exists)
        let empty = waitForFurniture(in: app, description: "new purchase highlighted without automatic placement") {
            $0.phase == "editing" && !$0.pending
        }
        XCTAssertTrue(empty.items.isEmpty)
        attachScreenshot(app, named: "Purchase — upstairs tray focuses new furniture")
        tapAnimationControl("layoutCancelButton", in: app)
        _ = waitForFurniture(in: app, description: "cancel upstairs purchase draft") { $0.phase == "idle" && !$0.pending }
        tapAnimationControl("homeFloor_ground", in: app)
        waitForHomeFloor("ground", in: app)
        let ground = waitForFurniture(in: app, description: "original full downstairs preserved") { $0.phase == "idle" && !$0.pending }
        XCTAssertEqual(ground.items.count, 24)
    }

    @MainActor
    func testUpgradeCelebrationStairsIndependentFloorAndPersistedFurniture() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--home-floors-fixture", "--furniture-test"]
        launchAndEnterHome(app)
        _ = waitForFurniture(in: app, description: "expanded room ready") { $0.phase == "idle" && !$0.pending }
        XCTAssertFalse(element("homeFloor_upper", in: app).exists)
        tapAnimationControl("decorateButton", in: app)
        tapAnimationControl("homeUpgradeButton", in: app)
        scrollCareerPage("homeUpgradeScroll", to: "homeUpgradeAction", in: app)
        tapAnimationControl("homeUpgradeAction", in: app)
        tapAnimationControl("homeUpgradeConfirm", in: app)
        waitForElement("homeUpgradeCelebration", in: app)
        attachScreenshot(app, named: "Home 58 — level 6 opens upstairs")
        tapAnimationControl("homeUpgradeCelebrationDone", in: app)
        tapAnimationControl("layoutCancelButton", in: app)
        waitForElement("homeFloor_upper", in: app)
        tapAnimationControl("homeFloor_upper", in: app)
        waitForHomeFloor("upper", in: app)
        _ = waitForFurniture(in: app, description: "upstairs ready") { $0.phase == "idle" && !$0.pending }
        let needBubble = element("catNeedBubble", in: app)
        let stairs = element("homeFloor_upper", in: app)
        let separated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            needBubble.exists && stairs.exists && needBubble.isHittable && stairs.isHittable
                && needBubble.frame.width > 0 && needBubble.frame.height > 0
                && app.frame.contains(needBubble.frame) && !needBubble.frame.intersects(stairs.frame)
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [separated], timeout: 8), .completed,
                       "The visible cat need bubble must stay clear of the stair button. Bubble: \(needBubble.frame), stairs: \(stairs.frame)")
        attachScreenshot(app, named: "Home 58 — separate empty upstairs and stair landing")
        tapAnimationControl("decorateButton", in: app)
        XCTAssertFalse(element("homeFloor_ground", in: app).exists, "Floor travel must leave the accessibility tree while a layout draft is open.")
        XCTAssertFalse(element("homeFloor_upper", in: app).exists)
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
        tapAnimationControl("homeFloor_ground", in: app)
        waitForHomeFloor("ground", in: app)
        _ = waitForFurniture(in: app, description: "downstairs preserved") { $0.phase == "idle" && !$0.pending }
        app.terminate()
        app.launchArguments = arguments(reset: false) + ["--furniture-test"]
        launchAndEnterHome(app)
        tapAnimationControl("homeFloor_upper", in: app)
        waitForHomeFloor("upper", in: app)
        _ = waitForFurniture(in: app, description: "upstairs cold launch") { $0.phase == "idle" && !$0.pending && $0.items.contains { $0.id == "upstairsPlant" } }
        attachScreenshot(app, named: "Home 58 — upstairs after cold launch")
        tapAnimationControl("tabTown", in: app)
        attachScreenshot(app, named: "Home 58 — refreshed town map icons")
    }
}
