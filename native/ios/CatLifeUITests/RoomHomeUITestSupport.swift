import XCTest

extension RoomHomeUITests {
    @MainActor
    func buyFoodForHomeNameProgressCheck(in app: XCUIApplication) {
        tapAnimationControl("tabShop", in: app)
        tapAnimationControl("buyFoodButton", in: app)
        waitForObservedValue("shopGoldCount", "180", in: app)
        tapAnimationControl("closeSheetButton", in: app)
        waitForObservedValue("foodCount", "4", in: app)
        waitForObservedValue("goldCount", "180", in: app)
    }

    @MainActor
    func assertHomeNamePreservedProgress(bowl original: CGVector, in app: XCUIApplication,
                                                file: StaticString = #filePath, line: UInt = #line) {
        waitForObservedValue("foodCount", "4", in: app, file: file, line: line)
        waitForObservedValue("goldCount", "180", in: app, file: file, line: line)
        waitForObservedValue("catSatiety", "35", in: app, file: file, line: line)
        let current = bowlPosition(in: app)
        XCTAssertEqual(current.dx, original.dx, accuracy: 0.005, file: file, line: line)
        XCTAssertEqual(current.dy, original.dy, accuracy: 0.005, file: file, line: line)
    }

    @MainActor
    func assertSettingsLanguageSelection(_ code: String, in app: XCUIApplication,
                                                 file: StaticString = #filePath, line: UInt = #line) {
        for option in ["zh-Hans", "zh-Hant", "en"] {
            waitForObservedValue("languageOption_\(option)", option == code ? "selected" : "unselected",
                                 in: app, file: file, line: line)
        }
    }

    @MainActor
    func waitForLabel(_ identifier: String, _ expected: String, in app: XCUIApplication,
                              contains: Bool = false, file: StaticString = #filePath, line: UInt = #line) {
        let target = element(identifier, in: app)
        let predicate = NSPredicate(format: contains ? "exists == true AND label CONTAINS %@"
                                                    : "exists == true AND label == %@", expected)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: target)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 8), .completed,
                       "\(identifier) should display \(expected); got \(target.label)", file: file, line: line)
    }

    @MainActor
    func scrollCareerPage(_ scrollIdentifier: String, to identifier: String,
                                   in app: XCUIApplication,
                                   file: StaticString = #filePath, line: UInt = #line) {
        scrollPage(scrollIdentifier, to: identifier, allowDisabled: true, maximumDrags: 9,
                   in: app, file: file, line: line)
    }

    @MainActor
    func scrollPage(_ scrollIdentifier: String, to identifier: String,
                              allowDisabled: Bool, maximumDrags: Int,
                              in app: XCUIApplication,
                              file: StaticString = #filePath, line: UInt = #line) {
        waitForElement(scrollIdentifier, in: app, file: file, line: line)
        let scroll = element(scrollIdentifier, in: app)
        let target = element(identifier, in: app)
        var searchingForward = false
        var movements: [String] = []
        for step in 0...maximumDrags {
            guard scroll.exists else {
                movements.append("step=\(step), scroll no longer exists")
                break
            }
            let viewport = unobscuredScrollViewport(scroll, in: app)
            guard viewport.width > 20, viewport.height > 40 else { break }
            let maximumDistance = viewport.height * 0.6
            let distance: CGFloat
            if target.exists {
                let frame = target.frame
                if frame.width > 0, frame.height > 0, viewport.contains(frame),
                   (allowDisabled && !target.isEnabled) || target.isHittable { return }
                // Move only the amount required to reveal the target, with a
                // small margin. Full-screen swipes can repeatedly overshoot a
                // short stat row or equipment tile in opposite directions.
                if frame.minY < viewport.minY + 8 {
                    distance = viewport.minY + 8 - frame.minY
                } else if frame.maxY > viewport.maxY - 8 {
                    distance = viewport.maxY - 8 - frame.maxY
                } else {
                    distance = viewport.midY - frame.midY
                }
                movements.append("step=\(step), target=\(frame), viewport=\(viewport), delta=\(distance)")
            } else {
                // Lazy grids can remove offscreen rows from the AX tree.
                // Rewind using the actual content offset, then search forward.
                // Pulling down at the top instead can dismiss the entire sheet.
                let contentFrame = scroll.children(matching: .other).allElementsBoundByIndex
                    .map(\.frame)
                    .filter { $0.width > viewport.width / 2 && $0.height > viewport.height }
                    .max { $0.height < $1.height }
                guard let contentFrame else {
                    movements.append("step=\(step), target absent, no measurable scroll content")
                    break
                }
                let remainingToTop = max(0, viewport.minY - contentFrame.minY)
                // Stop within the last touch-slop-sized distance. A smaller
                // drag cannot reliably scroll, and must never become a pull
                // past the top of a dismissible sheet.
                if remainingToTop <= 20 { searchingForward = true }
                distance = searchingForward ? -maximumDistance
                    : min(maximumDistance, remainingToTop - 8)
                movements.append("step=\(step), target absent, content=\(contentFrame), viewport=\(viewport), remainingToTop=\(remainingToTop), searchingForward=\(searchingForward), delta=\(distance)")
            }
            guard step < maximumDrags else { break }
            let bounded = min(maximumDistance, max(-maximumDistance, distance))
            let delta = bounded < 0 ? min(-12, bounded) : max(12, bounded)
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: viewport.midX, dy: viewport.midY - delta / 2))
            let end = origin.withOffset(CGVector(dx: viewport.midX, dy: viewport.midY + delta / 2))
            // Both endpoints stay inside the unobscured viewport. The slow
            // drag and brief hold avoid fling momentum beyond the target.
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.15)
        }
        let hierarchy = XCTAttachment(string: "target=\(identifier)\nscroll=\(scrollIdentifier)\n\(movements.joined(separator: "\n"))\n\(app.debugDescription)")
        hierarchy.name = "Scroll failure — \(identifier)"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        XCTFail("The real page could not scroll \(identifier) fully into view.", file: file, line: line)
    }

    @MainActor
    func unobscuredScrollViewport(_ scroll: XCUIElement, in app: XCUIApplication) -> CGRect {
        let viewport = scroll.frame.intersection(app.frame)
        var contentTop = viewport.minY
        // A SwiftUI scroll view may extend behind its translucent navigation
        // bar. XCTest can call a partly covered button hittable even though
        // its centre tap lands on that bar, so exclude the real bar geometry.
        for bar in app.navigationBars.allElementsBoundByIndex {
            let frame = bar.frame
            if frame.intersects(viewport) {
                contentTop = max(contentTop, min(frame.maxY, viewport.maxY))
            }
        }
        return CGRect(x: viewport.minX, y: contentTop,
                      width: viewport.width, height: max(0, viewport.maxY - contentTop))
    }

    @MainActor
    func assertVisibleTimerChanges(_ identifier: String, increasing: Bool, upperBound: Int? = nil,
                                            in app: XCUIApplication, context: String,
                                            file: StaticString = #filePath, line: UInt = #line) throws {
        scrollRecoveryCard(to: identifier, in: app, file: file, line: line)
        let timer = element(identifier, in: app)
        let initialLabel = timer.label
        let initial = try XCTUnwrap(displayedTimerSeconds(initialLabel),
                                   "Expected a displayed duration in \(identifier): \(initialLabel)",
                                   file: file, line: line)
        if let upperBound {
            XCTAssertGreaterThan(initial, 0, file: file, line: line)
            XCTAssertLessThanOrEqual(initial, upperBound,
                                    "The shift must not exceed its configured real duration.",
                                    file: file, line: line)
        }
        var latestLabel = initialLabel
        var latest = initial
        let changes = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            latestLabel = timer.label
            guard let seconds = self.displayedTimerSeconds(latestLabel) else { return false }
            latest = seconds
            return increasing ? seconds >= initial + 2 : seconds <= initial - 2
        }, object: nil)
        let result = XCTWaiter.wait(for: [changes], timeout: 7)
        let evidence = XCTAttachment(string: "\(context)\n\(identifier): \(initialLabel) -> \(latestLabel)\nseconds: \(initial) -> \(latest)")
        evidence.name = "Recovery clock — \(context)"
        evidence.lifetime = .keepAlways
        add(evidence)
        XCTAssertEqual(result, .completed,
                       "\(identifier) must visibly \(increasing ? "increase" : "decrease") by at least two seconds within seven seconds; observed \(initialLabel) -> \(latestLabel).",
                       file: file, line: line)
    }

    func displayedTimerSeconds(_ label: String) -> Int? {
        guard let range = label.range(of: #"\d+(?::[0-5]\d){1,2}"#, options: .regularExpression) else { return nil }
        let components = label[range].split(separator: ":").compactMap { Int($0) }
        guard components.count == 2 || components.count == 3 else { return nil }
        return components.reduce(0) { $0 * 60 + $1 }
    }

    @MainActor
    func scrollRecoveryCard(to identifier: String, in app: XCUIApplication,
                                     file: StaticString = #filePath, line: UInt = #line) {
        scrollPage("destinationScroll", to: identifier, allowDisabled: false, maximumDrags: 6,
                   in: app, file: file, line: line)
    }

    @MainActor
    func waitForAppBackground(in app: XCUIApplication,
                                       file: StaticString = #filePath, line: UInt = #line) {
        let backgrounded = XCTNSPredicateExpectation(predicate: NSPredicate { object, _ in
            guard let application = object as? XCUIApplication else { return false }
            return application.state == .runningBackground || application.state == .runningBackgroundSuspended
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [backgrounded], timeout: 8), .completed, file: file, line: line)
    }

    @MainActor
    func assertHomeControlRows(in app: XCUIApplication, stage: String,
                                       file: StaticString = #filePath, line: UInt = #line) {
        waitForElement("homeResourceCapsule", in: app, file: file, line: line)
        waitForElement("homeCatInfo", in: app, file: file, line: line)
        let resources = element("homeResourceCapsule", in: app)
        let gold = element("goldCount", in: app).frame
        let stamina = element("staminaCount", in: app).frame
        XCTAssertTrue(resources.descendants(matching: .any).matching(identifier: "goldCount").firstMatch.exists,
                      "Gold must belong to the shared resource capsule.", file: file, line: line)
        XCTAssertTrue(resources.descendants(matching: .any).matching(identifier: "staminaCount").firstMatch.exists,
                      "Stamina must belong to the same resource capsule.", file: file, line: line)
        XCTAssertEqual(gold.midY, stamina.midY, accuracy: 1, file: file, line: line)
        XCTAssertLessThanOrEqual(gold.maxX, stamina.minX + 1, file: file, line: line)
        XCTAssertTrue(resources.frame.insetBy(dx: -1, dy: -1).contains(gold), file: file, line: line)
        XCTAssertTrue(resources.frame.insetBy(dx: -1, dy: -1).contains(stamina), file: file, line: line)

        let catInfo = element("homeCatInfo", in: app).frame
        let food = element("foodCount", in: app).frame
        XCTAssertGreaterThanOrEqual(food.minX, catInfo.maxX - 1,
                                    "Food stock must be to the right of the cat information, not underneath it.", file: file, line: line)
        XCTAssertEqual(food.midY, catInfo.midY, accuracy: 1,
                       "Cat information and food stock must share one horizontal row.", file: file, line: line)

        let careIDs = ["feedButton", "cleanButton", "playButton"]
        let care = careIDs.map { element($0, in: app).frame }
        for (index, identifier) in careIDs.enumerated() {
            let control = element(identifier, in: app)
            XCTAssertTrue(control.isHittable, "\(identifier) must remain reachable.", file: file, line: line)
            XCTAssertGreaterThanOrEqual(care[index].width, 44, file: file, line: line)
            XCTAssertGreaterThanOrEqual(care[index].height, 44, file: file, line: line)
            XCTAssertEqual(care[index].midY, care[0].midY, accuracy: 1,
                           "Feed, Clean and Play must stay on the same row even when food is empty.", file: file, line: line)
            if index > 0 {
                XCTAssertLessThanOrEqual(care[index - 1].maxX, care[index].minX + 1,
                                         "Care button hit areas must not overlap.", file: file, line: line)
            }
        }

        let bar = element("homeNavigationBar", in: app)
        var tabMeasurements: [String] = []
        var tabMidY: CGFloat?
        for (index, identifier) in homeNavigationIdentifiers.enumerated() {
            ensureHomeNavigationItemVisible(identifier, in: app, file: file, line: line)
            let target = element(identifier, in: app)
            let frame = target.frame
            XCTAssertEqual(app.buttons.matching(identifier: identifier).count, 1,
                           "The destination must have one bottom entry, with no duplicate at the top.", file: file, line: line)
            XCTAssertTrue(bar.descendants(matching: .button).matching(identifier: identifier).firstMatch.exists,
                          "\(identifier) must belong to the horizontal bottom bar.", file: file, line: line)
            XCTAssertTrue(homeNavigationItemIsFullyVisible(identifier, in: app), file: file, line: line)
            XCTAssertEqual(frame.midY, tabMidY ?? frame.midY, accuracy: 1, file: file, line: line)
            tabMidY = frame.midY
            XCTAssertGreaterThanOrEqual(frame.width, 44, file: file, line: line)
            XCTAssertGreaterThanOrEqual(frame.height, 44, file: file, line: line)
            if index > 0 {
                // Read both frames at the same scroll offset, including the
                // preceding item if it has just moved outside the viewport.
                let previous = element(homeNavigationIdentifiers[index - 1], in: app).frame
                XCTAssertLessThanOrEqual(previous.maxX, frame.minX + 1,
                                         "The eight destinations must keep their declared left-to-right order.", file: file, line: line)
            }
            tabMeasurements.append("\(identifier)=\(frame); bar=\(bar.frame)")
        }
        let identifiers = ["roomScene", "homeResourceCapsule", "goldCount", "staminaCount", "homeCatInfo", "foodCount"] + careIDs
        let measurements = (identifiers.map { "\($0)=\(element($0, in: app).frame)" } + tabMeasurements).joined(separator: "\n")
        let attachment = XCTAttachment(string: "stage=\(stage)\nwindow=\(app.frame)\n\(measurements)")
        attachment.name = "Home layout — \(stage)"
        attachment.lifetime = .keepAlways
        add(attachment)
        attachScreenshot(app, named: "Home layout — \(stage)")
    }

    @MainActor
    func verifyHomeNavigationTabs(in app: XCUIApplication, roomFrame: CGRect,
                                          file: StaticString = #filePath, line: UInt = #line) {
        tapAnimationControl("tabHome", in: app, file: file, line: line)
        assertRoomFrame(roomFrame, in: app, context: "tapping Home", file: file, line: line)
        for (tab, destination) in [("tabWork", "startWorkButton"), ("tabShop", "buyFoodButton"),
                                   ("tabInventory", "inventoryFoodCount"), ("tabPlayer", "profileScroll")] {
            tapAnimationControl(tab, in: app, file: file, line: line)
            waitForElement(destination, in: app, file: file, line: line)
            tapAnimationControl("closeSheetButton", in: app, file: file, line: line)
            assertRoomFrame(roomFrame, in: app, context: "returning from \(tab)", file: file, line: line)
        }
        tapAnimationControl("tabTown", in: app, file: file, line: line)
        XCTAssertTrue(app.navigationBars["我的猫咪"].waitForExistence(timeout: 8), file: file, line: line)
        tapAnimationControl("closeSheetButton", in: app, file: file, line: line)
        assertRoomFrame(roomFrame, in: app, context: "returning from Cats", file: file, line: line)
        tapAnimationControl("decorateButton", in: app, file: file, line: line)
        waitForElement("layoutCancelButton", in: app, file: file, line: line)
        assertRoomFrame(roomFrame, in: app, context: "entering arrangement from the bottom bar", file: file, line: line)
        tapAnimationControl("layoutCancelButton", in: app, file: file, line: line)
        assertRoomFrame(roomFrame, in: app, context: "cancelling arrangement from the bottom bar", file: file, line: line)
        tapAnimationControl("decorateButton", in: app, file: file, line: line)
        tapAnimationControl("layoutDoneButton", in: app, file: file, line: line)
        assertRoomFrame(roomFrame, in: app, context: "finishing arrangement from the bottom bar", file: file, line: line)
        tapAnimationControl("settingsButton", in: app, file: file, line: line)
        waitForElement("settingsLanguageRow", in: app, file: file, line: line)
        tapAnimationControl("settingsCloseButton", in: app, file: file, line: line)
        assertRoomFrame(roomFrame, in: app, context: "closing settings from the bottom bar", file: file, line: line)
        waitForObservedValue("foodCount", "3", in: app, file: file, line: line)
        waitForObservedValue("goldCount", "200", in: app, file: file, line: line)
        waitForObservedValue("staminaCount", "80", in: app, file: file, line: line)
    }

    @MainActor
    func assertKnownHomeViewportBaseline(in app: XCUIApplication,
                                                 file: StaticString = #filePath, line: UInt = #line) {
        let window = app.frame.size
        // Measured on build 13 before rearranging controls or adding Welcome;
        // these reference dimensions must not be derived from the current UI.
        if abs(window.width - 375) <= 0.5 && abs(window.height - 667) <= 0.5 {
            assertRoomFrame(CGRect(x: 0, y: 20, width: 375, height: 436), in: app,
                            context: "against the build 13 iPhone SE baseline", file: file, line: line)
        } else if abs(window.width - 402) <= 0.5 && abs(window.height - 874) <= 0.5 {
            assertRoomFrame(CGRect(x: 0, y: 62, width: 402, height: 567), in: app,
                            context: "against the build 13 iPhone Pro baseline", file: file, line: line)
        }
    }

    @MainActor
    func assertRoomFrame(_ expected: CGRect, in app: XCUIApplication, context: String,
                                  file: StaticString = #filePath, line: UInt = #line) {
        let room = element("roomScene", in: app)
        let stable = XCTNSPredicateExpectation(predicate: NSPredicate { object, _ in
            guard let target = object as? XCUIElement, target.exists else { return false }
            let actual = target.frame
            return abs(actual.minX - expected.minX) <= 0.5 && abs(actual.minY - expected.minY) <= 0.5
                && abs(actual.width - expected.width) <= 0.5 && abs(actual.height - expected.height) <= 0.5
        }, object: room)
        XCTAssertEqual(XCTWaiter.wait(for: [stable], timeout: 8), .completed,
                       "The room viewport changed \(context): expected \(expected), received \(room.frame)", file: file, line: line)
        let attachment = XCTAttachment(string: "context=\(context)\nexpected=\(expected)\nactual=\(room.frame)")
        attachment.name = "Home viewport — \(context)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func launchAndEnterHome(_ app: XCUIApplication,
                                     file: StaticString = #filePath, line: UInt = #line) {
        app.launch()
        waitForWelcomeEntryReady(in: app, file: file, line: line)
        let welcomeVersion = element("welcomeVersion", in: app).value as? String
        tapAnimationControl("welcomeEnterButton", in: app, file: file, line: line)
        let room = element("roomScene", in: app)
        if !room.waitForExistence(timeout: 3) {
            let enter = element("welcomeEnterButton", in: app)
            // One initial simulator tap was recorded inside the ready button,
            // yet the same ready welcome remained with no loading or alert.
            // Retry only that unchanged state, once, and retain its evidence.
            if element("welcomeScreen", in: app).exists,
               !room.exists, !element("feedButton", in: app).exists,
               enter.exists, enter.isEnabled, enter.isHittable,
               !element("welcomeLoading", in: app).exists,
               !element("welcomeRetryButton", in: app).exists,
               app.alerts.count == 0,
               element("welcomeVersion", in: app).value as? String == welcomeVersion {
                let evidence = XCTAttachment(string: "One bounded retry after the initial tap left the same ready welcome.\n\(app.debugDescription)")
                evidence.name = "Welcome — initial tap left unchanged ready screen"
                evidence.lifetime = .keepAlways
                add(evidence)
                attachScreenshot(app, named: "Welcome — unchanged ready state before one retry")
                enter.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
        }
        waitForElement("feedButton", in: app, file: file, line: line)
    }

    @MainActor
    func waitForWelcomeEntryReady(in app: XCUIApplication,
                                          file: StaticString = #filePath, line: UInt = #line) {
        let enter = element("welcomeEnterButton", in: app)
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND enabled == true AND hittable == true"), object: enter)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 20), .completed,
                       "Welcome must finish loading before the user can enter home.", file: file, line: line)
    }

    @MainActor
    func launchFreshHome() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true)
        launchAndEnterHome(app)
        waitForElement("feedButton", in: app)
        return app
    }

    /// One predicate observes the element and value together. A separate
    /// existence wait can miss short, intentional phases such as cleaning.
    @MainActor
    func waitForObservedValue(_ identifier: String, _ expected: String, in app: XCUIApplication,
                                      timeout: TimeInterval = 8,
                                      file: StaticString = #filePath, line: UInt = #line) {
        let target = element(identifier, in: app)
        let predicate = NSPredicate(format: "exists == true AND value == %@", expected)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: target)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        if result != .completed {
            let hierarchy = XCTAttachment(string: "target=\(identifier)\nexpected=\(expected)\n\(app.debugDescription)")
            hierarchy.name = "Observed value failure — \(identifier)"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
            attachScreenshot(app, named: "Observed value failure — \(identifier)")
        }
        XCTAssertEqual(result, .completed,
                       "\(identifier) should become \(expected); got \(String(describing: target.value))",
                       file: file, line: line)
    }

    private var homeNavigationIdentifiers: [String] {
        ["tabHome", "tabWork", "tabShop", "tabInventory", "tabTown", "tabPlayer", "decorateButton", "settingsButton"]
    }

    @MainActor
    func homeNavigationItemIsFullyVisible(_ identifier: String, in app: XCUIApplication) -> Bool {
        let bar = element("homeNavigationBar", in: app)
        let target = element(identifier, in: app)
        guard bar.exists, target.exists else { return false }
        let viewport = bar.frame.intersection(app.frame).insetBy(dx: -0.5, dy: -0.5)
        let frame = target.frame
        guard frame.width >= 44, frame.height >= 44, viewport.contains(frame) else { return false }
        return target.isHittable
    }

    @MainActor
    func ensureHomeNavigationItemVisible(_ identifier: String, in app: XCUIApplication,
                                                  file: StaticString = #filePath, line: UInt = #line) {
        guard homeNavigationIdentifiers.contains(identifier) else { return }
        waitForElement("homeNavigationBar", in: app, timeout: 8, file: file, line: line)
        let bar = element("homeNavigationBar", in: app)
        let target = element(identifier, in: app)
        for _ in 0..<5 {
            if homeNavigationItemIsFullyVisible(identifier, in: app) { return }
            let viewport = bar.frame.intersection(app.frame)
            XCTAssertTrue(target.exists, "The bottom bar must retain its eight named destinations.", file: file, line: line)
            if target.frame.minX < viewport.minX { bar.swipeRight() }
            else if target.frame.maxX > viewport.maxX { bar.swipeLeft() }
            else { break }
        }
        XCTAssertTrue(homeNavigationItemIsFullyVisible(identifier, in: app),
                      "\(identifier) must scroll fully inside the bottom bar before it is tapped; target=\(target.frame), bar=\(bar.frame)",
                      file: file, line: line)
    }

    @MainActor
    func tapAnimationControl(_ identifier: String, in app: XCUIApplication,
                                      file: StaticString = #filePath, line: UInt = #line) {
        ensureHomeNavigationItemVisible(identifier, in: app, file: file, line: line)
        let target = element(identifier, in: app)
        if !(target.exists && target.isEnabled && target.isHittable) {
            let ready = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == true AND enabled == true AND hittable == true"),
                object: target)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 8), .completed,
                           "\(identifier) did not become tappable", file: file, line: line)
        }
        target.tap()
    }

    @MainActor
    func bringIntoView(_ identifier: String, in app: XCUIApplication) {
        let target = element(identifier, in: app)
        for _ in 0..<3 {
            if target.isHittable { return }
            app.scrollViews.firstMatch.swipeUp()
        }
    }

    @MainActor
    func relaunchPreservingSave(_ app: XCUIApplication) {
        app.terminate()
        app.launchArguments = arguments(reset: false)
        launchAndEnterHome(app)
        waitForElement("feedButton", in: app)
    }

    func arguments(reset: Bool) -> [String] {
        var values = ["--ui-testing", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        if reset { values.append("--reset-ui-test-save") }
        return values
    }

    @MainActor
    func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    func waitForElement(_ identifier: String, in app: XCUIApplication,
                                timeout: TimeInterval = 15,
                                file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element(identifier, in: app).waitForExistence(timeout: timeout),
                      "Expected UI element: \(identifier)", file: file, line: line)
    }

    @MainActor
    func waitForValue(_ identifier: String, _ expected: String, in app: XCUIApplication,
                              timeout: TimeInterval = 15,
                              file: StaticString = #filePath, line: UInt = #line) {
        let target = element(identifier, in: app)
        XCTAssertTrue(target.waitForExistence(timeout: timeout),
                      "Expected value element: \(identifier)", file: file, line: line)
        let predicate = NSPredicate(format: "value == %@", expected)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: target)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed,
                       "\(identifier) should have value \(expected); got \(String(describing: target.value))",
                       file: file, line: line)
    }

    @MainActor
    func tap(_ identifier: String, in app: XCUIApplication,
                     file: StaticString = #filePath, line: UInt = #line) {
        ensureHomeNavigationItemVisible(identifier, in: app, file: file, line: line)
        let target = element(identifier, in: app)
        XCTAssertTrue(target.waitForExistence(timeout: 15),
                      "Expected tappable element: \(identifier)", file: file, line: line)
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND enabled == true AND hittable == true"),
            object: target)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 15), .completed,
                       "\(identifier) did not become enabled and hittable", file: file, line: line)
        target.tap()
    }

    @MainActor
    func attachScreenshot(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
