import XCTest

extension RoomHomeUITests {
    @MainActor
    func testHabitHome65CareBarAndNeedBubbleBothOfferPlayChoicesAndRestoreTheStage() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--habit-play-need-fixture", "--furniture-test"]
        launchAndEnterHome(app)
        _ = waitForFurniture(in: app, description: "the real low-mood companion is ready",
                             matching: { $0.phase == "idle" && !$0.pending })
        waitForLabel("catNeedBubble", "陪我玩！", in: app)
        let identifiers = ["homeNamePlaque", "homeResourceCapsule", "homeMyCatsButton", "homeDecorateButton",
                           "roomStage63", "homeCareBar63", "feedButton", "cleanButton", "playButton", "roomViewControls"]
        let frames = Dictionary(uniqueKeysWithValues: identifiers.map { ($0, element($0, in: app).frame) })
        for entry in ["playButton", "catNeedBubble"] {
            tapAnimationControl(entry, in: app)
            let quick = habitHome65Choice("quickPlayChoice", labels: ["快速陪玩", "Quick Play"], in: app)
            let together = habitHome65Choice("playTogetherChoice", labels: ["一起玩", "Play Together"], in: app)
            XCTAssertTrue(quick.waitForExistence(timeout: 5) && quick.isHittable,
                          "Both entry points must preserve the explicit quick-play choice.")
            XCTAssertTrue(together.waitForExistence(timeout: 5) && together.isHittable,
                          "The new care bar and demand bubble must both offer Play Together.")
            attachScreenshot(app, named: "Habits 65 — \(entry) opens the same real play choices")
            together.tap()
            waitForElement("playTogetherStage", in: app)
            XCTAssertTrue(element("playTogetherStage", in: app).isHittable)
            XCTAssertFalse(element("roomScene", in: app).isHittable,
                           "The covered home scene must not accept interaction during Play Together.")
            XCTAssertFalse(element("playButton", in: app).isHittable)
            XCTAssertFalse(element("roomViewControls", in: app).isHittable)
            attachScreenshot(app, named: "Habits 65 — Play Together owns the foreground after \(entry)")
            tapAnimationControl("playTogetherFinishButton", in: app)
            waitForObservedValue("playTogetherResult", "cat_001|0|0", in: app)
            tapAnimationControl("playTogetherFinishButton", in: app)
            waitForElement("homeCareBar63", in: app)
            _ = waitForFurniture(in: app, description: "home resumes after ending without an input",
                                 matching: { $0.phase == "idle" && !$0.pending })
            for (identifier, frame) in frames {
                let current = element(identifier, in: app)
                XCTAssertTrue(current.exists && current.isHittable, "\(identifier) must return after dismissing Play Together.")
                XCTAssertEqual(current.frame.minX, frame.minX, accuracy: 1, identifier)
                XCTAssertEqual(current.frame.minY, frame.minY, accuracy: 1, identifier)
                XCTAssertEqual(current.frame.width, frame.width, accuracy: 1, identifier)
                XCTAssertEqual(current.frame.height, frame.height, accuracy: 1, identifier)
            }
            waitForObservedValue("goldCount", "200", in: app)
            waitForObservedValue("foodCount", "3", in: app)
            waitForObservedValue("toyCount", "3", in: app)
            XCTAssertEqual(try homeCareState63(in: app)["mood"] as? Int, 30,
                           "Merely opening and ending Play Together must not grant quick-play effects.")
            waitForLabel("catNeedBubble", "陪我玩！", in: app)
            attachScreenshot(app, named: "Habits 65 — unchanged HUD and real supplies restored after \(entry)")
        }
    }

    @MainActor
    func testHabitHome65IntroStaysInsideTheStageAndClearOfViewControlsAtLargestType() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--habit-play-need-fixture", "--furniture-test",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        launchAndEnterHome(app, keepsHabitIntro: true)
        waitForElement("habitRoomPromptScroll", in: app)
        let prompt = element("habitRoomPromptScroll", in: app).frame
        XCTAssertTrue(element("roomStage63", in: app).frame.contains(prompt),
                      "The native scroll viewport, including long prompt text, belongs within the room stage.")
        for id in ["roomViewControls", "homeNamePlaque", "homeResourceCapsule", "homeMyCatsButton",
                   "homeDecorateButton", "homeCareBar63", "homeNavigationBar"] {
            XCTAssertFalse(prompt.intersects(element(id, in: app).frame), "The habit prompt must leave \(id) clear.")
        }
        XCTAssertFalse(element("catNeedBubble", in: app).exists, "The introductory prompt temporarily replaces the need bubble.")
        attachScreenshot(app, named: "Habits 65 — largest-type introduction stays above the stage view capsule")
        scrollCareerPage("habitRoomPromptScroll", to: "habitIntroLater", in: app)
        tapAnimationControl("habitIntroLater", in: app)
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"),
                                             object: element("habitRoomPromptScroll", in: app))
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 8), .completed)
        waitForLabel("catNeedBubble", "陪我玩！", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        waitForObservedValue("toyCount", "3", in: app)
        attachScreenshot(app, named: "Habits 65 — postponing the introduction restores the real need action")
    }

    @MainActor
    private func habitHome65Choice(_ identifier: String, labels: [String], in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier == %@ OR label IN %@", identifier, labels)).firstMatch
    }
}
