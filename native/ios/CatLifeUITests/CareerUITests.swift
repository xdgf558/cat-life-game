import XCTest

extension RoomHomeUITests {
    @MainActor
    func testCompactWorkDirectoryPagesFiltersSearchAndLockedPreviewPreserveState() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        openCareerHome(in: app)
        for id in ["playerLevel", "selectedCareerName", "startWorkButton", "careerChooseJobButton"] {
            let target = element(id, in: app)
            XCTAssertTrue(target.exists && target.isHittable,
                          "The Work dashboard must expose \(id) without scrolling.")
            XCTAssertTrue(app.frame.contains(target.frame))
        }
        let start = element("startWorkButton", in: app)
        XCTAssertLessThanOrEqual(start.frame.maxY, element("homeNavigationBar", in: app).frame.minY)
        XCTAssertFalse(element("sleepStatus", in: app).exists,
                       "The complete recovery card belongs on its own page.")
        XCTAssertEqual(careerDirectoryRowIDs(in: app), [], "Search results stay on their own page.")
        waitForElement("workJobTile_job_flyer", in: app)
        XCTAssertFalse(element("workJobTile_job_store", in: app).isEnabled,
                       "Locked quick choices cannot select or charge a shift.")
        waitForObservedValue("workGridPage", "1/2", in: app)
        attachScreenshot(app, named: "Work — paged two-column careers and fixed start action")
        openCareerRest(in: app)
        waitForObservedValue("sleepStatus", "awake", in: app)
        waitForObservedValue("playerStamina", "80", in: app)
        waitForObservedValue("playerMood", "80", in: app)
        attachScreenshot(app, named: "Work — recovery attributes on a separate page")
        closeCareerRest(in: app)
        tapCareerControl("workDetailsButton", in: app)
        waitForElement("careerDetailScroll", in: app)
        waitForElement("careerSelect_job_flyer", in: app)
        tapAnimationControl("careerDetailBackButton", in: app)
        waitForElement("playerLevel", in: app)
        XCTAssertFalse(element("careerJobsScroll", in: app).exists,
                       "A direct current-job preview must return to Work home.")

        tapCareerControl("careerChooseJobButton", in: app)
        waitForObservedValue("careerPageIndicator", "1/2", in: app)
        XCTAssertEqual(careerDirectoryRowIDs(in: app),
                       ["job_flyer", "job_it_engineer", "job_petshop", "job_store"])
        attachScreenshot(app, named: "Work — bounded four-job directory")
        XCTAssertFalse(element("careerPagePrevious", in: app).isEnabled)
        tapCareerDirectoryControl("careerPageNext", in: app)
        waitForObservedValue("careerPageIndicator", "2/2", in: app)
        XCTAssertEqual(careerDirectoryRowIDs(in: app), ["job_cat_cafe_manager"])
        XCTAssertFalse(element("careerPageNext", in: app).isEnabled)
        tapCareerDirectoryControl("careerJobRow_job_cat_cafe_manager", in: app)
        scrollCareerPage("careerDetailScroll", to: "careerSelect_job_cat_cafe_manager", in: app)
        XCTAssertFalse(element("careerSelect_job_cat_cafe_manager", in: app).isEnabled)
        waitForLabel("careerLocked_job_cat_cafe_manager", "10", in: app, contains: true)
        attachScreenshot(app, named: "Work — locked career remains previewable without a charge")
        tapAnimationControl("careerDetailBackButton", in: app)
        waitForObservedValue("careerPageIndicator", "2/2", in: app)
        XCTAssertEqual(careerDirectoryRowIDs(in: app), ["job_cat_cafe_manager"])

        tapCareerDirectoryControl("careerFilter_locked", in: app)
        waitForObservedValue("careerFilter_locked", "selected", in: app)
        waitForObservedValue("careerPageIndicator", "1/1", in: app)
        XCTAssertEqual(careerDirectoryRowIDs(in: app),
                       ["job_cat_cafe_manager", "job_it_engineer", "job_petshop", "job_store"])
        enterCareerSearch("猫", in: app)
        XCTAssertEqual(careerDirectoryRowIDs(in: app), ["job_cat_cafe_manager"])
        tapCareerDirectoryControl("careerJobRow_job_cat_cafe_manager", in: app)
        waitForElement("careerDetailScroll", in: app)
        tapAnimationControl("careerDetailBackButton", in: app)
        waitForObservedValue("careerSearchField", "猫", in: app)
        waitForObservedValue("careerFilter_locked", "selected", in: app)
        waitForObservedValue("careerPageIndicator", "1/1", in: app)
        XCTAssertEqual(careerDirectoryRowIDs(in: app), ["job_cat_cafe_manager"])
        tapCareerDirectoryControl("careerFilter_available", in: app)
        waitForElement("careerEmptyState", in: app)
        waitForObservedValue("careerPageIndicator", "1/1", in: app)
        waitForElement("careerPagePrevious", in: app)
        waitForElement("careerPageNext", in: app)
        XCTAssertEqual(careerDirectoryRowIDs(in: app), [])
        XCTAssertFalse(element("careerPagePrevious", in: app).isEnabled)
        XCTAssertFalse(element("careerPageNext", in: app).isEnabled)
        tapCareerDirectoryControl("careerSearchClearButton", in: app)
        waitForElement("careerJobRow_job_flyer", in: app)
        XCTAssertEqual(careerDirectoryRowIDs(in: app), ["job_flyer"])
        XCTAssertFalse(element("careerEmptyState", in: app).exists)
        tapCareerDirectoryControl("careerFilter_all", in: app)
        waitForObservedValue("careerPageIndicator", "1/2", in: app)
        XCTAssertEqual(careerDirectoryRowIDs(in: app).count, 4)
        tapAnimationControl("careerJobsBackButton", in: app)
        waitForObservedValue("selectedCareerName", "job_flyer", in: app)
        XCTAssertFalse(element("workCountdown", in: app).exists)
        openCareerRest(in: app)
        waitForObservedValue("playerStamina", "80", in: app)
        waitForObservedValue("playerMood", "80", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        waitForObservedValue("foodCount", "3", in: app)
        assertKnownHomeViewportBaseline(in: app)
    }

    @MainActor
    func testChoosingFutureCareerKeepsActiveJobAndCapturedTerms() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--career-level10-fixture"]
        launchAndEnterHome(app)
        openCareerHome(in: app)
        tapCareerControl("careerChooseJobButton", in: app)
        openCareerDetailsFromDirectory("job_cat_cafe_manager", in: app)
        tapAnimationControl("careerSelect_job_cat_cafe_manager", in: app)
        waitForObservedValue("selectedCareerName", "job_cat_cafe_manager", in: app)
        assertWorkQuote(duration: 1800, stamina: 50, mood: 20, in: app)
        XCTAssertFalse(element("workCountdown", in: app).exists,
                       "Choosing a career must not begin or charge a shift.")
        openCareerRest(in: app)
        waitForObservedValue("playerStamina", "100", in: app)
        waitForObservedValue("playerMood", "100", in: app)
        closeCareerRest(in: app)
        tapCareerControl("startWorkButton", in: app)
        waitForObservedValue("activeWorkDurationSeconds", "1800", in: app)
        tapCareerControl("careerChooseJobButton", in: app)
        openCareerDetailsFromDirectory("job_flyer", in: app)
        tapAnimationControl("careerSelect_job_flyer", in: app)
        waitForObservedValue("careerNextJobName", "job_flyer", in: app)
        waitForObservedValue("selectedCareerName", "job_cat_cafe_manager", in: app)
        waitForObservedValue("activeWorkDurationSeconds", "1800", in: app)
        assertWorkQuote(duration: 1800, stamina: 50, mood: 20, in: app)
        XCTAssertFalse(element("startWorkButton", in: app).exists)
        tapCareerControl("workDetailsButton", in: app)
        waitForElement("careerSelect_job_cat_cafe_manager", in: app)
        XCTAssertFalse(element("careerSelect_job_flyer", in: app).exists,
                       "Current-job details must describe the active shift, not the next selection.")
        tapAnimationControl("careerDetailBackButton", in: app)
        waitForObservedValue("careerNextJobName", "job_flyer", in: app)
        openCareerRest(in: app)
        waitForObservedValue("sleepStatus", "working", in: app)
        waitForObservedValue("playerStamina", "50", in: app)
        waitForObservedValue("playerMood", "80", in: app)
        scrollCareerPage("workRestScroll", to: "sleepStartButton", in: app)
        XCTAssertFalse(element("sleepStartButton", in: app).isEnabled)
        closeCareerRest(in: app)
        attachScreenshot(app, named: "Work — future choice leaves the active cafe quote unchanged")
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        waitForObservedValue("foodCount", "3", in: app)
    }

    @MainActor
    func testCareerLocksSelectionAndActiveShiftPersistWithoutChargingTwice() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        assertKnownHomeViewportBaseline(in: app)
        openCareerHome(in: app)
        waitForObservedValue("playerLevel", "1", in: app)
        waitForObservedValue("playerExperience", "0", in: app)
        waitForObservedValue("selectedCareerName", "job_flyer", in: app)
        tapCareerControl("careerChooseJobButton", in: app)
        for (id, level) in [("job_store", 2), ("job_petshop", 4),
                            ("job_it_engineer", 6), ("job_cat_cafe_manager", 10)] {
            openCareerDetailsFromDirectory(id, in: app)
            XCTAssertFalse(element("careerSelect_\(id)", in: app).isEnabled,
                           "A level-one player must not start a locked career.")
            waitForLabel("careerLocked_\(id)", "\(level)", in: app, contains: true)
            tapAnimationControl("careerDetailBackButton", in: app)
            waitForElement("careerJobsScroll", in: app)
        }
        attachScreenshot(app, named: "Career — future jobs show their real level requirements")
        openCareerDetailsFromDirectory("job_flyer", in: app)
        tapAnimationControl("careerSelect_job_flyer", in: app)
        waitForObservedValue("selectedCareerName", "job_flyer", in: app)
        tapCareerControl("startWorkButton", in: app)
        try assertVisibleTimerChanges("workCountdown", increasing: false, upperBound: 120, in: app,
                                      context: "the selected flyer job counts down")
        tapAnimationControl("tabHome", in: app)
        relaunchPreservingSave(app)
        openCareerHome(in: app)
        waitForObservedValue("selectedCareerName", "job_flyer", in: app)
        waitForElement("workCountdown", in: app)
        openCareerRest(in: app)
        waitForObservedValue("sleepStatus", "working", in: app)
        waitForObservedValue("playerStamina", "70", in: app)
        waitForObservedValue("playerMood", "75", in: app)
        scrollCareerPage("workRestScroll", to: "sleepStartButton", in: app)
        XCTAssertFalse(element("sleepStartButton", in: app).isEnabled)
        closeCareerRest(in: app)
        XCTAssertFalse(element("startWorkButton", in: app).exists,
                       "The active shift must not expose a second Start action.")
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        waitForObservedValue("foodCount", "3", in: app)

        // A separate isolated save exercises the top career through real UI
        // selection. The cafe's real duration is 30 minutes, not duration:12.
        app.terminate()
        app.launchArguments = arguments(reset: true) + ["--career-level10-fixture"]
        launchAndEnterHome(app)
        openCareerHome(in: app)
        waitForObservedValue("playerLevel", "10", in: app)
        tapCareerControl("careerChooseJobButton", in: app)
        openCareerDetailsFromDirectory("job_cat_cafe_manager", in: app)
        XCTAssertTrue(element("careerSelect_job_cat_cafe_manager", in: app).isEnabled)
        tapAnimationControl("careerSelect_job_cat_cafe_manager", in: app)
        waitForObservedValue("selectedCareerName", "job_cat_cafe_manager", in: app)
        waitForObservedValue("workQuoteDurationSeconds", "1800", in: app)
        attachScreenshot(app, named: "Career — level ten can select the thirty-minute cat cafe job")
        tapCareerControl("startWorkButton", in: app)
        try assertVisibleTimerChanges("workCountdown", increasing: false, upperBound: 1800, in: app,
                                      context: "the cafe shift uses thirty real minutes")
        let seconds = try XCTUnwrap(displayedTimerSeconds(element("workCountdown", in: app).label))
        XCTAssertGreaterThan(seconds, 1700)
        openCareerRest(in: app)
        waitForObservedValue("playerStamina", "50", in: app)
        waitForObservedValue("playerMood", "80", in: app)
        tapAnimationControl("tabHome", in: app)
        relaunchPreservingSave(app)
        openCareerHome(in: app)
        waitForObservedValue("selectedCareerName", "job_cat_cafe_manager", in: app)
        waitForElement("workCountdown", in: app)
        openCareerRest(in: app)
        waitForObservedValue("playerStamina", "50", in: app)
        waitForObservedValue("playerMood", "80", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        assertKnownHomeViewportBaseline(in: app)
    }

    @MainActor
    func testOfflineCareerSettlementRetriesSaveThenPersistsLevelAndSingleReward() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--career-completion-fixture", "--career-save-failure-once"]
        app.launch()
        let failure = app.alerts.firstMatch
        XCTAssertTrue(failure.waitForExistence(timeout: 20))
        XCTAssertTrue(failure.staticTexts["这次操作还没有保存"].exists)
        failure.buttons["完成"].tap()
        // Reading succeeded: a failed reconciliation is a save error, not a
        // broken-save screen. Automatic retry settles the same durable shift.
        waitForWelcomeEntryReady(in: app)
        XCTAssertFalse(element("welcomeRetryButton", in: app).exists)
        attachScreenshot(app, named: "Career — a valid save remains usable after reconciliation write failure")
        waitForObservedValue("welcomeProgress", "100%", in: app)
        XCTAssertFalse(element("roomScene", in: app).exists,
                       "A successful retry must still wait for the player's Enter action.")
        tapAnimationControl("welcomeEnterButton", in: app)
        waitForObservedValue("goldCount", "260", in: app)
        waitForObservedValue("foodCount", "3", in: app)
        openCareerHome(in: app)
        waitForObservedValue("playerLevel", "2", in: app)
        waitForObservedValue("playerExperience", "12", in: app)
        openCareerResult(in: app)
        let resultID = try assertCareerResult(job: "job_flyer", gold: 60, experience: 22,
                                             levelBefore: 1, levelAfter: 2, expAfter: 12, in: app)
        waitForElement("careerUnlocked_job_store", in: app)
        attachScreenshot(app, named: "Career — offline flyer result awards one level and unlocks the store")
        closeCareerResult(in: app)
        openCareerResult(in: app)
        waitForObservedValue("workResultID", resultID, in: app)
        closeCareerResult(in: app)
        tapCareerControl("careerChooseJobButton", in: app)
        openCareerDetailsFromDirectory("job_store", in: app)
        XCTAssertTrue(element("careerSelect_job_store", in: app).isEnabled)
        tapAnimationControl("careerSelect_job_store", in: app)
        waitForObservedValue("selectedCareerName", "job_store", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", "260", in: app)

        // The fixture flag intentionally remains, but without reset it must
        // read the real saved result rather than seed or settle the shift again.
        app.terminate()
        app.launchArguments = arguments(reset: false) + ["--career-completion-fixture"]
        launchAndEnterHome(app)
        waitForObservedValue("goldCount", "260", in: app)
        openCareerHome(in: app)
        waitForObservedValue("playerLevel", "2", in: app)
        waitForObservedValue("playerExperience", "12", in: app)
        openCareerResult(in: app)
        let restoredID = try assertCareerResult(job: "job_flyer", gold: 60, experience: 22,
                                               levelBefore: 1, levelAfter: 2, expAfter: 12, in: app)
        XCTAssertEqual(restoredID, resultID)
        closeCareerResult(in: app)
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", "260", in: app)
        waitForObservedValue("foodCount", "3", in: app)
        assertKnownHomeViewportBaseline(in: app)
    }

    @MainActor
    func testActiveCareerCompletesInBackgroundAndKeepsOnePersistentResult() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--career-active-fixture", "--career-save-failure-once", "--audio-test"]
        launchAndEnterHome(app)
        waitForObservedValue("goldCount", "200", in: app)
        openCareerHome(in: app)
        waitForObservedValue("selectedCareerName", "job_petshop", in: app)
        try assertVisibleTimerChanges("workCountdown", increasing: false, upperBound: 45, in: app,
                                      context: "a previously saved pet-shop shift resumes")
        let remaining = try XCTUnwrap(displayedTimerSeconds(element("workCountdown", in: app).label))
        let expectedCompletion = Date().addingTimeInterval(TimeInterval(remaining + 2))
        assertWorkCompletionSoundCount(0, in: app)
        XCUIDevice.shared.press(.home)
        waitForAppBackground(in: app)
        let deadline = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            Date() >= expectedCompletion
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [deadline], timeout: TimeInterval(remaining + 6)), .completed)
        app.activate()
        let recoveryFailure = app.alerts["这次操作还没有保存"]
        XCTAssertTrue(recoveryFailure.waitForExistence(timeout: 8),
                      "The first foreground catch-up write must exercise the injected failure.")
        let saveRecovered = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: recoveryFailure)
        XCTAssertEqual(XCTWaiter.wait(for: [saveRecovered], timeout: 10), .completed)
        waitForElement("workResultID", in: app, timeout: 15)
        let resultID = try assertCareerResult(job: "job_petshop", gold: 160, experience: 52,
                                             levelBefore: 4, levelAfter: 4, expAfter: 52, in: app)
        assertWorkCompletionSoundCount(0, in: app)
        attachScreenshot(app, named: "Career — returning from background opens the real completed result")
        closeCareerResult(in: app)
        waitForObservedValue("playerLevel", "4", in: app)
        waitForObservedValue("playerExperience", "52", in: app)
        XCTAssertFalse(element("workCountdown", in: app).exists)
        openCareerRest(in: app)
        waitForObservedValue("playerStamina", "80", in: app)
        waitForObservedValue("playerMood", "88", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", "360", in: app)
        app.terminate()
        app.launchArguments = arguments(reset: false) + ["--career-active-fixture", "--audio-test"]
        launchAndEnterHome(app)
        waitForObservedValue("goldCount", "360", in: app)
        openCareerHome(in: app)
        waitForObservedValue("playerLevel", "4", in: app)
        waitForObservedValue("playerExperience", "52", in: app)
        openCareerResult(in: app)
        waitForObservedValue("workResultID", resultID, in: app)
        assertWorkCompletionSoundCount(0, in: app)
        closeCareerResult(in: app)
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", "360", in: app)
        waitForObservedValue("foodCount", "3", in: app)
    }

    @MainActor
    func testCareerSelectionAndSavedResultTranslateInAllThreeLanguages() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--career-completion-fixture"]
        launchAndEnterHome(app)
        waitForObservedValue("goldCount", "260", in: app)
        let ids = ["job_flyer", "job_store", "job_petshop", "job_it_engineer", "job_cat_cafe_manager"]
        let languages: [(code: String, jobsTitle: String, resultTitle: String, names: [String])] = [
            ("en", "Choose a job", "Work summary",
             ["Hand out flyers", "Store assistant", "Pet shop assistant", "IT engineer", "Cat cafe manager"]),
            ("zh-Hant", "職業選擇", "工作結算",
             ["發傳單", "便利商店兼職", "寵物店助理", "IT 工程師", "貓咖管理員"]),
            ("zh-Hans", "职业选择", "工作结算",
             ["发传单", "便利店兼职", "宠物店助理", "IT 工程师", "猫咖管理员"])
        ]
        var savedResultID: String?
        for language in languages {
            tapAnimationControl("settingsButton", in: app)
            scrollCareerPage("settingsScroll", to: "languageOption_\(language.code)", in: app)
            tapAnimationControl("languageOption_\(language.code)", in: app)
            assertSettingsLanguageSelection(language.code, in: app)
            tapAnimationControl("tabHome", in: app)
            openCareerHome(in: app)
            waitForObservedValue("playerLevel", "2", in: app)
            waitForObservedValue("playerExperience", "12", in: app)
            waitForLabel("selectedCareerName", language.names[0], in: app)
            tapCareerControl("careerChooseJobButton", in: app)
            XCTAssertTrue(app.navigationBars[language.jobsTitle].waitForExistence(timeout: 8))
            for (id, name) in zip(ids, language.names) {
                let identifier = "careerJobName_\(id)"
                revealCareerDirectoryJob(id, in: app)
                // SwiftUI exposes the card's name together with its reward and unlock text.
                waitForLabel(identifier, name, in: app, contains: true)
                XCTAssertTrue(element(identifier, in: app).isHittable)
            }
            enterCareerSearch(language.names[0], in: app)
            waitForObservedValue("careerPageIndicator", "1/1", in: app)
            XCTAssertEqual(careerDirectoryRowIDs(in: app), ["job_flyer"],
                           "Search must use the selected language's visible career name.")
            tapCareerDirectoryControl("careerSearchClearButton", in: app)
            waitForObservedValue("careerPageIndicator", "1/2", in: app)
            XCTAssertEqual(careerDirectoryRowIDs(in: app).count, 4)
            attachScreenshot(app, named: "Career — translated job list in \(language.code)")
            tapAnimationControl("careerJobsBackButton", in: app)
            openCareerResult(in: app)
            XCTAssertTrue(app.navigationBars[language.resultTitle].waitForExistence(timeout: 8))
            let currentID = try assertCareerResult(job: "job_flyer", gold: 60, experience: 22,
                                                  levelBefore: 1, levelAfter: 2, expAfter: 12, in: app)
            if let savedResultID { XCTAssertEqual(currentID, savedResultID) }
            else { savedResultID = currentID }
            waitForLabel("workResultJob", language.names[0], in: app)
            waitForElement("workResultCompletedAt", in: app)
            let completedAt = element("workResultCompletedAt", in: app).label
            if language.code == "en" {
                XCTAssertFalse(completedAt.contains("月"),
                               "The English result date must not retain the Chinese system locale.")
                XCTAssertNotNil(completedAt.range(of: "[A-Za-z]", options: .regularExpression),
                                "The displayed English date should contain localized month or time text.")
            } else {
                XCTAssertTrue(completedAt.contains("月"),
                              "The result date must follow the selected Chinese locale.")
            }
            let dateEvidence = XCTAttachment(string: "language=\(language.code)\ncompletedAt=\(completedAt)")
            dateEvidence.name = "Career result date — \(language.code)"
            dateEvidence.lifetime = .keepAlways
            add(dateEvidence)
            scrollCareerPage("careerResultScroll", to: "workResultGold", in: app)
            attachScreenshot(app, named: "Career — the same saved result is readable in \(language.code)")
            closeCareerResult(in: app)
            tapAnimationControl("tabHome", in: app)
            waitForObservedValue("goldCount", "260", in: app)
            waitForObservedValue("foodCount", "3", in: app)
            tapAnimationControl("tabTown", in: app)
            waitForElement("townMapScroll", in: app)
            attachScreenshot(app, named: "Town — cartoon map labels and badges in \(language.code)")
            tapAnimationControl("tabHome", in: app)
            assertKnownHomeViewportBaseline(in: app)
        }
    }

    @MainActor
    func testWorkStartsAndRemainsInProgressAfterRelaunch() throws {
        let app = launchFreshHome()
        waitForValue("staminaCount", "80", in: app)
        tap("tabWork", in: app)
        tap("startWorkButton", in: app)
        waitForElement("workCountdown", in: app)
        XCTAssertFalse(element("startWorkButton", in: app).exists,
                       "An active shift must not offer a second start action.")
        attachScreenshot(app, named: "Work — active shift countdown")

        tap("tabHome", in: app)
        waitForValue("staminaCount", "70", in: app)
        waitForValue("goldCount", "200", in: app)
        relaunchPreservingSave(app)
        waitForValue("staminaCount", "70", in: app)
        tap("tabWork", in: app)
        waitForElement("workCountdown", in: app)
        XCTAssertFalse(element("startWorkButton", in: app).exists,
                       "The shift must be restored instead of allowing duplicate work.")
        attachScreenshot(app, named: "Work — active shift restored after cold launch")
    }
    @MainActor
    private func careerDirectoryRowIDs(in app: XCUIApplication) -> [String] {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "careerJobRow_"))
            .allElementsBoundByIndex.map { String($0.identifier.dropFirst("careerJobRow_".count)) }.sorted()
    }

    @MainActor
    private func enterCareerSearch(_ query: String, in app: XCUIApplication,
                                   file: StaticString = #filePath, line: UInt = #line) {
        scrollCareerPage("careerJobsScroll", to: "careerSearchField", in: app, file: file, line: line)
        let field = element("careerSearchField", in: app)
        field.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 8), file: file, line: line)
        field.typeText(query + "\n")
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"),
                                                  object: app.keyboards.firstMatch)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 8), .completed,
                       "Submitting search should reveal the directory again.", file: file, line: line)
        waitForObservedValue("careerSearchField", query, in: app, file: file, line: line)
    }

}
