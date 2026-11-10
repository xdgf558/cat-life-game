import XCTest

extension RoomHomeUITests {
    @MainActor
    func testRoomViewsOverviewFloorTravelAndFurnitureSaveSurviveReopening() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--home-floors-fixture", "--furniture-test"]
        launchAndEnterHome(app)
        _ = waitForFurniture(in: app, description: "level-five whole room ready") { $0.phase == "idle" && !$0.pending }
        let initial = try waitForRoomView61(angle: 0, whole: true, in: app)
        attachScreenshot(app, named: "Room 61 — complete front view")

        tapAnimationControl("roomViewLeftButton", in: app)
        let left = try waitForRoomView61(angle: -1, whole: true, in: app)
        assertRoomView61Layout(left, equals: initial)
        XCTAssertFalse(element("roomViewLeftButton", in: app).isEnabled)
        attachScreenshot(app, named: "Room 61 — complete left view")
        tapAnimationControl("roomViewRightButton", in: app)
        _ = try waitForRoomView61(angle: 0, whole: true, in: app)
        tapAnimationControl("roomViewRightButton", in: app)
        let right = try waitForRoomView61(angle: 1, whole: true, in: app)
        assertRoomView61Layout(right, equals: initial)
        XCTAssertFalse(element("roomViewRightButton", in: app).isEnabled)
        attachScreenshot(app, named: "Room 61 — complete right view")
        tapAnimationControl("roomOverviewButton", in: app)
        assertRoomView61Layout(try waitForRoomView61(whole: false, in: app), equals: initial)
        tapAnimationControl("roomOverviewButton", in: app)
        assertRoomView61Layout(try waitForRoomView61(whole: true, in: app), equals: initial)

        try upgradeRoomView61Home(in: app)
        let ground = try waitForRoomView61(whole: true, in: app)
        assertRoomView61Layout(ground, equals: initial)
        let gold = try XCTUnwrap(element("goldCount", in: app).value as? String)
        tapAnimationControl("homeFloor_upper", in: app)
        waitForHomeFloor("upper", in: app)
        _ = try waitForRoomView61(angle: 0, whole: true, in: app)

        tapAnimationControl("homeDecorateButton", in: app)
        XCTAssertFalse(element("roomViewControls", in: app).exists)
        tapAnimationControl("layoutStored_upstairsPlant", in: app)
        _ = waitForFurniture(in: app, description: "upstairs plant placed in the draft") {
            $0.phase == "editing" && !$0.pending && $0.items.contains { $0.id == "upstairsPlant" }
        }
        tapAnimationControl("layoutTrayToggle", in: app)
        waitForObservedValue("layoutTrayToggle", "collapsed", in: app)
        let selected = try selectFurniture("upstairsPlant", in: app)
        let plant = try XCTUnwrap(selected.items.first { $0.id == "upstairsPlant" })
        let direction = plant.x < selected.bowl.x ? -1.0 : 1.0
        let target = CGVector(dx: min(0.82, max(0.18, plant.x + direction * 0.06)),
                              dy: min(0.78, plant.y + 0.035))
        let moved = dragFurniture(plant, to: target, in: app)
        let movedPlant = try XCTUnwrap(moved.items.first { $0.id == "upstairsPlant" })
        XCTAssertGreaterThan(hypot(movedPlant.x - plant.x, movedPlant.y - plant.y), 0.01,
                             "Dragging the projected plant must move its real placement.")
        tapAnimationControl("layoutDoneButton", in: app)
        _ = waitForFurniture(in: app, description: "upstairs plant layout saved") { $0.phase == "idle" && !$0.pending }
        let upstairs = try waitForRoomView61(whole: true, in: app)
        XCTAssertTrue(upstairs.savedFurniture.contains { $0.itemID == "upstairsPlant" })
        tapAnimationControl("roomViewLeftButton", in: app)
        let beforeNavigation = try waitForRoomView61(angle: -1, whole: true, in: app)
        assertRoomView61Layout(beforeNavigation, equals: upstairs)
        attachScreenshot(app, named: "Room 61 — moved upstairs furniture from the left")

        tapAnimationControl("tabShop", in: app)
        tapAnimationControl("tabHome", in: app)
        assertRoomView61Layout(try waitForRoomView61(angle: beforeNavigation.viewAngle,
                                                   whole: beforeNavigation.wholeRoom, in: app), equals: upstairs)
        tapAnimationControl("roomOverviewButton", in: app)
        _ = try waitForRoomView61(whole: false, in: app)
        app.terminate()
        app.launchArguments = arguments(reset: false) + ["--furniture-test"]
        launchAndEnterHome(app)
        waitForHomeFloor("ground", in: app)
        assertRoomView61Layout(try waitForRoomView61(angle: 0, whole: true, in: app), equals: ground)
        waitForObservedValue("goldCount", gold, in: app)
        waitForObservedValue("foodCount", "5", in: app)
        tapAnimationControl("homeFloor_upper", in: app)
        waitForHomeFloor("upper", in: app)
        assertRoomView61Layout(try waitForRoomView61(angle: 0, whole: true, in: app), equals: upstairs)
        attachScreenshot(app, named: "Room 61 — saved upstairs layout after a cold launch")
    }

    @MainActor
    func testRoomViewControlsStayReachableInThreeLanguagesAtLargestAccessibilityType() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--home-floors-fixture", "--furniture-test"]
        launchAndEnterHome(app)
        _ = try waitForRoomView61(angle: 0, whole: true, in: app)
        try upgradeRoomView61Home(in: app)
        app.terminate()
        app.launchArguments = arguments(reset: false) + ["--furniture-test",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        launchAndEnterHome(app)

        for (language, status) in [("zh-Hans", "正面视角 · 全屋"),
                                   ("zh-Hant", "正面視角 · 全屋"), ("en", "Front view · Whole room")] {
            selectCatTestLanguage(language, in: app)
            _ = try waitForRoomView61(angle: 0, whole: true, in: app)
            waitForLabel("roomViewStatus", status, in: app)
            assertRoomView61ControlsVisible(in: app)
            attachScreenshot(app, named: "Room 61 — \(language) at largest accessibility text")
            tapAnimationControl("roomViewLeftButton", in: app)
            _ = try waitForRoomView61(angle: -1, whole: true, in: app)
            tapAnimationControl("roomViewRightButton", in: app)
            _ = try waitForRoomView61(angle: 0, whole: true, in: app)
            tapAnimationControl("roomViewRightButton", in: app)
            _ = try waitForRoomView61(angle: 1, whole: true, in: app)
            tapAnimationControl("roomOverviewButton", in: app)
            _ = try waitForRoomView61(whole: false, in: app)
            tapAnimationControl("roomOverviewButton", in: app)
            _ = try waitForRoomView61(whole: true, in: app)
            assertRoomView61ControlsVisible(in: app, atFront: false)
            let nextFloor = element("homeFloor_ground", in: app).isSelected ? "upper" : "ground"
            tapAnimationControl("homeFloor_" + nextFloor, in: app)
            waitForHomeFloor(nextFloor, in: app)
            _ = try waitForRoomView61(angle: 0, whole: true, in: app)
            assertRoomView61ControlsVisible(in: app)
            attachScreenshot(app, named: "Room 61 — \(language) stairs keep the full room visible")
        }
    }

    private struct RoomView61State: Decodable {
        struct Point: Decodable, Equatable { let x: Double; let y: Double }
        struct Placement: Decodable, Equatable { let itemID: String; let x: Double; let y: Double }
        let viewAngle: Int
        let wholeRoom: Bool
        let savedBowl: Point
        let savedFurniture: [Placement]

        init?(value: Any?) {
            guard let text = value as? String, let data = text.data(using: .utf8),
                  let state = try? JSONDecoder().decode(Self.self, from: data) else { return nil }
            self = state
        }
    }

    @MainActor
    private func waitForRoomView61(angle: Int? = nil, whole: Bool,
                                   in app: XCUIApplication) throws -> RoomView61State {
        let room = element("roomScene", in: app)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard room.exists, let state = RoomView61State(value: room.value) else { return false }
            return (angle == nil || state.viewAngle == angle) && state.wholeRoom == whole
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed,
                       "Expected room angle \(String(describing: angle)), whole \(whole); received \(room.value ?? "missing").")
        return try XCTUnwrap(RoomView61State(value: room.value))
    }

    private func assertRoomView61Layout(_ actual: RoomView61State, equals expected: RoomView61State,
                                        file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.savedBowl, expected.savedBowl,
                       "Changing the room view must preserve the saved bowl.", file: file, line: line)
        XCTAssertEqual(actual.savedFurniture.sorted { $0.itemID < $1.itemID },
                       expected.savedFurniture.sorted { $0.itemID < $1.itemID },
                       "Changing the room view must preserve saved furniture coordinates.", file: file, line: line)
    }

    @MainActor
    private func upgradeRoomView61Home(in app: XCUIApplication) throws {
        tapAnimationControl("decorateButton", in: app)
        tapAnimationControl("homeUpgradeButton", in: app)
        scrollCareerPage("homeUpgradeScroll", to: "homeUpgradeAction", in: app)
        tapAnimationControl("homeUpgradeAction", in: app)
        tapAnimationControl("homeUpgradeConfirm", in: app)
        tapAnimationControl("homeUpgradeCelebrationDone", in: app)
        tapAnimationControl("layoutCancelButton", in: app)
        waitForElement("homeFloor_upper", in: app)
        _ = try waitForRoomView61(whole: true, in: app)
    }

    @MainActor
    private func assertRoomView61ControlsVisible(in app: XCUIApplication, atFront: Bool = true,
                                                file: StaticString = #filePath, line: UInt = #line) {
        let identifiers = ["roomViewLeftButton", "roomOverviewButton", "roomViewRightButton", "homeFloor_ground", "homeFloor_upper"]
        let controls = identifiers.map { element($0, in: app) }
        let viewport = app.frame.insetBy(dx: -0.5, dy: -0.5)
        let tabs = element("homeNavigationBar", in: app).frame
        for (identifier, control) in zip(identifiers, controls) {
            if !(control.exists && control.isHittable) {
                attachScreenshot(app, named: "Blocked room control — " + identifier)
                let hierarchy = XCTAttachment(string: app.debugDescription)
                hierarchy.name = "Blocked room control hierarchy"; hierarchy.lifetime = .keepAlways
                add(hierarchy)
            }
            XCTAssertTrue(control.exists && control.isHittable, "\(identifier) must remain reachable.", file: file, line: line)
            if atFront { XCTAssertTrue(control.isEnabled, "\(identifier) must be enabled at the front view.", file: file, line: line) }
            XCTAssertGreaterThanOrEqual(control.frame.width, 44 - 0.001, "\(identifier) touch width", file: file, line: line)
            XCTAssertGreaterThanOrEqual(control.frame.height, 44 - 0.001, "\(identifier) touch height", file: file, line: line)
            XCTAssertTrue(viewport.contains(control.frame), "\(identifier) must fit on screen.", file: file, line: line)
            XCTAssertLessThanOrEqual(control.frame.maxY, tabs.minY + 1, file: file, line: line)
            XCTAssertFalse(control.label.contains("roomView."), "Room controls must be localized.", file: file, line: line)
        }
        for first in controls.indices {
            for second in controls.indices where second > first {
                XCTAssertFalse(controls[first].frame.insetBy(dx: 1, dy: 1).intersects(controls[second].frame),
                               "Room controls and stairs must have separate hit areas.", file: file, line: line)
            }
        }
    }
}
