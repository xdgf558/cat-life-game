import XCTest

extension RoomHomeUITests {
    @MainActor
    func testPlayerSleepPersistsAcrossRelaunchAndIsMutuallyExclusiveWithWork() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        openPlayerSleepCard(in: app)
        waitForObservedValue("sleepStatus", "awake", in: app)
        waitForObservedValue("playerStamina", "80", in: app)
        waitForObservedValue("playerMood", "80", in: app)
        scrollCareerPage("workRestScroll", to: "sleepStartButton", in: app)
        tapAnimationControl("sleepStartButton", in: app)
        waitForObservedValue("sleepStatus", "asleep", in: app)
        waitForElement("sleepElapsed", in: app)
        try assertVisibleTimerChanges("sleepElapsed", increasing: true, scrollIdentifier: "workRestScroll", in: app,
                                      context: "after starting sleep")
        XCTAssertFalse(element("sleepStartButton", in: app).exists)
        assertSleepPreventsWorkThenReturnToRest(in: app)
        attachScreenshot(app, named: "Recovery — player sleeping with work unavailable")

        XCUIDevice.shared.press(.home)
        waitForAppBackground(in: app)
        app.activate()
        waitForObservedValue("sleepStatus", "asleep", in: app)
        try assertVisibleTimerChanges("sleepElapsed", increasing: true, scrollIdentifier: "workRestScroll", in: app,
                                      context: "after returning to the foreground")
        assertSleepPreventsWorkThenReturnToRest(in: app)
        relaunchPreservingSave(app)
        openPlayerSleepCard(in: app)
        waitForObservedValue("sleepStatus", "asleep", in: app)
        waitForElement("sleepElapsed", in: app)
        try assertVisibleTimerChanges("sleepElapsed", increasing: true, scrollIdentifier: "workRestScroll", in: app,
                                      context: "after restoring sleep on cold launch")
        assertSleepPreventsWorkThenReturnToRest(in: app)
        scrollCareerPage("workRestScroll", to: "sleepWakeButton", in: app)
        tapAnimationControl("sleepWakeButton", in: app)
        waitForObservedValue("sleepStatus", "awake", in: app)
        waitForObservedValue("playerStamina", "80", in: app)
        waitForObservedValue("playerMood", "80", in: app)
        XCTAssertFalse(element("sleepWakeButton", in: app).exists,
                       "The completed sleep must not expose another Wake action that could pay twice.")
        tapAnimationControl("tabHome", in: app)
        openPlayerSleepCard(in: app)
        waitForObservedValue("sleepStatus", "awake", in: app)
        waitForObservedValue("playerStamina", "80", in: app)
        waitForObservedValue("playerMood", "80", in: app)
        XCTAssertFalse(element("sleepWakeButton", in: app).exists)
        closeCareerRest(in: app)
        bringWorkStartIntoView(in: app)
        tapAnimationControl("startWorkButton", in: app)
        waitForElement("workCountdown", in: app)
        try assertVisibleTimerChanges("workCountdown", increasing: false, upperBound: 120, in: app,
                                      context: "after starting the two-minute work shift")
        openCareerRest(in: app)
        waitForObservedValue("sleepStatus", "working", in: app)
        scrollCareerPage("workRestScroll", to: "sleepStartButton", in: app)
        XCTAssertFalse(element("sleepStartButton", in: app).isEnabled,
                       "A running work shift cannot also start player sleep.")
        XCTAssertFalse(element("sleepWakeButton", in: app).exists)
        waitForObservedValue("playerStamina", "70", in: app)
        waitForObservedValue("playerMood", "75", in: app)
        attachScreenshot(app, named: "Recovery — active work prevents a second simultaneous activity")
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("foodCount", "3", in: app)
        waitForObservedValue("goldCount", "200", in: app)
    }

    @MainActor
    func testOfflinePlayerSleepSettlesThirtyMinutesOnceWithoutReseeding() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--recovery-sleep-fixture"]
        launchAndEnterHome(app)
        waitForObservedValue("foodCount", "4", in: app)
        waitForObservedValue("goldCount", "180", in: app)
        openPlayerSleepCard(in: app)
        assertPlayerSleepRecovery(stamina: 50, mood: 60, status: "asleep", in: app)
        assertSleepPreventsWorkThenReturnToRest(in: app)
        attachScreenshot(app, named: "Recovery — real load settles the past thirty minutes to 50 stamina and 60 mood")

        // Retain the fixture flag while removing reset: this must load the
        // saved result rather than creating another thirty-minute sleep.
        app.terminate()
        app.launchArguments = arguments(reset: false) + ["--recovery-sleep-fixture"]
        launchAndEnterHome(app)
        openPlayerSleepCard(in: app)
        assertPlayerSleepRecovery(stamina: 50, mood: 60, status: "asleep", in: app)
        scrollCareerPage("workRestScroll", to: "sleepWakeButton", in: app)
        tapAnimationControl("sleepWakeButton", in: app)
        assertPlayerSleepRecovery(stamina: 50, mood: 60, status: "awake", in: app)
        XCTAssertFalse(element("sleepWakeButton", in: app).exists)
        app.terminate()
        app.launchArguments = arguments(reset: false) + ["--recovery-sleep-fixture"]
        launchAndEnterHome(app)
        openPlayerSleepCard(in: app)
        assertPlayerSleepRecovery(stamina: 50, mood: 60, status: "awake", in: app)
        XCTAssertFalse(element("sleepWakeButton", in: app).exists)
        attachScreenshot(app, named: "Recovery — waking and another cold launch do not pay or seed the old sleep again")
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("foodCount", "4", in: app)
        waitForObservedValue("goldCount", "180", in: app)
    }

    @MainActor
    func testCatRestRecoversPartiallyWhenFedAndCapsAfterBackgroundCompletion() throws {
        continueAfterFailure = false
        let app = launchRestHome()
        let before = furnitureState(in: app)
        let originalEnergy = try XCTUnwrap(before.catEnergy)
        XCTAssertEqual(originalEnergy, 80)
        let bed = try XCTUnwrap(before.items.first { $0.id == "catBed" })
        let feedTouch = element("feedButton", in: app).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        element("roomScene", in: app).coordinate(withNormalizedOffset: restFurnitureTouchPoint(bed)).tap()
        let approach = waitForFurniture(in: app, timeout: 20, description: "approaching the bed before recovery starts",
                                         matching: { $0.phase == "rest-approach" })
        XCTAssertEqual(approach.catEnergy, originalEnergy)
        XCTAssertNil(approach.savedRestSession,
                     "Walking toward furniture must not start a saved recovery session.")
        let partial = waitForCommittedBedRest(in: app, atLeastSeconds: 3)
        feedTouch.tap()
        _ = waitForFurniture(in: app, timeout: 30, description: "waking before the feeding route starts",
                             matching: { $0.phase == "feeding" && $0.restFurniture == nil
                                 && $0.restExits == (partial.restExits ?? -1) + 1 })
        _ = waitForFurniture(in: app, timeout: 30, description: "the interrupted cat really touches food",
                             matching: { $0.foodContactSamples > before.foodContactSamples })
        let fed = waitForFurniture(in: app, timeout: 40, description: "exactly one meal after partial bed recovery",
                                   matching: { $0.phase == "idle" && $0.completedMeals == before.completedMeals + 1
                                       && $0.savedRestSession == nil })
        let partialEnergy = try XCTUnwrap(fed.catEnergy)
        XCTAssertGreaterThan(partialEnergy, originalEnergy)
        XCTAssertLessThan(partialEnergy, 100,
                          "Early waking must award elapsed recovery, not the complete bed reward.")
        waitForObservedValue("foodCount", "2", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        attachRecoveryDiagnostics(fed, in: app, named: "Recovery — early wake pays only part and feeds once")

        let reloaded = relaunchRestHome(app)
        XCTAssertEqual(reloaded.catEnergy, partialEnergy,
                       "The partial award must not repeat on cold launch.")
        XCTAssertNil(reloaded.savedRestSession)
        let sleeping = try beginFurnitureRest("catBed", in: app)
        let committed = waitForFurniture(in: app, description: "the full bed visit is saved before backgrounding",
                                         matching: { $0.phase == "resting" && $0.restSessionCommitted == true
                                             && $0.savedRestSession == $0.restSession && $0.restSession != nil })
        let deadline = try XCTUnwrap(committed.restDeadline)
        XCUIDevice.shared.press(.home)
        waitForAppBackground(in: app)
        let expired = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            Date().timeIntervalSince1970 >= deadline + 0.25
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expired], timeout: 20), .completed,
                       "Wait for this recorded real rest deadline while the app remains in the background.")
        app.activate()
        let completed = waitForFurniture(in: app, timeout: 30, description: "background rest settles and exits without replaying",
                                         matching: { $0.phase == "idle" && $0.restFurniture == nil && $0.savedRestSession == nil
                                             && $0.restExits == (sleeping.restExits ?? -1) + 1 })
        XCTAssertEqual(completed.catEnergy, min(100, partialEnergy + 21),
                       "One bed rest awards at most 20 plus the default comfort bonus of 1, capped at 100.")
        XCTAssertEqual(completed.completedMeals, 0)
        XCTAssertNil(completed.restSession)
        waitForObservedValue("foodCount", "2", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        attachRecoveryDiagnostics(completed, in: app, named: "Recovery — one background rest reaches its cap and ends")
        tapAnimationControl("tabTown", in: app)
        tapAnimationControl("catProfile_cat_001", in: app)
        scrollCareerPage("catProfileScroll", to: "catProfileEnergy", in: app)
        waitForObservedValue("catProfileEnergy", "100", in: app)
        attachScreenshot(app, named: "Recovery — the real cat profile shows the recovered energy")
    }

    @MainActor
    func testColdLaunchSettlesAnActiveCatRestWithoutReplayingOrAwardingTwice() throws {
        continueAfterFailure = false
        let app = launchRestHome()
        let before = furnitureState(in: app)
        let originalEnergy = try XCTUnwrap(before.catEnergy)
        let bed = try XCTUnwrap(before.items.first { $0.id == "catBed" })
        element("roomScene", in: app).coordinate(withNormalizedOffset: restFurnitureTouchPoint(bed)).tap()
        let committed = waitForCommittedBedRest(in: app, atLeastSeconds: 3)
        XCTAssertNotNil(committed.savedRestSession)
        let session = try XCTUnwrap(committed.restSession)
        app.terminate()
        app.launchArguments = arguments(reset: false) + ["--rest-test"]
        launchAndEnterHome(app)
        let restored = waitForFurniture(in: app, description: "cold launch ends the previously saved cat rest",
                                        matching: { $0.phase == "idle" && $0.restPhase == "none"
                                            && $0.restFurniture == nil && $0.savedRestSession == nil })
        let restoredEnergy = try XCTUnwrap(restored.catEnergy)
        XCTAssertGreaterThan(restoredEnergy, originalEnergy)
        XCTAssertLessThanOrEqual(restoredEnergy, min(100, originalEnergy + 21))
        XCTAssertNil(restored.restSession)
        XCTAssertNil(restored.restDeadline)
        XCTAssertEqual(restored.completedRests, 0,
                       "The new actor must not perform another sleep for the old saved recovery session.")
        let settled = relaunchRestHome(app)
        XCTAssertEqual(settled.catEnergy, restoredEnergy,
                       "The second load must not award the ended session \(session) again.")
        XCTAssertNil(settled.savedRestSession)
        XCTAssertNil(settled.restSession)
        XCTAssertEqual(settled.completedRests, 0)
        assertRestSuppliesUnchanged(in: app)
        attachRecoveryDiagnostics(settled, in: app, named: "Recovery — old cat rest remains ended after a second cold launch")
    }

    @MainActor
    func testFailedCatRestEndRetriesOriginalPartialRecoveryWithoutAwardingPastWake() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--rest-test", "--recovery-end-failure-once"]
        launchAndEnterHome(app)
        let before = waitForFurniture(in: app, description: "room with one injected recovery-save failure to open",
                                      matching: { $0.phase == "idle" && !$0.pending })
        let originalEnergy = try XCTUnwrap(before.catEnergy)
        let bed = try XCTUnwrap(before.items.first { $0.id == "catBed" })
        let room = element("roomScene", in: app)
        let beforeValue = try XCTUnwrap(room.value as? String)
        let beforeData = try XCTUnwrap(beforeValue.data(using: .utf8))
        let beforeJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: beforeData) as? [String: Any])
        let supplyIDs = ["foodCount", "goldCount", "staminaCount", "catSatiety"]
        let originalSupplies = try supplyIDs.map { try XCTUnwrap(observedHomeValue($0, in: app)) }
        let bedTouch = room.coordinate(withNormalizedOffset: restFurnitureTouchPoint(bed))
        bedTouch.tap()

        // The first SE run recorded began;cancelled at the visible bed, without
        // ended/requested or any state change. Observe that exact cancellation
        // before considering one retry; never retry an active or saved rest.
        let touchSettled = XCTNSPredicateExpectation(predicate: NSPredicate { object, _ in
            guard let target = object as? XCUIElement, let value = target.value as? String,
                  let data = value.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
            return (json["lastRestInput"] as? String)?.hasSuffix(";cancelled") == true
                || (json["phase"] as? String) != "idle"
        }, object: room)
        _ = XCTWaiter.wait(for: [touchSettled], timeout: 3)
        if let value = room.value as? String, let data = value.data(using: .utf8),
           let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let state = FurnitureState(value: value),
           (json["lastRestInput"] as? String)?.hasSuffix(";cancelled") == true,
           state.phase == "idle", !state.pending, state.restPhase == "none",
           state.restFurniture == nil, state.restSession == nil, state.savedRestSession == nil,
           state.catEnergy == originalEnergy,
           NSDictionary(dictionary: beforeJSON.filter { $0.key != "lastRestInput" })
               .isEqual(to: json.filter { $0.key != "lastRestInput" }),
           supplyIDs.enumerated().allSatisfy({ observedHomeValue($0.element, in: app) == originalSupplies[$0.offset] }),
           room.isHittable, app.alerts.count == 0 {
            let evidence = XCTAttachment(string: "One retry of a cancelled initial bed touch. All scene fields except lastRestInput and all visible resources are unchanged.\nBefore: \(beforeValue)\nAfter: \(value)\nSupplies: \(originalSupplies)")
            evidence.name = "Recovery — cancelled initial touch before one bounded retry"
            evidence.lifetime = .keepAlways
            add(evidence)
            bedTouch.tap()
        }
        let sleeping = waitForCommittedBedRest(in: app, atLeastSeconds: 3)
        let deadline = try XCTUnwrap(sleeping.restDeadline)
        let visibleCat = try XCTUnwrap(sleeping.restVisualPoint)
        element("roomScene", in: app)
            .coordinate(withNormalizedOffset: CGVector(dx: visibleCat.x, dy: visibleCat.y - 0.035)).tap()
        let failure = app.alerts.firstMatch
        XCTAssertTrue(failure.waitForExistence(timeout: 8),
                      "The injected first rest-end write must show the real save failure alert.")
        XCTAssertTrue(failure.staticTexts["这次操作还没有保存"].exists)
        attachScreenshot(app, named: "Recovery — early wake reports its first save failure")
        // Dismiss only the alert so the room diagnostics are accessible again.
        // The queued end event is retried by the product, not by this test.
        failure.buttons["完成"].tap()
        let retried = waitForFurniture(in: app, timeout: 30, description: "the original early-wake event retries and clears its saved session",
                                       matching: { $0.phase == "idle" && $0.restFurniture == nil
                                           && $0.restSession == nil && $0.savedRestSession == nil })
        let recoveredEnergy = try XCTUnwrap(retried.catEnergy)
        XCTAssertGreaterThan(recoveredEnergy, originalEnergy)
        XCTAssertLessThan(recoveredEnergy, 100,
                          "Retrying a failed early wake must not convert it into a complete rest.")
        let originalDeadlinePassed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            Date().timeIntervalSince1970 >= deadline + 0.25
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [originalDeadlinePassed], timeout: 20), .completed)
        let afterDeadline = furnitureState(in: app)
        XCTAssertEqual(afterDeadline.catEnergy, recoveredEnergy,
                       "A cat that already woke must earn no extra recovery after the original sleep deadline.")
        XCTAssertNil(afterDeadline.savedRestSession)
        XCTAssertEqual(afterDeadline.completedMeals, 0)
        let reloaded = relaunchRestHome(app)
        XCTAssertEqual(reloaded.catEnergy, recoveredEnergy)
        XCTAssertNil(reloaded.savedRestSession)
        XCTAssertNil(reloaded.restSession)
        assertRestSuppliesUnchanged(in: app)
        attachRecoveryDiagnostics(reloaded, in: app, named: "Recovery — retried early-wake reward remains fixed after deadline and cold launch")
    }

    @MainActor
    private func openPlayerSleepCard(in app: XCUIApplication,
                                      file: StaticString = #filePath, line: UInt = #line) {
        openCareerHome(in: app, file: file, line: line)
        openCareerRest(in: app, file: file, line: line)
    }

    @MainActor
    private func assertSleepPreventsWorkThenReturnToRest(in app: XCUIApplication,
                                                        file: StaticString = #filePath, line: UInt = #line) {
        closeCareerRest(in: app, file: file, line: line)
        scrollCareerPage("destinationScroll", to: "startWorkButton", in: app, file: file, line: line)
        waitForElement("startWorkButton", in: app, file: file, line: line)
        XCTAssertFalse(element("startWorkButton", in: app).isEnabled,
                       "A sleeping player cannot start a work shift.", file: file, line: line)
        openCareerRest(in: app, file: file, line: line)
        waitForObservedValue("sleepStatus", "asleep", in: app, file: file, line: line)
    }

    @MainActor
    private func assertPlayerSleepRecovery(stamina: Int, mood: Int, status: String, in app: XCUIApplication,
                                           file: StaticString = #filePath, line: UInt = #line) {
        waitForObservedValue("sleepStatus", status, in: app, file: file, line: line)
        waitForObservedValue("playerStamina", "\(stamina)", in: app, file: file, line: line)
        waitForObservedValue("playerMood", "\(mood)", in: app, file: file, line: line)
    }

    @MainActor
    private func waitForCommittedBedRest(in app: XCUIApplication, atLeastSeconds elapsed: TimeInterval,
                                         file: StaticString = #filePath, line: UInt = #line) -> FurnitureState {
        waitForFurniture(in: app, timeout: 40, description: "a real saved bed rest with elapsed recovery time", matching: { state in
            guard state.phase == "resting", state.restPhase == "resting", state.restFurniture == "catBed",
                  state.restSession != nil, state.savedRestSession == state.restSession,
                  state.restSessionCommitted == true, (state.restContactSamples ?? 0) > 0,
                  let deadline = state.restDeadline else { return false }
            let now = Date().timeIntervalSince1970
            return now >= deadline - 12 + elapsed && now < deadline - 3
        }, file: file, line: line)
    }

    @MainActor
    private func attachRecoveryDiagnostics(_ state: FurnitureState, in app: XCUIApplication, named name: String) {
        let diagnostics = element("roomScene", in: app).value
        let attachment = XCTAttachment(string: "energy=\(String(describing: state.catEnergy))\nscene=\(String(describing: diagnostics))")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        attachScreenshot(app, named: name)
    }
}
