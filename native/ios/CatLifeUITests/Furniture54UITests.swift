import XCTest

extension RoomHomeUITests {
    @MainActor
    func testNewBookcasePurchasePlacementMirroringAndStorageSurviveRelaunch() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        let itemID = "shop_oak_bookcase_1"
        app.launchArguments = arguments(reset: true) + ["--community-fixture", "--furniture-test"]
        launchAndEnterHome(app)
        let initial = waitForFurniture(in: app, description: "level-three room before buying a bookcase") {
            $0.phase == "idle" && !$0.pending
        }

        tapAnimationControl("tabShop", in: app)
        tapAnimationControl("shopCategory_furniture", in: app)
        scrollCareerPage("destinationScroll", to: "shopItem_oak_bookcase", in: app)
        attachScreenshot(app, named: "New furniture — oak bookcase and rattan chair in the shop")
        tapAnimationControl("shopItem_oak_bookcase", in: app)
        scrollCareerPage("shopDetailScroll", to: "shopBuy_oak_bookcase", in: app)
        XCTAssertFalse(element("furniturePurchaseBanner", in: app).exists)
        tapAnimationControl("shopBuy_oak_bookcase", in: app)
        waitForObservedValue("shopOwned_oak_bookcase", "1", in: app)
        waitForElement("furniturePurchaseBanner", in: app)
        XCTAssertTrue(element("shopDecoratePurchaseButton", in: app).isHittable)
        attachScreenshot(app, named: "New furniture — saved purchase offers an Arrange shortcut")
        tapAnimationControl("shopDecoratePurchaseButton", in: app)
        let readyToPlace = waitForFurniture(in: app, description: "purchase shortcut opens the arrangement tray without placing") {
            $0.phase == "editing" && !$0.pending
        }
        waitForObservedValue("goldCount", "4,740", in: app)
        XCTAssertFalse(readyToPlace.items.contains { $0.id == itemID },
                       "Buying furniture puts it in the bag without silently rearranging the room.")
        XCTAssertEqual(readyToPlace.items.map(\.id).sorted(), initial.items.map(\.id).sorted())
        XCTAssertFalse(element("furniturePurchaseBanner", in: app).exists)
        waitForObservedValue("layoutTrayToggle", "expanded", in: app)
        waitForElement("layoutStored_" + itemID, in: app)

        tapAnimationControl("layoutStored_" + itemID, in: app)
        let placed = waitForFurniture(in: app, timeout: 30, description: "new bookcase safely placed in expanded room") {
            $0.phase == "editing" && !$0.pending && $0.selected == itemID && $0.items.contains { $0.id == itemID }
        }
        XCTAssertEqual(placed.items.count, initial.items.count + 1)
        if element("layoutTrayToggle", in: app).value as? String == "collapsed" {
            tapAnimationControl("layoutTrayToggle", in: app)
        }
        tapAnimationControl("flipFurnitureButton", in: app)
        _ = waitForFurniture(in: app, description: "new bookcase faces the opposite direction") {
            !$0.pending && $0.items.first { $0.id == itemID }?.orientation == "mirrored"
        }
        attachScreenshot(app, named: "New furniture — mirrored oak bookcase in the expanded room")
        tapAnimationControl("layoutDoneButton", in: app)
        _ = waitForFurniture(in: app, description: "new bookcase layout saved") { $0.phase == "idle" && !$0.pending }

        app.terminate()
        app.launchArguments = arguments(reset: false) + ["--furniture-test"]
        launchAndEnterHome(app)
        let reopened = waitForFurniture(in: app, description: "bookcase ownership and facing after cold launch") {
            $0.phase == "idle" && !$0.pending
        }
        XCTAssertEqual(reopened.items.first { $0.id == itemID }?.orientation, "mirrored")
        XCTAssertEqual(reopened.items.count, initial.items.count + 1)
        waitForObservedValue("goldCount", "4,740", in: app)

        // Select from the bag so the test also works when the expanded camera leaves the bookcase offscreen.
        tapAnimationControl("tabInventory", in: app)
        scrollCareerPage("destinationScroll", to: "inventoryFurnitureTab", in: app)
        tapAnimationControl("inventoryFurnitureTab", in: app)
        scrollCareerPage("destinationScroll", to: "inventoryFurniture_" + itemID, in: app)
        tapAnimationControl("inventoryFurniture_" + itemID, in: app)
        tapAnimationControl("inventoryArrangeButton", in: app)
        _ = waitForFurniture(in: app, description: "placed bookcase selected from the bag") {
            $0.phase == "editing" && !$0.pending && $0.selected == itemID
        }
        if element("layoutTrayToggle", in: app).value as? String == "collapsed" {
            tapAnimationControl("layoutTrayToggle", in: app)
        }
        tapAnimationControl("storeFurnitureButton", in: app)
        _ = waitForFurniture(in: app, description: "bookcase returned to the bag") {
            !$0.pending && !$0.items.contains { $0.id == itemID }
        }
        tapAnimationControl("layoutDoneButton", in: app)
        _ = waitForFurniture(in: app, description: "bookcase storage saved") { $0.phase == "idle" && !$0.pending }

        app.terminate()
        app.launchArguments = arguments(reset: false) + ["--furniture-test"]
        launchAndEnterHome(app)
        let stored = waitForFurniture(in: app, description: "stored bookcase remains unplaced after relaunch") {
            $0.phase == "idle" && !$0.pending
        }
        XCTAssertFalse(stored.items.contains { $0.id == itemID })
        XCTAssertEqual(stored.items.count, initial.items.count)
        waitForObservedValue("goldCount", "4,740", in: app)
        tapAnimationControl("tabInventory", in: app)
        scrollCareerPage("destinationScroll", to: "inventoryFurnitureTab", in: app)
        tapAnimationControl("inventoryFurnitureTab", in: app)
        waitForObservedValue("inventoryStoredFurnitureCount", "1", in: app)
        scrollCareerPage("destinationScroll", to: "inventoryFurniture_" + itemID, in: app)
        XCTAssertTrue(element("inventoryFurniture_" + itemID, in: app).exists)
        attachScreenshot(app, named: "New furniture — owned bookcase remains in the bag after cold launch")
    }
}
