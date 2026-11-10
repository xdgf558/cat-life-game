import XCTest

extension RoomHomeUITests {
    @MainActor
    func testFeedingDuringAndAfterAmbientStrollReachesBowl() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--navigation-test", "--allow-ambient-motion"]
        launchAndEnterHome(app)
        let initial = waitForNavigationPhase("idle", in: app, timeout: 15)
        let feed = element("feedButton", in: app)
        XCTAssertTrue(feed.exists && feed.isEnabled && feed.isHittable)
        let strolling = waitForNavigation(in: app, timeout: 35, description: "ambient stroll to move away from its starting point",
                                         matching: { $0.phase == "strolling"
                                             && hypot($0.cat.dx - initial.cat.dx, $0.cat.dy - initial.cat.dy) > 0.02 })
        // Tap immediately after observing real movement. Extra screenshots or
        // control readiness queries here could let a short stroll finish first.
        feed.tap()
        let feeding = waitForNavigationPhase("feeding", in: app, timeout: 20)
        let queuedMeal = XCTAttachment(string: "initialCat=\(initial.cat.dx),\(initial.cat.dy)\nstrollingCat=\(strolling.cat.dx),\(strolling.cat.dy)\nfeedingStartCat=\(feeding.cat.dx),\(feeding.cat.dy)\ncompletedMealsBefore=\(strolling.completedMeals)\nfoodContactSamplesBefore=\(strolling.foodContactSamples)")
        queuedMeal.name = "Feeding — request issued after ambient stroll moved away from its origin"
        queuedMeal.lifetime = .keepAlways
        add(queuedMeal)
        waitForObservedValue("foodCount", "2", in: app)
        _ = waitForNavigation(in: app, timeout: 30, description: "queued feeding mouth to reach the food after strolling",
                              matching: { $0.foodContactSamples > strolling.foodContactSamples })
        attachScreenshot(app, named: "Feeding — request during a natural stroll reaches the bowl")
        let firstMeal = waitForNavigationPhase("idle", in: app, timeout: 35)
        XCTAssertEqual(firstMeal.completedMeals, strolling.completedMeals + 1,
                       "Feeding queued during a natural stroll must complete one real meal.")
        XCTAssertGreaterThan(firstMeal.foodContactSamples, strolling.foodContactSamples,
                             "Restoring satiety alone is insufficient: the lowered mouth must reach the food.")
        waitForObservedValue("foodCount", "2", in: app)
        waitForObservedValue("catSatiety", "60", in: app)
        waitForObservedValue("goldCount", "200", in: app)

        // Also cover feeding from a new resting place after an uninterrupted
        // natural stroll, rather than only from the initial room position.
        _ = waitForNavigation(in: app, timeout: 35, description: "a second natural stroll to make real progress",
                              matching: { $0.phase == "strolling"
                                  && hypot($0.cat.dx - firstMeal.cat.dx, $0.cat.dy - firstMeal.cat.dy) > 0.02 })
        let settled = waitForNavigationPhase("idle", in: app, timeout: 25)
        XCTAssertEqual(settled.completedMeals, firstMeal.completedMeals,
                       "The ambient stroll must not replay or charge the previous feeding request.")
        completeNavigationFeed(in: app, remainingFood: 1)
        waitForObservedValue("catSatiety", "85", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        attachScreenshot(app, named: "Feeding — another meal completes after natural movement settles")
    }

    @MainActor
    func testNavigationCareStaysClearAfterMovingBowlNearCat() throws {
        let app = launchNavigationHome()
        completeNavigationFeed(in: app, remainingFood: 2)

        tapAnimationControl("decorateButton", in: app)
        let editing = waitForNavigationPhase("editing", in: app, timeout: 5)
        // Put the bowl just ahead and to the right of the actual cat. Use the
        // scene's visible coordinates: legacy saved coordinates can be projected.
        let nearby = CGVector(dx: min(0.82, editing.cat.dx + 0.30),
                              dy: max(0.60, editing.cat.dy - 0.11))
        dragBowl(from: editing.bowl, to: nearby, in: app)
        let moved = waitForNavigationBowlMoved(from: editing.bowl, in: app)
        XCTAssertGreaterThan(moved.bowl.dx, moved.cat.dx + 0.10,
                             "The right-side placement must actually move the visible bowl beside the cat.")
        attachScreenshot(app, named: "Navigation — bowl moved close to the cat on the right")
        tapAnimationControl("layoutDoneButton", in: app)
        waitForNavigationPhase("idle", in: app, timeout: 5)

        completeNavigationFeed(in: app, remainingFood: 1)
        purchaseToyAndCompleteNavigationPlay(in: app)
        let settled = navigationState(in: app)
        XCTAssertGreaterThanOrEqual(settled.maxRoutePoints, 2,
                                    "Care must exercise a real walking route, not only a stationary fallback.")
        waitForObservedValue("goldCount", "165", in: app)
        waitForObservedValue("foodCount", "1", in: app)
        attachScreenshot(app, named: "Navigation — feeding and playing completed beside the moved bowl")
    }

    @MainActor
    func testNavigationRejectsWallDropAndFeedsFromLeftSide() throws {
        let app = launchNavigationHome()
        tapAnimationControl("decorateButton", in: app)
        let editing = waitForNavigationPhase("editing", in: app, timeout: 5)
        let leftSide = CGVector(dx: max(0.20, editing.cat.dx - 0.15),
                               dy: max(0.60, editing.cat.dy - 0.12))
        dragBowl(from: editing.bowl, to: leftSide, in: app)
        let moved = waitForNavigationBowlMoved(from: editing.bowl, in: app)
        XCTAssertLessThan(moved.bowl.dx, moved.cat.dx - 0.02,
                          "The regression must also exercise a bowl on the cat's left.")
        tapAnimationControl("layoutDoneButton", in: app)
        waitForNavigationPhase("idle", in: app, timeout: 5)
        completeNavigationFeed(in: app, remainingFood: 2)
        let routed = navigationState(in: app)
        XCTAssertGreaterThanOrEqual(routed.maxRoutePoints, 2,
                                    "The cat must use a real safe approach to the left-side bowl.")
        attachScreenshot(app, named: "Navigation — cat returned safely after approaching the left-side bowl")

        tapAnimationControl("decorateButton", in: app)
        let beforeWallDrop = waitForNavigationPhase("editing", in: app, timeout: 5)
        let wall = CGVector(dx: 0.16, dy: 0.22)
        dragBowl(from: beforeWallDrop.bowl, to: wall, in: app)
        tapAnimationControl("layoutDoneButton", in: app)
        let afterWallDrop = waitForNavigationPhase("idle", in: app, timeout: 5)
        // The upper wall is visibly outside the floor. Either reject this drop
        // or project it onto the floor; do not assert one internal clamp policy.
        XCTAssertGreaterThan(afterWallDrop.bowl.dy, 0.45,
                             "A bowl dragged onto the wall must remain on the visible floor.")
        XCTAssertGreaterThan(hypot(afterWallDrop.bowl.dx - wall.dx, afterWallDrop.bowl.dy - wall.dy), 0.20,
                             "The illegal wall coordinate must not become the bowl's placement.")
        attachScreenshot(app, named: "Navigation — wall drop rejected or projected back onto the floor")

        // A rejected/projected edit must leave both care actions usable and the
        // collision count clean, including their paths back to the resting spot.
        completeNavigationFeed(in: app, remainingFood: 1)
        purchaseToyAndCompleteNavigationPlay(in: app)
        waitForObservedValue("foodCount", "1", in: app)
        attachScreenshot(app, named: "Navigation — feeding and playing still work after the wall drop")
    }

    @MainActor
    func testBowlCanMoveToFloorBelowWallPicturesAndPersist() throws {
        continueAfterFailure = false
        let app = launchNavigationHome()
        tapAnimationControl("decorateButton", in: app)
        let editing = waitForNavigationPhase("editing", in: app, timeout: 5)
        let originalSource = artworkCoordinate(forRoomCoordinate: editing.bowl, in: app)
        let targetSource = CGVector(dx: 0.70, dy: 0.50)
        let target = roomCoordinate(forArtworkCoordinate: targetSource, in: app)

        // Locate the floor below the pictures in the artwork, not at an
        // arbitrary screen fraction that changes with aspect-fill cropping.
        dragBowl(from: editing.bowl, to: target, in: app)
        let moved = waitForNavigationBowlMoved(from: editing.bowl, in: app)
        let movedSource = artworkCoordinate(forRoomCoordinate: moved.bowl, in: app)
        XCTAssertEqual(movedSource.dx, targetSource.dx, accuracy: 0.06,
                       "The bowl must reach the floor directly below the wall pictures.")
        XCTAssertEqual(movedSource.dy, targetSource.dy, accuracy: 0.06,
                       "Dragging upward must not silently stop at the former lower floor boundary.")
        XCTAssertLessThan(movedSource.dy, originalSource.dy - 0.10,
                          "The bowl must move visibly toward the wall, not remain near its starting spot.")
        tapAnimationControl("layoutDoneButton", in: app)
        let saved = waitForNavigationPhase("idle", in: app, timeout: 5)
        XCTAssertEqual(saved.bowl.dx, moved.bowl.dx, accuracy: 0.005)
        XCTAssertEqual(saved.bowl.dy, moved.bowl.dy, accuracy: 0.005)
        attachScreenshot(app, named: "Arrangement — bowl saved on the floor below the wall pictures")

        completeNavigationFeed(in: app, remainingFood: 2)
        waitForObservedValue("catSatiety", "60", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        app.terminate()
        app.launchArguments = arguments(reset: false) + ["--navigation-test"]
        launchAndEnterHome(app)
        let restored = waitForNavigationPhase("idle", in: app, timeout: 15)
        XCTAssertEqual(restored.bowl.dx, saved.bowl.dx, accuracy: 0.005,
                       "The saved bowl position must survive a cold launch without lateral projection.")
        XCTAssertEqual(restored.bowl.dy, saved.bowl.dy, accuracy: 0.005,
                       "The bowl must remain near the wall after reloading the saved layout.")
        waitForObservedValue("foodCount", "2", in: app)
        attachScreenshot(app, named: "Arrangement — upper floor bowl position restored after cold launch")

        completeNavigationFeed(in: app, remainingFood: 1)
        waitForObservedValue("catSatiety", "85", in: app)
        waitForObservedValue("goldCount", "200", in: app)
    }

    @MainActor
    func testBowlDragRespondsAndCancelledValidationCannotOverwriteLayout() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--drag-performance-test", "--slow-placement-test"]
        launchAndEnterHome(app)
        waitForElement("feedButton", in: app)
        tapAnimationControl("decorateButton", in: app)
        let original = waitForDragPerformance(in: app, timeout: 5, description: "layout ready for dragging",
                                             matching: { !$0.resolving })
        let upperFloor = roomCoordinate(forArtworkCoordinate: CGVector(dx: 0.70, dy: 0.50), in: app)
        dragBowlSlowly(from: original.bowl, to: upperFloor, in: app)
        let resolved = waitForDragPerformance(in: app, timeout: 20, description: "continuous drag and placement validation to finish",
                                             matching: { $0.samples > 5 && !$0.resolving })
        let resolvedMetrics = XCTAttachment(string: "samples=\(resolved.samples)\nmaxMoveMilliseconds=\(resolved.maxMoveMilliseconds)\nresolving=\(resolved.resolving)\nbowl=\(resolved.bowl.dx),\(resolved.bowl.dy)")
        resolvedMetrics.name = "Drag metrics — placement validation completed"
        resolvedMetrics.lifetime = .keepAlways
        add(resolvedMetrics)
        XCTAssertLessThan(resolved.maxMoveMilliseconds, 50,
                          "Each drag update must stay lightweight while full placement validation runs after release.")
        let resolvedSource = artworkCoordinate(forRoomCoordinate: resolved.bowl, in: app)
        XCTAssertEqual(resolvedSource.dx, 0.70, accuracy: 0.06)
        XCTAssertEqual(resolvedSource.dy, 0.50, accuracy: 0.06)
        XCTAssertTrue(element("layoutDoneButton", in: app).isEnabled,
                      "A finished placement must allow the layout to be saved.")
        attachScreenshot(app, named: "Arrangement — sustained dragging responds before safe placement settles")

        tapAnimationControl("layoutCancelButton", in: app)
        let reverted = waitForDragPerformance(in: app, timeout: 5, description: "cancel restores the original layout",
                                             matching: { !$0.resolving && hypot($0.bowl.dx - original.bowl.dx, $0.bowl.dy - original.bowl.dy) < 0.005 })
        XCTAssertEqual(reverted.bowl.dx, original.bowl.dx, accuracy: 0.005)
        XCTAssertEqual(reverted.bowl.dy, original.bowl.dy, accuracy: 0.005)

        tapAnimationControl("decorateButton", in: app)
        let wall = roomCoordinate(forArtworkCoordinate: CGVector(dx: 0.70, dy: 0.30), in: app)
        dragBowlSlowly(from: reverted.bowl, to: wall, in: app)
        // The test-only delayed result leaves a deterministic window in which
        // cancellation must invalidate an outstanding placement calculation.
        let pending = waitForDragPerformance(in: app, timeout: 3, description: "background placement still resolving",
                                            matching: { $0.resolving })
        let pendingMetrics = XCTAttachment(string: "samples=\(pending.samples)\nmaxMoveMilliseconds=\(pending.maxMoveMilliseconds)\nresolving=\(pending.resolving)\nbowl=\(pending.bowl.dx),\(pending.bowl.dy)")
        pendingMetrics.name = "Drag metrics — background placement pending before cancellation"
        pendingMetrics.lifetime = .keepAlways
        add(pendingMetrics)
        XCTAssertGreaterThan(pending.samples, 5)
        XCTAssertLessThan(pending.maxMoveMilliseconds, 50)
        XCTAssertGreaterThan(hypot(pending.bowl.dx - original.bowl.dx, pending.bowl.dy - original.bowl.dy), 0.05,
                             "The cancelled preview must differ from the saved position to expose stale-result overwrites.")
        XCTAssertFalse(element("layoutDoneButton", in: app).isEnabled,
                       "An unresolved layout cannot be committed.")
        XCTAssertTrue(element("layoutCancelButton", in: app).isEnabled,
                      "Cancelling must remain available during background validation.")
        tapAnimationControl("layoutCancelButton", in: app)
        _ = waitForDragPerformance(in: app, timeout: 3, description: "pending placement cancelled and original position restored",
                                  matching: { !$0.resolving && hypot($0.bowl.dx - original.bowl.dx, $0.bowl.dy - original.bowl.dy) < 0.005 })
        waitForElement("decorateButton", in: app)

        let staleResult = XCTNSPredicateExpectation(predicate: NSPredicate { object, _ in
            guard let room = object as? XCUIElement, room.exists,
                  let state = DragPerformanceState(value: room.value) else { return false }
            return state.resolving || hypot(state.bowl.dx - original.bowl.dx, state.bowl.dy - original.bowl.dy) > 0.005
        }, object: element("roomScene", in: app))
        staleResult.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [staleResult], timeout: 5), .completed,
                       "A cancelled background result must not move the bowl or reopen layout resolution.")
        let stable = dragPerformanceState(in: app)
        XCTAssertFalse(stable.resolving)
        XCTAssertEqual(stable.bowl.dx, original.bowl.dx, accuracy: 0.005)
        XCTAssertEqual(stable.bowl.dy, original.bowl.dy, accuracy: 0.005)
        attachScreenshot(app, named: "Arrangement — cancelled background validation cannot overwrite the restored bowl")

        tapAnimationControl("decorateButton", in: app)
        tapAnimationControl("layoutDoneButton", in: app)
        waitForElement("decorateButton", in: app)
        app.terminate()
        app.launchArguments = arguments(reset: false) + ["--drag-performance-test"]
        launchAndEnterHome(app)
        waitForElement("feedButton", in: app)
        let restored = waitForDragPerformance(in: app, timeout: 5, description: "saved layout restored after cancellation",
                                             matching: { !$0.resolving })
        XCTAssertEqual(restored.bowl.dx, original.bowl.dx, accuracy: 0.005)
        XCTAssertEqual(restored.bowl.dy, original.bowl.dy, accuracy: 0.005)
        waitForObservedValue("foodCount", "3", in: app)
        waitForObservedValue("goldCount", "200", in: app)
    }

    @MainActor
    func testNavigationCanResumeAfterCancellingMealAtBowl() throws {
        continueAfterFailure = false
        let app = launchNavigationHome()
        ensureHomeNavigationItemVisible("decorateButton", in: app)
        let arrangeTouch = element("decorateButton", in: app).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        tapAnimationControl("feedButton", in: app)
        _ = waitForNavigation(in: app, timeout: 25, description: "a bite at the food surface before cancellation",
                              matching: { $0.phase == "feeding" && $0.foodContactSamples > 0 })

        // Interrupt only after the low-head pose touches the food, so restoring
        // the ordinary footprint must also recover a safe position by the bowl.
        arrangeTouch.tap()
        let editing = waitForNavigationPhase("editing", in: app, timeout: 5)
        XCTAssertEqual(editing.completedMeals, 0,
                       "Arrangement must interrupt the first meal at the bowl before it completes.")
        XCTAssertGreaterThan(editing.foodContactSamples, 0,
                             "This cancellation must exercise an actual bite, not the walking approach.")
        tapAnimationControl("layoutCancelButton", in: app)
        let settled = waitForNavigationPhase("idle", in: app, timeout: 5)
        XCTAssertEqual(settled.violations, 0,
                       "Restoring the normal pose must not overlap the bowl or leave the floor.")
        XCTAssertEqual(settled.foodContactViolations, 0,
                       "The interrupted meal must keep its mouth aligned with the food.")
        XCTAssertEqual(settled.completedMeals, 0,
                       "The cancelled meal must not run a stale completion after leaving arrangement.")
        waitForObservedValue("foodCount", "2", in: app)
        waitForObservedValue("catSatiety", "60", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        attachScreenshot(app, named: "Navigation — eating at the bowl cancelled into a safe idle pose")

        completeNavigationFeed(in: app, remainingFood: 1)
        waitForObservedValue("catSatiety", "85", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        attachScreenshot(app, named: "Navigation — another meal reaches the bowl after contact cancellation")
    }

    private struct DragPerformanceState {
        let samples: Int
        let maxMoveMilliseconds: Double
        let resolving: Bool
        let bowl: CGVector

        init?(value: Any?) {
            guard let value = value as? String else { return nil }
            let fields = value.split(separator: "|", omittingEmptySubsequences: false)
            guard fields.count == 4, let samples = Int(fields[0]), samples >= 0,
                  let milliseconds = Double(fields[1]), milliseconds.isFinite, milliseconds >= 0,
                  fields[2] == "0" || fields[2] == "1" else { return nil }
            let point = fields[3].split(separator: ",").compactMap { Double($0) }
            guard point.count == 2, point.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else { return nil }
            self.samples = samples
            maxMoveMilliseconds = milliseconds
            resolving = fields[2] == "1"
            bowl = CGVector(dx: point[0], dy: point[1])
        }
    }

    @MainActor
    private func dragPerformanceState(in app: XCUIApplication,
                                      file: StaticString = #filePath, line: UInt = #line) -> DragPerformanceState {
        let value = element("roomScene", in: app).value
        guard let state = DragPerformanceState(value: value) else {
            XCTFail("Expected drag performance diagnostics, received \(String(describing: value))", file: file, line: line)
            return DragPerformanceState(value: "0|0|0|0,0")!
        }
        return state
    }

    @MainActor
    private func waitForDragPerformance(in app: XCUIApplication, timeout: TimeInterval, description: String,
                                        matching condition: @escaping (DragPerformanceState) -> Bool,
                                        file: StaticString = #filePath, line: UInt = #line) -> DragPerformanceState {
        let room = element("roomScene", in: app)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { object, _ in
            guard let target = object as? XCUIElement, target.exists,
                  let state = DragPerformanceState(value: target.value) else { return false }
            return condition(state)
        }, object: room)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: timeout), .completed,
                       "Expected \(description); received \(String(describing: room.value))", file: file, line: line)
        return dragPerformanceState(in: app, file: file, line: line)
    }

    @MainActor
    private func purchaseToyAndCompleteNavigationPlay(in app: XCUIApplication,
                                                       file: StaticString = #filePath, line: UInt = #line) {
        tapQuickPlay(in: app, file: file, line: line)
        scrollCareerPage("destinationScroll", to: "buyToyButton", in: app, file: file, line: line)
        tapAnimationControl("buyToyButton", in: app, file: file, line: line)
        waitForObservedValue("shopGoldCount", "165", in: app, file: file, line: line)
        tapAnimationControl("tabHome", in: app, file: file, line: line)
        let before = waitForNavigationPhase("idle", in: app, timeout: 5, file: file, line: line)
        tapQuickPlay(in: app, file: file, line: line)
        waitForNavigationPhase("playing", in: app, timeout: 5, file: file, line: line)
        let after = waitForNavigationPhase("idle", in: app, timeout: 35, file: file, line: line)
        XCTAssertEqual(after.completedPounces, before.completedPounces + 1,
                       "This play action must complete a real pounce, not a stationary fallback.",
                       file: file, line: line)
        XCTAssertEqual(after.cat.dx, before.cat.dx, accuracy: 0.008,
                       "Playing must return to the starting floor position.", file: file, line: line)
        XCTAssertEqual(after.cat.dy, before.cat.dy, accuracy: 0.008,
                       "Playing must finish its return path.", file: file, line: line)
    }

    @MainActor
    private func waitForNavigationBowlMoved(from original: CGVector, in app: XCUIApplication,
                                            file: StaticString = #filePath, line: UInt = #line) -> NavigationState {
        let done = element("layoutDoneButton", in: app)
        return waitForNavigation(in: app, timeout: 10, description: "the moved bowl placement to finish validation",
                                 matching: { done.exists && done.isEnabled
                                     && hypot($0.bowl.dx - original.dx, $0.bowl.dy - original.dy) > 0.02 },
                                 file: file, line: line)
    }

    @MainActor
    private func dragBowlSlowly(from: CGVector, to: CGVector, in app: XCUIApplication) {
        let room = element("roomScene", in: app)
        room.coordinate(withNormalizedOffset: from)
            .press(forDuration: 0.15, thenDragTo: room.coordinate(withNormalizedOffset: to),
                   withVelocity: .slow, thenHoldForDuration: 0)
    }
}
