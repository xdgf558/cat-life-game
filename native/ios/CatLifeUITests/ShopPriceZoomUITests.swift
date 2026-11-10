import XCTest

extension RoomHomeUITests {
    @MainActor
    func testSupplyPricesMatchOtherCategoriesAndOneTapPurchasesRemainAtomic() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        tapAnimationControl("tabShop", in: app)
        for (button, price) in [("buyFoodButton", "20 金币"),
                                 ("buyLitterButton", "18 金币"),
                                 ("buyToyButton", "35 金币")] {
            scrollCareerPage("destinationScroll", to: button, in: app)
            waitForLabel(button, price, in: app, contains: true)
        }
        attachScreenshot(app, named: "Shop — consistent prices inside two-column purchase buttons")
        scrollCareerPage("destinationScroll", to: "shopCategory_furniture", in: app)
        tapAnimationControl("shopCategory_furniture", in: app)
        scrollCareerPage("destinationScroll", to: "shopItem_potted_plant", in: app)
        waitForLabel("shopItem_potted_plant", "120 金币", in: app, contains: true)
        scrollCareerPage("destinationScroll", to: "shopCategory_equipment", in: app)
        tapAnimationControl("shopCategory_equipment", in: app)
        waitForLabel("shopItem_advanced_cap", "360 金币", in: app, contains: true)
        tapAnimationControl("shopCategory_supplies", in: app)
        for purchase in 1...10 {
            scrollCareerPage("destinationScroll", to: "buyFoodButton", in: app)
            tapAnimationControl("buyFoodButton", in: app)
            waitForObservedValue("shopGoldCount", "\(200 - purchase * 20)", in: app)
            XCTAssertFalse(element("shopDetailScroll", in: app).exists, "Restocking must stay one tap.")
        }
        for (id, button) in [("food", "buyFoodButton"), ("litter", "buyLitterButton"), ("toy", "buyToyButton")] {
            scrollCareerPage("destinationScroll", to: button, in: app)
            XCTAssertFalse(element(button, in: app).isEnabled)
            waitForElement("shopInsufficientGold_\(id)", in: app)
        }
        attachScreenshot(app, named: "Shop — insufficient gold gives a visible explanation")
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("foodCount", "13", in: app)
        waitForObservedValue("goldCount", "0", in: app)
        relaunchPreservingSave(app)
        waitForObservedValue("foodCount", "13", in: app)
        waitForObservedValue("goldCount", "0", in: app)
    }

    @MainActor
    func testPinchZoomPreservesLayoutAndSupportsPlacementFeedingAndRelaunch() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--room-zoom-fixture", "--furniture-test"]
        launchAndEnterHome(app)
        _ = waitForFurniture(in: app, description: "expanded room ready for pinch", matching: { $0.phase == "idle" && !$0.pending })
        let room = element("roomScene", in: app)
        let original = try waitForZoom(wholeRoom: true, in: app)
        XCTAssertEqual(original.scale, original.fitScale, accuracy: 0.001)
        XCTAssertTrue(element("homeCareBar63", in: app).isHittable)
        element("roomPinchSurface", in: app).pinch(withScale: 2, velocity: 1)
        let magnified = try waitForZoom(in: app, description: "pinch magnifies the whole-room view") {
            !$0.wholeRoom && $0.scale < original.scale
        }
        XCTAssertEqual(magnified.layout, original.layout)
        XCTAssertEqual(magnified.number("catVisualWidth"), original.number("catVisualWidth"))
        XCTAssertEqual(magnified.number("worldWidth"), original.number("worldWidth"))
        attachScreenshot(app, named: "Room — two-finger zoom shows a closer view")
        element("roomPinchSurface", in: app).pinch(withScale: 0.35, velocity: -1)
        let overview = try waitForZoom(wholeRoom: true, in: app)
        XCTAssertEqual(overview.scale, overview.fitScale, accuracy: 0.001)
        XCTAssertEqual(overview.layout, original.layout)
        XCTAssertTrue(element("homeCareBar63", in: app).isHittable)
        waitForObservedValue("foodCount", "3", in: app)
        waitForObservedValue("goldCount", "5,000", in: app)
        attachScreenshot(app, named: "Room — pinch out shows the complete expanded room")

        tapAnimationControl("homeDecorateButton", in: app)
        tapAnimationControl("layoutTrayToggle", in: app)
        waitForObservedValue("layoutTrayToggle", "collapsed", in: app)
        let editingOverview = try waitForZoom(wholeRoom: true, in: app)
        element("roomPinchSurface", in: app).pinch(withScale: 2, velocity: 1)
        _ = try waitForZoom(in: app, description: "pinch magnifies the resized editing canvas") {
            !$0.wholeRoom && $0.scale < editingOverview.scale
        }
        element("roomPinchSurface", in: app).pinch(withScale: 0.4, velocity: -1)
        let editing = try waitForZoom(wholeRoom: true, in: app)
        XCTAssertEqual(editing.scale, editing.fitScale, accuracy: 0.001)
        _ = waitForFurniture(in: app, description: "pinch releases the arrangement gesture", matching: { $0.phase == "editing" && !$0.pending })
        XCTAssertEqual(editing.layout, original.layout, "A second finger must not commit a furniture drag.")
        let before = furnitureState(in: app)
        let cushion = try XCTUnwrap(before.items.first { $0.id == "floorCushion" })
        let offset = 0.02 / editing.scale
        room.coordinate(withNormalizedOffset: CGVector(dx: cushion.x, dy: cushion.y - offset))
            .press(forDuration: 0.15, thenDragTo: room.coordinate(withNormalizedOffset: CGVector(dx: 0.59, dy: 0.74 - offset)),
                   withVelocity: .slow, thenHoldForDuration: 0)
        let moved = waitForFurniture(in: app, description: "single-finger furniture drag after pinch", matching: {
            $0.selected == "floorCushion" && !$0.pending
        })
        let placed = try XCTUnwrap(moved.items.first { $0.id == "floorCushion" })
        XCTAssertGreaterThan(hypot(placed.x - cushion.x, placed.y - cushion.y), 0.02)
        tapAnimationControl("layoutDoneButton", in: app)
        _ = waitForFurniture(in: app, description: "zoomed placement saved", matching: { $0.phase == "idle" && !$0.pending })
        let saved = try zoomState(in: app)
        XCTAssertNotEqual(saved.layout, original.layout)
        tapAnimationControl("feedButton", in: app)
        let fed = waitForFurniture(in: app, timeout: 45, description: "one real meal after pinch and rearrangement", matching: {
            $0.phase == "idle" && $0.completedMeals == 1 && $0.foodContactSamples > 0
        })
        XCTAssertEqual(fed.violations, 0)
        XCTAssertEqual(fed.foodContactViolations, 0)
        waitForObservedValue("foodCount", "2", in: app)
        tapAnimationControl("roomOverviewButton", in: app)
        _ = try waitForZoom(in: app, description: "Close up focuses within the current whole-room scale") {
            !$0.wholeRoom && abs($0.scale - $0.fitScale / 1.6) < 0.025
        }
        attachScreenshot(app, named: "Room — Close up shows a close view after a real meal")
        app.terminate()
        app.launchArguments = arguments(reset: false) + ["--furniture-test"]
        launchAndEnterHome(app)
        _ = waitForFurniture(in: app, description: "zoomed furniture layout reopens", matching: { $0.phase == "idle" && !$0.pending })
        let reopened = try waitForZoom(wholeRoom: true, in: app)
        XCTAssertEqual(reopened.scale, reopened.fitScale, accuracy: 0.001)
        XCTAssertEqual(reopened.layout, saved.layout)
        waitForObservedValue("foodCount", "2", in: app)
        waitForObservedValue("goldCount", "5,000", in: app)
    }

    @MainActor
    func testInitialRoomAllowsZoomWithoutAccidentalCareActions() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--furniture-test"]
        launchAndEnterHome(app)
        _ = waitForFurniture(in: app, description: "initial room ready", matching: { $0.phase == "idle" && !$0.pending })
        let before = try waitForZoom(wholeRoom: true, in: app)
        element("roomPinchSurface", in: app).pinch(withScale: 2, velocity: 1)
        let after = try waitForZoom(in: app, description: "the initial room supports a real pinch zoom") {
            !$0.wholeRoom && $0.scale < before.scale
        }
        XCTAssertEqual(after.layout, before.layout)
        tapAnimationControl("roomOverviewButton", in: app)
        XCTAssertEqual(try waitForZoom(wholeRoom: true, in: app).layout, before.layout)
        tapAnimationControl("roomOverviewButton", in: app)
        _ = try waitForZoom(wholeRoom: false, in: app)
        element("roomPinchSurface", in: app).pinch(withScale: 0.35, velocity: -1)
        XCTAssertEqual(try waitForZoom(wholeRoom: true, in: app).layout, before.layout)
        let untouched = furnitureState(in: app)
        XCTAssertEqual(untouched.completedMeals, 0, "Zooming must not feed the cat.")
        XCTAssertEqual(untouched.completedPounces, 0, "Zooming must not start a play action.")
        waitForObservedValue("foodCount", "3", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        XCTAssertFalse(element("destinationScroll", in: app).exists)
        tapAnimationControl("feedButton", in: app)
        _ = waitForFurniture(in: app, timeout: 40, description: "normal feeding remains available after zooming", matching: {
            $0.phase == "idle" && $0.completedMeals == 1 && $0.foodContactSamples > 0
        })
        waitForObservedValue("foodCount", "2", in: app)
    }

    private struct ZoomState {
        let values: [String: Any]
        var scale: Double { number("cameraScale") }
        var fitScale: Double { number("fitScale") }
        var wholeRoom: Bool { values["wholeRoom"] as? Bool ?? false }
        func number(_ key: String) -> Double { values[key] as? Double ?? -1 }
        var layout: String {
            let data = try? JSONSerialization.data(withJSONObject: ["bowl": values["savedBowl"] ?? [:],
                "furniture": values["savedFurniture"] ?? []], options: .sortedKeys)
            return data.map { String(decoding: $0, as: UTF8.self) } ?? "invalid"
        }
    }

    @MainActor
    private func zoomState(in app: XCUIApplication) throws -> ZoomState {
        let text = try XCTUnwrap(element("roomScene", in: app).value as? String)
        let values = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        XCTAssertNotNil(values["cameraScale"])
        XCTAssertNotNil(values["wholeRoom"])
        let state = ZoomState(values: values)
        XCTAssertTrue(state.scale.isFinite && state.scale > 0)
        XCTAssertTrue(state.fitScale.isFinite && state.fitScale > 0)
        XCTAssertLessThanOrEqual(state.scale, state.fitScale + 0.001)
        return state
    }

    @MainActor
    private func waitForZoom(wholeRoom: Bool, in app: XCUIApplication) throws -> ZoomState {
        try waitForZoom(in: app, description: wholeRoom ? "complete room at its fitted scale" : "closer room view") {
            $0.wholeRoom == wholeRoom && (!wholeRoom || abs($0.scale - $0.fitScale) < 0.001)
        }
    }

    @MainActor
    private func waitForZoom(in app: XCUIApplication, description: String,
                             matching condition: @escaping (ZoomState) -> Bool) throws -> ZoomState {
        let room = element("roomScene", in: app)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let text = room.value as? String,
                  let value = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] else { return false }
            return condition(ZoomState(values: value))
        }, object: nil)
        let result = XCTWaiter.wait(for: [ready], timeout: 8)
        XCTAssertEqual(result, .completed, "Expected \(description); actual: \(room.value ?? "missing").")
        return try zoomState(in: app)
    }
}
