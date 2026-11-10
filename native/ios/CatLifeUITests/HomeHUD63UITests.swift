import XCTest

extension RoomHomeUITests {
    @MainActor
    func testHomeHUD63KeepsTwoRowsAndCareActionsFixedAcrossViewsAndResidentPreview() throws {
        let app = try launchHomeHUD63()
        let initial = try waitForHomeHUD63(in: app) { $0.viewAngle == 0 && $0.wholeRoom }
        let frames = homeHUD63Frames(in: app)
        assertHomeControlRows(in: app, stage: "Home 63 — whole-room baseline")
        attachScreenshot(app, named: "Home 63 — whole front baseline")
        XCTAssertFalse(element("homeCatInfo", in: app).exists)
        XCTAssertFalse(element("focusCatButton", in: app).exists)
        XCTAssertFalse(element("homeCareVisibilityButton", in: app).exists)
        for (control, angle, whole) in [("roomViewLeftButton", -1, true), ("roomOverviewButton", -1, false),
                                      ("roomOverviewButton", -1, true), ("roomViewRightButton", 0, true),
                                      ("roomViewRightButton", 1, true), ("roomOverviewButton", 1, false),
                                      ("roomOverviewButton", 1, true)] {
            tapAnimationControl(control, in: app)
            let state = try waitForHomeHUD63(in: app) { $0.viewAngle == angle && $0.wholeRoom == whole }
            assertHomeHUD63Frames(frames, in: app)
            assertHomeHUD63SavedLayout(state, equals: initial)
            if !whole,
               let before = initial.residentCats.first(where: { $0.id == initial.activeCatID }),
               let after = state.residentCats.first(where: { $0.id == state.activeCatID }) {
                XCTAssertGreaterThan(after.screenWidth, before.screenWidth * 2.2,
                                     "The high-level companion must visibly grow in close view without changing its saved body or coordinates.")
            }
            attachScreenshot(app, named: "Home 63 — angle \(angle), \(whole ? "whole" : "close")")
        }
        let state = try waitForHomeHUD63(in: app) { $0.wholeRoom }
        let target = try homeHUD63PreviewResident(from: state, in: app)
        waitForObservedValue("roomResidentPreview", target, in: app)
        let preview = element("roomResidentPreview", in: app)
        XCTAssertTrue(element("roomStage63", in: app).frame.contains(preview.frame))
        for id in ["homeMyCatsButton", "homeCareBar63", "roomViewControls"] {
            XCTAssertFalse(preview.frame.intersects(element(id, in: app).frame), "Resident preview covers \(id).")
        }
        for id in ["roomResidentGrowthButton", "roomResidentCompanionButton"] {
            XCTAssertTrue(element(id, in: app).isHittable)
        }
        XCTAssertFalse(element("catNeedBubble", in: app).exists, "The resident preview temporarily replaces the companion need bubble.")
        waitForObservedValue("homeMyCatsButton", "cat_001", in: app)
        assertHomeHUD63Frames(frames, in: app)
        waitForObservedValue("foodCount", "12", in: app)
        waitForObservedValue("goldCount", "27,000", in: app)
        attachScreenshot(app, named: "Home 63 — fixed two-row HUD and stage-contained resident preview")
    }

    @MainActor
    func testHomeHUD63DirectoryAndFloorTravelKeepTheCareRecipientAndChargeOneMeal() throws {
        let app = try launchHomeHUD63()
        waitForHomeFloor("ground", in: app)
        let original = try waitForHomeHUD63(in: app) { $0.wholeRoom }
        try homeHUD63SelectCompanion("cat_005", in: app)
        waitForObservedValue("catSatiety", "35", in: app)
        waitForObservedValue("foodCount", "12", in: app)
        tapAnimationControl("roomOverviewButton", in: app)
        _ = try waitForHomeHUD63(in: app) { !$0.wholeRoom }
        tapAnimationControl("feedButton", in: app)
        waitForObservedValue("foodCount", "11", in: app)
        let fed = try waitForHomeHUD63(in: app, timeout: 50) {
            $0.activeCatID == "cat_005" && $0.completedMeals == 1 && $0.foodContactSamples > 0
        }
        XCTAssertEqual(fed.foodContactViolations, 0)
        waitForObservedValue("catSatiety", "60", in: app)
        let groundLayout = fed.savedLayout
        for floor in ["upper", "ground"] {
            tapAnimationControl("homeFloor_" + floor, in: app)
            waitForHomeFloor(floor, in: app)
            let arrived = try waitForHomeHUD63(in: app) { $0.activeCatID == "cat_005" && $0.wholeRoom }
            waitForObservedValue("homeMyCatsButton", "cat_005", in: app)
            waitForObservedValue("catSatiety", "60", in: app)
            waitForObservedValue("foodCount", "11", in: app)
            waitForObservedValue("goldCount", "27,000", in: app)
            if floor == "ground" { XCTAssertEqual(arrived.savedLayout, groundLayout) }
            attachScreenshot(app, named: "Home 63 — \(floor), selected companion and persistent care")
        }
        try homeHUD63SelectCompanion("cat_001", in: app)
        waitForObservedValue("catSatiety", "35", in: app)
        try homeHUD63SelectCompanion("cat_005", in: app)
        waitForObservedValue("catSatiety", "60", in: app)
        XCTAssertEqual(try waitForHomeHUD63(in: app) { $0.activeCatID == "cat_005" }.savedLayout, original.savedLayout)
        app.terminate()
        app.launchArguments = arguments(reset: false) + ["--shared-home-test", "--shared-home-upper-test", "--furniture-test"]
        launchAndEnterHome(app)
        _ = try waitForHomeHUD63(in: app) { $0.activeCatID == "cat_005" && $0.wholeRoom }
        waitForObservedValue("homeMyCatsButton", "cat_005", in: app)
        waitForObservedValue("catSatiety", "60", in: app)
        waitForObservedValue("foodCount", "11", in: app)
        attachScreenshot(app, named: "Home 63 — My Cats selection and exactly one saved meal survive relaunch")
    }

    @MainActor
    func testHomeHUD63ThreeLanguagesLargestTypeAndReducedMotionStayReachable() throws {
        let app = try launchHomeHUD63(extra: ["--animation-test", "--reduce-motion-test",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        for (language, name, status, closeTitle) in [
            ("zh-Hans", "小橘", "正面视角 · 全屋", "近看小橘"),
            ("zh-Hant", "小橘", "正面視角 · 全屋", "近看小橘"),
            ("en", "Sunny", "Front view · Whole room", "Close up: Sunny")
        ] {
            selectCatTestLanguage(language, in: app)
            _ = try waitForHomeHUD63(in: app) { $0.viewAngle == 0 && $0.wholeRoom }
            waitForLabel("roomViewStatus", status, in: app)
            waitForLabel("roomOverviewButton", closeTitle, in: app)
            waitForObservedValue("homeCatName", name, in: app)
            assertHomeControlRows(in: app, stage: "Home 63 — \(language), largest accessibility type, reduced motion")
            let before = homeHUD63Frames(in: app)
            for id in ["roomViewLeftButton", "roomOverviewButton", "roomViewRightButton", "homeFloor_ground", "homeFloor_upper"] {
                let button = element(id, in: app)
                XCTAssertTrue(button.exists && button.isHittable, "\(language): \(id) must remain reachable.")
                XCTAssertGreaterThanOrEqual(button.frame.width, 44)
                XCTAssertGreaterThanOrEqual(button.frame.height, 44)
                XCTAssertTrue(app.frame.contains(button.frame))
                XCTAssertFalse(button.label.contains("home63.") || button.label.contains("roomView."))
            }
            let bubble = element("catNeedBubble", in: app)
            XCTAssertTrue(bubble.waitForExistence(timeout: 8) && bubble.isHittable)
            XCTAssertTrue(element("roomStage63", in: app).frame.contains(bubble.frame))
            waitForObservedValue("catNeedBubble", name, in: app)
            let bubbleFrame = bubble.frame
            let moves = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                abs(bubble.frame.midX - bubbleFrame.midX) > 1 || abs(bubble.frame.midY - bubbleFrame.midY) > 1
            }, object: bubble)
            moves.isInverted = true
            XCTAssertEqual(XCTWaiter.wait(for: [moves], timeout: 2.5), .completed,
                           "Reduced motion must stop the SwiftUI need bubble's floating animation.")
            tapAnimationControl("roomOverviewButton", in: app)
            _ = try waitForHomeHUD63(in: app) { !$0.wholeRoom }
            assertHomeHUD63Frames(before, in: app)
            tapAnimationControl("roomOverviewButton", in: app)
            _ = try waitForHomeHUD63(in: app) { $0.wholeRoom }
            assertHomeHUD63Frames(before, in: app)
            attachScreenshot(app, named: "Home 63 — \(language), largest type and calm need bubble")
        }
        waitForObservedValue("foodCount", "12", in: app)
        waitForObservedValue("catSatiety", "35", in: app)
        let beforeCare = try waitForHomeHUD63(in: app) { $0.activeCatID == "cat_001" }
        tapAnimationControl("catNeedBubble", in: app)
        waitForObservedValue("foodCount", "11", in: app)
        // Reduced motion completes one real care plan through its calm static response.
        _ = try waitForHomeHUD63(in: app, timeout: 5) {
            $0.carePlanCompletions == beforeCare.carePlanCompletions + 1 && !$0.bowlHasFood
        }
        waitForObservedValue("catSatiety", "60", in: app)
        waitForObservedValue("foodCount", "11", in: app)
        waitForObservedValue("goldCount", "27,000", in: app)
        app.terminate()
        app.launchArguments = arguments(reset: false) + ["--shared-home-test", "--shared-home-upper-test", "--furniture-test",
            "--animation-test", "--reduce-motion-test", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        launchAndEnterHome(app)
        let reopened = try waitForHomeHUD63(in: app) { $0.activeCatID == "cat_001" && $0.wholeRoom }
        XCTAssertEqual(reopened.savedLayout, beforeCare.savedLayout)
        waitForObservedValue("catSatiety", "60", in: app)
        waitForObservedValue("foodCount", "11", in: app)
        waitForObservedValue("goldCount", "27,000", in: app)
    }

    @MainActor
    private func launchHomeHUD63(extra: [String] = []) throws -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true)
            + ["--shared-home-test", "--shared-home-upper-test", "--furniture-test"] + extra
        launchAndEnterHome(app)
        _ = try waitForHomeHUD63(in: app) { $0.activeCatID == "cat_001" && $0.wholeRoom }
        return app
    }

    @MainActor
    private func homeHUD63Frames(in app: XCUIApplication) -> [String: CGRect] {
        Dictionary(uniqueKeysWithValues: ["homeNamePlaque", "homeResourceCapsule", "homeMyCatsButton",
            "homeDecorateButton", "homeFloor_ground", "homeFloor_upper", "roomStage63", "homeCareBar63",
            "feedButton", "cleanButton", "playButton"].map { ($0, element($0, in: app).frame) })
    }

    @MainActor
    private func assertHomeHUD63Frames(_ expected: [String: CGRect], in app: XCUIApplication,
                                       file: StaticString = #filePath, line: UInt = #line) {
        for (id, frame) in expected {
            let current = element(id, in: app)
            XCTAssertTrue(current.exists && current.isHittable, "\(id) must stay visible.", file: file, line: line)
            XCTAssertEqual(current.frame.minX, frame.minX, accuracy: 1, id, file: file, line: line)
            XCTAssertEqual(current.frame.minY, frame.minY, accuracy: 1, id, file: file, line: line)
            XCTAssertEqual(current.frame.width, frame.width, accuracy: 1, id, file: file, line: line)
            XCTAssertEqual(current.frame.height, frame.height, accuracy: 1, id, file: file, line: line)
        }
        XCTAssertTrue(element("roomStage63", in: app).frame.contains(element("roomViewControls", in: app).frame),
                      "Room view controls belong inside the stage.", file: file, line: line)
    }

    private func assertHomeHUD63SavedLayout(_ state: HomeHUD63RoomState, equals original: HomeHUD63RoomState,
                                            file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(state.savedLayout, original.savedLayout, file: file, line: line)
        XCTAssertEqual(state.activeCatID, original.activeCatID, file: file, line: line)
        XCTAssertEqual(state.completedMeals, original.completedMeals, file: file, line: line)
        XCTAssertEqual(state.completedPounces, original.completedPounces, file: file, line: line)
        XCTAssertEqual(state.violations, 0, file: file, line: line)
        XCTAssertEqual(state.residentCollisions, 0, file: file, line: line)
    }

    @MainActor
    private func homeHUD63SelectCompanion(_ id: String, in app: XCUIApplication) throws {
        tapAnimationControl("homeMyCatsButton", in: app)
        waitForElement("sharedHomeDirectory", in: app)
        attachScreenshot(app, named: "Home 63 — My Cats drawer before choosing a companion")
        scrollCareerPage("sharedHomeDirectory", to: "sharedHomeSelect_" + id, in: app)
        tapAnimationControl("sharedHomeSelect_" + id, in: app)
        _ = try waitForHomeHUD63(in: app) { $0.activeCatID == id }
        waitForObservedValue("homeMyCatsButton", id, in: app)
        XCTAssertEqual(try homeCareState63(in: app)["id"] as? String, id)
    }

    @MainActor
    private func homeHUD63PreviewResident(from state: HomeHUD63RoomState, in app: XCUIApplication) throws -> String {
        let room = element("roomScene", in: app)
        let controls = ["catNeedBubble", "roomViewControls"].map { element($0, in: app) }.filter(\.exists)
        let target = try XCTUnwrap(state.residentCats.first { cat in
            let frame = cat.frame(in: room.frame)
            return cat.id != state.activeCatID && cat.visible
                && element("roomStage63", in: app).frame.contains(frame)
                && !controls.contains { $0.frame.contains(CGPoint(x: frame.midX, y: frame.midY)) }
                && !state.residentCats.contains { $0.id != cat.id && $0.frame(in: room.frame).contains(CGPoint(x: frame.midX, y: frame.midY)) }
        }, "Expected a real visible resident body to preview.")
        room.coordinate(withNormalizedOffset: CGVector(dx: target.x, dy: target.y)).tap()
        return target.id
    }

    @MainActor
    private func waitForHomeHUD63(in app: XCUIApplication, timeout: TimeInterval = 25,
                                  matching condition: @escaping (HomeHUD63RoomState) -> Bool) throws -> HomeHUD63RoomState {
        let room = element("roomScene", in: app)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let state = HomeHUD63RoomState(value: room.value) else { return false }
            return state.phase == "idle" && !state.pending && !state.residentsBusy && condition(state)
        }, object: room)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: timeout), .completed,
                       "The real room did not settle in the requested HUD state: \(room.value ?? "missing").")
        return try XCTUnwrap(HomeHUD63RoomState(value: room.value))
    }
}

private struct HomeHUD63RoomState: Decodable {
    struct Point: Codable { let x: Double; let y: Double }
    struct Placement: Codable { let itemID: String; let x: Double; let y: Double }
    struct Resident: Decodable {
        let id: String; let x: Double; let y: Double; let visible: Bool
        let screenWidth: Double; let screenHeight: Double
        func frame(in room: CGRect) -> CGRect {
            CGRect(x: room.minX + CGFloat(x) * room.width - CGFloat(screenWidth) / 2,
                   y: room.minY + CGFloat(y) * room.height - CGFloat(screenHeight) / 2,
                   width: CGFloat(screenWidth), height: CGFloat(screenHeight))
        }
    }
    let phase: String; let pending: Bool; let residentsBusy: Bool
    let activeCatID: String; let viewAngle: Int; let wholeRoom: Bool
    let completedMeals: Int; let completedPounces: Int; let carePlanCompletions: Int; let bowlHasFood: Bool
    let foodContactSamples: Int; let foodContactViolations: Int; let violations: Int; let residentCollisions: Int
    let savedBowl: Point; let savedFurniture: [Placement]; let residentCats: [Resident]
    var savedLayout: String {
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        let bowl = (try? encoder.encode(savedBowl)).map { String(decoding: $0, as: UTF8.self) } ?? "invalid bowl"
        let furniture = (try? encoder.encode(savedFurniture.sorted { $0.itemID < $1.itemID }))
            .map { String(decoding: $0, as: UTF8.self) } ?? "invalid furniture"
        return bowl + furniture
    }
    init?(value: Any?) {
        guard let text = value as? String, let state = try? JSONDecoder().decode(Self.self, from: Data(text.utf8)) else { return nil }
        self = state
    }
}
