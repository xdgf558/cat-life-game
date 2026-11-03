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
        waitForLabel("shopItem_potted_plant", "120 金币", in: app, contains: true)
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
        let original = try zoomState(in: app)
        XCTAssertEqual(original.scale, 1, accuracy: 0.001)
        tapAnimationControl("homeCareVisibilityButton", in: app)
        waitForObservedValue("homeCareVisibilityButton", "hidden", in: app)
        element("roomPinchSurface", in: app).pinch(withScale: 2, velocity: 1)
        let magnified = try waitForZoom(0.625, in: app)
        XCTAssertEqual(magnified.layout, original.layout)
        XCTAssertEqual(magnified.number("catVisualWidth"), original.number("catVisualWidth"))
        XCTAssertEqual(magnified.number("worldWidth"), original.number("worldWidth"))
        attachScreenshot(app, named: "Room — two-finger zoom in at its upper limit")
        element("roomPinchSurface", in: app).pinch(withScale: 0.35, velocity: -1)
        let overview = try waitForZoom(1.5, in: app)
        XCTAssertEqual(overview.number("cameraX"), overview.number("worldWidth") / 2, accuracy: 0.5)
        XCTAssertEqual(overview.number("cameraY"), overview.number("worldHeight") / 2, accuracy: 0.5)
        XCTAssertEqual(overview.layout, original.layout)
        tapAnimationControl("homeCareVisibilityButton", in: app)
        waitForObservedValue("homeCareVisibilityButton", "visible", in: app)
        waitForObservedValue("foodCount", "3", in: app)
        waitForObservedValue("goldCount", "5,000", in: app)
        attachScreenshot(app, named: "Room — pinch out shows the complete expanded room")

        tapAnimationControl("homeDecorateButton", in: app)
        tapAnimationControl("layoutTrayToggle", in: app)
        waitForObservedValue("layoutTrayToggle", "collapsed", in: app)
        element("roomPinchSurface", in: app).pinch(withScale: 2, velocity: 1)
        _ = try waitForZoom(0.75, in: app)
        element("roomPinchSurface", in: app).pinch(withScale: 0.4, velocity: -1)
        let editing = try waitForZoom(1.5, in: app)
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
        tapAnimationControl("focusCatButton", in: app)
        _ = try waitForZoom(1, in: app)
        attachScreenshot(app, named: "Room — Find Cat restores normal zoom after a real meal")
        app.terminate()
        app.launchArguments = arguments(reset: false) + ["--furniture-test"]
        launchAndEnterHome(app)
        _ = waitForFurniture(in: app, description: "zoomed furniture layout reopens", matching: { $0.phase == "idle" && !$0.pending })
        let reopened = try zoomState(in: app)
        XCTAssertEqual(reopened.scale, 1, accuracy: 0.001)
        XCTAssertEqual(reopened.layout, saved.layout)
        waitForObservedValue("foodCount", "2", in: app)
        waitForObservedValue("goldCount", "5,000", in: app)
    }

    @MainActor
    func testInitialRoomIgnoresPinchWithoutAccidentalCareActions() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--furniture-test"]
        launchAndEnterHome(app)
        _ = waitForFurniture(in: app, description: "initial room ready", matching: { $0.phase == "idle" && !$0.pending })
        let before = try zoomState(in: app)
        element("roomPinchSurface", in: app).pinch(withScale: 2, velocity: 1)
        let after = try waitForZoom(1, in: app)
        XCTAssertEqual(after.layout, before.layout)
        waitForObservedValue("foodCount", "3", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        XCTAssertFalse(element("destinationScroll", in: app).exists)
        tapAnimationControl("feedButton", in: app)
        _ = waitForFurniture(in: app, timeout: 40, description: "normal feeding remains available after ignored pinch", matching: {
            $0.phase == "idle" && $0.completedMeals == 1
        })
        waitForObservedValue("foodCount", "2", in: app)
    }

    private struct ZoomState {
        let values: [String: Any]
        var scale: Double { number("cameraScale") }
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
        return ZoomState(values: values)
    }

    @MainActor
    private func waitForZoom(_ expected: Double, in app: XCUIApplication) throws -> ZoomState {
        let room = element("roomScene", in: app)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let text = room.value as? String,
                  let value = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
                  let scale = value["cameraScale"] as? Double else { return false }
            return abs(scale - expected) < 0.025
        }, object: nil)
        let result = XCTWaiter.wait(for: [ready], timeout: 8)
        XCTAssertEqual(result, .completed, "Pinch should reach camera scale \(expected); actual: \(room.value ?? "missing").")
        return try zoomState(in: app)
    }
}
