import XCTest

extension RoomHomeUITests {
    @MainActor
    func testBowlPlanningCancelsAcrossBackgroundAndLayoutExitThenFeedsOnce() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--furniture-test", "--slow-bowl-planning-test"]
        launchAndEnterHome(app)
        let initialPlan = try waitForBowlPlan(in: app, description: "initial bowl restoration finishes off the UI thread") {
            !$0.bowlPlanning && $0.phase == "idle" && $0.bowlPlanCompletions > 0
        }
        XCTAssertFalse(initialPlan.lastBowlPlanOnMainThread)
        let initial = furnitureState(in: app)

        // Changing to arrangement creates a fresh, delayed geometry request.
        // Background it before completion, then cancel the resumed arrangement.
        tapAnimationControl("decorateButton", in: app)
        let pending = try waitForBowlPlan(in: app, timeout: 5, description: "arrangement bowl planning is pending") {
            $0.bowlPlanning
        }
        XCUIDevice.shared.press(.home)
        let backgrounded = XCTNSPredicateExpectation(predicate: NSPredicate { object, _ in
            guard let application = object as? XCUIApplication else { return false }
            return application.state == .runningBackground || application.state == .runningBackgroundSuspended
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [backgrounded], timeout: 5), .completed)
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        let resumed = try waitForBowlPlan(in: app, description: "backgrounded bowl worker is cancelled before resuming") {
            $0.bowlPlanCancelled > pending.bowlPlanCancelled
        }
        XCTAssertGreaterThan(resumed.bowlPlanCancelled, pending.bowlPlanCancelled)
        tapAnimationControl("layoutCancelButton", in: app)
        let restoredPlan = try waitForBowlPlan(in: app, description: "only the latest home geometry is committed") {
            !$0.bowlPlanning && $0.phase == "idle" && $0.bowlPlanCompletions > initialPlan.bowlPlanCompletions
        }
        XCTAssertFalse(restoredPlan.lastBowlPlanOnMainThread)
        XCTAssertFalse(element("layoutCancelButton", in: app).exists)
        let restored = furnitureState(in: app)
        XCTAssertFalse(restored.pending)
        XCTAssertEqual(restored.bowl.x, initial.bowl.x, accuracy: 0.005)
        XCTAssertEqual(restored.bowl.y, initial.bowl.y, accuracy: 0.005)
        XCTAssertEqual(restored.completedMeals, initial.completedMeals)
        waitForObservedValue("foodCount", "3", in: app)

        tapAnimationControl("feedButton", in: app)
        waitForObservedValue("foodCount", "2", in: app)
        let fed = waitForFurniture(in: app, timeout: 45, description: "one committed feed reaches the restored bowl") {
            $0.phase == "idle" && $0.completedMeals == initial.completedMeals + 1
        }
        XCTAssertGreaterThan(fed.foodContactSamples, initial.foodContactSamples,
                             "The cat must reach the actual food surface, not use a stationary fallback.")
        XCTAssertEqual(fed.foodContactViolations, 0)
        XCTAssertEqual(fed.bowl.x, initial.bowl.x, accuracy: 0.005)
        XCTAssertEqual(fed.bowl.y, initial.bowl.y, accuracy: 0.005)
        waitForObservedValue("foodCount", "2", in: app)
        waitForObservedValue("catSatiety", "60", in: app)
        waitForObservedValue("goldCount", "200", in: app)

        // Observe beyond the delayed worker's lifetime: no stale layout result
        // may reopen planning or replay the already completed meal.
        let staleResult = XCTNSPredicateExpectation(predicate: NSPredicate { object, _ in
            guard let room = object as? XCUIElement, room.exists,
                  let plan = BowlPlanTestState(value: room.value),
                  let state = FurnitureState(value: room.value) else { return false }
            return plan.bowlPlanning || plan.bowlPlanCompletions != restoredPlan.bowlPlanCompletions
                || state.phase != "idle" || state.completedMeals != initial.completedMeals + 1
                || hypot(state.bowl.x - initial.bowl.x, state.bowl.y - initial.bowl.y) > 0.005
        }, object: element("roomScene", in: app))
        staleResult.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [staleResult], timeout: 4), .completed)
        waitForObservedValue("foodCount", "2", in: app)
        let evidence = XCTAttachment(string: "initialCompletions=\(initialPlan.bowlPlanCompletions)\n"
            + "pendingCancellations=\(pending.bowlPlanCancelled)\nresumedCancellations=\(resumed.bowlPlanCancelled)\n"
            + "\(String(describing: element("roomScene", in: app).value))")
        evidence.name = "Bowl planning — cancelled generations, worker thread, and one real meal"
        evidence.lifetime = .keepAlways
        add(evidence)
        attachScreenshot(app, named: "Bowl planning — restored home after one meal and no stale layout replay")
    }

    private struct BowlPlanTestState: Decodable {
        let phase: String
        let bowlPlanning: Bool
        let bowlPlanCompletions: Int
        let bowlPlanCancelled: Int
        let lastBowlPlanOnMainThread: Bool

        init?(value: Any?) {
            guard let value = value as? String, let data = value.data(using: .utf8),
                  let state = try? JSONDecoder().decode(Self.self, from: data) else { return nil }
            self = state
        }
    }

    @MainActor
    private func waitForBowlPlan(in app: XCUIApplication, timeout: TimeInterval = 20, description: String,
                                 matching condition: @escaping (BowlPlanTestState) -> Bool,
                                 file: StaticString = #filePath, line: UInt = #line) throws -> BowlPlanTestState {
        let room = element("roomScene", in: app)
        var matched: BowlPlanTestState?
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { object, _ in
            guard let target = object as? XCUIElement, target.exists,
                  let state = BowlPlanTestState(value: target.value), condition(state) else { return false }
            matched = state
            return true
        }, object: room)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: timeout), .completed,
                       "Expected \(description); received \(String(describing: room.value))", file: file, line: line)
        return try XCTUnwrap(matched, file: file, line: line)
    }
}
