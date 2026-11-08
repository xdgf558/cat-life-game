import XCTest

extension RoomHomeUITests {
    @MainActor
    func testLevelFourResidentsCanSelectCompanionAndEatWithoutDuplicateCosts() throws {
        let app = try launchSharedHome()
        waitForObservedValue("foodCount", "12", in: app)
        waitForObservedValue("goldCount", "27,000", in: app)
        attachScreenshot(app, named: "Shared home — five adopted cats together at level four")

        for (id, remaining) in [("cat_002", 11), ("cat_004", 10)] {
            try selectSharedResident(id, in: app)
            let before = try sharedHomeState(in: app)
            tapAnimationControl("feedButton", in: app)
            waitForObservedValue("foodCount", "\(remaining)", in: app)
            let finishedEating = try waitForSharedHome(in: app, timeout: 45,
                                                       description: "bowl empties before the cat returns home") {
                $0.phase == "feeding" && $0.completedMeals == before.completedMeals + 1 && !$0.bowlHasFood
            }
            XCTAssertEqual(finishedEating.activeCatID, id)
            let settled = try waitForSharedHome(in: app, description: "five residents return after feeding") {
                $0.phase == "idle" && !$0.residentsBusy && $0.visibleCount == 5
            }
            assertAllSharedResidents(settled)
            XCTAssertEqual(settled.completedMeals, before.completedMeals + 1)
            XCTAssertFalse(settled.bowlHasFood)
            waitForObservedValue("foodCount", "\(remaining)", in: app)
            waitForObservedValue("catSatiety", "60", in: app)
            waitForObservedValue("goldCount", "27,000", in: app)
        }
        attachScreenshot(app, named: "Shared home — selected Siamese has eaten and all five cats remain")

        app.terminate()
        app.launchArguments = arguments(reset: false) + ["--shared-home-test", "--furniture-test"]
        launchAndEnterHome(app)
        let relaunched = try waitForSharedHome(in: app, description: "five residents after cold launch") {
            $0.phase == "idle" && !$0.residentsBusy && $0.visibleCount == 5
        }
        assertAllSharedResidents(relaunched)
        XCTAssertEqual(relaunched.activeCatID, "cat_004")
        waitForObservedValue("foodCount", "10", in: app)
    }

    @MainActor
    func testFiveResidentsSurviveFloorTravelAndCancelledArrangement() throws {
        let app = try launchSharedHome(upperFloorUnlocked: true)
        for floor in ["2F · 二楼", "1F · 一楼"] {
            tapAnimationControl("homeStairsButton", in: app)
            waitForObservedValue("homeStairsButton", floor, in: app)
            let arrived = try waitForSharedHome(in: app, description: "all cats arrive on \(floor)") {
                $0.phase == "idle" && !$0.residentsBusy && $0.visibleCount == 5
            }
            assertAllSharedResidents(arrived)
            tapAnimationControl("decorateButton", in: app)
            _ = try waitForSharedHome(in: app, description: "arrangement opens") { $0.phase == "editing" }
            tapAnimationControl("layoutCancelButton", in: app)
            let cancelled = try waitForSharedHome(in: app, description: "all cats resume after cancelling arrangement") {
                $0.phase == "idle" && !$0.residentsBusy && $0.visibleCount == 5
            }
            assertAllSharedResidents(cancelled)
            XCTAssertEqual(cancelled.activeCatID, "cat_001")
            waitForObservedValue("foodCount", "12", in: app)
            waitForObservedValue("goldCount", "27,000", in: app)
            attachScreenshot(app, named: "Shared home — five cats on \(floor) after cancelling arrangement")
        }
    }

    @MainActor
    func testSharedHomeAmbientWalkQueuesFeedingWithoutCollisions() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--shared-home-test", "--shared-home-stroll-test", "--furniture-test", "--allow-ambient-motion"]
        launchAndEnterHome(app)
        _ = try waitForSharedHome(in: app, description: "five cats ready") { $0.visibleCount == 5 && !$0.residentsBusy }
        _ = try waitForSharedHome(in: app, timeout: 30, description: "a cat takes a quiet stroll") { $0.residentsBusy }
        tapAnimationControl("feedButton", in: app)
        waitForObservedValue("foodCount", "11", in: app)
        let result = try waitForSharedHome(in: app, timeout: 40, description: "queued meal completes") {
            $0.completedMeals == 1 && !$0.bowlHasFood && $0.phase == "idle" && !$0.residentsBusy
        }
        assertAllSharedResidents(result)
        waitForObservedValue("foodCount", "11", in: app)
    }

    @MainActor
    private func launchSharedHome(upperFloorUnlocked: Bool = false) throws -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--shared-home-test", "--furniture-test"]
        if upperFloorUnlocked { app.launchArguments.append("--shared-home-upper-test") }
        launchAndEnterHome(app)
        let ready = try waitForSharedHome(in: app, description: "five resident cats in the room") {
            $0.phase == "idle" && !$0.residentsBusy && $0.visibleCount == 5
        }
        assertAllSharedResidents(ready)
        return app
    }

    @MainActor
    private func selectSharedResident(_ id: String, in app: XCUIApplication) throws {
        let state = try sharedHomeState(in: app)
        let resident = try XCTUnwrap(state.residentCats.first { $0.id == id && $0.visible })
        XCTAssertTrue((0...1).contains(resident.x) && (0...1).contains(resident.y))
        element("roomScene", in: app)
            .coordinate(withNormalizedOffset: CGVector(dx: resident.x, dy: resident.y)).tap()
        waitForObservedValue("catProfileScroll", id, in: app)
        scrollCareerPage("catProfileScroll", to: "catCompanionButton", in: app)
        tapAnimationControl("catCompanionButton", in: app)
        waitForObservedValue("catCompanionButton", "active", in: app)
        tapAnimationControl("closeSheetButton", in: app)
        let selected = try waitForSharedHome(in: app, description: "selected resident becomes the care companion") {
            $0.activeCatID == id && $0.phase == "idle" && !$0.residentsBusy && $0.visibleCount == 5
        }
        assertAllSharedResidents(selected)
    }

    @MainActor
    private func sharedHomeState(in app: XCUIApplication,
                                 file: StaticString = #filePath, line: UInt = #line) throws -> SharedHomeState {
        let value = element("roomScene", in: app).value
        return try XCTUnwrap(SharedHomeState(value: value), "Expected shared-home diagnostics: \(String(describing: value))",
                             file: file, line: line)
    }

    @MainActor
    private func waitForSharedHome(in app: XCUIApplication, timeout: TimeInterval = 25, description: String,
                                   matching condition: @escaping (SharedHomeState) -> Bool,
                                   file: StaticString = #filePath, line: UInt = #line) throws -> SharedHomeState {
        let room = element("roomScene", in: app)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { target, _ in
            guard let element = target as? XCUIElement, element.exists,
                  let state = SharedHomeState(value: element.value) else { return false }
            return condition(state)
        }, object: room)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: timeout), .completed,
                       "Expected \(description); got \(String(describing: room.value))", file: file, line: line)
        return try sharedHomeState(in: app, file: file, line: line)
    }

    private func assertAllSharedResidents(_ state: SharedHomeState,
                                          file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(state.residentCollisions, 0, file: file, line: line)
        XCTAssertEqual(state.residentCats.count, 5, file: file, line: line)
        XCTAssertEqual(Set(state.residentCats.map(\.id)), Set(["cat_001", "cat_002", "cat_003", "cat_004", "cat_005"]),
                       file: file, line: line)
        XCTAssertEqual(state.visibleCount, 5, file: file, line: line)
        XCTAssertTrue(state.residentCats.allSatisfy { $0.x.isFinite && $0.y.isFinite }, file: file, line: line)
    }
}

private struct SharedHomeState: Decodable {
    struct Resident: Decodable {
        let id: String
        let x: Double
        let y: Double
        let visible: Bool
    }

    let phase: String
    let activeCatID: String
    let residentCats: [Resident]
    let residentsBusy: Bool
    let bowlHasFood: Bool
    let completedMeals: Int
    let residentCollisions: Int
    var visibleCount: Int { residentCats.filter(\.visible).count }

    init?(value: Any?) {
        guard let value = value as? String, let data = value.data(using: .utf8),
              let state = try? JSONDecoder().decode(Self.self, from: data) else { return nil }
        self = state
    }
}
