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
        let page = profilePage(containing: identifier)
        prepareProfilePage(page, in: app, file: file, line: line)
        tapProfilePageControl(identifier, scroll: page.scrollIdentifier, in: app, file: file, line: line)
    }

    @MainActor
    func assertProfileValue(_ identifier: String, _ expected: String,
                                      in app: XCUIApplication,
                                      file: StaticString = #filePath, line: UInt = #line) {
        let page = profilePage(containing: identifier)
        prepareProfilePage(page, in: app, file: file, line: line)
        scrollCareerPage(page.scrollIdentifier, to: identifier, in: app, file: file, line: line)
        XCTAssertTrue(element(page.scrollIdentifier, in: app).descendants(matching: .any)
            .matching(identifier: identifier).firstMatch.exists,
            "Read \(identifier) from its visible profile page, not a hidden parent view.", file: file, line: line)
        waitForObservedValue(identifier, expected, in: app, file: file, line: line)
        // The modal obscures the parent navigation. Always dismiss it explicitly
        // so a later Done action cannot accidentally address the covered profile.
        if page == .attributes { closeProfileAttributes(in: app, file: file, line: line) }
    }

    @MainActor
    func closeProfileAttributes(in app: XCUIApplication,
                                file: StaticString = #filePath, line: UInt = #line) {
        tapAnimationControl("profileAttributesCloseButton", in: app, file: file, line: line)
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"),
            object: element("profileAttributesSheet", in: app))
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 8), .completed, file: file, line: line)
        waitForElement("profileScroll", in: app, file: file, line: line)
    }

    @MainActor
    func returnToProfileRoot(in app: XCUIApplication,
                             file: StaticString = #filePath, line: UInt = #line) {
        if element("profileAttributesCloseButton", in: app).exists {
            closeProfileAttributes(in: app, file: file, line: line)
        }
        // Name drafts, avatar selection, and equipment details keep their own
        // explicit back actions in each test. Do not silently discard a draft.
        for identifier in ["playerNameScroll", "avatarPickerScroll", "equipmentScroll"] {
            XCTAssertFalse(element(identifier, in: app).exists,
                "Return from \(identifier) with its own Back button first.", file: file, line: line)
        }
        if element("profileSectionBackButton", in: app).exists {
            tapAnimationControl("profileSectionBackButton", in: app, file: file, line: line)
            let returned = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"),
                object: element("profileSectionBackButton", in: app))
            XCTAssertEqual(XCTWaiter.wait(for: [returned], timeout: 8), .completed, file: file, line: line)
        }
        waitForElement("profileScroll", in: app, file: file, line: line)
        waitForElement("profileAttributesButton", in: app, file: file, line: line)
    }

    @MainActor
    func closePlayerProfile(in app: XCUIApplication,
                             file: StaticString = #filePath, line: UInt = #line) {
        returnToProfileRoot(in: app, file: file, line: line)
        tapAnimationControl("closeSheetButton", in: app, file: file, line: line)
    }

    private enum ProfilePage {
        case root, attributes, wardrobe, bonuses

        var scrollIdentifier: String {
            switch self {
            case .root: "profileScroll"
            case .attributes: "profileAttributesSheet"
            case .wardrobe: "profileWardrobeScroll"
            case .bonuses: "profileBonusesScroll"
            }
        }

        var entryIdentifier: String? {
            switch self {
            case .root: nil
            case .attributes: "profileAttributesButton"
            case .wardrobe: "profileWardrobeButton"
            case .bonuses: "profileBonusesButton"
            }
        }
    }

    private func profilePage(containing identifier: String) -> ProfilePage {
        switch identifier {
        case "profileLevel", "profileExp", "profileStamina", "profileMood", "profileGold", "profileCompletedWork":
            return .attributes
        case "profileDurationBonus", "profileStaminaBonus", "profileMoodBonus":
            return .bonuses
        case "profileEquippedCount", "profileEquipAllButton":
            return .wardrobe
        default:
            return identifier.hasPrefix("equipmentSlot_") ? .wardrobe : .root
        }
    }

    @MainActor
    private func prepareProfilePage(_ page: ProfilePage, in app: XCUIApplication,
                                    file: StaticString, line: UInt) {
        // A presented sheet may leave its parent in the AX tree. Its explicit
        // Close control, rather than existence of profileScroll, owns navigation.
        if page == .attributes && element("profileAttributesCloseButton", in: app).exists { return }
        if element("profileAttributesCloseButton", in: app).exists {
            closeProfileAttributes(in: app, file: file, line: line)
        }
        if page != .root && element(page.scrollIdentifier, in: app).exists,
           !element("equipmentScroll", in: app).exists { return }
        returnToProfileRoot(in: app, file: file, line: line)
        if let entry = page.entryIdentifier {
            tapProfilePageControl(entry, scroll: "profileScroll", in: app, file: file, line: line)
            waitForElement(page.scrollIdentifier, in: app, file: file, line: line)
        }
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
