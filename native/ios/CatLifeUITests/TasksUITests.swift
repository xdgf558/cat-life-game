import XCTest

extension RoomHomeUITests {
    @MainActor
    func testTaskFeedRewardsCommitOnceAndPersistAcrossRelaunch() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        let roomFrame = element("roomScene", in: app).frame
        XCTAssertTrue((element("tabMore", in: app).value as? String ?? "").isEmpty,
                      "A new game must not announce rewards before a goal is completed.")
        tapAnimationControl("feedButton", in: app)
        waitForObservedValue("foodCount", "2", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        waitForObservedValue("tabMore", "2 项可领取", in: app)
        attachScreenshot(app, named: "Home review — More marks two rewards without adding a home task card")

        tapAnimationControl("tabTasks", in: app)
        waitForObservedValue("tasksDailySummary", "1/5", in: app)
        waitForObservedValue("tasksClaimableSummary", "2", in: app)
        openTaskCard("daily_feed", category: "daily", in: app)
        waitForObservedValue("taskProgress_daily_feed", "1/1", in: app)
        attachScreenshot(app, named: "Tasks — ready card with direct reward action")
        tapAnimationControl("taskClaim_daily_feed", in: app)
        waitForObservedValue("taskRewardCelebration", "daily_feed", in: app)
        // The brief celebration closes itself; durable totals below and Store tests verify its receipt.
        attachScreenshot(app, named: "Tasks — committed reward celebration")
        assertClaimedTaskIsHidden("daily_feed", in: app)
        waitForObservedValue("tasksClaimableSummary", "1", in: app)
        waitForObservedValue("tabMore", "1 项可领取", in: app)

        openTaskCard("tutorial_feed", category: "tutorial", in: app)
        tapAnimationControl("taskClaim_tutorial_feed", in: app)
        assertClaimedTaskIsHidden("tutorial_feed", in: app)
        attachScreenshot(app, named: "Tasks — real feeding earns separate daily and starter rewards")
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", "235", in: app)
        waitForObservedValue("foodCount", "2", in: app)
        XCTAssertTrue((element("tabMore", in: app).value as? String ?? "").isEmpty,
                      "Claiming the last reward must clear More's visual reminder and spoken value.")
        attachScreenshot(app, named: "Home review — More reminder clears after both real rewards are claimed")
        assertRoomFrame(roomFrame, in: app, context: "returning from two committed task rewards")
        tapAnimationControl("tabWork", in: app)
        waitForObservedValue("playerExperience", "9", in: app)
        XCTAssertFalse(element("workCountdown", in: app).exists)

        relaunchPreservingSave(app)
        waitForObservedValue("goldCount", "235", in: app)
        waitForObservedValue("foodCount", "2", in: app)
        XCTAssertFalse(element("tabMore", in: app).frame.intersects(element("homeCareBar63", in: app).frame),
                       "The care bar must leave the More entry reachable after relaunch.")
        tapAnimationControl("tabTasks", in: app)
        waitForObservedValue("tasksDailySummary", "1/5", in: app)
        waitForObservedValue("tasksClaimableSummary", "0", in: app)
        assertClaimedTaskIsHidden("daily_feed", in: app)
        selectTaskCategory("tutorial", in: app)
        assertClaimedTaskIsHidden("tutorial_feed", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", "235", in: app)
        waitForObservedValue("foodCount", "2", in: app)
        assertRoomFrame(roomFrame, in: app, context: "reopening claimed goals after cold launch")
    }

    @MainActor
    func testCleaningCompletesCareGoalsAndClaimedCardsStayHiddenAfterRelaunch() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        tapAnimationControl("cleanButton", in: app)
        tapAnimationControl("tabTasks", in: app)
        waitForObservedValue("tasksDailySummary", "1/5", in: app)
        waitForObservedValue("tasksClaimableSummary", "2", in: app)
        for (id, category) in [("daily_clean", "daily"), ("tutorial_clean", "tutorial")] {
            openTaskCard(id, category: category, in: app)
            waitForObservedValue("tasksPageIndicator", "1/2", in: app)
            XCTAssertLessThan(element("taskCard_\(id)", in: app).frame.minY,
                              element("taskCard_\(category)_work", in: app).frame.minY,
                              "Claimable care goals must move ahead of unfinished work goals.")
            waitForObservedValue("taskProgress_\(id)", "1/1", in: app)
            tapAnimationControl("taskClaim_\(id)", in: app)
            assertClaimedTaskIsHidden(id, in: app)
            assertRemainingCareTaskPages(category, in: app)
        }
        attachScreenshot(app, named: "Tasks — cleaning rewards disappear while remaining goals keep compact pages")
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", "235", in: app)
        relaunchPreservingSave(app)
        waitForObservedValue("goldCount", "235", in: app)
        tapAnimationControl("tabTasks", in: app)
        waitForObservedValue("tasksClaimableSummary", "0", in: app)
        for category in ["daily", "tutorial"] {
            selectTaskCategory(category, in: app)
            assertClaimedTaskIsHidden("\(category)_clean", in: app)
            assertRemainingCareTaskPages(category, in: app)
        }
        tapAnimationControl("tabWork", in: app)
        waitForObservedValue("playerExperience", "9", in: app)
    }

    @MainActor
    func testTaskDestinationsAndThreeCardCategoriesPreserveResources() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        let roomFrame = element("roomScene", in: app).frame
        let entry = element("tabMore", in: app)
        XCTAssertTrue(entry.isHittable)
        XCTAssertGreaterThanOrEqual(entry.frame.height, 44)
        XCTAssertGreaterThanOrEqual(entry.frame.width, 44)
        tapAnimationControl("tabTasks", in: app)
        waitForObservedValue("tasksDailySummary", "0/5", in: app)
        assertFixedNavigationAvailable(in: app)

        for category in ["tutorial", "daily", "achievement"] {
            selectTaskCategory(category, in: app)
            XCTAssertEqual(app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH %@", "taskCard_")).count, 3,
                "Each task category must keep a compact three-card list.")
        }
        openTaskCard("daily_work", category: "daily", in: app)
        assertTaskActionAboveNavigation("taskGo_daily_work", in: app)
        tapAnimationControl("taskGo_daily_work", in: app)
        waitForElement("startWorkButton", in: app)
        XCTAssertFalse(element("workCountdown", in: app).exists,
                       "Going to a task destination must not start work automatically.")

        tapAnimationControl("tabTasks", in: app)
        openTaskCard("tutorial_furniture", category: "tutorial", in: app)
        tapAnimationControl("taskGo_tutorial_furniture", in: app)
        waitForElement("shopCategory_furniture", in: app)
        XCTAssertTrue(element("shopCategory_furniture", in: app).isSelected,
                      "The furniture goal must open the furniture category, not general supplies.")
        waitForElement("shopItem_potted_plant", in: app)
        waitForObservedValue("shopGoldCount", "200", in: app)

        tapAnimationControl("tabTasks", in: app)
        openTaskCard("achievement_room2", category: "achievement", in: app)
        tapAnimationControl("taskGo_achievement_room2", in: app)
        waitForElement("homeUpgradeScroll", in: app)
        waitForObservedValue("homeUpgradeCurrentLevel", "1", in: app)
        waitForObservedValue("homeUpgradeGold", "200", in: app)

        tapAnimationControl("tabTasks", in: app)
        openTaskCard("daily_visit", category: "daily", in: app)
        waitForObservedValue("taskProgress_daily_visit", "0/1", in: app)
        assertTaskActionAboveNavigation("taskGo_daily_visit", in: app)
        tapAnimationControl("taskGo_daily_visit", in: app)
        waitForElement("communityDirectory", in: app)
        tapAnimationControl("neighborCard_neighbor_mira", in: app)
        waitForObservedValue("neighborFriendshipValue", "0", in: app)
        tapAnimationControl("tabTasks", in: app)
        openTaskCard("daily_visit", category: "daily", in: app)
        waitForObservedValue("taskProgress_daily_visit", "0/1", in: app)
        waitForObservedValue("tasksDailySummary", "0/5", in: app)

        tapAnimationControl("tabTasks", in: app)
        openTaskCard("daily_feed", category: "daily", in: app)
        tapAnimationControl("taskGo_daily_feed", in: app)
        waitForElement("feedButton", in: app)
        waitForObservedValue("foodCount", "3", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        waitForObservedValue("staminaCount", "80", in: app)
        assertRoomFrame(roomFrame, in: app, context: "task destination shortcuts preserve the original room")
        assertFixedNavigationAvailable(in: app)
        attachScreenshot(app, named: "Tasks — care shortcut returns home without consuming supplies")
    }

    @MainActor
    func testTaskClaimSaveFailureKeepsRewardAvailableUntilSuccessfulRetry() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--task-claim-save-failure-once"]
        launchAndEnterHome(app)
        tapAnimationControl("feedButton", in: app)
        waitForObservedValue("foodCount", "2", in: app)
        tapAnimationControl("tabTasks", in: app)
        openTaskCard("daily_feed", category: "daily", in: app)
        tapAnimationControl("taskClaim_daily_feed", in: app)

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 8))
        XCTAssertEqual(app.alerts.count, 1, "Task details must use the shell's single save alert.")
        XCTAssertTrue(alert.staticTexts["这次操作还没有保存"].exists)
        alert.buttons["完成"].tap()
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: alert)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
        XCTAssertFalse(element("taskClaimed_daily_feed", in: app).exists,
                       "A rejected write must not mark the reward as claimed.")
        waitForElement("tasksScroll", in: app)
        waitForElement("taskClaim_daily_feed", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        waitForObservedValue("foodCount", "2", in: app)
        XCTAssertFalse(app.alerts.firstMatch.exists, "Returning home must not reveal a duplicate alert.")

        tapAnimationControl("tabTasks", in: app)
        waitForObservedValue("tasksClaimableSummary", "2", in: app)
        openTaskCard("daily_feed", category: "daily", in: app)
        tapAnimationControl("taskClaim_daily_feed", in: app)
        assertClaimedTaskIsHidden("daily_feed", in: app)
        XCTAssertFalse(app.alerts.firstMatch.exists)
        attachScreenshot(app, named: "Tasks — failed reward remains claimable and succeeds on explicit retry")
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", "215", in: app)
        waitForObservedValue("foodCount", "2", in: app)
        relaunchPreservingSave(app)
        waitForObservedValue("goldCount", "215", in: app)
        waitForObservedValue("foodCount", "2", in: app)
        tapAnimationControl("tabTasks", in: app)
        assertClaimedTaskIsHidden("daily_feed", in: app)
    }

    @MainActor
    func testTaskHighLevelPaginationClampsAndDailyEmptyStatePersists() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--tasks-level10-fixture"]
        launchAndEnterHome(app)
        tapAnimationControl("tabTasks", in: app)
        waitForObservedValue("tasksDailySummary", "10/10", in: app)
        waitForObservedValue("tasksPageIndicator", "1/4", in: app)
        XCTAssertFalse(element("tasksPreviousPage", in: app).isEnabled)
        XCTAssertFalse(element("tasksNextUnlock", in: app).exists)
        assertTaskCardCount(3, in: app)

        turnTaskPage("tasksNextPage", in: app)
        waitForObservedValue("tasksPageIndicator", "2/4", in: app)
        assertTaskCardCount(3, in: app)
        turnTaskPage("tasksNextPage", in: app)
        waitForObservedValue("tasksPageIndicator", "3/4", in: app)
        assertTaskCardCount(3, in: app)
        turnTaskPage("tasksNextPage", in: app)
        waitForObservedValue("tasksPageIndicator", "4/4", in: app)
        XCTAssertFalse(element("tasksNextPage", in: app).isEnabled)
        assertTaskCardCount(1, in: app)
        scrollPage("tasksScroll", to: "taskClaim_daily_gift", allowDisabled: false, maximumDrags: 6, in: app)
        waitForObservedValue("taskProgress_daily_gift", "1/1", in: app)
        tapAnimationControl("taskClaim_daily_gift", in: app)
        assertClaimedTaskIsHidden("daily_gift", in: app)
        waitForObservedValue("tasksPageIndicator", "3/3", in: app)
        assertTaskCardCount(3, in: app)
        scrollPage("tasksScroll", to: "taskClaim_daily_visit", allowDisabled: false, maximumDrags: 6, in: app)
        waitForObservedValue("taskProgress_daily_visit", "1/1", in: app)
        tapAnimationControl("taskClaim_daily_visit", in: app)
        assertClaimedTaskIsHidden("daily_visit", in: app)
        waitForObservedValue("tasksPageIndicator", "3/3", in: app)
        assertTaskCardCount(2, in: app)
        scrollPage("tasksScroll", to: "taskClaim_daily_work3", allowDisabled: false, maximumDrags: 6, in: app)
        waitForObservedValue("taskProgress_daily_work3", "3/3", in: app)
        tapAnimationControl("taskClaim_daily_work3", in: app)
        assertClaimedTaskIsHidden("daily_work3", in: app)
        waitForObservedValue("tasksPageIndicator", "3/3", in: app)
        assertTaskCardCount(1, in: app)
        scrollPage("tasksScroll", to: "taskClaim_daily_clean", allowDisabled: false, maximumDrags: 6, in: app)
        waitForObservedValue("taskProgress_daily_clean", "1/1", in: app)
        tapAnimationControl("taskClaim_daily_clean", in: app)
        assertClaimedTaskIsHidden("daily_clean", in: app)
        waitForObservedValue("tasksPageIndicator", "2/2", in: app)
        assertTaskCardCount(3, in: app)
        assertFixedNavigationAvailable(in: app)
        attachScreenshot(app, named: "Tasks — claiming the final page returns to the last nonempty page")

        selectTaskCategory("achievement", in: app)
        waitForObservedValue("tasksPageIndicator", "1/5", in: app)
        assertTaskCardCount(3, in: app)
        selectTaskCategory("daily", in: app)
        waitForObservedValue("tasksPageIndicator", "1/2", in: app)
        for id in ["daily_work", "daily_feed", "daily_play", "daily_work2", "daily_feed2", "daily_play2"] {
            openTaskCard(id, category: "daily", in: app)
            tapAnimationControl("taskClaim_\(id)", in: app)
            assertClaimedTaskIsHidden(id, in: app)
        }
        waitForElement("tasksEmptyState", in: app)
        waitForObservedValue("tasksDailySummary", "10/10", in: app)
        assertTaskCardCount(0, in: app)
        XCTAssertFalse(element("tasksPageIndicator", in: app).exists)
        XCTAssertFalse(element("tasksNextPage", in: app).exists)
        XCTAssertFalse(element("tasksNextUnlock", in: app).exists)
        attachScreenshot(app, named: "Tasks — all daily goals claimed leaves a compact tomorrow empty state")
        selectTaskCategory("tutorial", in: app)
        assertTaskCardCount(3, in: app)
        XCTAssertFalse(element("tasksEmptyState", in: app).exists, "An empty daily list must not hide starter goals.")
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", "415", in: app)
        tapAnimationControl("tabWork", in: app)
        waitForObservedValue("playerLevel", "10", in: app)
        waitForObservedValue("playerExperience", "54", in: app)

        relaunchPreservingSave(app)
        waitForObservedValue("goldCount", "415", in: app)
        tapAnimationControl("tabTasks", in: app)
        waitForElement("tasksEmptyState", in: app)
        waitForObservedValue("tasksDailySummary", "10/10", in: app)
        assertTaskCardCount(0, in: app)
        XCTAssertFalse(element("tasksPageIndicator", in: app).exists)
    }

    @MainActor
    func testTaskRewardLevelUpRevealsEligibleGoalsWithoutResettingProgress() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--tasks-level-up-fixture"]
        launchAndEnterHome(app)
        tapAnimationControl("tabTasks", in: app)
        waitForObservedValue("tasksDailySummary", "2/5", in: app)
        waitForObservedValue("tasksNextUnlock", "2", in: app)
        assertTaskCardCount(3, in: app)
        XCTAssertFalse(element("taskCard_daily_work2", in: app).exists,
                       "Enough work progress alone must not reveal a level-locked goal.")
        openTaskCard("daily_feed", category: "daily", in: app)
        tapAnimationControl("taskClaim_daily_feed", in: app)
        assertClaimedTaskIsHidden("daily_feed", in: app)
        waitForObservedValue("tasksDailySummary", "3/7", in: app)
        waitForObservedValue("tasksNextUnlock", "4", in: app)
        assertTaskCardCount(3, in: app)
        waitForElement("taskCard_daily_work2", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", "215", in: app)
        waitForObservedValue("foodCount", "2", in: app)
        tapAnimationControl("tabWork", in: app)
        waitForObservedValue("playerLevel", "2", in: app)
        waitForObservedValue("playerExperience", "3", in: app)

        tapAnimationControl("tabTasks", in: app)
        openTaskCard("daily_work2", category: "daily", in: app)
        waitForObservedValue("taskProgress_daily_work2", "2/2", in: app)
        assertTaskActionAboveNavigation("taskClaim_daily_work2", in: app)
        attachScreenshot(app, named: "Tasks — a reward level-up unlocks a goal using existing daily progress")
        tapAnimationControl("taskClaim_daily_work2", in: app)
        assertClaimedTaskIsHidden("daily_work2", in: app)
        waitForObservedValue("tasksDailySummary", "3/7", in: app)
        assertTaskCardCount(3, in: app)
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", "250", in: app)
        waitForObservedValue("foodCount", "2", in: app)
        tapAnimationControl("tabWork", in: app)
        waitForObservedValue("playerLevel", "2", in: app)
        waitForObservedValue("playerExperience", "11", in: app)
    }

    @MainActor
    func testTaskCategoriesDetailsAndCareRouteTranslateInAllThreeLanguages() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        let roomFrame = element("roomScene", in: app).frame
        let languages = [
            (code: "zh-Hans", tutorial: "新手", daily: "每日", achievement: "成就",
             title: "好好吃饭", action: "回家照顾"),
            (code: "en", tutorial: "Starter", daily: "Daily", achievement: "Achievements",
             title: "A lovely meal", action: "Care at home"),
            (code: "zh-Hant", tutorial: "新手", daily: "每日", achievement: "成就",
             title: "好好吃飯", action: "回家照顧")
        ]
        for language in languages {
            tapAnimationControl("settingsButton", in: app)
            tapSettingsRootControl("languageOption_\(language.code)", in: app)
            assertSettingsLanguageSelection(language.code, in: app)
            tapAnimationControl("tabTasks", in: app)
            waitForLabel("taskCategory_tutorial", language.tutorial, in: app)
            waitForLabel("taskCategory_daily", language.daily, in: app)
            waitForLabel("taskCategory_achievement", language.achievement, in: app)
            waitForLabel("taskCard_daily_feed", language.title, in: app, contains: true)
            openTaskCard("daily_feed", category: "daily", in: app)
            XCTAssertFalse(element("taskDetailScroll", in: app).exists, "Actions now live on compact task cards.")
            waitForObservedValue("taskProgress_daily_feed", "0/1", in: app)
            waitForLabel("taskGo_daily_feed", language.action, in: app, contains: true)
            assertTaskActionAboveNavigation("taskGo_daily_feed", in: app)
            attachScreenshot(app, named: "Tasks — translated details and fixed action in \(language.code)")
            tapAnimationControl("taskGo_daily_feed", in: app)
            waitForElement("feedButton", in: app)
            waitForObservedValue("foodCount", "3", in: app)
            waitForObservedValue("goldCount", "200", in: app)
            assertRoomFrame(roomFrame, in: app, context: "task care route in \(language.code)")
        }
    }

    @MainActor
    private func assertRemainingCareTaskPages(_ category: String, in app: XCUIApplication,
                                             file: StaticString = #filePath, line: UInt = #line) {
        assertTaskCardCount(3, in: app, file: file, line: line)
        if category == "daily" {
            waitForObservedValue("tasksPageIndicator", "1/2", in: app, file: file, line: line)
            turnTaskPage("tasksNextPage", in: app, file: file, line: line)
            waitForObservedValue("tasksPageIndicator", "2/2", in: app, file: file, line: line)
            assertTaskCardCount(1, in: app, file: file, line: line)
            waitForElement("taskCard_daily_visit", in: app, file: file, line: line)
            turnTaskPage("tasksPreviousPage", in: app, file: file, line: line)
            waitForObservedValue("tasksPageIndicator", "1/2", in: app, file: file, line: line)
        } else {
            XCTAssertFalse(element("tasksPageIndicator", in: app).exists,
                           "The three remaining starter goals must fit on one page.", file: file, line: line)
        }
    }

    @MainActor
    private func assertClaimedTaskIsHidden(_ id: String, in app: XCUIApplication,
                                          file: StaticString = #filePath, line: UInt = #line) {
        let card = element("taskCard_\(id)", in: app)
        let hidden = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: card)
        XCTAssertEqual(XCTWaiter.wait(for: [hidden], timeout: 8), .completed, file: file, line: line)
        // Let the short-lived celebration close instead of racing its dismiss button's removal.
        let celebration = element("taskRewardCelebration", in: app)
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: celebration)
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 6), .completed, file: file, line: line)
        waitForElement("tasksScroll", in: app, file: file, line: line)
        XCTAssertFalse(element("taskCard_\(id)", in: app).exists,
                       "Claimed goals must stay hidden, including after cold launch.", file: file, line: line)
        XCTAssertFalse(element("taskClaim_\(id)", in: app).exists, file: file, line: line)
    }

    @MainActor
    private func assertTaskCardCount(_ expected: Int, in app: XCUIApplication,
                                     file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "taskCard_")).count, expected,
            "Only this page's remaining, unlocked goals should appear.", file: file, line: line)
    }

    @MainActor
    private func turnTaskPage(_ control: String, in app: XCUIApplication,
                              file: StaticString = #filePath, line: UInt = #line) {
        scrollPage("tasksScroll", to: control, allowDisabled: false,
                   maximumDrags: 6, in: app, file: file, line: line)
        tapAnimationControl(control, in: app, file: file, line: line)
    }

    @MainActor
    private func selectTaskCategory(_ category: String, in app: XCUIApplication,
                                    file: StaticString = #filePath, line: UInt = #line) {
        scrollPage("tasksScroll", to: "taskCategory_\(category)", allowDisabled: false,
                   maximumDrags: 6, in: app, file: file, line: line)
        tapAnimationControl("taskCategory_\(category)", in: app, file: file, line: line)
    }

    @MainActor
    private func openTaskCard(_ id: String, category: String, in app: XCUIApplication,
                              file: StaticString = #filePath, line: UInt = #line) {
        selectTaskCategory(category, in: app, file: file, line: line)
        for _ in 0..<6 {
            if element("taskCard_\(id)", in: app).exists { break }
            guard element("tasksNextPage", in: app).exists && element("tasksNextPage", in: app).isEnabled else { break }
            turnTaskPage("tasksNextPage", in: app, file: file, line: line)
        }
        let claim = "taskClaim_\(id)"
        let go = "taskGo_\(id)"
        let action = element(claim, in: app).exists ? claim : go
        scrollPage("tasksScroll", to: action, allowDisabled: false,
                   maximumDrags: 6, in: app, file: file, line: line)
        waitForElement("taskCard_\(id)", in: app, file: file, line: line)

    }

    @MainActor
    private func assertTaskActionAboveNavigation(_ id: String, in app: XCUIApplication,
                                                 file: StaticString = #filePath, line: UInt = #line) {
        assertFixedNavigationAvailable(in: app, file: file, line: line)
        let action = element(id, in: app)
        XCTAssertTrue(action.exists && action.isEnabled && action.isHittable, file: file, line: line)
        XCTAssertTrue(app.frame.contains(action.frame), file: file, line: line)
        XCTAssertLessThanOrEqual(action.frame.maxY, element("homeNavigationBar", in: app).frame.minY + 1,
                                 "The fixed task action must sit above the five-tab navigation.", file: file, line: line)
    }
}
