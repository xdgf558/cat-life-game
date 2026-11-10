import XCTest

extension RoomHomeUITests {
    @MainActor
    func testFrontRoom66StarterAndSharedHomesKeepLayoutAcrossViewsAndDecorationCancel() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        for (name, fixtures) in [("starter", ["--furniture-test"]),
                                 ("shared level 4", ["--shared-home-test", "--furniture-test"])] {
            app.terminate()
            app.launchArguments = arguments(reset: true) + fixtures
            launchAndEnterHome(app)
            let original = try waitForFrontRoom66(angle: 0, in: app)
            let originalLayout = try frontRoom66Layout(original)
            XCTAssertEqual(original["wholeRoom"] as? Bool, true)
            let stage = element("roomStage63", in: app).frame
            XCTAssertTrue(app.frame.contains(stage))
            for id in ["feedButton", "cleanButton", "playButton", "roomViewLeftButton", "roomViewRightButton"] {
                XCTAssertTrue(element(id, in: app).isHittable, "The front-facing room must keep \(id) reachable.")
            }
            attachScreenshot(app, named: "Front 66 — \(name), default straight room")

            for (control, angle) in [("roomViewLeftButton", -1), ("roomViewRightButton", 0),
                                     ("roomViewRightButton", 1), ("roomViewLeftButton", 0)] {
                tapAnimationControl(control, in: app)
                let current = try waitForFrontRoom66(angle: angle, in: app)
                XCTAssertEqual(try frontRoom66Layout(current), originalLayout,
                               "A presentation change must not move saved furniture or the food bowl.")
                XCTAssertEqual(element("roomStage63", in: app).frame, stage)
                if angle != 0 { attachScreenshot(app, named: "Front 66 — \(name), supporting view \(angle)") }
            }

            tapAnimationControl("homeDecorateButton", in: app)
            waitForElement("layoutCancelButton", in: app)
            _ = waitForFurniture(in: app, description: "front-facing furniture is ready for editing",
                                 matching: { $0.phase == "editing" && !$0.pending })
            let moved = try moveFrontRoom66Cabinet(in: app)
            XCTAssertEqual(moved.selected, "cabinet")
            attachScreenshot(app, named: "Front 66 — \(name), cabinet dragged in the real front room")
            tapAnimationControl("layoutCancelButton", in: app)
            waitForElement("homeDecorateButton", in: app)
            let restored = try waitForFrontRoom66(angle: 0, in: app)
            XCTAssertEqual(try frontRoom66Layout(restored), originalLayout)
            app.terminate()
            app.launchArguments = arguments(reset: false) + ["--furniture-test"]
            launchAndEnterHome(app)
            XCTAssertEqual(try frontRoom66Layout(waitForFrontRoom66(angle: 0, in: app)), originalLayout,
                           "A cancelled drag must leave the durable layout unchanged after cold launch.")
            attachScreenshot(app, named: "Front 66 — \(name), cancellation preserves layout after cold launch")
        }
    }

    @MainActor
    func testFrontRoom66FurnitureDragAndFacingSurviveColdLaunchWhileCancelledWallAndStorageRestore() throws {
        continueAfterFailure = false
        let app = launchFurnitureHome()
        let original = try waitForFrontRoom66(angle: 0, in: app)
        let originalLayout = try frontRoom66Layout(original)
        let originalPositions = try frontRoom66SavedPositions(original)
        tapAnimationControl("homeDecorateButton", in: app)
        _ = waitForFurniture(in: app, description: "front room ready for a saved furniture move") {
            $0.phase == "editing" && !$0.pending
        }
        _ = try moveFrontRoom66Cabinet(in: app)
        tapAnimationControl("flipFurnitureButton", in: app)
        _ = waitForFurniture(in: app, description: "moved cabinet is mirrored in the draft") {
            !$0.pending && $0.items.first { $0.id == "cabinet" }?.orientation == "mirrored"
        }
        // The scene payload reflects the draft; durable persistence is checked after cold launch below.
        attachScreenshot(app, named: "Front 66 — moved and mirrored cabinet before saving")
        tapAnimationControl("layoutDoneButton", in: app)
        let saved = try waitForFrontRoom66(angle: 0, in: app)
        let savedLayout = try frontRoom66Layout(saved)
        XCTAssertNotEqual(savedLayout, originalLayout)
        let savedPositions = try frontRoom66SavedPositions(saved)
        XCTAssertNotEqual(savedPositions["cabinet"], originalPositions["cabinet"])
        for id in originalPositions.keys where id != "cabinet" {
            XCTAssertEqual(savedPositions[id], originalPositions[id], "Moving the cabinet must preserve \(id).")
        }
        XCTAssertEqual(try JSONSerialization.data(withJSONObject: XCTUnwrap(saved["savedBowl"]), options: .sortedKeys),
                       try JSONSerialization.data(withJSONObject: XCTUnwrap(original["savedBowl"]), options: .sortedKeys))

        app.terminate()
        app.launchArguments = arguments(reset: false) + ["--furniture-test"]
        launchAndEnterHome(app)
        let reopened = try waitForFrontRoom66(angle: 0, in: app)
        XCTAssertEqual(try frontRoom66Layout(reopened), savedLayout,
                       "Cold launch must retain the actual saved coordinates, independently of camera framing.")
        XCTAssertEqual(furnitureState(in: app).items.first { $0.id == "cabinet" }?.orientation, "mirrored")
        attachScreenshot(app, named: "Front 66 — cabinet placement and facing restored after cold launch")

        tapAnimationControl("homeDecorateButton", in: app)
        collapseFrontRoom66Tray(in: app)
        let editing = waitForFurniture(in: app, description: "front wall and floor are ready for dragging") {
            $0.phase == "editing" && !$0.pending
        }
        let picture = try XCTUnwrap(editing.items.first { $0.id == "wallFlower" })
        let floorTarget = CGVector(dx: editing.bowl.x, dy: editing.bowl.y)
        let wallDraft = dragFurniture(picture, to: floorTarget, in: app)
        XCTAssertGreaterThan(try XCTUnwrap(frontRoom66Payload(in: app)["dragPreviewSamples"] as? Int), 0,
                             "The wall constraint must be exercised by a real drag, rather than a selection-only tap.")
        let constrainedPicture = try XCTUnwrap(wallDraft.items.first { $0.id == "wallFlower" })
        XCTAssertGreaterThan(hypot(constrainedPicture.x - floorTarget.dx, constrainedPicture.y - floorTarget.dy), 0.12,
                             "A wall picture dragged toward the bowl must stay on the wall.")
        tapAnimationControl("quickStoreFurnitureButton", in: app)
        _ = waitForFurniture(in: app, description: "wall picture is stored only in the current front-room draft") {
            !$0.pending && !$0.items.contains { $0.id == "wallFlower" }
        }
        attachScreenshot(app, named: "Front 66 — wall picture constrained and stored in the draft")
        tapAnimationControl("layoutCancelButton", in: app)
        let cancelled = try waitForFrontRoom66(angle: 0, in: app)
        XCTAssertEqual(try frontRoom66Layout(cancelled), savedLayout,
                       "Cancelling must restore both the saved floor layout and wall picture coordinates.")
        XCTAssertEqual(furnitureState(in: app).items.first { $0.id == "cabinet" }?.orientation, "mirrored")
        app.terminate()
        app.launchArguments = arguments(reset: false) + ["--furniture-test"]
        launchAndEnterHome(app)
        XCTAssertEqual(try frontRoom66Layout(waitForFrontRoom66(angle: 0, in: app)), savedLayout,
                       "Cancelled wall moves and storage must not reach the durable save.")
    }

    @MainActor
    private func moveFrontRoom66Cabinet(in app: XCUIApplication) throws -> FurnitureState {
        collapseFrontRoom66Tray(in: app)
        let original = try XCTUnwrap(furnitureState(in: app).items.first { $0.id == "cabinet" })
        let originalWorld = try frontRoom66WorldPoint("cabinet", in: app)
        let room = element("roomScene", in: app)
        // Targets are relative to the displayed cabinet, not to the obsolete artwork projection.
        for offset in [(0.14, 0.10), (-0.12, 0.16), (0.0, 0.23)] {
            let current = try XCTUnwrap(furnitureState(in: app).items.first { $0.id == "cabinet" })
            let target = CGVector(dx: min(0.84, max(0.16, original.x + offset.0)),
                                  dy: min(0.82, max(0.25, original.y + offset.1)))
            room.coordinate(withNormalizedOffset: CGVector(dx: current.x, dy: current.y - 0.02))
                .press(forDuration: 0.15,
                       thenDragTo: room.coordinate(withNormalizedOffset: CGVector(dx: target.dx, dy: target.dy - 0.02)),
                       withVelocity: .slow, thenHoldForDuration: 0)
            let state = waitForFurniture(in: app, timeout: 25, description: "real cabinet drag resolves in the front room") {
                $0.phase == "editing" && $0.selected == "cabinet" && !$0.pending
            }
            let movedWorld = try frontRoom66WorldPoint("cabinet", in: app)
            if hypot(movedWorld.x - originalWorld.x, movedWorld.y - originalWorld.y) > 0.02 {
                XCTAssertTrue(element("layoutDoneButton", in: app).isEnabled)
                return state
            }
        }
        XCTFail("A real cabinet drag must change its physical position, rather than only moving the camera.")
        return furnitureState(in: app)
    }

    @MainActor
    private func collapseFrontRoom66Tray(in app: XCUIApplication) {
        if element("layoutTrayToggle", in: app).value as? String == "expanded" {
            tapAnimationControl("layoutTrayToggle", in: app)
            waitForObservedValue("layoutTrayToggle", "collapsed", in: app)
        }
    }

    @MainActor
    private func frontRoom66Payload(in app: XCUIApplication) throws -> [String: Any] {
        let text = try XCTUnwrap(element("roomScene", in: app).value as? String)
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    }

    @MainActor
    private func frontRoom66WorldPoint(_ id: String, in app: XCUIApplication) throws -> CGPoint {
        let items = try XCTUnwrap(try frontRoom66Payload(in: app)["items"] as? [[String: Any]])
        let item = try XCTUnwrap(items.first { $0["id"] as? String == id })
        return CGPoint(x: try XCTUnwrap(item["worldX"] as? Double), y: try XCTUnwrap(item["worldY"] as? Double))
    }

    private func frontRoom66SavedPositions(_ state: [String: Any]) throws -> [String: Data] {
        let items = try XCTUnwrap(state["savedFurniture"] as? [[String: Any]])
        return try Dictionary(uniqueKeysWithValues: items.map {
            (try XCTUnwrap($0["itemID"] as? String),
             try JSONSerialization.data(withJSONObject: $0, options: .sortedKeys))
        })
    }

    @MainActor
    private func waitForFrontRoom66(angle: Int, in app: XCUIApplication) throws -> [String: Any] {
        let room = element("roomScene", in: app)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard room.exists, let text = room.value as? String,
                  let state = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] else { return false }
            return state["phase"] as? String == "idle" && state["pending"] as? Bool == false
                && state["residentsBusy"] as? Bool == false && state["viewAngle"] as? Int == angle
        }, object: room)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 25), .completed,
                       "The real front-room scene must settle in the requested view.")
        let text = try XCTUnwrap(room.value as? String)
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    }

    private func frontRoom66Layout(_ state: [String: Any]) throws -> Data {
        let furniture = try XCTUnwrap(state["savedFurniture"])
        let bowl = try XCTUnwrap(state["savedBowl"])
        return try JSONSerialization.data(withJSONObject: ["furniture": furniture, "bowl": bowl], options: .sortedKeys)
    }
}
