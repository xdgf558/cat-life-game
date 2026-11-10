import XCTest

extension RoomHomeUITests {
    @MainActor
    func testCompanionship67MovedCushionEarnsANewMemoryOnlyAfterANaturalRest() throws {
        continueAfterFailure = false
        let app = launchRestHome()
        let original = try companion67Position("floorCushion", in: app)
        tapAnimationControl("homeDecorateButton", in: app)
        if element("layoutTrayToggle", in: app).value as? String == "expanded" {
            tapAnimationControl("layoutTrayToggle", in: app)
            waitForObservedValue("layoutTrayToggle", "collapsed", in: app)
        }
        var editing = waitForFurniture(in: app, description: "the cushion is ready for a real move") {
            $0.phase == "editing" && !$0.pending
        }
        var displacement = 0.0
        for target in [CGVector(dx: 0.50, dy: 0.80), CGVector(dx: 0.62, dy: 0.77),
                       CGVector(dx: 0.46, dy: 0.64)] {
            let cushion = try XCTUnwrap(editing.items.first { $0.id == "floorCushion" })
            editing = dragFurniture(cushion, to: target, in: app)
            let moved = try companion67Position("floorCushion", in: app)
            displacement = hypot(moved.x - original.x, moved.y - original.y)
            if displacement > 0.15 { break }
        }
        XCTAssertGreaterThan(displacement, 0.15, "The actual saved-position delta must qualify, not only a screen-space drag.")
        attachScreenshot(app, named: "Companionship 67 — cushion moved beyond the real location threshold")
        tapAnimationControl("layoutDoneButton", in: app)
        _ = waitForFurniture(in: app, description: "the new cushion location is committed") { $0.phase == "idle" && !$0.pending }
        _ = relaunchRestHome(app)
        _ = waitForFurniture(in: app, description: "the moved room returns after a cold launch") { $0.phase == "idle" && !$0.pending }
        try openCurrentCatProfile(in: app)
        XCTAssertFalse(element("catMemory_settledAfterMove", in: app).exists, "Moving furniture alone must not invent a memory.")
        tapAnimationControl("closeSheetButton", in: app)
        tapAnimationControl("tabHome", in: app)
        _ = try beginFurnitureRest("floorCushion", in: app)
        attachScreenshot(app, named: "Companionship 67 — the cat climbs onto the moved cushion")
        waitForElement("habitCornerOffer", in: app, timeout: 25)
        tapAnimationControl("habitCornerLater", in: app)
        _ = waitForFurniture(in: app, description: "the complete observation finishes naturally") {
            $0.phase == "idle" && $0.restPhase == "none" && !$0.pending
        }
        assertRestSuppliesUnchanged(in: app)
        try openCurrentCatProfile(in: app)
        scrollCareerPage("catProfileScroll", to: "catMemory_settledAfterMove", in: app)
        XCTAssertTrue(element("catMemory_settledAfterMove", in: app).isHittable)
        XCTAssertFalse(element("catMemory_understandEachOther", in: app).exists,
                       "A moved cushion cannot replace both confirmed preferences and a corner.")
        attachScreenshot(app, named: "Companionship 67 — a new place becomes a saved memory")
        tapAnimationControl("closeSheetButton", in: app)
        _ = relaunchRestHome(app)
        try openCurrentCatProfile(in: app)
        scrollCareerPage("catProfileScroll", to: "catMemory_settledAfterMove", in: app)
        XCTAssertTrue(element("catMemory_settledAfterMove", in: app).isHittable)
    }

    @MainActor
    private func companion67Position(_ id: String, in app: XCUIApplication) throws -> CGPoint {
        let text = try XCTUnwrap(element("roomScene", in: app).value as? String)
        let payload = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        let placements = try XCTUnwrap(payload["savedFurniture"] as? [[String: Any]])
        let item = try XCTUnwrap(placements.first { $0["itemID"] as? String == id })
        return CGPoint(x: try XCTUnwrap(item["x"] as? Double), y: try XCTUnwrap(item["y"] as? Double))
    }
}
