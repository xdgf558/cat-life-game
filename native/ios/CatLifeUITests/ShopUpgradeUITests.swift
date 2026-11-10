import XCTest

extension RoomHomeUITests {
    @MainActor
    func testFurniturePurchaseInFullRoomOffersUpgradeWithoutChangingLayout() throws {
        continueAfterFailure = false
        let app = launchShopUpgradeHome()
        let initial = try expansionState(in: app)
        tapAnimationControl("tabShop", in: app)
        tapAnimationControl("shopCategory_furniture", in: app)
        scrollCareerPage("destinationScroll", to: "shopItem_potted_plant", in: app)
        tapAnimationControl("shopItem_potted_plant", in: app)
        scrollCareerPage("shopDetailScroll", to: "shopBuy_potted_plant", in: app)
        tapAnimationControl("shopBuy_potted_plant", in: app)
        waitForObservedValue("shopOwned_potted_plant", "1", in: app)
        waitForElement("furniturePurchaseBanner", in: app)
        waitForLabel("shopDecoratePurchaseButton", "升级", in: app, contains: true)
        attachScreenshot(app, named: "Furniture purchase — full room offers upgrade")
        tapAnimationControl("shopDecoratePurchaseButton", in: app)
        waitForObservedValue("homeUpgradeCurrentLevel", "1", in: app)
        scrollCareerPage("homeUpgradeScroll", to: "homeUpgradeGold", in: app)
        waitForObservedValue("homeUpgradeGold", "4,880", in: app)
        XCTAssertFalse(element("layoutReturnButton", in: app).exists,
                       "A full-room purchase shortcut must not enter an unusable arrangement session.")
        XCTAssertFalse(element("furniturePurchaseBanner", in: app).exists)
        tapAnimationControl("tabHome", in: app)
        _ = waitForFurniture(in: app, description: "return from full-room upgrade suggestion") {
            $0.phase == "idle" && !$0.pending
        }
        let returned = try expansionState(in: app)
        XCTAssertEqual(returned.number("roomLevel"), 1)
        XCTAssertEqual(returned.savedLayout, initial.savedLayout)
        waitForObservedValue("goldCount", "4,880", in: app)
    }

    @MainActor
    func testShopPurchasesEquipmentAndFurniturePersistWithoutDuplicateCharges() throws {
        continueAfterFailure = false
        let app = launchShopUpgradeHome()
        tapAnimationControl("tabShop", in: app)
        tapAnimationControl("shopCategory_equipment", in: app)
        tapAnimationControl("shopItem_advanced_cap", in: app)
        scrollCareerPage("shopDetailScroll", to: "shopBuy_advanced_cap", in: app)
        tapAnimationControl("shopBuy_advanced_cap", in: app)
        waitForObservedValue("shopOwned_advanced_cap", "1", in: app)
        XCTAssertFalse(element("shopBuy_advanced_cap", in: app).isEnabled)
        attachScreenshot(app, named: "Shop — purchased advanced cap and its work benefit")
        tapAnimationControl("shopDetailBackButton", in: app)
        waitForObservedValue("shopGoldCount", "4,640", in: app)
        tapAnimationControl("shopCategory_furniture", in: app)
        scrollCareerPage("destinationScroll", to: "shopItem_potted_plant", in: app)
        tapAnimationControl("shopItem_potted_plant", in: app)
        for count in 1...2 {
            scrollCareerPage("shopDetailScroll", to: "shopBuy_potted_plant", in: app)
            tapAnimationControl("shopBuy_potted_plant", in: app)
            waitForObservedValue("shopOwned_potted_plant", "\(count)", in: app)
        }
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", "4,400", in: app)
        tapAnimationControl("tabInventory", in: app)
        scrollCareerPage("destinationScroll", to: "inventoryFurnitureTab", in: app)
        tapAnimationControl("inventoryFurnitureTab", in: app)
        waitForObservedValue("inventoryStoredFurnitureCount", "2", in: app)
        XCTAssertFalse(element("placeFurniture_shop_potted_plant_1", in: app).isEnabled)
        attachScreenshot(app, named: "Backpack — two independent plants and full-room guidance")
        tapAnimationControl("tabHome", in: app)
        openPlayerProfile(in: app)
        tapProfileControl("equipmentSlot_head", in: app)
        tapProfilePageControl("equipItem_advanced_cap", scroll: "equipmentScroll", in: app)
        waitForObservedValue("equippedItem_head", "advanced_cap", in: app)
        tapAnimationControl("profileBackButton", in: app)
        closePlayerProfile(in: app)
        relaunchPreservingSave(app)
        waitForObservedValue("goldCount", "4,400", in: app)
        openPlayerProfile(in: app)
        assertProfileValue("equipmentSlot_head", "advanced_cap", in: app)
        closePlayerProfile(in: app)
        tapAnimationControl("tabInventory", in: app)
        scrollCareerPage("destinationScroll", to: "inventoryFurnitureTab", in: app)
        tapAnimationControl("inventoryFurnitureTab", in: app)
        waitForObservedValue("inventoryStoredFurnitureCount", "2", in: app)
    }

    @MainActor
    func testRoomExpansionPreservesScaleSupportsPanPlacementAndFeedingAfterRelaunch() throws {
        continueAfterFailure = false
        let app = launchShopUpgradeHome()
        let initial = try expansionState(in: app)
        tapAnimationControl("tabShop", in: app)
        tapAnimationControl("shopCategory_furniture", in: app)
        scrollCareerPage("destinationScroll", to: "shopItem_potted_plant", in: app)
        tapAnimationControl("shopItem_potted_plant", in: app)
        scrollCareerPage("shopDetailScroll", to: "shopBuy_potted_plant", in: app)
        tapAnimationControl("shopBuy_potted_plant", in: app)
        waitForObservedValue("shopOwned_potted_plant", "1", in: app)
        tapAnimationControl("tabHome", in: app)
        tapAnimationControl("decorateButton", in: app)
        tapAnimationControl("homeUpgradeButton", in: app)
        waitForObservedValue("homeUpgradeCurrentLevel", "1", in: app)
        for level in 2...3 {
            scrollCareerPage("homeUpgradeScroll", to: "homeUpgradeAction", in: app)
            tapAnimationControl("homeUpgradeAction", in: app)
            tapAnimationControl("homeUpgradeConfirm", in: app)
            waitForElement("homeUpgradeCelebration", in: app)
            tapAnimationControl("homeUpgradeCelebrationDone", in: app)
            tapAnimationControl("homeUpgradeButton", in: app)
            scrollCareerPage("homeUpgradeScroll", to: "homeUpgradeCurrentLevel", in: app)
            waitForObservedValue("homeUpgradeCurrentLevel", "\(level)", in: app)
        }
        scrollCareerPage("homeUpgradeScroll", to: "homeUpgradeNextLevel", in: app)
        waitForObservedValue("homeUpgradeNextLevel", "4", in: app)
        attachScreenshot(app, named: "Room renovation — level three and sixteen furniture slots")
        tapAnimationControl("layoutReturnButton", in: app)
        _ = waitForFurniture(in: app, description: "expanded room geometry to finish", matching: { $0.phase == "editing" && !$0.pending })
        let expanded = try expansionState(in: app)
        XCTAssertEqual(expanded.number("roomLevel"), 3)
        XCTAssertEqual(expanded.number("worldWidth"), initial.number("worldWidth") * 1.5, accuracy: 1)
        XCTAssertEqual(expanded.number("worldHeight"), initial.number("worldHeight") * 1.5, accuracy: 1)
        for key in ["catVisualWidth", "bowlVisualWidth", "viewportWidth", "viewportHeight"] {
            XCTAssertEqual(expanded.number(key), initial.number(key), accuracy: 0.01, "Expansion must keep \(key) unchanged.")
        }
        for old in initial.items {
            let item = try XCTUnwrap(expanded.items.first { $0["id"] as? String == old["id"] as? String })
            XCTAssertEqual((item["width"] as? Double) ?? -1, (old["width"] as? Double) ?? -2, accuracy: 0.01)
        }
        XCTAssertEqual(expanded.savedLayout, initial.savedLayout)
        let room = element("roomScene", in: app)
        room.coordinate(withNormalizedOffset: CGVector(dx: 0.70, dy: 0.22))
            .press(forDuration: 0.08, thenDragTo: room.coordinate(withNormalizedOffset: CGVector(dx: 0.20, dy: 0.22)))
        tapAnimationControl("furnitureInventoryButton", in: app)
        tapAnimationControl("placeFurniture_shop_potted_plant_1", in: app)
        _ = waitForFurniture(in: app, description: "new plant to receive a safe floor position", matching: {
            !$0.pending && $0.items.contains { $0.id == "shop_potted_plant_1" }
        })
        var occupiesNewSpace = false
        for target in [CGVector(dx: 0.86, dy: 0.60), CGVector(dx: 0.85, dy: 0.70), CGVector(dx: 0.85, dy: 0.48)] {
            let current = furnitureState(in: app)
            let plant = try XCTUnwrap(current.items.first { $0.id == "shop_potted_plant_1" })
            _ = dragFurniture(plant, to: target, in: app)
            let state = try expansionState(in: app)
            let placed = try XCTUnwrap(state.items.first { $0["id"] as? String == "shop_potted_plant_1" })
            let x = (placed["worldX"] as? Double ?? 0) * state.number("worldWidth")
            let halfWidth = (placed["footprintWidth"] as? Double ?? 0) / 2
            occupiesNewSpace = x - halfWidth > initial.number("worldWidth")
            if occupiesNewSpace { break }
        }
        XCTAssertTrue(occupiesNewSpace, "The purchased plant must fit entirely inside space beyond the original room width.")
        attachScreenshot(app, named: "Room expansion — purchased plant placed in the newly available floor area")
        tapAnimationControl("layoutDoneButton", in: app)
        _ = waitForFurniture(in: app, description: "expanded layout to save", matching: { $0.phase == "idle" && !$0.pending })
        let beforePan = try expansionState(in: app)
        // Start below the task/reminder HUD, and pan away from the current camera edge.
        let canMoveCameraLeft = beforePan.number("cameraX") > beforePan.number("viewportWidth") / 2 + 20
        room.coordinate(withNormalizedOffset: CGVector(dx: canMoveCameraLeft ? 0.30 : 0.68, dy: 0.42))
            .press(forDuration: 0.08, thenDragTo: room.coordinate(withNormalizedOffset:
                CGVector(dx: canMoveCameraLeft ? 0.68 : 0.30, dy: 0.49)))
        let panned = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let value = room.value as? String,
                  let state = try? JSONSerialization.jsonObject(with: Data(value.utf8)) as? [String: Any],
                  let x = state["cameraX"] as? Double, let y = state["cameraY"] as? Double else { return false }
            return abs(x - beforePan.number("cameraX")) + abs(y - beforePan.number("cameraY")) > 5
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [panned], timeout: 5), .completed)
        let afterPan = try expansionState(in: app)
        XCTAssertGreaterThan(abs(afterPan.number("cameraX") - beforePan.number("cameraX"))
                             + abs(afterPan.number("cameraY") - beforePan.number("cameraY")), 5)
        XCTAssertEqual(afterPan.savedLayout, beforePan.savedLayout, "Panning cannot save a furniture move.")
        tapAnimationControl("roomOverviewButton", in: app)
        attachScreenshot(app, named: "Expanded room — camera view with unchanged cat and furniture scale")
        app.terminate()
        app.launchArguments = arguments(reset: false) + ["--furniture-test"]
        launchAndEnterHome(app)
        let reopened = try expansionState(in: app)
        XCTAssertEqual(reopened.number("roomLevel"), 3)
        XCTAssertEqual(reopened.savedLayout, afterPan.savedLayout)
        waitForObservedValue("goldCount", "3,530", in: app)
        tapAnimationControl("feedButton", in: app)
        let fed = waitForFurniture(in: app, timeout: 60, description: "cat reaches its bowl in the expanded room", matching: {
            $0.phase == "idle" && $0.completedMeals == 1 && $0.foodContactSamples > 0
        })
        XCTAssertEqual(fed.foodContactViolations, 0)
        XCTAssertEqual(fed.violations, 0)
        waitForObservedValue("foodCount", "2", in: app)
        attachScreenshot(app, named: "Expanded room — completed meal at the saved bowl")
    }

    @MainActor
    func testRoomAndEquipmentRequirementsAreVisibleBeforeSpending() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        tapAnimationControl("tabShop", in: app)
        tapAnimationControl("shopCategory_equipment", in: app)
        tapAnimationControl("shopItem_advanced_cap", in: app)
        scrollCareerPage("shopDetailScroll", to: "shopBuy_advanced_cap", in: app)
        XCTAssertFalse(element("shopBuy_advanced_cap", in: app).isEnabled)
        waitForElement("shopPurchaseStatus", in: app)
        tapAnimationControl("tabHome", in: app)
        tapAnimationControl("decorateButton", in: app)
        tapAnimationControl("homeUpgradeButton", in: app)
        scrollCareerPage("homeUpgradeScroll", to: "homeUpgradeAction", in: app)
        XCTAssertFalse(element("homeUpgradeAction", in: app).isEnabled)
        waitForObservedValue("homeUpgradeGold", "200", in: app)
        attachScreenshot(app, named: "Room renovation — visible level and gold requirements")
    }

    @MainActor
    private func launchShopUpgradeHome() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--shop-upgrade-fixture", "--furniture-test"]
        launchAndEnterHome(app)
        _ = waitForFurniture(in: app, description: "shop fixture room ready", matching: { $0.phase == "idle" && !$0.pending })
        return app
    }

    @MainActor
    func testShopAndRenovationTranslateIntoEnglishAndTraditionalChinese() throws {
        continueAfterFailure = false
        for (code, locale, equipment, renovation) in [
            ("en", "en_US", "Equipment", "Upgrade home"),
            ("zh-Hant", "zh_TW", "裝備", "升級小家")
        ] {
            let app = XCUIApplication()
            app.launchArguments = ["--ui-testing", "--reset-ui-test-save", "--shop-upgrade-fixture",
                                   "-AppleLanguages", "(\(code))", "-AppleLocale", locale]
            launchAndEnterHome(app)
            tapAnimationControl("tabShop", in: app)
            waitForLabel("shopCategory_equipment", equipment, in: app)
            tapAnimationControl("shopCategory_equipment", in: app)
            tapAnimationControl("shopItem_advanced_sneakers", in: app)
            scrollCareerPage("shopDetailScroll", to: "shopBuy_advanced_sneakers", in: app)
            XCTAssertTrue(element("shopBuy_advanced_sneakers", in: app).isEnabled)
            attachScreenshot(app, named: "Shop equipment — \(code)")
            tapAnimationControl("tabHome", in: app)
            tapAnimationControl("decorateButton", in: app)
            waitForLabel("homeUpgradeButton", renovation, in: app, contains: true)
            tapAnimationControl("homeUpgradeButton", in: app)
            scrollCareerPage("homeUpgradeScroll", to: "homeUpgradeAction", in: app)
            XCTAssertTrue(element("homeUpgradeAction", in: app).isEnabled)
            attachScreenshot(app, named: "Room renovation — \(code)")
            app.terminate()
        }
    }

    private struct ExpansionState {
        let values: [String: Any]
        func number(_ key: String) -> Double { values[key] as? Double ?? -1 }
        var items: [[String: Any]] { values["items"] as? [[String: Any]] ?? [] }
        var savedLayout: String {
            let data = try? JSONSerialization.data(withJSONObject: ["bowl": values["savedBowl"] ?? [:],
                "furniture": values["savedFurniture"] ?? []], options: .sortedKeys)
            return data.map { String(decoding: $0, as: UTF8.self) } ?? "invalid"
        }
    }

    @MainActor
    private func expansionState(in app: XCUIApplication) throws -> ExpansionState {
        let value = try XCTUnwrap(element("roomScene", in: app).value as? String)
        let values = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(value.utf8)) as? [String: Any])
        XCTAssertNotNil(values["roomLevel"], "The running scene must expose its actual world geometry.")
        return ExpansionState(values: values)
    }
}
