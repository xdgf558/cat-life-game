import XCTest

extension RoomHomeUITests {
    @MainActor
    func testCarePlansRunOffMainThreadAndConsumeSuppliesOnce() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--furniture-test"]
        launchAndEnterHome(app)
        let initial = try waitForCarePlan(in: app, description: "room before any care planning") {
            $0.phase == "idle" && $0.carePlanCompletions == 0
        }

        tapAnimationControl("feedButton", in: app)
        let feeding = try waitForCarePlan(in: app, description: "feeding route planned off the UI thread") {
            $0.carePlanCompletions == 1 && !$0.carePlanning
        }
        assertCareWorker(feeding, named: "Feeding", in: app)
        let fed = waitForFurniture(in: app, timeout: 40, description: "one real meal at the bowl") {
            $0.phase == "idle" && $0.completedMeals == initial.completedMeals + 1
        }
        XCTAssertGreaterThan(fed.foodContactSamples, initial.foodContactSamples)
        waitForObservedValue("foodCount", "2", in: app)
        waitForObservedValue("catSatiety", "60", in: app)

        // Buy a real six-use toy. Planning and rendering must not buy or
        // consume an additional item when their asynchronous result arrives.
        tapAnimationControl("playButton", in: app)
        waitForElement("buyToyButton", in: app)
        bringIntoView("buyToyButton", in: app)
        tapAnimationControl("buyToyButton", in: app)
        waitForObservedValue("shopGoldCount", "165", in: app)
        tapAnimationControl("closeSheetButton", in: app)
        _ = waitForFurniture(in: app, description: "home after buying a toy") { $0.phase == "idle" }
        tapAnimationControl("playButton", in: app)
        let playing = try waitForCarePlan(in: app, description: "pounce route planned off the UI thread") {
            $0.carePlanCompletions == 2 && !$0.carePlanning
        }
        assertCareWorker(playing, named: "Playing", in: app)
        _ = waitForFurniture(in: app, timeout: 30, description: "play response completes") { $0.phase == "idle" }
        waitForObservedValue("goldCount", "165", in: app)
        waitForObservedValue("foodCount", "2", in: app)
        tapAnimationControl("tabInventory", in: app)
        waitForObservedValue("inventoryToyUses", "5", in: app)
        waitForObservedValue("inventoryFoodCount", "2", in: app)
        attachScreenshot(app, named: "Care planning — one food portion and one toy use consumed")
    }

    @MainActor
    func testInterruptedCarePlanningResumesAndPreservesQueuedFeed() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--furniture-test", "--slow-care-planning-test"]
        launchAndEnterHome(app)
        _ = try waitForCarePlan(in: app, description: "fresh room before delayed route planning") {
            $0.phase == "idle" && $0.carePlanCompletions == 0 && $0.carePlanCancelled == 0
        }

        tapAnimationControl("feedButton", in: app)
        // The delay affects only the detached worker. Its pending state must
        // remain observable while the native UI and lifecycle stay responsive.
        _ = try waitForCarePlan(in: app, timeout: 5, description: "first route worker is pending") {
            $0.carePlanning && $0.carePlanCompletions == 0
        }
        XCUIDevice.shared.press(.home)
        let backgrounded = XCTNSPredicateExpectation(predicate: NSPredicate { object, _ in
            guard let application = object as? XCUIApplication else { return false }
            return application.state == .runningBackground || application.state == .runningBackgroundSuspended
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [backgrounded], timeout: 5), .completed)
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        _ = try waitForCarePlan(in: app, timeout: 8, description: "old worker cancelled and saved action replanned") {
            $0.carePlanCancelled == 1 && $0.carePlanCompletions <= 1
                && ($0.carePlanning || $0.phase == "feeding")
        }

        // Queue one additional committed feed while the resumed one is still
        // planning or performing. Activation may outlast its worker delay;
        // returning from background must still retain both presentations.
        tapAnimationControl("feedButton", in: app)
        waitForObservedValue("foodCount", "1", in: app)
        let finished = try waitForCarePlan(in: app, timeout: 65, description: "exactly two queued meals finish") {
            $0.phase == "idle" && !$0.carePlanning && $0.carePlanCompletions == 2 && $0.completedMeals == 2
        }
        XCTAssertEqual(finished.carePlanCancelled, 1)
        assertCareWorker(finished, named: "Resumed and queued feeding", in: app)
        XCTAssertGreaterThan(finished.foodContactSamples, 0)
        _ = furnitureState(in: app)
        waitForObservedValue("foodCount", "1", in: app)
        waitForObservedValue("catSatiety", "85", in: app)
        waitForObservedValue("goldCount", "200", in: app)

        app.terminate()
        app.launchArguments = arguments(reset: false) + ["--furniture-test"]
        launchAndEnterHome(app)
        _ = try waitForCarePlan(in: app, description: "cold launch does not replay transient care") {
            $0.phase == "idle" && $0.carePlanCompletions == 0 && $0.completedMeals == 0
        }
        waitForObservedValue("foodCount", "1", in: app)
        waitForObservedValue("catSatiety", "85", in: app)
    }

    private struct CarePlanTestState: Decodable {
        let phase: String
        let carePlanning: Bool
        let carePlanCompletions: Int
        let carePlanCancelled: Int
        let lastCarePlanMilliseconds: Double
        let lastCarePlanOnMainThread: Bool
        let completedMeals: Int
        let foodContactSamples: Int
        let violations: Int
        let foodContactViolations: Int

        init?(value: Any?) {
            guard let value = value as? String, let data = value.data(using: .utf8),
                  let state = try? JSONDecoder().decode(Self.self, from: data) else { return nil }
            self = state
        }
    }

    @MainActor
    private func waitForCarePlan(in app: XCUIApplication, timeout: TimeInterval = 15, description: String,
                                 matching condition: @escaping (CarePlanTestState) -> Bool,
                                 file: StaticString = #filePath, line: UInt = #line) throws -> CarePlanTestState {
        let room = element("roomScene", in: app)
        var matched: CarePlanTestState?
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { object, _ in
            guard let target = object as? XCUIElement, target.exists,
                  let state = CarePlanTestState(value: target.value) else { return false }
            if state.violations != 0 || state.foodContactViolations != 0 || condition(state) {
                matched = state
                return true
            }
            return false
        }, object: room)
        let result = XCTWaiter.wait(for: [ready], timeout: timeout)
        if result != .completed {
            let evidence = XCTAttachment(string: "Expected \(description); received \(String(describing: room.value))\n\(app.debugDescription)")
            evidence.name = "Care planning — failed observation"
            evidence.lifetime = .keepAlways
            add(evidence)
        }
        XCTAssertEqual(result, .completed, "Expected \(description)", file: file, line: line)
        let state = try XCTUnwrap(matched, file: file, line: line)
        XCTAssertEqual(state.violations, 0, file: file, line: line)
        XCTAssertEqual(state.foodContactViolations, 0, file: file, line: line)
        return state
    }

    @MainActor
    private func assertCareWorker(_ state: CarePlanTestState, named name: String, in app: XCUIApplication,
                                  file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(state.lastCarePlanOnMainThread, "\(name) must plan outside the UI thread.", file: file, line: line)
        XCTAssertTrue(state.lastCarePlanMilliseconds.isFinite, file: file, line: line)
        XCTAssertGreaterThanOrEqual(state.lastCarePlanMilliseconds, 0, file: file, line: line)
        let evidence = XCTAttachment(string: "\(name)\n\(String(describing: element("roomScene", in: app).value))")
        evidence.name = "Care planning — \(name) thread and elapsed time"
        evidence.lifetime = .keepAlways
        add(evidence)
    }
}
