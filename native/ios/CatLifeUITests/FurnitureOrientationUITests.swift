import XCTest

extension RoomHomeUITests {
    @MainActor
    func testFullRoomPinchCatBedDragToWindowFloorPreservesDraftAndFacing() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--room-zoom-fixture", "--furniture-test"]
        launchAndEnterHome(app)
        _ = waitForFurniture(in: app, description: "level-three room is ready for a full-room drag") {
            $0.phase == "idle" && !$0.pending
        }
        let original = try fullRoomState(in: app)
        let originalBed = try XCTUnwrap(original.items.first { $0.id == "catBed" })
        var savedBed: FullRoomItem?

        for shouldSave in [false, true] {
            tapAnimationControl("homeDecorateButton", in: app)
            _ = try selectFurnitureForFacing("catBed", in: app)
            tapAnimationControl("flipFurnitureButton", in: app)
            _ = waitForFurnitureOrientation("catBed", "mirrored", in: app)
            tapAnimationControl("layoutTrayToggle", in: app)
            waitForObservedValue("layoutTrayToggle", "collapsed", in: app)
            element("roomPinchSurface", in: app).pinch(withScale: 0.35, velocity: -1)
            let overviewReady = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                guard let state = try? self.fullRoomState(in: app) else { return false }
                return abs(state.cameraScale - 1.5) < 0.025 && !state.pending
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [overviewReady], timeout: 10), .completed)
            let before = try fullRoomState(in: app)
            let bed = try XCTUnwrap(before.items.first { $0.id == "catBed" })
            XCTAssertEqual(before.cameraScale, 1.5, accuracy: 0.025)
            XCTAssertEqual(before.cameraX, before.worldWidth / 2, accuracy: 0.5)
            XCTAssertEqual(before.cameraY, before.worldHeight / 2, accuracy: 0.5)
            XCTAssertEqual(bed.worldX, originalBed.worldX, accuracy: 0.008)
            XCTAssertEqual(bed.worldY, originalBed.worldY, accuracy: 0.008)
            XCTAssertEqual(before.savedFurniture, original.savedFurniture,
                           "Pinching and turning must not move the draft's furniture placements.")

            // This window-floor location fits the rounded bed, but the old
            // rectangular floor check stopped its empty back-left corner.
            let artworkScale = max(before.worldWidth / 1024, before.worldHeight / 1536)
            let target = CGPoint(x: before.worldWidth / 2 + (255 - 512) * artworkScale,
                                 y: before.worldHeight / 2 + (750 - 768) * artworkScale)
            let targetFootprint = CGRect(x: target.x - bed.footprintWidth / 2,
                                         y: target.y - bed.footprintHeight / 2,
                                         width: bed.footprintWidth, height: bed.footprintHeight)
            XCTAssertGreaterThan(targetFootprint.minX, 6)
            let leftSourceX = 512 + (Double(targetFootprint.minX) - before.worldWidth / 2) / artworkScale
            let topSourceY = 768 + (Double(targetFootprint.minY) - before.worldHeight / 2) / artworkScale
            XCTAssertTrue((0...335).contains(leftSourceX))
            XCTAssertLessThan(topSourceY, 785 - 150 * leftSourceX / 335,
                              "The old full rectangle must cross the window edge, or this target does not reproduce the preview bug.")
            let halfWidth = bed.footprintWidth / 2
            let halfHeight = bed.footprintHeight / 2
            let roundedOffsets: [(Double, Double)] = [
                (-1, -0.5), (-0.5, -1), (0.5, -1), (1, -0.5),
                (1, 0.5), (0.5, 1), (-0.5, 1), (-1, 0.5)
            ]
            for (dx, dy) in roundedOffsets {
                let x = Double(target.x) + dx * halfWidth
                let y = Double(target.y) + dy * halfHeight
                let sourceX = 512 + (x - before.worldWidth / 2) / artworkScale
                let sourceY = 768 + (y - before.worldHeight / 2) / artworkScale
                XCTAssertTrue((0...442).contains(sourceX))
                let floorTop = sourceX <= 335 ? 785 - 150 * sourceX / 335
                    : 585 - 55 * (sourceX - 335) / 107
                XCTAssertGreaterThan(sourceY, floorTop,
                                     "Every corner of the bed's enclosing octagon must stay below the actual window-floor edge.")
                XCTAssertGreaterThan(x, 6)
                XCTAssertLessThan(x, before.worldWidth - 6)
                XCTAssertGreaterThan(y, 6)
                XCTAssertLessThan(y, before.worldHeight - 24)
            }
            for other in before.items where other.id != "catBed" && !other.kind.hasPrefix("wall") {
                let obstacle = CGRect(x: other.worldX * before.worldWidth - other.footprintWidth / 2,
                                      y: other.worldY * before.worldHeight - other.footprintHeight / 2,
                                      width: other.footprintWidth, height: other.footprintHeight)
                XCTAssertFalse(targetFootprint.intersects(obstacle.insetBy(dx: -2, dy: -2)),
                               "The window-floor target must not overlap \(other.id).")
            }
            attachFullRoomDiagnostic(app, name: "Full-room bed drag — before \(shouldSave ? "save" : "cancel")",
                                     target: target, state: before)
            let targetScreen = before.screenPoint(worldTopLeft: target)
            let touchOffset = 0.02 / before.cameraScale
            element("roomScene", in: app)
                .coordinate(withNormalizedOffset: CGVector(dx: bed.x, dy: bed.y - touchOffset))
                .press(forDuration: 0.15,
                       thenDragTo: element("roomScene", in: app).coordinate(withNormalizedOffset:
                           CGVector(dx: targetScreen.dx, dy: targetScreen.dy - touchOffset)),
                       withVelocity: .slow, thenHoldForDuration: 0.25)
            _ = waitForFurniture(in: app, timeout: 30, description: "zoomed bed drag commits a changed preview position") {
                $0.phase == "editing" && $0.selected == "catBed" && !$0.pending
            }
            let after = try fullRoomState(in: app)
            let moved = try XCTUnwrap(after.items.first { $0.id == "catBed" })
            attachFullRoomDiagnostic(app, name: "Full-room bed drag — after \(shouldSave ? "save" : "cancel")",
                                     target: target, state: after)
            attachScreenshot(app, named: "Full-room bed drag — actual selected preview at left window floor")
            XCTAssertEqual(after.cameraScale, before.cameraScale, accuracy: 0.001)
            XCTAssertEqual(after.cameraX, before.cameraX, accuracy: 0.5)
            XCTAssertEqual(after.cameraY, before.cameraY, accuracy: 0.5,
                           "Grabbing the bed must move furniture rather than pan the room.")
            XCTAssertLessThan(moved.worldY, bed.worldY - 0.04)
            XCTAssertLessThan(moved.worldX, bed.worldX - 0.01)
            XCTAssertGreaterThan(hypot(moved.x - bed.x, moved.y - bed.y), 0.04,
                                 "A tap-only selection must not satisfy this real-drag regression.")
            XCTAssertEqual(moved.worldX, Double(target.x) / before.worldWidth, accuracy: 0.025)
            XCTAssertEqual(moved.worldY, Double(target.y) / before.worldHeight, accuracy: 0.025)
            XCTAssertEqual(moved.orientation, "mirrored")
            XCTAssertGreaterThan(after.dragPreviewSamples, 0,
                                 "The gesture must update the bed while the finger is still moving.")
            let preview = try XCTUnwrap(after.dragPreviewWorld)
            XCTAssertEqual(preview.x, Double(target.x) / before.worldWidth, accuracy: 2 / before.worldWidth)
            XCTAssertEqual(preview.y, Double(target.y) / before.worldHeight, accuracy: 2 / before.worldHeight,
                           "The live preview must reach the window-floor target before the release planner runs.")
            XCTAssertEqual(preview.x, moved.worldX, accuracy: 2 / before.worldWidth)
            XCTAssertEqual(preview.y, moved.worldY, accuracy: 2 / before.worldHeight,
                           "Releasing must preserve the position already reached during the drag.")
            // Despite its legacy name, savedFurniture reports sceneSnapshot's
            // current draft. Only a cold relaunch proves what reached disk.
            let draftedBed = try XCTUnwrap(after.savedFurniture.first { $0.itemID == "catBed" })
            XCTAssertEqual(draftedBed.x,
                           0.5 + (moved.worldX - 0.5) * after.worldWidth / (1024 * artworkScale), accuracy: 0.008)
            XCTAssertEqual(draftedBed.y,
                           0.5 + (moved.worldY - 0.5) * after.worldHeight / (1536 * artworkScale), accuracy: 0.008)
            XCTAssertNotEqual(after.savedFurniture, original.savedFurniture)
            XCTAssertEqual(after.savedFurniture.filter { $0.itemID != "catBed" },
                           original.savedFurniture.filter { $0.itemID != "catBed" })
            tapAnimationControl(shouldSave ? "layoutDoneButton" : "layoutCancelButton", in: app)
            _ = waitForFurnitureOrientation("catBed", shouldSave ? "mirrored" : "normal", phase: "idle", in: app)
            let finished = try fullRoomState(in: app)
            if shouldSave {
                XCTAssertNotEqual(finished.savedFurniture, original.savedFurniture)
                savedBed = moved
            } else {
                let restored = try XCTUnwrap(finished.items.first { $0.id == "catBed" })
                XCTAssertEqual(restored.worldX, originalBed.worldX, accuracy: 0.008)
                XCTAssertEqual(restored.worldY, originalBed.worldY, accuracy: 0.008)
                XCTAssertEqual(finished.savedFurniture, original.savedFurniture)
                app.terminate()
                app.launchArguments = arguments(reset: false) + ["--room-zoom-fixture", "--furniture-test"]
                launchAndEnterHome(app)
                _ = waitForFurnitureOrientation("catBed", "normal", phase: "idle", in: app)
                let cancelledOnDisk = try fullRoomState(in: app)
                let reopenedBed = try XCTUnwrap(cancelledOnDisk.items.first { $0.id == "catBed" })
                XCTAssertEqual(cancelledOnDisk.savedFurniture, original.savedFurniture,
                               "Cancelling must preserve the original layout on disk, not only restore the live preview.")
                XCTAssertEqual(reopenedBed.worldX, originalBed.worldX, accuracy: 0.008)
                XCTAssertEqual(reopenedBed.worldY, originalBed.worldY, accuracy: 0.008)
                XCTAssertEqual(reopenedBed.orientation, "normal")
                waitForObservedValue("goldCount", "5,000", in: app)
                waitForObservedValue("foodCount", "3", in: app)
            }
        }
        _ = reopenFurnitureOrientationRoom(app)
        let reopened = try fullRoomState(in: app)
        let persisted = try XCTUnwrap(reopened.items.first { $0.id == "catBed" })
        let expected = try XCTUnwrap(savedBed)
        XCTAssertEqual(persisted.worldX, expected.worldX, accuracy: 0.008)
        XCTAssertEqual(persisted.worldY, expected.worldY, accuracy: 0.008)
        XCTAssertEqual(persisted.orientation, "mirrored")
        waitForObservedValue("goldCount", "5,000", in: app)
        waitForObservedValue("foodCount", "3", in: app)
    }

    @MainActor
    func testExpandedRoomFurnitureFacingDraftSaveStorageAndUpwardDrag() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--room-zoom-fixture", "--rest-test"]
        launchAndEnterHome(app)
        let initial = waitForFurniture(in: app, description: "expanded room ready for furniture direction changes") {
            $0.phase == "idle" && !$0.pending
        }
        let original = try XCTUnwrap(initial.items.first { $0.id == "catBed" })
        XCTAssertEqual(original.orientation, "normal")

        tapAnimationControl("homeDecorateButton", in: app)
        _ = try selectFurnitureForFacing("catBed", in: app)
        waitForObservedValue("flipFurnitureButton", "默认朝向", in: app)
        let flip = element("flipFurnitureButton", in: app)
        XCTAssertGreaterThanOrEqual(flip.frame.width, 44)
        XCTAssertGreaterThanOrEqual(flip.frame.height, 44)
        tapAnimationControl("flipFurnitureButton", in: app)
        _ = waitForFurnitureOrientation("catBed", "mirrored", in: app)
        waitForObservedValue("flipFurnitureButton", "反向朝向", in: app)
        tapAnimationControl("layoutCancelButton", in: app)
        let cancelled = waitForFurnitureOrientation("catBed", "normal", phase: "idle", in: app)
        let cancelledBed = try XCTUnwrap(cancelled.items.first { $0.id == "catBed" })
        XCTAssertEqual(cancelledBed.x, original.x, accuracy: 0.008)
        XCTAssertEqual(cancelledBed.y, original.y, accuracy: 0.008)

        tapAnimationControl("homeDecorateButton", in: app)
        _ = try selectFurnitureForFacing("catBed", in: app)
        tapAnimationControl("flipFurnitureButton", in: app)
        _ = waitForFurnitureOrientation("catBed", "mirrored", in: app)
        tapAnimationControl("layoutTrayToggle", in: app)
        waitForObservedValue("layoutTrayToggle", "collapsed", in: app)
        let mirrored = furnitureState(in: app)
        let beforeMove = try XCTUnwrap(mirrored.items.first { $0.id == "catBed" })
        // The upgraded world projects differently from a level-one room;
        // use its live screen position rather than the old artwork conversion.
        let moved = dragFurniture(beforeMove,
                                  to: CGVector(dx: beforeMove.x, dy: beforeMove.y - 0.10), in: app)
        let movedBed = try XCTUnwrap(moved.items.first { $0.id == "catBed" })
        XCTAssertLessThan(movedBed.y, beforeMove.y - 0.04,
                          "A level-three cat bed must actually move toward the wall instead of staying below the old boundary.")
        XCTAssertEqual(movedBed.orientation, "mirrored")
        attachScreenshot(app, named: "Expanded room — mirrored cat bed moved upward before saving")
        tapAnimationControl("layoutDoneButton", in: app)
        _ = waitForFurnitureOrientation("catBed", "mirrored", phase: "idle", in: app)
        let reopened = reopenFurnitureOrientationRoom(app)
        let savedBed = try XCTUnwrap(reopened.items.first { $0.id == "catBed" })
        XCTAssertEqual(savedBed.orientation, "mirrored")
        XCTAssertEqual(savedBed.x, movedBed.x, accuracy: 0.008)
        XCTAssertEqual(savedBed.y, movedBed.y, accuracy: 0.008)

        tapAnimationControl("homeDecorateButton", in: app)
        _ = try selectFurnitureForFacing("catBed", in: app)
        tapAnimationControl("storeFurnitureButton", in: app)
        _ = waitForFurniture(in: app, description: "mirrored cat bed moved into the draft bag") {
            !$0.pending && !$0.items.contains { $0.id == "catBed" }
        }
        tapAnimationControl("layoutDoneButton", in: app)
        _ = waitForFurniture(in: app, description: "stored cat bed saved") {
            $0.phase == "idle" && !$0.pending && !$0.items.contains { $0.id == "catBed" }
        }
        let stored = reopenFurnitureOrientationRoom(app)
        XCTAssertFalse(stored.items.contains { $0.id == "catBed" })
        tapAnimationControl("tabInventory", in: app)
        scrollCareerPage("destinationScroll", to: "inventoryFurnitureTab", in: app)
        tapAnimationControl("inventoryFurnitureTab", in: app)
        selectBagFurniture("catBed", in: app)
        tapAnimationControl("placeFurniture_catBed", in: app)
        _ = waitForFurnitureOrientation("catBed", "mirrored", in: app)
        waitForObservedValue("flipFurnitureButton", "反向朝向", in: app)
        attachScreenshot(app, named: "Furniture bag — placing the saved bed preserves its direction")
        tapAnimationControl("layoutDoneButton", in: app)
        _ = waitForFurnitureOrientation("catBed", "mirrored", phase: "idle", in: app)
        let replaced = reopenFurnitureOrientationRoom(app)
        XCTAssertEqual(replaced.items.count, initial.items.count)
        XCTAssertEqual(replaced.items.first { $0.id == "catBed" }?.orientation, "mirrored")
        let resting = try beginFurnitureRest("catBed", in: app)
        XCTAssertEqual(resting.items.first { $0.id == "catBed" }?.orientation, "mirrored")
        attachScreenshot(app, named: "Reversed cat bed — climbing and resting keep real paw and rim contact")
        waitForObservedValue("goldCount", "5,000", in: app)
        waitForObservedValue("foodCount", "3", in: app)
    }

    @MainActor
    func testFurnitureFacingControlsExcludeWallsAndBowlAndCancelAllChanges() throws {
        continueAfterFailure = false
        let app = launchFurnitureHome()
        tapAnimationControl("homeDecorateButton", in: app)
        let editing = waitForFurniture(in: app, description: "furniture controls initially select the bowl") {
            $0.phase == "editing" && !$0.pending && $0.selected == "bowl"
        }
        waitForElement("flipFurnitureButton", in: app)
        tapAnimationControl("flipFurnitureButton", in: app)
        waitForLabel("actionToast", "食盆不提供转向", in: app, contains: true)
        let frontToBack = editing.items.sorted {
            if $0.isWall != $1.isWall { return !$0.isWall }
            if $0.y != $1.y { return $0.y > $1.y }
            return $0.id < $1.id
        }
        var flippedKinds = Set<String>()
        var capturedWallExplanation = false
        for item in frontToBack {
            _ = try selectFurnitureForFacing(item.id, in: app)
            XCTAssertTrue(element("flipFurnitureButton", in: app).isEnabled)
            if !item.isWall {
                tapAnimationControl("flipFurnitureButton", in: app)
                _ = waitForFurnitureOrientation(item.id, "mirrored", in: app)
                flippedKinds.insert(item.kind)
            } else {
                tapAnimationControl("flipFurnitureButton", in: app)
                waitForLabel("actionToast", "墙饰贴在墙上，不能左右转向", in: app, contains: true)
                XCTAssertEqual(furnitureState(in: app).items.first { $0.id == item.id }?.orientation, "normal")
                if !capturedWallExplanation {
                    attachScreenshot(app, named: "F3 — wall direction is unavailable with an explanation")
                    capturedWallExplanation = true
                }
            }
            tapAnimationControl("storeFurnitureButton", in: app)
            _ = waitForFurniture(in: app, description: "stored \(item.id) reveals the next furniture control") {
                !$0.pending && !$0.items.contains { $0.id == item.id }
            }
        }
        XCTAssertEqual(flippedKinds, Set(["cabinet", "catTree", "catBed", "plant", "floorCushion", "flowerStool"]))
        tapAnimationControl("layoutCancelButton", in: app)
        let cancelled = waitForFurniture(in: app, description: "cancelling restores every original placement and direction") {
            $0.phase == "idle" && !$0.pending && $0.items.count == editing.items.count
        }
        XCTAssertTrue(cancelled.items.allSatisfy { $0.orientation == "normal" })
        attachScreenshot(app, named: "Furniture directions — cancelling restores all original furniture")
        waitForObservedValue("goldCount", "200", in: app)
        waitForObservedValue("foodCount", "3", in: app)
    }

    @MainActor
    func testArrangementSegmentsQuickActionsAndUnsavedBadgeUseOneDraft() throws {
        continueAfterFailure = false
        let app = launchFurnitureHome()
        tapAnimationControl("homeDecorateButton", in: app)
        _ = try selectFurnitureForFacing("catBed", in: app)
        XCTAssertFalse(element("layoutUnsavedChanges", in: app).exists)
        let initialControls = ["flipFurnitureButton", "quickStoreFurnitureButton", "storeFurnitureButton",
                               "furnitureOrientation_normal", "furnitureOrientation_mirrored", "layoutDoneButton"]
            .map { id in
                let control = element(id, in: app)
                return "\(id): exists=\(control.exists), enabled=\(control.isEnabled), hittable=\(control.isHittable), frame=\(control.frame)"
            }.joined(separator: "\n")
        let initialHitTesting = XCTAttachment(string: initialControls + "\nScene: \(element("roomScene", in: app).value ?? "nil")\n\n" + app.debugDescription)
        initialHitTesting.name = "Arrangement — initial button hit testing and accessibility hierarchy"
        initialHitTesting.lifetime = .keepAlways
        add(initialHitTesting)
        attachScreenshot(app, named: "Arrangement — initial quick-action hit-testing checkpoint")
        for id in ["flipFurnitureButton", "quickStoreFurnitureButton"] {
            let button = element(id, in: app)
            if !(button.exists && button.isEnabled && button.isHittable) {
                let ready = XCTNSPredicateExpectation(
                    predicate: NSPredicate(format: "exists == true AND enabled == true AND hittable == true"), object: button)
                let result = XCTWaiter.wait(for: [ready], timeout: 8)
                if result != .completed {
                    let failure = XCTAttachment(string: "\(id): enabled=\(button.isEnabled), frame=\(button.frame)\n" + app.debugDescription)
                    failure.name = "Arrangement — quick-action hit-testing timeout"
                    failure.lifetime = .keepAlways
                    add(failure)
                    attachScreenshot(app, named: "Arrangement — quick-action hit-testing timeout")
                }
                XCTAssertEqual(result, .completed, "\(id) must become enabled and hittable after native layout or saving settles.")
            }
            XCTAssertTrue(button.isHittable, "\(id) must remain tappable after settling.")
            XCTAssertGreaterThanOrEqual(button.frame.minX, app.frame.minX + 10)
            XCTAssertLessThanOrEqual(button.frame.maxX, app.frame.maxX - 10)
            XCTAssertGreaterThanOrEqual(button.frame.width, 44)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
        }
        for id in ["furnitureOrientation_normal", "furnitureOrientation_mirrored"] {
            XCTAssertGreaterThanOrEqual(element(id, in: app).frame.height, 44)
        }
        attachScreenshot(app, named: "F1 — default furniture direction and quick actions")
        tapAnimationControl("furnitureOrientation_mirrored", in: app)
        _ = waitForFurnitureOrientation("catBed", "mirrored", in: app)
        waitForElement("layoutUnsavedChanges", in: app)
        waitForObservedValue("flipFurnitureButton", "反向朝向", in: app)
        attachScreenshot(app, named: "F2 — mirrored selection, segments and unsaved state")
        tapAnimationControl("furnitureOrientation_normal", in: app)
        _ = waitForFurnitureOrientation("catBed", "normal", in: app)
        XCTAssertFalse(element("layoutUnsavedChanges", in: app).exists)
        tapAnimationControl("quickStoreFurnitureButton", in: app)
        _ = waitForFurniture(in: app, description: "quick storage uses the same arrangement draft") {
            !$0.pending && !$0.items.contains { $0.id == "catBed" }
        }
        waitForElement("layoutUnsavedChanges", in: app)
        tapAnimationControl("layoutCancelButton", in: app)
        _ = waitForFurnitureOrientation("catBed", "normal", phase: "idle", in: app)
        waitForLabel("actionToast", "已恢复原来的布置", in: app, contains: true)

        tapAnimationControl("homeDecorateButton", in: app)
        _ = try selectFurnitureForFacing("catBed", in: app)
        tapAnimationControl("furnitureInventoryButton", in: app)
        waitForElement("layoutReturnButton", in: app)
        XCTAssertFalse(element("flipFurnitureButton", in: app).exists)
        tapAnimationControl("layoutReturnButton", in: app)
        _ = waitForFurniture(in: app, description: "returning from the bag restores the same selected furniture") {
            $0.phase == "editing" && !$0.pending && $0.selected == "catBed"
        }
        waitForObservedValue("flipFurnitureButton", "默认朝向", in: app)
        XCTAssertTrue(element("flipFurnitureButton", in: app).isHittable)
        XCTAssertTrue(element("quickStoreFurnitureButton", in: app).isHittable)
        XCTAssertFalse(element("layoutUnsavedChanges", in: app).exists)
        tapAnimationControl("layoutCancelButton", in: app)
        _ = waitForFurnitureOrientation("catBed", "normal", phase: "idle", in: app)
    }

    @MainActor
    private func selectFurnitureForFacing(_ id: String, in app: XCUIApplication) throws -> FurnitureState {
        if element("layoutTrayToggle", in: app).value as? String == "expanded" {
            tapAnimationControl("layoutTrayToggle", in: app)
            waitForObservedValue("layoutTrayToggle", "collapsed", in: app)
        }
        let selected = try selectFurniture(id, in: app)
        tapAnimationControl("layoutTrayToggle", in: app)
        waitForObservedValue("layoutTrayToggle", "expanded", in: app)
        waitForElement("flipFurnitureButton", in: app)
        return selected
    }

    @MainActor
    private func waitForFurnitureOrientation(_ id: String, _ orientation: String, phase: String = "editing",
                                            in app: XCUIApplication) -> FurnitureState {
        waitForFurniture(in: app, timeout: 25, description: "\(id) is \(orientation) during \(phase)") {
            $0.phase == phase && !$0.pending && $0.items.first { $0.id == id }?.orientation == orientation
        }
    }

    @MainActor
    private func reopenFurnitureOrientationRoom(_ app: XCUIApplication) -> FurnitureState {
        app.terminate()
        app.launchArguments = arguments(reset: false) + ["--rest-test"]
        launchAndEnterHome(app)
        return waitForFurniture(in: app, description: "room reopens with saved furniture directions") {
            $0.phase == "idle" && !$0.pending
        }
    }

    private struct FullRoomItem: Decodable {
        let id: String
        let kind: String
        let orientation: String
        let x, y, worldX, worldY, footprintWidth, footprintHeight: Double
    }

    private struct FullRoomState: Decodable {
        struct Placement: Decodable, Equatable {
            let itemID: String
            let x, y: Double
        }
        let cameraScale, cameraX, cameraY, worldWidth, worldHeight, viewportWidth, viewportHeight: Double
        let pending: Bool
        let dragPreviewSamples: Int
        let dragPreviewWorld: FurniturePoint?
        let items: [FullRoomItem]
        let savedFurniture: [Placement]

        func screenPoint(worldTopLeft point: CGPoint) -> CGVector {
            CGVector(dx: ((Double(point.x) - cameraX) / cameraScale + viewportWidth / 2) / viewportWidth,
                     dy: (viewportHeight / 2 - (worldHeight - Double(point.y) - cameraY) / cameraScale) / viewportHeight)
        }
    }

    @MainActor
    private func fullRoomState(in app: XCUIApplication) throws -> FullRoomState {
        let text = try XCTUnwrap(element("roomScene", in: app).value as? String)
        return try JSONDecoder().decode(FullRoomState.self, from: Data(text.utf8))
    }

    @MainActor
    private func attachFullRoomDiagnostic(_ app: XCUIApplication, name: String, target: CGPoint, state: FullRoomState) {
        let detail = "targetWorldTopLeft=\(target), targetScreen=\(state.screenPoint(worldTopLeft: target))\n"
            + String(describing: element("roomScene", in: app).value)
        let attachment = XCTAttachment(string: detail)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
