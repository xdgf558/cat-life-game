import XCTest

extension RoomHomeUITests {
    var playerStarterEquipment: [(String, String)] {
        [("head", "starter_cap"), ("body", "starter_jacket"),
         ("feet", "starter_sneakers"), ("accessory", "starter_charm")]
    }

    @MainActor
    func openPlayerProfile(in app: XCUIApplication,
                                    file: StaticString = #filePath, line: UInt = #line) {
        tapAnimationControl("tabPlayer", in: app, file: file, line: line)
        waitForElement("profileScroll", in: app, file: file, line: line)
    }

    @MainActor
    func tapProfilePageControl(_ identifier: String, scroll: String,
                                        in app: XCUIApplication,
                                        file: StaticString = #filePath, line: UInt = #line) {
        scrollCareerPage(scroll, to: identifier, in: app, file: file, line: line)
        tapAnimationControl(identifier, in: app, file: file, line: line)
    }

    @MainActor
    func tapProfileControl(_ identifier: String, in app: XCUIApplication,
                                    file: StaticString = #filePath, line: UInt = #line) {
        tapProfilePageControl(identifier, scroll: "profileScroll", in: app, file: file, line: line)
    }

    @MainActor
    func assertProfileValue(_ identifier: String, _ expected: String,
                                      in app: XCUIApplication,
                                      file: StaticString = #filePath, line: UInt = #line) {
        scrollCareerPage("profileScroll", to: identifier, in: app, file: file, line: line)
        waitForObservedValue(identifier, expected, in: app, file: file, line: line)
    }

    @MainActor
    func assertWorkQuote(duration: Int, stamina: Int, mood: Int,
                                  in app: XCUIApplication,
                                  file: StaticString = #filePath, line: UInt = #line) {
        for (identifier, value) in [("workQuoteDurationSeconds", duration),
                                    ("workQuoteStaminaCost", stamina), ("workQuoteMoodCost", mood)] {
            scrollRecoveryCard(to: identifier, in: app, file: file, line: line)
            waitForObservedValue(identifier, "\(value)", in: app, file: file, line: line)
        }
    }

    @MainActor
    func openCareerHome(in app: XCUIApplication,
                                 file: StaticString = #filePath, line: UInt = #line) {
        tapAnimationControl("tabWork", in: app, file: file, line: line)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            self.element("playerLevel", in: app).exists
                || self.element("workResultID", in: app).exists
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed,
                       "Opening Work must show its home or the newly committed result.", file: file, line: line)
        if element("workResultID", in: app).exists {
            closeCareerResult(in: app, file: file, line: line)
        }
        waitForElement("playerLevel", in: app, file: file, line: line)
    }

    @MainActor
    func tapCareerControl(_ identifier: String, in app: XCUIApplication,
                                   file: StaticString = #filePath, line: UInt = #line) {
        scrollRecoveryCard(to: identifier, in: app, file: file, line: line)
        tapAnimationControl(identifier, in: app, file: file, line: line)
    }

    @MainActor
    func openCareerResult(in app: XCUIApplication,
                                   file: StaticString = #filePath, line: UInt = #line) {
        if !element("workResultID", in: app).exists {
            tapCareerControl("careerPreviousResultButton", in: app, file: file, line: line)
        }
        waitForElement("workResultID", in: app, file: file, line: line)
    }

    @MainActor
    func closeCareerResult(in app: XCUIApplication,
                                    file: StaticString = #filePath, line: UInt = #line) {
        let done = element("careerResultDoneButton", in: app)
        if !(done.exists && done.isHittable
             && unobscuredScrollViewport(element("careerResultScroll", in: app), in: app).contains(done.frame)) {
            scrollCareerPage("careerResultScroll", to: "careerResultDoneButton", in: app, file: file, line: line)
        }
        tapAnimationControl("careerResultDoneButton", in: app, file: file, line: line)
        waitForElement("playerLevel", in: app, file: file, line: line)
    }

    @MainActor
    func assertCareerResult(job: String, gold: Int, experience: Int,
                                      levelBefore: Int, levelAfter: Int, expAfter: Int,
                                      in app: XCUIApplication,
                                      file: StaticString = #filePath, line: UInt = #line) throws -> String {
        waitForObservedValue("workResultJob", job, in: app, file: file, line: line)
        for (identifier, value) in [("workResultGold", gold), ("workResultExp", experience),
                                    ("workResultLevelBefore", levelBefore), ("workResultLevelAfter", levelAfter),
                                    ("workResultExpAfter", expAfter)] {
            waitForObservedValue(identifier, "\(value)", in: app, file: file, line: line)
        }
        let id = try XCTUnwrap(element("workResultID", in: app).value as? String,
                               "A saved result must expose its stable work session ID.", file: file, line: line)
        XCTAssertFalse(id.isEmpty, file: file, line: line)
        return id
    }

    @MainActor
    func bringWorkStartIntoView(in app: XCUIApplication) {
        scrollRecoveryCard(to: "startWorkButton", in: app)
    }
}
