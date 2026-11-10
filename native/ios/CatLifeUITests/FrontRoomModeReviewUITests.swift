import XCTest

extension RoomHomeUITests {
    @MainActor
    func testFrontRoomGeometryStaysTheSameAcrossHomeAndBothTrayStates() throws {
        continueAfterFailure = false
        let app = launchFurnitureHome()
        let normal = try captureRoomModeReview("normal", phase: "idle", in: app)
        attachScreenshot(app, named: "Room mode review — normal home")

        tapAnimationControl("homeDecorateButton", in: app)
        waitForObservedValue("layoutTrayToggle", "expanded", in: app)
        let expanded = try captureRoomModeReview("expanded", phase: "editing", in: app)
        attachScreenshot(app, named: "Room mode review — decoration, tray expanded")

        tapAnimationControl("layoutTrayToggle", in: app)
        waitForObservedValue("layoutTrayToggle", "collapsed", in: app)
        let collapsed = try captureRoomModeReview("collapsed", phase: "editing", in: app)
        attachScreenshot(app, named: "Room mode review — decoration, tray collapsed")

        tapAnimationControl("layoutTrayToggle", in: app)
        waitForObservedValue("layoutTrayToggle", "expanded", in: app)
        let reopened = try captureRoomModeReview("expanded again", phase: "editing", in: app)
        tapAnimationControl("layoutCancelButton", in: app)
        let restored = try captureRoomModeReview("normal after cancellation", phase: "idle", in: app)

        // Collect all three visual states before asserting, so the old distortion keeps its evidence.
        for state in [expanded, collapsed, reopened, restored] {
            XCTAssertEqual(state.layout, normal.layout, "Changing panels must not change saved furniture or bowl coordinates.")
            for (pair, expected) in normal.vectors {
                let actual = try XCTUnwrap(state.vectors[pair])
                XCTAssertEqual(actual.x, expected.x, accuracy: 0.03,
                               "\(state.name): \(pair) horizontal spacing must retain its shape relative to the cabinet artwork.")
                XCTAssertEqual(actual.y, expected.y, accuracy: 0.03,
                               "\(state.name): \(pair) depth must retain its shape relative to the cabinet artwork.")
            }
        }
        for (pair, expected) in expanded.vectors {
            let actual = try XCTUnwrap(reopened.vectors[pair])
            XCTAssertEqual(actual.x, expected.x, accuracy: 0.003, "Reopening the same tray must reproduce \(pair).")
            XCTAssertEqual(actual.y, expected.y, accuracy: 0.003, "Reopening the same tray must reproduce \(pair).")
        }
    }

    private struct RoomModeReviewSnapshot {
        let name: String
        let layout: Data
        let vectors: [String: CGPoint]
    }

    @MainActor
    private func captureRoomModeReview(_ name: String, phase: String,
                                      in app: XCUIApplication) throws -> RoomModeReviewSnapshot {
        let room = element("roomScene", in: app)
        var lastGeometry: Data?
        var stableSince: Date?
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard room.exists, let text = room.value as? String,
                  let state = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
                  state["phase"] as? String == phase, state["pending"] as? Bool == false,
                  state["bowlPlanning"] as? Bool == false, state["residentsBusy"] as? Bool == false,
                  state["viewAngle"] as? Int == 0,
                  let items = state["items"] as? [[String: Any]],
                  let viewportWidth = state["viewportWidth"], let viewportHeight = state["viewportHeight"],
                  let cameraScale = state["cameraScale"],
                  let geometry = try? JSONSerialization.data(withJSONObject: [
                    "width": viewportWidth, "height": viewportHeight,
                    "cameraScale": cameraScale, "items": items
                  ], options: .sortedKeys) else { return false }
            if geometry != lastGeometry { lastGeometry = geometry; stableSince = Date(); return false }
            return stableSince.map { Date().timeIntervalSince($0) >= 0.4 } ?? false
        }, object: room)
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 25), .completed,
                       "The actual front room must settle after changing to \(name).")
        let text = try XCTUnwrap(room.value as? String)
        let state = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        let items = try XCTUnwrap(state["items"] as? [[String: Any]])
        let width = try XCTUnwrap(state["viewportWidth"] as? Double)
        let height = try XCTUnwrap(state["viewportHeight"] as? Double)
        XCTAssertEqual(width, room.frame.width, accuracy: 0.01, "Screen samples must use the displayed viewport, not the physical room reference.")
        XCTAssertEqual(height, room.frame.height, accuracy: 0.01)
        let cabinet = try XCTUnwrap(items.first { $0["id"] as? String == "cabinet" })
        let unit = try XCTUnwrap(cabinet["screenWidth"] as? Double)
        XCTAssertGreaterThan(unit, 0)
        func anchor(_ id: String) throws -> CGPoint {
            let item = try XCTUnwrap(items.first { $0["id"] as? String == id })
            return CGPoint(x: try XCTUnwrap(item["x"] as? Double) * width,
                           y: try XCTUnwrap(item["y"] as? Double) * height)
        }
        var vectors: [String: CGPoint] = [:]
        for (a, b) in [("cabinet", "catTree"), ("catBed", "floorCushion"),
                       ("cabinet", "flowerStool"), ("catTree", "plantSmall")] {
            let first = try anchor(a), second = try anchor(b)
            vectors[a + "→" + b] = CGPoint(x: (second.x - first.x) / unit, y: (second.y - first.y) / unit)
        }
        var evidence = state
        evidence["mode"] = name
        evidence["anchorVectorsInCabinetWidths"] = vectors.mapValues { ["x": $0.x, "y": $0.y] }
        evidence["roomViewFrame"] = ["x": room.frame.minX, "y": room.frame.minY,
                                     "width": room.frame.width, "height": room.frame.height]
        let json = try JSONSerialization.data(withJSONObject: evidence, options: [.sortedKeys, .prettyPrinted])
        let attachment = XCTAttachment(string: try XCTUnwrap(String(data: json, encoding: .utf8)))
        attachment.name = "Room mode review — \(name), geometry.json"
        attachment.lifetime = .keepAlways
        add(attachment)
        let layout = try JSONSerialization.data(withJSONObject: [
            "furniture": try XCTUnwrap(state["savedFurniture"]), "bowl": try XCTUnwrap(state["savedBowl"])
        ], options: .sortedKeys)
        return RoomModeReviewSnapshot(name: name, layout: layout, vectors: vectors)
    }
}
