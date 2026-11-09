import XCTest

extension RoomHomeUITests {
    @MainActor
    func testIntegratedFiveCatPreviewsStayAnchoredAcrossFloorsAndFixedRoomViews() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true)
            + ["--shared-home-test", "--shared-home-upper-test", "--furniture-test"]
        launchAndEnterHome(app)
        waitForObservedValue("homeCaringContext", "cat_001", in: app)
        let contextFrame = integrated62Element("homeCaringContext", in: app).frame

        for (index, floor) in ["1F · 一楼", "2F · 二楼"].enumerated() {
            if index > 0 { tapAnimationControl("homeStairsButton", in: app) }
            waitForObservedValue("homeStairsButton", floor, in: app)
            let original = try integrated62Wait(in: app, angle: 0, whole: true)
            integrated62AssertRoom(original, original: original, contextFrame: contextFrame, in: app)
            integrated62Screenshot("Integrated 62 — \(floor), front, five cats", in: app)

            let targetID = try integrated62OpenResident(from: original, in: app)
            integrated62AssertPreview(targetID, contextFrame: contextFrame, in: app)
            let previewed = try integrated62Wait(in: app, angle: 0, whole: true)
            integrated62AssertRoom(previewed, original: original, contextFrame: contextFrame, in: app)

            tapAnimationControl("roomViewLeftButton", in: app)
            let left = try integrated62Wait(in: app, angle: -1, whole: true)
            integrated62AssertRoom(left, original: original, contextFrame: contextFrame, in: app)
            integrated62AssertPreview(targetID, contextFrame: contextFrame, in: app)
            integrated62Screenshot("Integrated 62 — \(floor), left, resident preview", in: app)

            tapAnimationControl("focusCatButton", in: app)
            let close = try integrated62Wait(in: app, angle: -1, whole: false)
            integrated62AssertIdentityAndSave(close, original: original, contextFrame: contextFrame, in: app)
            integrated62AssertPreview(targetID, contextFrame: contextFrame, in: app)
            tapAnimationControl("roomOverviewButton", in: app)
            let overview = try integrated62Wait(in: app, angle: -1, whole: true)
            integrated62AssertRoom(overview, original: original, contextFrame: contextFrame, in: app)
            integrated62AssertPreview(targetID, contextFrame: contextFrame, in: app)

            let room = integrated62Element("roomScene", in: app)
            room.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 1))
                .withOffset(CGVector(dx: 4, dy: -4)).tap()
            let preview = integrated62Element("roomResidentPreview", in: app)
            let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: preview)
            XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 8), .completed,
                           "A tap four points inside the canvas bottom-left must close the resident preview.")

            tapAnimationControl("roomViewRightButton", in: app)
            let front = try integrated62Wait(in: app, angle: 0, whole: true)
            integrated62AssertRoom(front, original: original, contextFrame: contextFrame, in: app)
            tapAnimationControl("roomViewRightButton", in: app)
            let right = try integrated62Wait(in: app, angle: 1, whole: true)
            integrated62AssertRoom(right, original: original, contextFrame: contextFrame, in: app)
            integrated62Screenshot("Integrated 62 — \(floor), right, five cats", in: app)
            waitForObservedValue("foodCount", "12", in: app)
            waitForObservedValue("goldCount", "27,000", in: app)
        }
    }

    @MainActor
    func testChangingFloorsWithResidentPreviewOpenRestoresTheNewFloorsStatusCard() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true)
            + ["--shared-home-test", "--shared-home-upper-test", "--furniture-test"]
        launchAndEnterHome(app)
        waitForObservedValue("homeCaringContext", "cat_001", in: app)
        waitForElement("homeCatInfo", in: app)
        let original = try integrated62Wait(in: app, angle: 0, whole: true)
        let contextFrame = integrated62Element("homeCaringContext", in: app).frame
        let resources = try ["foodCount", "goldCount", "staminaCount"].map { identifier in
            (identifier, try XCTUnwrap(integrated62Element(identifier, in: app).value as? String))
        }
        let targetID = try integrated62OpenResident(from: original, in: app)
        integrated62AssertPreview(targetID, contextFrame: contextFrame, in: app)

        // Do not dismiss first: the outgoing host must relinquish this preview to the new floor owner.
        tapAnimationControl("homeFloor_upper", in: app)
        waitForObservedValue("homeStairsButton", "2F · 二楼", in: app)
        let upstairs = try integrated62Wait(in: app, angle: 0, whole: true)
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let status = self.integrated62Element("homeCatInfo", in: app)
            return !self.integrated62Element("roomResidentPreview", in: app).exists
                && status.exists && status.isHittable
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 10), .completed,
                       "The upstairs host must clear the old preview and restore its cat status card.")
        XCTAssertEqual(upstairs.activeCatID, original.activeCatID)
        XCTAssertEqual(upstairs.companionLabelText, original.companionLabelText)
        XCTAssertEqual(upstairs.completedMeals, original.completedMeals)
        XCTAssertEqual(upstairs.completedPounces, original.completedPounces)
        waitForObservedValue("homeCaringContext", "cat_001", in: app)
        XCTAssertEqual(integrated62Element("homeCaringContext", in: app).frame, contextFrame)
        for (identifier, value) in resources { waitForObservedValue(identifier, value, in: app) }
        integrated62Screenshot("Integrated 62 — switching floors closes a resident preview and restores status", in: app)

        tapAnimationControl("homeFloor_ground", in: app)
        waitForObservedValue("homeStairsButton", "1F · 一楼", in: app)
        let downstairs = try integrated62Wait(in: app, angle: 0, whole: true)
        XCTAssertFalse(integrated62Element("roomResidentPreview", in: app).exists)
        XCTAssertTrue(integrated62Element("homeCatInfo", in: app).exists)
        integrated62AssertIdentityAndSave(downstairs, original: original, contextFrame: contextFrame, in: app)
        for (identifier, value) in resources { waitForObservedValue(identifier, value, in: app) }
    }

    @MainActor
    private func integrated62Element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    private func integrated62Wait(in app: XCUIApplication, angle: Int, whole: Bool) throws -> Integrated62RoomState {
        let room = integrated62Element("roomScene", in: app)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard room.exists, let state = Integrated62RoomState(value: room.value) else { return false }
            return state.phase == "idle" && !state.residentsBusy && !state.pending
                && state.viewAngle == angle && state.wholeRoom == whole
                && state.residentCats.count == 5 && state.residentCats.allSatisfy {
                    $0.visible && $0.screenWidth > 0 && $0.screenHeight > 0
                        && [$0.x, $0.y, $0.screenWidth, $0.screenHeight].allSatisfy(\.isFinite)
                }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 25), .completed,
                       "Expected idle five-cat room at angle \(angle), whole \(whole); got \(room.value ?? "missing").")
        return try XCTUnwrap(Integrated62RoomState(value: room.value))
    }

    @MainActor
    private func integrated62AssertIdentityAndSave(_ state: Integrated62RoomState, original: Integrated62RoomState,
                                                   contextFrame: CGRect, in app: XCUIApplication,
                                                   file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(state.activeCatID, "cat_001", file: file, line: line)
        XCTAssertEqual(state.companionLabelText, "♥ 小橘", "The real projected name plaque must still name the care companion.", file: file, line: line)
        let context = integrated62Element("homeCaringContext", in: app)
        XCTAssertEqual(context.value as? String, "cat_001", file: file, line: line)
        XCTAssertEqual(context.label, "照顾：小橘", file: file, line: line)
        XCTAssertEqual(context.frame, contextFrame, "Previewing and changing the view must not move the fixed care recipient.", file: file, line: line)
        XCTAssertEqual(state.savedBowl, original.savedBowl, file: file, line: line)
        XCTAssertEqual(state.savedFurniture.sorted { $0.itemID < $1.itemID },
                       original.savedFurniture.sorted { $0.itemID < $1.itemID },
                       "View changes must not rewrite canonical furniture coordinates.", file: file, line: line)
        XCTAssertEqual(state.completedMeals, 0, file: file, line: line)
        XCTAssertEqual(state.completedPounces, 0, file: file, line: line)
        XCTAssertEqual(state.violations, 0, file: file, line: line)
        XCTAssertEqual(state.foodContactViolations, 0, file: file, line: line)
        XCTAssertEqual(state.residentCollisions, 0, file: file, line: line)
    }

    @MainActor
    private func integrated62AssertRoom(_ state: Integrated62RoomState, original: Integrated62RoomState,
                                        contextFrame: CGRect, in app: XCUIApplication,
                                        file: StaticString = #filePath, line: UInt = #line) {
        integrated62AssertIdentityAndSave(state, original: original, contextFrame: contextFrame, in: app, file: file, line: line)
        XCTAssertEqual(Set(state.residentCats.map(\.id)), Set(["cat_001", "cat_002", "cat_003", "cat_004", "cat_005"]), file: file, line: line)
        let roomFrame = integrated62Element("roomScene", in: app).frame
        let controls = ["playButton", "cleanButton", "feedButton"].map { integrated62Element($0, in: app) }
        for control in controls {
            XCTAssertTrue(control.exists && control.isHittable, "Care controls must remain reachable.", file: file, line: line)
        }
        for id in ["roomViewControls", "homeStairsButton"] {
            let tool = integrated62Element(id, in: app)
            XCTAssertTrue(tool.exists && tool.isHittable, "Room tools must remain reachable.", file: file, line: line)
            for control in controls {
                XCTAssertFalse(tool.frame.intersects(control.frame), "Room tool \(id) covers a care action.", file: file, line: line)
            }
        }
        for resident in state.residentCats {
            let frame = resident.frame(in: roomFrame)
            XCTAssertTrue(app.frame.contains(frame), "The whole-room view must contain the real frame of \(resident.id): \(frame).", file: file, line: line)
            for control in controls {
                XCTAssertFalse(frame.intersects(control.frame),
                               "Real cat frame \(resident.id) \(frame) overlaps care button \(control.identifier) \(control.frame).", file: file, line: line)
            }
        }
    }

    @MainActor
    private func integrated62OpenResident(from state: Integrated62RoomState, in app: XCUIApplication) throws -> String {
        let room = integrated62Element("roomScene", in: app)
        let hud = ["playButton", "cleanButton", "feedButton", "homeCaringContext", "homeCatInfo",
                   "catNeedBubble", "roomViewControls", "homeStairsButton"].map { integrated62Element($0, in: app) }.filter(\.exists)
        let target = try XCTUnwrap(state.residentCats.sorted { $0.id < $1.id }.first { resident in
            guard resident.id != state.activeCatID else { return false }
            let frame = resident.frame(in: room.frame)
            let center = CGPoint(x: frame.midX, y: frame.midY)
            return app.frame.contains(frame) && !hud.contains { $0.frame.contains(center) }
                && !state.residentCats.contains { $0.id != resident.id && $0.frame(in: room.frame).contains(center) }
        }, "Expected an exposed non-companion cat center to tap in the real room.")
        room.coordinate(withNormalizedOffset: CGVector(dx: target.x, dy: target.y)).tap()
        waitForObservedValue("roomResidentPreview", target.id, in: app)
        return target.id
    }

    @MainActor
    private func integrated62AssertPreview(_ targetID: String, contextFrame: CGRect, in app: XCUIApplication,
                                           file: StaticString = #filePath, line: UInt = #line) {
        waitForObservedValue("roomResidentPreview", targetID, in: app, file: file, line: line)
        let preview = integrated62Element("roomResidentPreview", in: app)
        XCTAssertTrue(app.frame.contains(preview.frame), "The resident preview must fit on screen.", file: file, line: line)
        let obstacles = ["playButton", "cleanButton", "feedButton", "homeCaringContext", "roomViewControls", "homeStairsButton"].map { integrated62Element($0, in: app) }
        for obstacle in obstacles {
            XCTAssertFalse(preview.frame.intersects(obstacle.frame),
                           "Preview \(preview.frame) covers \(obstacle.identifier) \(obstacle.frame).", file: file, line: line)
            XCTAssertTrue(obstacle.exists && obstacle.isHittable, "The preview must leave care controls and context accessible.", file: file, line: line)
        }
        XCTAssertEqual(integrated62Element("homeCaringContext", in: app).frame, contextFrame, file: file, line: line)
        for id in ["roomResidentGrowthButton", "roomResidentCompanionButton"] {
            let button = integrated62Element(id, in: app)
            XCTAssertTrue(button.exists && button.isEnabled && button.isHittable,
                          "Resident preview action \(id) is blocked.", file: file, line: line)
            XCTAssertTrue(app.frame.contains(button.frame), "Resident preview action \(id) must fit on screen.", file: file, line: line)
        }
    }

    @MainActor
    private func integrated62Screenshot(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

private struct Integrated62RoomState: Decodable {
    struct Point: Decodable, Equatable { let x: Double; let y: Double }
    struct Placement: Decodable, Equatable { let itemID: String; let x: Double; let y: Double }
    struct Resident: Decodable {
        let id: String
        let x: Double
        let y: Double
        let visible: Bool
        let screenWidth: Double
        let screenHeight: Double
        func frame(in room: CGRect) -> CGRect {
            CGRect(x: room.minX + CGFloat(x) * room.width - CGFloat(screenWidth) / 2,
                   y: room.minY + CGFloat(y) * room.height - CGFloat(screenHeight) / 2,
                   width: CGFloat(screenWidth), height: CGFloat(screenHeight))
        }
    }
    let phase: String
    let pending: Bool
    let activeCatID: String
    let companionLabelText: String
    let residentCats: [Resident]
    let residentsBusy: Bool
    let viewAngle: Int
    let wholeRoom: Bool
    let savedBowl: Point
    let savedFurniture: [Placement]
    let completedMeals: Int
    let completedPounces: Int
    let violations: Int
    let foodContactViolations: Int
    let residentCollisions: Int

    init?(value: Any?) {
        guard let text = value as? String, let data = text.data(using: .utf8),
              let state = try? JSONDecoder().decode(Self.self, from: data) else { return nil }
        self = state
    }
}
