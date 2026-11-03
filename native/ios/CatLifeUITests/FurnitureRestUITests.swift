import XCTest

extension RoomHomeUITests {
    @MainActor
    func testCatBedSleepAndMovedCushionRestReachFurnitureWithoutSpendingSupplies() throws {
        continueAfterFailure = false
        let app = launchRestHome()
        let beforeBed = furnitureState(in: app)
        _ = try beginFurnitureRest("catBed", in: app)
        attachScreenshot(app, named: "Rest — cat settled inside the cat bed")
        let awake = waitForFurniture(in: app, timeout: 60, description: "cat naturally wakes and leaves the bed",
                                     matching: { $0.phase == "idle" && $0.restFurniture == nil
                                         && $0.restPhase == "none"
                                         && $0.completedRests == (beforeBed.completedRests ?? -1) + 1
                                         && $0.restExits == (beforeBed.restExits ?? -1) + 1 })
        XCTAssertGreaterThan(awake.restContactSamples ?? -1, beforeBed.restContactSamples ?? -1)
        XCTAssertEqual(awake.completedMeals, beforeBed.completedMeals)
        assertRestSuppliesUnchanged(in: app)

        // Move the cushion through the real arrangement flow. The next rest
        // must use its saved new position, including after a cold launch.
        tapAnimationControl("homeDecorateButton", in: app)
        var editing = waitForFurniture(in: app, description: "cushion arrangement to open",
                                        matching: { $0.phase == "editing" && !$0.pending })
        let original = try XCTUnwrap(editing.items.first { $0.id == "floorCushion" })
        let targets = [CGVector(dx: 0.42, dy: 0.80), CGVector(dx: 0.44, dy: 0.70),
                       CGVector(dx: 0.60, dy: 0.80)]
        for target in targets {
            let current = try XCTUnwrap(editing.items.first { $0.id == "floorCushion" })
            editing = dragFurniture(current, to: roomCoordinate(forArtworkCoordinate: target, in: app), in: app)
            let moved = try XCTUnwrap(editing.items.first { $0.id == "floorCushion" })
            if hypot(moved.x - original.x, moved.y - original.y) > 0.02 { break }
        }
        let moved = try XCTUnwrap(editing.items.first { $0.id == "floorCushion" })
        XCTAssertGreaterThan(hypot(moved.x - original.x, moved.y - original.y), 0.02,
                             "The cushion must actually move before testing its rest location.")
        let movedSource = artworkCoordinate(forRoomCoordinate: moved.position, in: app)
        tapAnimationControl("layoutDoneButton", in: app)
        _ = waitForFurniture(in: app, description: "moved cushion to save",
                             matching: { $0.phase == "idle" && !$0.pending })
        let restored = relaunchRestHome(app)
        let restoredCushion = try XCTUnwrap(restored.items.first { $0.id == "floorCushion" })
        let restoredSource = artworkCoordinate(forRoomCoordinate: restoredCushion.position, in: app)
        XCTAssertEqual(restoredSource.dx, movedSource.dx, accuracy: 0.008)
        XCTAssertEqual(restoredSource.dy, movedSource.dy, accuracy: 0.008)

        let resting = try beginFurnitureRest("floorCushion", in: app)
        attachScreenshot(app, named: "Rest — cat settled on the moved and saved cushion")
        let room = element("roomScene", in: app)
        // Furniture support can separate the visual body from its navigation anchor.
        let visualPoint = try XCTUnwrap(resting.restVisualPoint)
        room.coordinate(withNormalizedOffset: CGVector(dx: visualPoint.x, dy: visualPoint.y - 0.035)).tap()
        let exited = waitForFurniture(in: app, timeout: 30, description: "tapping the resting cat wakes it and clears the cushion",
                                      matching: { $0.phase == "idle" && $0.restFurniture == nil && $0.restPhase == "none"
                                          && $0.restExits == (resting.restExits ?? -1) + 1 })
        XCTAssertEqual(exited.completedMeals, 0)
        assertRestSuppliesUnchanged(in: app)
        attachScreenshot(app, named: "Rest — cat safely leaves the moved cushion without consuming supplies")
    }

    @MainActor
    func testDecoratingWakesSleepingCatBeforeBedStorageAndPersists() throws {
        continueAfterFailure = false
        let app = launchRestHome()
        let sleeping = try beginFurnitureRest("catBed", in: app)
        tapAnimationControl("homeDecorateButton", in: app)
        let editing = waitForFurniture(in: app, timeout: 30, description: "cat leaves the bed before arrangement becomes ready",
                                       matching: { $0.phase == "editing" && !$0.pending && $0.restFurniture == nil
                                           && $0.restPhase == "none"
                                           && $0.restExits == (sleeping.restExits ?? -1) + 1 })
        XCTAssertTrue(editing.items.contains { $0.id == "catBed" },
                      "Requesting arrangement must leave the occupied bed in place until the cat has exited.")
        _ = try selectFurniture("catBed", in: app)
        tapAnimationControl("storeFurnitureButton", in: app)
        _ = waitForFurniture(in: app, description: "unoccupied cat bed removed from the draft",
                             matching: { !$0.pending && !$0.items.contains { $0.id == "catBed" } })
        tapAnimationControl("layoutDoneButton", in: app)
        _ = waitForFurniture(in: app, description: "stored cat bed layout saved",
                             matching: { $0.phase == "idle" && !$0.pending })
        let restored = relaunchRestHome(app)
        XCTAssertEqual(restored.items.count, 8)
        XCTAssertFalse(restored.items.contains { $0.id == "catBed" })
        tapAnimationControl("tabInventory", in: app)
        scrollCareerPage("destinationScroll", to: "inventoryFurnitureTab", in: app)
        tapAnimationControl("inventoryFurnitureTab", in: app)
        waitForObservedValue("inventoryStoredFurnitureCount", "1", in: app)
        waitForObservedValue("inventoryPlacedFurnitureCount", "8", in: app)
        selectBagFurniture("catBed", in: app)
        waitForObservedValue("inventoryFurniture_catBed", "收纳中 · 可摆回房间", in: app)
        XCTAssertFalse(element("inventoryLayoutDraft", in: app).exists)
        attachScreenshot(app, named: "Rest — previously occupied bed is saved safely in the furniture bag")
        tapAnimationControl("tabHome", in: app)
        completeFurnitureFeed(in: app, remainingFood: 2)
        waitForObservedValue("catSatiety", "60", in: app)
        waitForObservedValue("goldCount", "200", in: app)
    }

    @MainActor
    func testFeedingWakesRestingCatBeforeWalkingToBowl() throws {
        continueAfterFailure = false
        let app = launchRestHome()
        let resting = try beginFurnitureRest("floorCushion", in: app)
        tapAnimationControl("feedButton", in: app)
        let feeding = waitForFurniture(in: app, timeout: 30, description: "rest exit finishes before the feeding route starts",
                                       matching: { $0.phase == "feeding" && $0.restFurniture == nil && $0.restPhase == "none"
                                           && $0.restExits == (resting.restExits ?? -1) + 1 })
        XCTAssertEqual(feeding.completedMeals, resting.completedMeals,
                       "Leaving furniture must not count as completing a meal.")
        _ = waitForFurniture(in: app, timeout: 30, description: "awakened cat's mouth reaches the actual food",
                             matching: { $0.foodContactSamples > resting.foodContactSamples })
        attachScreenshot(app, named: "Rest — awakened cat reaches the food bowl before eating")
        let finished = waitForFurniture(in: app, timeout: 40, description: "interrupted rest followed by exactly one complete meal",
                                        matching: { $0.phase == "idle" && $0.restFurniture == nil
                                            && $0.completedMeals == resting.completedMeals + 1 })
        XCTAssertGreaterThan(finished.foodContactSamples, resting.foodContactSamples)
        XCTAssertEqual(finished.restExits, (resting.restExits ?? -1) + 1)
        waitForObservedValue("foodCount", "2", in: app)
        waitForObservedValue("catSatiety", "60", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        tapAnimationControl("tabInventory", in: app)
        waitForObservedValue("inventoryFoodCount", "2", in: app)
        waitForObservedValue("inventoryLitterCount", "2", in: app)
        waitForObservedValue("inventoryToyUses", "0", in: app)
        tapAnimationControl("tabHome", in: app)
        let saved = relaunchRestHome(app)
        XCTAssertNil(saved.restFurniture, "A finished transient rest must not resume after a cold launch.")
        waitForObservedValue("foodCount", "2", in: app)
        waitForObservedValue("catSatiety", "60", in: app)
    }

    @MainActor
    func testFeedingDuringCushionStepExitsSafelyAndCanRestAgain() throws {
        continueAfterFailure = false
        let app = launchRestHome()
        tapAnimationControl("homeDecorateButton", in: app)
        var editing = waitForFurniture(in: app, description: "cushion arrangement for an unobstructed step to open",
                                        matching: { $0.phase == "editing" && !$0.pending })
        let original = try XCTUnwrap(editing.items.first { $0.id == "floorCushion" })
        // Keep this first rest target away from the freshly launched cat's
        // visible body; tapping that body correctly opens the cat sheet.
        for target in [CGVector(dx: 0.55, dy: 0.68), CGVector(dx: 0.60, dy: 0.66)] {
            let current = try XCTUnwrap(editing.items.first { $0.id == "floorCushion" })
            editing = dragFurniture(current, to: roomCoordinate(forArtworkCoordinate: target, in: app), in: app)
            let moved = try XCTUnwrap(editing.items.first { $0.id == "floorCushion" })
            if hypot(moved.x - original.x, moved.y - original.y) > 0.02 { break }
        }
        let moved = try XCTUnwrap(editing.items.first { $0.id == "floorCushion" })
        XCTAssertGreaterThan(hypot(moved.x - original.x, moved.y - original.y), 0.02)
        tapAnimationControl("layoutDoneButton", in: app)
        let before = waitForFurniture(in: app, description: "visible cushion position to save",
                                      matching: { $0.phase == "idle" && !$0.pending })
        try assertFeedingInterruptsFurnitureEntry("floorCushion", label: "Cushion", before: before, in: app)
    }

    @MainActor
    func testFeedingDuringCatBedStepExitsSafelyAndCanRestAgain() throws {
        continueAfterFailure = false
        let app = launchRestHome()
        let before = furnitureState(in: app)
        try assertFeedingInterruptsFurnitureEntry("catBed", label: "Cat bed", before: before, in: app)
    }

    @MainActor
    private func assertFeedingInterruptsFurnitureEntry(_ id: String, label: String,
                                                        before: FurnitureState, in app: XCUIApplication) throws {
        let item = try XCTUnwrap(before.items.first { $0.id == id })
        let room = element("roomScene", in: app)
        let feedFrame = element("feedButton", in: app).frame
        let appFrame = app.frame
        let feedPoint = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: feedFrame.midX - appFrame.minX, dy: feedFrame.midY - appFrame.minY))
        let enteringPhases: Set<String> = ["reaching", "frontPaws", "lifting"]
        // The bed's short entry can fall between the predicate waiter's
        // one-second snapshots. Observe its existing room value more often,
        // while keeping the actual feed-event phase assertions below strict.
        var observedStep: FurnitureState?
        var observedValue = ""
        var observedTimeline: [String] = []
        let observe: (Any?) -> Bool = { rawValue in
            guard let value = rawValue as? String,
                  let state = FurnitureState(value: value) else { return false }
            observedValue = value
            if observedTimeline.count < 240 {
                observedTimeline.append("\(state.phase)/\(state.restPhase ?? "none")/\(state.stepPhase ?? "none") progress=\(state.stepProgress ?? -1)")
            }
            if state.violations != 0 || (state.stepClearanceViolations ?? 0) != 0
                || (state.bedEdgeContactViolations ?? 0) != 0 { return true }
            guard state.restFurniture == id, state.restPhase == "entering",
                  enteringPhases.contains(state.stepPhase ?? ""),
                  let progress = state.stepProgress, progress > 0, progress <= 0.45,
                  id == "catBed" || progress >= 0.12 else { return false }
            observedStep = state
            return true
        }
        let entering: XCTNSPredicateExpectation? = id == "catBed" ? nil : XCTNSPredicateExpectation(
            predicate: NSPredicate { object, _ in
                guard let target = object as? XCUIElement, target.exists else { return false }
                return observe(target.value)
            }, object: room)
        room.coordinate(withNormalizedOffset: restFurnitureTouchPoint(item)).tap()
        let entered: XCTWaiter.Result
        if id == "catBed" {
            let deadline = Date(timeIntervalSinceNow: 60)
            var completed = false
            repeat {
                // launchRestHome already confirmed this room exists. Avoid an
                // extra hierarchy snapshot before reading each phase value.
                if observe(room.value) { completed = true; break }
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.04))
            } while Date() < deadline
            entered = completed ? .completed : .timedOut
        } else {
            entered = XCTWaiter.wait(for: [try XCTUnwrap(entering)], timeout: 60)
        }
        if entered != .completed || observedStep == nil {
            let evidence = XCTAttachment(string: "observations=\(observedTimeline.joined(separator: "\n"))\nlast=\(observedValue)")
            evidence.name = "\(label) step — last observation before the interruption window was missed"
            evidence.lifetime = .keepAlways
            add(evidence)
        }
        XCTAssertEqual(entered, .completed, "The test must observe a real, incomplete step onto \(id).")
        let stepping = try XCTUnwrap(observedStep,
                                     "A collision or a completed rest cannot substitute for observing entry mid-step.")
        // Deliver the real care tap immediately. Screenshots or another AX
        // snapshot here could let the cat finish climbing before input arrives.
        feedPoint.tap()
        let interrupted = waitForFurniture(in: app, timeout: 10, description: "the actual feed input records its interruption phase",
                                           matching: { $0.lastRestInterrupt?.reason == "feed" })
        let evidence = XCTAttachment(string: "observations=\(observedTimeline.joined(separator: "\n"))\nbeforeInput=\(observedValue)\nafterInput=\(String(describing: room.value))")
        evidence.name = "\(label) step — observed entry and actual feed interruption"
        evidence.lifetime = .keepAlways
        add(evidence)
        let input = try XCTUnwrap(interrupted.lastRestInterrupt)
        XCTAssertEqual(input.restPhase, "entering",
                       "The feed must interrupt climbing, rather than a cat that has already settled.")
        XCTAssertTrue(enteringPhases.contains(input.stepPhase),
                      "A supported or already resting pose does not exercise mid-step cancellation.")
        XCTAssertGreaterThan(input.stepProgress, 0)
        XCTAssertLessThan(input.stepProgress, 1)
        let front = try XCTUnwrap(stepping.frontPaw)
        let rear = try XCTUnwrap(stepping.rearPaw)
        XCTAssertTrue([front.x, front.y, rear.x, rear.y].allSatisfy(\.isFinite))
        XCTAssertGreaterThan(hypot(front.x - rear.x, front.y - rear.y), 0.005,
                             "Entry diagnostics must use distinct front and rear paw landmarks from the step atlas.")
        let elevation = try XCTUnwrap(stepping.supportElevation)
        XCTAssertTrue(elevation.isFinite && elevation >= 0)
        XCTAssertEqual(stepping.completedRests, before.completedRests)

        let feeding = waitForFurniture(in: app, timeout: 30, description: "incomplete step safely reverses before feeding starts",
                                       matching: { $0.phase == "feeding" && $0.restFurniture == nil && $0.restPhase == "none"
                                           && $0.restExits == (before.restExits ?? -1) + 1 })
        XCTAssertGreaterThan(feeding.stepDownSamples ?? -1, before.stepDownSamples ?? -1,
                             "The cat must visibly step down instead of jumping directly to its feeding route.")
        XCTAssertEqual(feeding.stepPhase, "none")
        XCTAssertEqual(feeding.completedRests, before.completedRests)
        _ = waitForFurniture(in: app, timeout: 30, description: "mouth reaches the bowl after the interrupted climb",
                             matching: { $0.foodContactSamples > before.foodContactSamples })
        attachScreenshot(app, named: "\(label) step — interrupted entry exits safely and reaches actual food")
        let finished = waitForFurniture(in: app, timeout: 40, description: "exactly one meal completes after entry is interrupted",
                                        matching: { $0.phase == "idle" && $0.completedMeals == before.completedMeals + 1 })
        XCTAssertEqual(finished.completedRests, before.completedRests)
        XCTAssertGreaterThan(finished.foodContactSamples, before.foodContactSamples)
        waitForObservedValue("foodCount", "2", in: app)
        waitForObservedValue("catSatiety", "60", in: app)
        waitForObservedValue("goldCount", "200", in: app)

        let restingAgain = try beginFurnitureRest(id, in: app)
        XCTAssertEqual(restingAgain.completedMeals, before.completedMeals + 1)
        attachScreenshot(app, named: "\(label) step — another full climb and rest succeeds after mid-step interruption")
        let visualPoint = try XCTUnwrap(restingAgain.restVisualPoint)
        room.coordinate(withNormalizedOffset: CGVector(dx: visualPoint.x, dy: visualPoint.y - 0.035)).tap()
        _ = waitForFurniture(in: app, timeout: 30, description: "the second rest safely leaves \(id)",
                             matching: { $0.phase == "idle" && $0.restFurniture == nil
                                 && $0.restExits == (restingAgain.restExits ?? -1) + 1 })
        tapAnimationControl("tabInventory", in: app)
        waitForObservedValue("inventoryFoodCount", "2", in: app)
        waitForObservedValue("inventoryLitterCount", "2", in: app)
        waitForObservedValue("inventoryToyUses", "0", in: app)
        tapAnimationControl("tabHome", in: app)
        _ = relaunchRestHome(app)
        waitForObservedValue("foodCount", "2", in: app)
        waitForObservedValue("catSatiety", "60", in: app)
        waitForObservedValue("goldCount", "200", in: app)
    }

    @MainActor
    private func completeFurnitureFeed(in app: XCUIApplication, remainingFood: Int,
                                       file: StaticString = #filePath, line: UInt = #line) {
        let before = furnitureState(in: app, file: file, line: line)
        tapAnimationControl("feedButton", in: app, file: file, line: line)
        _ = waitForFurniture(in: app, timeout: 10, description: "furniture-aware feeding to begin",
                             matching: { $0.phase == "feeding" }, file: file, line: line)
        _ = waitForFurniture(in: app, timeout: 30, description: "mouth reaches the bowl after furniture interaction",
                             matching: { $0.foodContactSamples > before.foodContactSamples }, file: file, line: line)
        attachScreenshot(app, named: "Rest — actual bowl contact after storing the previously occupied bed")
        let finished = waitForFurniture(in: app, timeout: 40, description: "meal and safe return to complete",
                                        matching: { $0.phase == "idle" && $0.completedMeals == before.completedMeals + 1 },
                                        file: file, line: line)
        XCTAssertGreaterThan(finished.foodContactSamples, before.foodContactSamples, file: file, line: line)
        waitForObservedValue("foodCount", "\(remainingFood)", in: app, file: file, line: line)
    }
}
