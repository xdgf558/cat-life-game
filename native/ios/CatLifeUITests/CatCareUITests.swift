import XCTest

extension RoomHomeUITests {
    @MainActor
    func testFeedingPersistsAcrossRelaunch() throws {
        let app = launchFreshHome()
        waitForValue("foodCount", "3", in: app)
        waitForValue("catSatiety", "35", in: app)

        tap("feedButton", in: app)
        waitForValue("foodCount", "2", in: app)
        waitForValue("catSatiety", "60", in: app)
        attachScreenshot(app, named: "Feeding — food consumed and satiety restored")

        relaunchPreservingSave(app)
        waitForValue("foodCount", "2", in: app)
        waitForValue("catSatiety", "60", in: app)
        attachScreenshot(app, named: "Feeding — restored after cold launch")
    }

    @MainActor
    func testLastFoodStillCompletesMealAtBowl() throws {
        continueAfterFailure = false
        let app = launchNavigationHome()
        assertKnownHomeViewportBaseline(in: app)
        let initialFrame = element("roomScene", in: app).frame
        assertHomeControlRows(in: app, stage: "initial home")
        verifyHomeNavigationTabs(in: app, roomFrame: initialFrame)
        completeNavigationFeed(in: app, remainingFood: 2)
        completeNavigationFeed(in: app, remainingFood: 1)
        let beforeLast = navigationState(in: app)
        let frameBeforeLast = element("roomScene", in: app).frame
        assertRoomFrame(initialFrame, in: app, context: "before the final portion")
        XCTAssertEqual(beforeLast.completedMeals, 2)
        let lastFoodContext = XCTAttachment(string: "foodBefore=1\ncompletedMealsBefore=\(beforeLast.completedMeals)\nfoodContactSamplesBefore=\(beforeLast.foodContactSamples)\nroomFrameBefore=\(frameBeforeLast)")
        lastFoodContext.name = "Feeding — last portion before the care panel changes to restocking"
        lastFoodContext.lifetime = .keepAlways
        add(lastFoodContext)

        // Consuming the last portion changes the primary control to restocking.
        // That UI change must not resize/reset the scene and cancel the meal.
        completeNavigationFeed(in: app, remainingFood: 0)
        let empty = navigationState(in: app)
        let frameAfterLast = element("roomScene", in: app).frame
        XCTAssertEqual(frameAfterLast.minX, frameBeforeLast.minX, accuracy: 0.5,
                       "The empty-food control must preserve the room's horizontal position.")
        XCTAssertEqual(frameAfterLast.minY, frameBeforeLast.minY, accuracy: 0.5,
                       "The empty-food control must preserve the room's vertical position.")
        XCTAssertEqual(frameAfterLast.width, frameBeforeLast.width, accuracy: 0.5,
                       "The care panel must not change the room width when the last food is consumed.")
        XCTAssertEqual(frameAfterLast.height, frameBeforeLast.height, accuracy: 0.5,
                       "The care panel must not resize the room and interrupt the last meal.")
        XCTAssertEqual(empty.completedMeals, 3,
                       "All three portions, including the final one, must complete their eating animation.")
        XCTAssertGreaterThan(empty.foodContactSamples, beforeLast.foodContactSamples,
                             "The last portion must reach the bowl instead of only changing inventory and satiety.")
        waitForObservedValue("catSatiety", "100", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        assertHomeControlRows(in: app, stage: "empty food changes Feed to restocking")
        assertRoomFrame(initialFrame, in: app, context: "after consuming the final portion")
        attachScreenshot(app, named: "Feeding — the final portion completed at the bowl with empty stock")

        app.terminate()
        app.launchArguments = arguments(reset: false) + ["--navigation-test"]
        launchAndEnterHome(app)
        waitForNavigationPhase("idle", in: app, timeout: 15)
        waitForObservedValue("foodCount", "0", in: app)
        waitForObservedValue("catSatiety", "100", in: app)
        assertRoomFrame(initialFrame, in: app, context: "cold launch with empty food")
        tapAnimationControl("feedButton", in: app)
        waitForElement("buyFoodButton", in: app)
        scrollCareerPage("destinationScroll", to: "buyFoodButton", in: app)
        for balance in [180, 160, 140] {
            tapAnimationControl("buyFoodButton", in: app)
            waitForObservedValue("shopGoldCount", "\(balance)", in: app)
        }
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("foodCount", "3", in: app)
        waitForObservedValue("goldCount", "140", in: app)
        assertRoomFrame(initialFrame, in: app, context: "returning from restocking in the shop")
        assertHomeControlRows(in: app, stage: "home after restocking")

        app.terminate()
        app.launchArguments = arguments(reset: false) + ["--navigation-test"]
        launchAndEnterHome(app)
        waitForNavigationPhase("idle", in: app, timeout: 15)
        waitForObservedValue("foodCount", "3", in: app)
        assertRoomFrame(initialFrame, in: app, context: "cold launch after restocking")
        completeNavigationFeed(in: app, remainingFood: 2)
        let restockedMeal = navigationState(in: app)
        XCTAssertEqual(restockedMeal.completedMeals, 1,
                       "A saved empty-to-restocked inventory must still allow a real meal after relaunch.")
        XCTAssertGreaterThan(restockedMeal.foodContactSamples, 0)
        waitForObservedValue("catSatiety", "100", in: app)
        waitForObservedValue("goldCount", "140", in: app)
        assertRoomFrame(initialFrame, in: app, context: "after the restocked meal completes")
        attachScreenshot(app, named: "Feeding — purchased food still reaches the bowl after cold launch")
    }

    @MainActor
    func testEmptyFoodRoutesToShopAndPurchaseUpdatesBalance() throws {
        let app = launchFreshHome()
        waitForValue("goldCount", "200", in: app)
        for remaining in [2, 1, 0] {
            tap("feedButton", in: app)
            waitForValue("foodCount", "\(remaining)", in: app)
        }
        waitForValue("catSatiety", "100", in: app)

        // The same primary control becomes the way to restock when food runs out.
        tap("feedButton", in: app)
        waitForElement("buyFoodButton", in: app)
        waitForValue("shopGoldCount", "200", in: app)
        scrollCareerPage("destinationScroll", to: "buyFoodButton", in: app)
        tap("buyFoodButton", in: app)
        waitForValue("shopGoldCount", "180", in: app)
        attachScreenshot(app, named: "Shop — purchased one portion for 20 gold")

        tap("tabHome", in: app)
        waitForValue("foodCount", "1", in: app)
        waitForValue("goldCount", "180", in: app)
        attachScreenshot(app, named: "Home — food restocked and balance updated")
    }

    @MainActor
    func testCareAnimationsFinishWithoutRepeatingResourceCosts() throws {
        let app = launchAnimationHome()

        tapAnimationControl("feedButton", in: app)
        waitForAnimationPhase("feeding", in: app, timeout: 4)
        attachScreenshot(app, named: "Animation — food approach and feeding in progress")
        waitForObservedValue("foodCount", "2", in: app)
        waitForAnimationPhase("idle", in: app, timeout: 20)
        waitForObservedValue("foodCount", "2", in: app)
        waitForObservedValue("catSatiety", "60", in: app)
        attachScreenshot(app, named: "Animation — feeding finished without a second food charge")

        tapAnimationControl("cleanButton", in: app)
        waitForAnimationPhase("cleaning", in: app, timeout: 4)
        attachScreenshot(app, named: "Animation — cleaning response")
        waitForAnimationPhase("idle", in: app, timeout: 10)

        // An empty toy inventory must still route to the real shop before the
        // playing response can occur. Buying and animating must each happen once.
        tapAnimationControl("playButton", in: app)
        waitForElement("buyToyButton", in: app)
        scrollCareerPage("destinationScroll", to: "buyToyButton", in: app)
        tapAnimationControl("buyToyButton", in: app)
        waitForObservedValue("shopGoldCount", "165", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForAnimationPhase("idle", in: app, timeout: 18)
        tapAnimationControl("playButton", in: app)
        waitForAnimationPhase("playing", in: app, timeout: 4)
        attachScreenshot(app, named: "Animation — looking at and pouncing toward the toy")
        waitForAnimationPhase("idle", in: app, timeout: 18)
        waitForObservedValue("goldCount", "165", in: app)
        waitForObservedValue("foodCount", "2", in: app)
        attachScreenshot(app, named: "Animation — playing settled back into idle")
    }

    @MainActor
    func testQueuedCareCanBeCancelledByRoomArrangement() throws {
        let app = launchAnimationHome()
        waitForElement("homeDecorateButton", in: app)
        let arrangeTouch = element("homeDecorateButton", in: app).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        tapAnimationControl("feedButton", in: app)
        waitForAnimationPhase("feeding", in: app, timeout: 4)

        // These controls are tapped without the slower general-purpose waits:
        // cleaning should queue while the first feeding response is still active.
        tapAnimationControl("cleanButton", in: app)
        arrangeTouch.tap()
        waitForAnimationPhase("editing", in: app, timeout: 5)
        attachScreenshot(app, named: "Animation — arrangement interrupts queued care safely")

        tapAnimationControl("layoutCancelButton", in: app)
        waitForAnimationPhase("idle", in: app, timeout: 5)
        waitForObservedValue("foodCount", "2", in: app)
        waitForObservedValue("catSatiety", "60", in: app)

        // A fresh response must work after cancellation: no stale completion
        // may leave the actor or the native controls permanently busy.
        tapAnimationControl("feedButton", in: app)
        waitForAnimationPhase("feeding", in: app, timeout: 4)
        waitForAnimationPhase("idle", in: app, timeout: 20)
        waitForObservedValue("foodCount", "1", in: app)
        waitForObservedValue("catSatiety", "85", in: app)
        attachScreenshot(app, named: "Animation — new feeding completed after arrangement cancellation")
    }

    @MainActor
    func testReducedMotionSettlesPromptlyAndConsumesFoodOnce() throws {
        let app = launchAnimationHome(reducedMotion: true)
        tapAnimationControl("feedButton", in: app)
        waitForObservedValue("foodCount", "2", in: app, timeout: 4)
        // The ordinary feeding path takes several seconds. With reduced motion,
        // the static response must have settled within this short bounded wait.
        waitForAnimationPhase("idle", in: app, timeout: 2)
        waitForObservedValue("catSatiety", "60", in: app)
        attachScreenshot(app, named: "Animation — reduced motion shows a calm settled cat")

        app.terminate()
        app.launchArguments = arguments(reset: false) + ["--animation-test", "--reduce-motion-test"]
        launchAndEnterHome(app)
        waitForAnimationPhase("idle", in: app, timeout: 10)
        waitForObservedValue("foodCount", "2", in: app)
        waitForObservedValue("catSatiety", "60", in: app)
    }

    @MainActor
    private func launchAnimationHome(reducedMotion: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--animation-test"]
        if reducedMotion { app.launchArguments.append("--reduce-motion-test") }
        launchAndEnterHome(app)
        waitForAnimationPhase("idle", in: app, timeout: 15)
        return app
    }

    @MainActor
    private func waitForAnimationPhase(_ phase: String, in app: XCUIApplication,
                                       timeout: TimeInterval,
                                       file: StaticString = #filePath, line: UInt = #line) {
        waitForObservedValue("roomScene", phase, in: app, timeout: timeout, file: file, line: line)
    }
}
