import XCTest

extension RoomHomeUITests {
    @MainActor
    func testRoomArrangementCanSaveAndCancel() throws {
        let app = launchFreshHome()
        tap("decorateButton", in: app)
        waitForElement("layoutDoneButton", in: app)
        waitForElement("layoutCancelButton", in: app)
        attachScreenshot(app, named: "Arrangement — editing controls")

        let original = bowlPosition(in: app)
        dragBowl(from: original, to: CGVector(dx: 0.63, dy: 0.69), in: app)
        waitForBowlMoved(from: original, in: app)
        let moved = bowlPosition(in: app)
        tap("layoutDoneButton", in: app)
        waitForElement("decorateButton", in: app)
        XCTAssertFalse(element("layoutDoneButton", in: app).exists)

        relaunchPreservingSave(app)
        let restored = bowlPosition(in: app)
        XCTAssertEqual(restored.dx, moved.dx, accuracy: 0.005)
        XCTAssertEqual(restored.dy, moved.dy, accuracy: 0.005)

        tap("decorateButton", in: app)
        dragBowl(from: restored, to: CGVector(dx: 0.80, dy: 0.83), in: app)
        waitForBowlMoved(from: restored, in: app)
        tap("layoutCancelButton", in: app)
        waitForElement("decorateButton", in: app)
        XCTAssertFalse(element("layoutCancelButton", in: app).exists)
        let cancelled = bowlPosition(in: app)
        XCTAssertEqual(cancelled.dx, moved.dx, accuracy: 0.005)
        XCTAssertEqual(cancelled.dy, moved.dy, accuracy: 0.005)
        waitForValue("foodCount", "3", in: app)
        waitForValue("goldCount", "200", in: app)
        attachScreenshot(app, named: "Arrangement — returned to normal home")
    }

    @MainActor
    func testFurnitureMovePersistsAndCancelledStorageRestoresRoom() throws {
        continueAfterFailure = false
        let app = launchFurnitureHome()
        tapAnimationControl("decorateButton", in: app)
        let editing = waitForFurniture(in: app, description: "furniture editing to open",
                                       matching: { $0.phase == "editing" && !$0.pending })
        let originalCabinet = try XCTUnwrap(editing.items.first { $0.id == "cabinet" })
        let targets = [
            CGVector(dx: min(0.80, originalCabinet.x + 0.10), dy: min(0.85, originalCabinet.y + 0.12)),
            roomCoordinate(forArtworkCoordinate: CGVector(dx: 0.60, dy: 0.70), in: app),
            roomCoordinate(forArtworkCoordinate: CGVector(dx: 0.60, dy: 0.58), in: app)
        ]
        var moved = editing
        for target in targets {
            let cabinet = try XCTUnwrap(moved.items.first { $0.id == "cabinet" })
            moved = dragFurniture(cabinet, to: target, in: app)
            let placed = try XCTUnwrap(moved.items.first { $0.id == "cabinet" })
            if hypot(placed.x - originalCabinet.x, placed.y - originalCabinet.y) > 0.02 { break }
        }
        let movedCabinet = try XCTUnwrap(moved.items.first { $0.id == "cabinet" })
        XCTAssertGreaterThan(hypot(movedCabinet.x - originalCabinet.x, movedCabinet.y - originalCabinet.y), 0.02,
                             "A real cabinet drag must reach a different safe location.")
        let movedSource = artworkCoordinate(forRoomCoordinate: movedCabinet.position, in: app)
        attachScreenshot(app, named: "Furniture — cabinet dragged to a new validated floor location")
        tapAnimationControl("layoutDoneButton", in: app)
        _ = waitForFurniture(in: app, description: "cabinet layout to save",
                             matching: { $0.phase == "idle" && !$0.pending })
        let restored = relaunchFurnitureHome(app)
        let restoredCabinet = try XCTUnwrap(restored.items.first { $0.id == "cabinet" })
        let restoredSource = artworkCoordinate(forRoomCoordinate: restoredCabinet.position, in: app)
        XCTAssertEqual(restoredSource.dx, movedSource.dx, accuracy: 0.008)
        XCTAssertEqual(restoredSource.dy, movedSource.dy, accuracy: 0.008,
                       "The moved cabinet must survive a cold launch in artwork coordinates.")
        let savedWall = try XCTUnwrap(restored.items.first { $0.id == "wallFlower" })
        let savedWallSource = artworkCoordinate(forRoomCoordinate: savedWall.position, in: app)

        tapAnimationControl("decorateButton", in: app)
        let wallEditing = waitForFurniture(in: app, description: "wall picture editing to open",
                                           matching: { $0.phase == "editing" && !$0.pending })
        let flower = try XCTUnwrap(wallEditing.items.first { $0.id == "wallFlower" })
        let floorSource = CGVector(dx: 0.62, dy: 0.76)
        let constrained = dragFurniture(flower, to: roomCoordinate(forArtworkCoordinate: floorSource, in: app), in: app)
        let wallPicture = try XCTUnwrap(constrained.items.first { $0.id == "wallFlower" })
        let wallSource = artworkCoordinate(forRoomCoordinate: wallPicture.position, in: app)
        XCTAssertLessThan(wallSource.dy, 0.46,
                          "Wall art dragged toward the floor must remain within the wall region.")
        XCTAssertGreaterThan(hypot(wallSource.dx - floorSource.dx, wallSource.dy - floorSource.dy), 0.15,
                             "The picture must not accept its requested floor coordinate.")
        attachScreenshot(app, named: "Furniture — wall picture remains on the wall after a floor drop")

        _ = try selectFurniture("cabinet", in: app)
        tapAnimationControl("storeFurnitureButton", in: app)
        _ = waitForFurniture(in: app, description: "cabinet removed from the room draft",
                             matching: { !$0.pending && !$0.items.contains { $0.id == "cabinet" } })
        tapAnimationControl("furnitureInventoryButton", in: app)
        waitForObservedValue("inventoryStoredFurnitureCount", "1", in: app)
        waitForObservedValue("inventoryPlacedFurnitureCount", "8", in: app)
        waitForElement("storedFurniture_cabinet", in: app)
        waitForElement("inventoryLayoutDraft", in: app)
        attachScreenshot(app, named: "Furniture — stored cabinet appears in the bag as an unsaved layout draft")
        tapAnimationControl("closeSheetButton", in: app)
        tapAnimationControl("layoutCancelButton", in: app)
        let cancelled = waitForFurniture(in: app, description: "cancelled furniture draft restored",
                                         matching: { $0.phase == "idle" && !$0.pending && $0.items.count == 9 })
        let returnedCabinet = try XCTUnwrap(cancelled.items.first { $0.id == "cabinet" })
        let returnedSource = artworkCoordinate(forRoomCoordinate: returnedCabinet.position, in: app)
        XCTAssertEqual(returnedSource.dx, movedSource.dx, accuracy: 0.008)
        XCTAssertEqual(returnedSource.dy, movedSource.dy, accuracy: 0.008)
        let returnedWall = try XCTUnwrap(cancelled.items.first { $0.id == "wallFlower" })
        let returnedWallSource = artworkCoordinate(forRoomCoordinate: returnedWall.position, in: app)
        XCTAssertEqual(returnedWallSource.dx, savedWallSource.dx, accuracy: 0.008)
        XCTAssertEqual(returnedWallSource.dy, savedWallSource.dy, accuracy: 0.008)
        tapAnimationControl("tabInventory", in: app)
        tapAnimationControl("inventoryFurnitureTab", in: app)
        waitForObservedValue("inventoryStoredFurnitureCount", "0", in: app)
        waitForObservedValue("inventoryPlacedFurnitureCount", "9", in: app)
        XCTAssertFalse(element("storedFurniture_cabinet", in: app).exists)
        XCTAssertFalse(element("inventoryLayoutDraft", in: app).exists)
    }

    @MainActor
    func testAllFurnitureCanBeStoredWithoutLossAndCancelledPlacementRestoresBag() throws {
        continueAfterFailure = false
        let app = launchFurnitureHome()
        let expectedIDs = ["cabinet", "catTree", "catBed", "wallFlower", "wallCat",
                           "plantLarge", "plantSmall", "floorCushion", "flowerStool"]
        tapAnimationControl("decorateButton", in: app)
        let editing = waitForFurniture(in: app, description: "all original furniture available for editing",
                                       matching: { $0.phase == "editing" && !$0.pending })
        XCTAssertEqual(Set(editing.items.map(\.id)), Set(expectedIDs))
        // Remove foreground furniture first, so a tall item's visible body
        // cannot intercept a tap intended for something behind it.
        let frontToBack = editing.items.sorted {
            if $0.isWall != $1.isWall { return !$0.isWall }
            if $0.y != $1.y { return $0.y > $1.y }
            return $0.id < $1.id
        }
        for (index, item) in frontToBack.enumerated() {
            _ = try selectFurniture(item.id, in: app)
            tapAnimationControl("storeFurnitureButton", in: app)
            let remaining = expectedIDs.count - index - 1
            _ = waitForFurniture(in: app, description: "\(item.id) stored without removing any other item",
                                 matching: { !$0.pending && $0.items.count == remaining
                                     && !$0.items.contains { $0.id == item.id } })
        }
        attachScreenshot(app, named: "Furniture — all nine items individually selected and stored")
        tapAnimationControl("layoutDoneButton", in: app)
        _ = waitForFurniture(in: app, description: "empty room layout saved",
                             matching: { $0.phase == "idle" && !$0.pending && $0.items.isEmpty })
        let empty = relaunchFurnitureHome(app)
        XCTAssertTrue(empty.items.isEmpty,
                      "A deliberately empty room must stay empty rather than restoring default furniture.")
        tapAnimationControl("tabInventory", in: app)
        tapAnimationControl("inventoryFurnitureTab", in: app)
        waitForObservedValue("inventoryStoredFurnitureCount", "9", in: app)
        waitForObservedValue("inventoryPlacedFurnitureCount", "0", in: app)
        for id in expectedIDs {
            XCTAssertEqual(app.staticTexts.matching(identifier: "storedFurniture_\(id)").count, 1,
                           "Every original furniture item must appear exactly once in the saved bag.")
        }
        attachScreenshot(app, named: "Furniture — all nine owned items remain in the bag after cold launch")
        tapAnimationControl("closeSheetButton", in: app)

        // Place both a floor item and a wall item into one new draft, then
        // cancel the entire draft. Neither item may duplicate or disappear.
        tapAnimationControl("tabInventory", in: app)
        tapAnimationControl("inventoryFurnitureTab", in: app)
        bringIntoView("placeFurniture_cabinet", in: app)
        tapAnimationControl("placeFurniture_cabinet", in: app)
        let done = element("layoutDoneButton", in: app)
        _ = waitForFurniture(in: app, timeout: 25, description: "cabinet placed into a new empty-room draft",
                             matching: { $0.phase == "editing" && !$0.pending && done.exists && done.isEnabled
                                 && $0.items.count == 1 && $0.items.contains { $0.id == "cabinet" } })
        tapAnimationControl("furnitureInventoryButton", in: app)
        waitForObservedValue("inventoryStoredFurnitureCount", "8", in: app)
        bringIntoView("placeFurniture_wallFlower", in: app)
        tapAnimationControl("placeFurniture_wallFlower", in: app)
        _ = waitForFurniture(in: app, timeout: 25, description: "wall picture and cabinet both present in the draft",
                             matching: { $0.phase == "editing" && !$0.pending && done.exists && done.isEnabled
                                 && Set($0.items.map(\.id)) == Set(["cabinet", "wallFlower"]) })
        tapAnimationControl("layoutCancelButton", in: app)
        _ = waitForFurniture(in: app, description: "cancelling the whole placement draft restores an empty room",
                             matching: { $0.phase == "idle" && !$0.pending && $0.items.isEmpty })
        let cancelled = relaunchFurnitureHome(app)
        XCTAssertTrue(cancelled.items.isEmpty)
        waitForObservedValue("foodCount", "3", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        tapAnimationControl("tabInventory", in: app)
        tapAnimationControl("inventoryFurnitureTab", in: app)
        waitForObservedValue("inventoryStoredFurnitureCount", "9", in: app)
        waitForObservedValue("inventoryPlacedFurnitureCount", "0", in: app)
        XCTAssertFalse(element("inventoryLayoutDraft", in: app).exists)
        for id in expectedIDs {
            XCTAssertEqual(app.staticTexts.matching(identifier: "storedFurniture_\(id)").count, 1,
                           "Cancelling multiple placements must restore each item to the bag exactly once.")
        }
        attachScreenshot(app, named: "Furniture — cancelling floor and wall placements preserves all nine stored items")
    }

    @MainActor
    func testFurnitureStorageAndReplacementPersistAndKeepFeedingReachable() throws {
        continueAfterFailure = false
        let app = launchFurnitureHome()
        tapAnimationControl("decorateButton", in: app)
        _ = waitForFurniture(in: app, description: "furniture editing to open",
                             matching: { $0.phase == "editing" && !$0.pending })
        _ = try selectFurniture("catTree", in: app)
        tapAnimationControl("storeFurnitureButton", in: app)
        _ = waitForFurniture(in: app, description: "cat tree removed from the draft",
                             matching: { !$0.pending && !$0.items.contains { $0.id == "catTree" } })
        tapAnimationControl("layoutDoneButton", in: app)
        _ = waitForFurniture(in: app, description: "stored cat tree layout saved",
                             matching: { $0.phase == "idle" && !$0.pending })
        let stored = relaunchFurnitureHome(app)
        XCTAssertEqual(stored.items.count, 8)
        XCTAssertFalse(stored.items.contains { $0.id == "catTree" },
                       "A saved stored item must not reappear in the room on launch.")
        tapAnimationControl("tabInventory", in: app)
        tapAnimationControl("inventoryFurnitureTab", in: app)
        waitForObservedValue("inventoryStoredFurnitureCount", "1", in: app)
        waitForObservedValue("inventoryPlacedFurnitureCount", "8", in: app)
        waitForElement("storedFurniture_catTree", in: app)
        XCTAssertFalse(element("inventoryLayoutDraft", in: app).exists)
        attachScreenshot(app, named: "Furniture — stored cat tree survives a cold launch in the bag")
        let bagAccessibility = XCTAttachment(string: app.debugDescription)
        bagAccessibility.name = "Furniture bag — accessible stored item and placement button"
        bagAccessibility.lifetime = .keepAlways
        add(bagAccessibility)
        XCTAssertTrue(app.buttons["placeFurniture_catTree"].waitForExistence(timeout: 5),
                      "Stored furniture must expose its own real placement button independently of the row label.")
        bringIntoView("placeFurniture_catTree", in: app)
        tapAnimationControl("placeFurniture_catTree", in: app)
        let done = element("layoutDoneButton", in: app)
        _ = waitForFurniture(in: app, timeout: 25, description: "bag item placed back into a validated room draft",
                             matching: { $0.phase == "editing" && !$0.pending && done.exists && done.isEnabled
                                 && $0.items.contains { $0.id == "catTree" } })
        attachScreenshot(app, named: "Furniture — bag placement returns to the room with the cat tree selected")
        tapAnimationControl("layoutDoneButton", in: app)
        _ = waitForFurniture(in: app, description: "replaced cat tree layout saved",
                             matching: { $0.phase == "idle" && !$0.pending })
        let replaced = relaunchFurnitureHome(app)
        XCTAssertEqual(replaced.items.count, 9)
        XCTAssertTrue(replaced.items.contains { $0.id == "catTree" })
        tapAnimationControl("tabInventory", in: app)
        tapAnimationControl("inventoryFurnitureTab", in: app)
        waitForObservedValue("inventoryStoredFurnitureCount", "0", in: app)
        waitForObservedValue("inventoryPlacedFurnitureCount", "9", in: app)
        XCTAssertFalse(element("storedFurniture_catTree", in: app).exists)
        tapAnimationControl("closeSheetButton", in: app)
        waitForObservedValue("foodCount", "3", in: app)
        waitForObservedValue("goldCount", "200", in: app)

        let beforeMeal = furnitureState(in: app)
        tapAnimationControl("feedButton", in: app)
        _ = waitForFurniture(in: app, timeout: 5, description: "feeding after furniture replacement to begin",
                             matching: { $0.phase == "feeding" })
        _ = waitForFurniture(in: app, timeout: 30, description: "mouth reaches food after furniture replacement",
                             matching: { $0.foodContactSamples > beforeMeal.foodContactSamples })
        attachScreenshot(app, named: "Furniture — cat reaches actual food after furniture is stored and replaced")
        let afterMeal = waitForFurniture(in: app, timeout: 40, description: "meal and safe return path to finish",
                                         matching: { $0.phase == "idle" && $0.completedMeals == beforeMeal.completedMeals + 1 })
        XCTAssertGreaterThan(afterMeal.foodContactSamples, beforeMeal.foodContactSamples)
        XCTAssertEqual(afterMeal.completedMeals, beforeMeal.completedMeals + 1)
        waitForObservedValue("foodCount", "2", in: app)
        waitForObservedValue("catSatiety", "60", in: app)
        waitForObservedValue("goldCount", "200", in: app)
    }

    @MainActor
    private func relaunchFurnitureHome(_ app: XCUIApplication) -> FurnitureState {
        app.terminate()
        app.launchArguments = arguments(reset: false) + ["--furniture-test"]
        launchAndEnterHome(app)
        return waitForFurniture(in: app, description: "saved furniture room to reopen",
                                matching: { $0.phase == "idle" && !$0.pending })
    }

    @MainActor
    private func waitForBowlMoved(from: CGVector, in app: XCUIApplication) {
        let previous = String(format: "%.3f,%.3f", from.dx, from.dy)
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value != %@", previous),
                                                object: element("roomScene", in: app))
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed)
    }
}
