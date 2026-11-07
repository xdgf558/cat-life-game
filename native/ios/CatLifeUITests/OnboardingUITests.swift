import XCTest

extension RoomHomeUITests {
    @MainActor
    func testFirstHomeEntryToursAllFiveDestinationsWithoutSpendingAndStaysComplete() throws {
        continueAfterFailure = false
        let app = launchOnboardingGame(reset: true, expectsGuide: true)
        let destinations = [("care", "feedButton"), ("work", "startWorkButton"),
                            ("supplies", "shopCategory_supplies"), ("tasks", "tasksScroll"),
                            ("town", "townMapScroll")]
        for (step, destination) in destinations {
            waitForObservedValue("onboardingStep", step, in: app)
            if step == "care" { attachScreenshot(app, named: "Onboarding — first entry introduces care") }
            tapGuideControl("onboardingExploreButton", in: app)
            waitForOnboardingClosed(in: app)
            waitForElement(destination, in: app)
            if step == "care" {
                assertHomeGuideDoesNotOverlapCatStatus(in: app)
                attachScreenshot(app, named: "Onboarding — care shortcut keeps resume visible above cat status")
            }
            if step == "work" { XCTAssertFalse(element("workCountdown", in: app).exists) }
            if step == "tasks" { waitForObservedValue("tasksDailySummary", "0/5", in: app) }
            tapAnimationControl("onboardingResumeButton", in: app)
            waitForObservedValue("onboardingStep", step, in: app)
            tapGuideControl("onboardingNextButton", in: app)
        }
        waitForOnboardingClosed(in: app)
        tapAnimationControl("tabHome", in: app)
        assertOnboardingDidNotSpend(in: app)
        XCTAssertFalse(element("onboardingResumeButton", in: app).exists)
        attachScreenshot(app, named: "Onboarding — completion leaves the original playable home")
        app.terminate()
        app.launchArguments = onboardingArguments(reset: false)
        enterOnboardingGame(app, expectsGuide: false)
        assertOnboardingDidNotSpend(in: app)
        XCTAssertFalse(element("onboardingResumeButton", in: app).exists)
    }

    @MainActor
    func testOnboardingResumesAfterColdLaunchAndSkippedTourCanBeReplayedFromSettings() throws {
        continueAfterFailure = false
        let app = launchOnboardingGame(reset: true, expectsGuide: true)
        tapGuideControl("onboardingNextButton", in: app)
        waitForObservedValue("onboardingStep", "work", in: app)
        tapGuideControl("onboardingExploreButton", in: app)
        waitForOnboardingClosed(in: app)
        waitForElement("startWorkButton", in: app)
        app.terminate()
        app.launchArguments = onboardingArguments(reset: false)
        enterOnboardingGame(app, expectsGuide: true)
        waitForObservedValue("onboardingStep", "work", in: app)
        attachScreenshot(app, named: "Onboarding — unfinished guide resumes its saved step")
        tapGuideControl("onboardingSkipButton", in: app)
        waitForOnboardingClosed(in: app)
        app.terminate()
        app.launchArguments = onboardingArguments(reset: false)
        enterOnboardingGame(app, expectsGuide: true)
        waitForObservedValue("onboardingStep", "work", in: app)
        tapGuideControl("onboardingSkipButton", in: app)
        waitForOnboardingClosed(in: app)
        XCTAssertTrue(element("onboardingResumeButton", in: app).exists)
        tapAnimationControl("settingsButton", in: app)
        tapSettingsRootControl("settingsOnboardingRow", in: app)
        waitForObservedValue("onboardingStep", "care", in: app)
        tapGuideControl("onboardingNextButton", in: app)
        waitForObservedValue("onboardingStep", "work", in: app)
        tapGuideControl("onboardingPreviousButton", in: app)
        waitForObservedValue("onboardingStep", "care", in: app)
        attachScreenshot(app, named: "Onboarding — settings replay starts at care and supports going back")
        tapGuideControl("onboardingSkipButton", in: app)
        waitForOnboardingClosed(in: app)
        tapAnimationControl("tabHome", in: app)
        assertOnboardingDidNotSpend(in: app)
    }

    @MainActor
    func testExistingSaveDoesNotAutoStartGuideButSettingsReplayIsAvailable() throws {
        continueAfterFailure = false
        let app = launchOnboardingGame(reset: true, expectsGuide: false,
                                      extra: ["--onboarding-existing-save"])
        XCTAssertFalse(element("onboardingResumeButton", in: app).exists)
        assertOnboardingDidNotSpend(in: app)
        tapAnimationControl("settingsButton", in: app)
        tapSettingsRootControl("settingsOnboardingRow", in: app)
        waitForObservedValue("onboardingStep", "care", in: app)
        attachScreenshot(app, named: "Onboarding — an existing save opts into the guide from settings")
        tapGuideControl("onboardingSkipButton", in: app)
        waitForOnboardingClosed(in: app)
        tapAnimationControl("tabHome", in: app)
        assertOnboardingDidNotSpend(in: app)
    }

    @MainActor
    func testOnboardingLocalizesAndControlsRemainReachableAtAccessibilitySize() throws {
        continueAfterFailure = false
        let languages = [("zh-Hans", "先认识你的猫咪", "下一步", "跳过引导"),
                         ("zh-Hant", "先認識你的貓咪", "下一步", "跳過引導"),
                         ("en", "Meet your little companion", "Next", "Skip guide")]
        for (code, title, next, skip) in languages {
            let app = XCUIApplication()
            let locale = code == "en" ? "en_US" : (code == "zh-Hant" ? "zh_TW" : "zh_CN")
            app.launchArguments = onboardingArguments(reset: true)
                .map { $0 == "(zh-Hans)" ? "(\(code))" : ($0 == "zh_CN" ? locale : $0) }
                + ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
            enterOnboardingGame(app, expectsGuide: true)
            waitForObservedValue("onboardingStep", "care", in: app)
            waitForLabel("onboardingTitle", title, in: app)
            waitForLabel("onboardingSkipButton", skip, in: app)
            scrollGuide(to: "onboardingExploreButton", in: app)
            XCTAssertTrue(element("onboardingExploreButton", in: app).isHittable)
            attachScreenshot(app, named: "Onboarding — \(code) accessible care instructions")
            tapAnimationControl("onboardingExploreButton", in: app)
            waitForOnboardingClosed(in: app)
            waitForElement("feedButton", in: app)
            assertHomeGuideDoesNotOverlapCatStatus(in: app)
            attachScreenshot(app, named: "Onboarding — \(code) accessible home resume stays clear of cat status")
            tapAnimationControl("onboardingResumeButton", in: app)
            waitForObservedValue("onboardingStep", "care", in: app)
            scrollGuide(to: "onboardingNextButton", in: app)
            waitForLabel("onboardingNextButton", next, in: app)
            tapAnimationControl("onboardingNextButton", in: app)
            waitForObservedValue("onboardingStep", "work", in: app)
            scrollGuide(to: "onboardingPreviousButton", in: app)
            XCTAssertTrue(element("onboardingPreviousButton", in: app).isHittable)
            scrollGuide(to: "onboardingSkipButton", in: app)
            tapAnimationControl("onboardingSkipButton", in: app)
            waitForOnboardingClosed(in: app)
            app.terminate()
        }
    }


    @MainActor
    func testSpotlightsFollowRealControlsAndSkippingKeepsProgressWithoutSpending() throws {
        continueAfterFailure = false
        let app = launchOnboardingGame(reset: true, expectsGuide: true)
        let steps = [("care", ["playButton", "cleanButton", "feedButton"], "feedButton"),
                     ("work", ["tabWork"], "startWorkButton"),
                     ("supplies", ["tabShop"], "shopCategory_supplies"),
                     ("tasks", ["homeTasksButton"], "tasksScroll"),
                     ("town", ["tabTown"], "townMapScroll")]
        for (step, controls, destination) in steps {
            waitForObservedValue("onboardingStep", step, in: app)
            waitForElement("onboardingSpotlight", in: app)
            let spotlight = element("onboardingSpotlight", in: app).frame
            let card = element("onboardingCard", in: app).frame
            XCTAssertTrue(app.frame.contains(spotlight), "Outline \(spotlight) must fit screen \(app.frame), including its stroke.")
            XCTAssertFalse(card.intersects(spotlight), "Guide card must not cover its highlighted controls.")
            attachScreenshot(app, named: "Spotlight — \(step)")
            tapGuideControl("onboardingSkipButton", in: app)
            waitForOnboardingClosed(in: app)
            waitForElement("onboardingResumeButton", in: app)
            var touchPoint = CGPoint(x: spotlight.midX, y: spotlight.midY)
            for id in controls {
                let target = element(id, in: app)
                waitForElement(id, in: app)
                XCTAssertTrue(spotlight.insetBy(dx: -2, dy: -2).contains(target.frame),
                              "Spotlight must contain the actual \(id) frame, not an estimated position.")
                if id == "feedButton" { touchPoint = CGPoint(x: target.frame.midX, y: target.frame.midY) }
            }
            assertHomeGuideDoesNotOverlapCatStatus(in: app)
            assertOnboardingDidNotSpend(in: app)
            tapAnimationControl("onboardingResumeButton", in: app)
            waitForObservedValue("onboardingStep", step, in: app)
            XCTAssertTrue(app.buttons["onboardingSpotlight"].isHittable)
            // A real touch in the hole follows the shortcut, without running the underlying action.
            let origin = app.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(CGVector(dx: touchPoint.x, dy: touchPoint.y)).tap()
            waitForOnboardingClosed(in: app)
            waitForElement(destination, in: app)
            if step == "work" { XCTAssertFalse(element("workCountdown", in: app).exists) }
            tapAnimationControl("tabHome", in: app)
            assertOnboardingDidNotSpend(in: app)
            tapAnimationControl("onboardingResumeButton", in: app)
            waitForObservedValue("onboardingStep", step, in: app)
            tapGuideControl("onboardingNextButton", in: app)
        }
        waitForOnboardingClosed(in: app)
        XCTAssertFalse(element("onboardingResumeButton", in: app).exists)
    }

    private func onboardingArguments(reset: Bool) -> [String] {
        arguments(reset: reset).filter { $0 != "--skip-onboarding" }
    }

    @MainActor
    private func tapGuideControl(_ identifier: String, in app: XCUIApplication) {
        scrollGuide(to: identifier, in: app)
        tapAnimationControl(identifier, in: app)
    }

    @MainActor
    private func scrollGuide(to identifier: String, in app: XCUIApplication) {
        waitForElement("onboardingGuide", in: app)
        if ["onboardingNextButton", "onboardingPreviousButton", "onboardingSkipButton"].contains(identifier) {
            let target = element(identifier, in: app)
            let visible = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                target.exists && target.isHittable && app.frame.contains(target.frame)
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [visible], timeout: 8), .completed,
                           "Pinned guide control \(identifier) must be fully visible and tappable without scrolling.")
            return
        }
        let scroll = element("onboardingGuide", in: app)
        let target = element(identifier, in: app)
        for _ in 0..<40 {
            guard scroll.exists, target.exists else { break }
            var viewport = unobscuredScrollViewport(scroll, in: app)
            let header = element("onboardingHeader", in: app)
            let footer = element("onboardingFooter", in: app)
            let top = header.exists ? max(viewport.minY, header.frame.maxY) : viewport.minY
            let bottom = footer.exists ? min(viewport.maxY, footer.frame.minY) : viewport.maxY
            viewport = CGRect(x: viewport.minX, y: top, width: viewport.width, height: max(0, bottom - top))
            guard viewport.height > 40 else { break }
            let frame = target.frame
            if viewport.contains(frame), target.isHittable { return }
            let distance = frame.minY < viewport.minY + 8
                ? viewport.minY + 8 - frame.minY : viewport.maxY - 8 - frame.maxY
            let bounded = min(viewport.height * 0.55, max(-viewport.height * 0.55, distance))
            let delta = bounded < 0 ? min(-24, bounded) : max(24, bounded)
            let origin = app.coordinate(withNormalizedOffset: .zero)
            // The guide padding stays outside its large tappable action buttons.
            let start = origin.withOffset(CGVector(dx: viewport.minX + 10, dy: viewport.midY - delta / 2))
            let end = origin.withOffset(CGVector(dx: viewport.minX + 10, dy: viewport.midY + delta / 2))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.15)
        }
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "Guide scroll failure — \(identifier)"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        attachScreenshot(app, named: "Guide scroll failure — \(identifier)")
        XCTFail("The guide could not scroll \(identifier) fully into view: target \(target.frame), viewport \(scroll.frame), hittable \(target.isHittable).")
    }

    @MainActor
    private func assertHomeGuideDoesNotOverlapCatStatus(in app: XCUIApplication) {
        waitForElement("onboardingResumeButton", in: app)
        let resume = element("onboardingResumeButton", in: app)
        let catStatus = element("homeCatInfo", in: app)
        if !resume.isHittable {
            attachScreenshot(app, named: "Home guide resume is not tappable")
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "Home guide resume hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
        XCTAssertTrue(resume.isHittable)
        XCTAssertFalse(resume.frame.intersects(catStatus.frame),
                       "Continue guide must not be covered by the cat status card.")
    }

    @MainActor
    private func launchOnboardingGame(reset: Bool, expectsGuide: Bool,
                                      extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = onboardingArguments(reset: reset) + extra
        enterOnboardingGame(app, expectsGuide: expectsGuide)
        return app
    }

    @MainActor
    private func enterOnboardingGame(_ app: XCUIApplication, expectsGuide: Bool) {
        app.launch()
        waitForWelcomeEntryReady(in: app)
        XCTAssertFalse(element("onboardingGuide", in: app).exists,
                       "The guide must wait for the player's explicit home entry.")
        tapAnimationControl("welcomeEnterButton", in: app)
        if expectsGuide { waitForElement("onboardingGuide", in: app) }
        else {
            waitForElement("feedButton", in: app)
            XCTAssertFalse(element("onboardingGuide", in: app).exists)
        }
    }

    @MainActor
    private func waitForOnboardingClosed(in app: XCUIApplication) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"),
                                                     object: element("onboardingGuide", in: app))
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 8), .completed)
    }

    @MainActor
    private func assertOnboardingDidNotSpend(in app: XCUIApplication) {
        waitForObservedValue("goldCount", "200", in: app)
        waitForObservedValue("foodCount", "3", in: app)
    }
}
