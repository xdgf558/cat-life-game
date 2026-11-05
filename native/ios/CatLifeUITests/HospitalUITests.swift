import XCTest

extension RoomHomeUITests {
    @MainActor
    func testHospitalTreatmentPersistsAndKeepsOtherCatAndRoomUnchanged() throws {
        continueAfterFailure = false
        let app = hospitalFixture()
        let room = element("roomScene", in: app).frame
        waitForLabel("catNeedBubble", "不太舒服，去医院看看", in: app)
        openHospitalDirectory(in: app)
        waitForObservedValue("hospitalSummary", "1/2", in: app)
        for id in ["hospitalBackToTown", "hospitalPageTitle", "hospitalWallet", "hospitalCat_cat_001"] {
            let frame = element(id, in: app).frame
            XCTAssertGreaterThanOrEqual(frame.minX, app.frame.minX, "\(id) must fit the screen horizontally.")
            XCTAssertLessThanOrEqual(frame.maxX, app.frame.maxX, "\(id) must fit the screen horizontally.")
        }
        attachScreenshot(app, named: "Hospital — compact cat directory")
        tapAnimationControl("hospitalCat_cat_001", in: app)
        waitForObservedValue("hospitalCondition", "cold", in: app)
        waitForObservedValue("hospitalHealth", "50/100", in: app)
        waitForObservedValue("hospitalTreatmentCost", "120", in: app)
        scrollCareerPage("hospitalDetailScroll", to: "hospitalTreatButton", in: app)
        attachScreenshot(app, named: "Hospital — diagnosis and treatment cost")
        tapAnimationControl("hospitalTreatButton", in: app)
        waitForElement("hospitalTreatingState", in: app)
        XCTAssertFalse(element("hospitalBackButton", in: app).isEnabled)
        attachScreenshot(app, named: "Hospital — committed care presentation")
        waitForElement("hospitalHealthyState", in: app)
        scrollCareerPage("hospitalRecoveryScroll", to: "hospitalHealth", in: app)
        waitForObservedValue("hospitalHealth", "80/100", in: app)
        XCTAssertFalse(element("hospitalTreatButton", in: app).exists)
        attachScreenshot(app, named: "Hospital — recovery and protection")
        scrollCareerPage("hospitalRecoveryScroll", to: "hospitalRecoveryDirectory", in: app)
        tapAnimationControl("hospitalRecoveryDirectory", in: app)
        waitForObservedValue("hospitalSummary", "0/2", in: app)
        tapAnimationControl("hospitalCat_cat_002", in: app)
        waitForObservedValue("hospitalHealth", "90/100", in: app)
        waitForObservedValue("hospitalCondition", "healthy", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", "880", in: app)
        waitForObservedValue("homeCatName", "小橘", in: app)
        assertRoomFrame(room, in: app, context: "hospital treatment")
        relaunchPreservingSave(app)
        waitForObservedValue("goldCount", "880", in: app)
        tapAnimationControl("homeCatProfileButton", in: app)
        scrollCareerPage("catProfileScroll", to: "catHealthButton", in: app)
        tapAnimationControl("catHealthButton", in: app)
        waitForObservedValue("hospitalCondition", "healthy", in: app)
        waitForObservedValue("hospitalHealth", "80/100", in: app)
        waitForElement("hospitalProtectionHint", in: app)
        tapAnimationControl("catHealthBackButton", in: app)
        waitForObservedValue("catProfileScroll", "cat_001", in: app)
        tapAnimationControl("closeSheetButton", in: app)
        assertRoomFrame(room, in: app, context: "health details dismissed")
    }

    @MainActor
    func testHospitalFailedSaveLeavesTreatmentUnpaidAndOffersRetry() throws {
        continueAfterFailure = false
        let app = hospitalFixture(["--hospital-save-failure-once"])
        tapAnimationControl("catNeedBubble", in: app)
        waitForObservedValue("hospitalDetailScroll", "cat_001", in: app)
        scrollCareerPage("hospitalDetailScroll", to: "hospitalTreatButton", in: app)
        tapAnimationControl("hospitalTreatButton", in: app)
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 8))
        XCTAssertEqual(app.alerts.count, 1)
        alert.buttons["完成"].tap()
        waitForObservedValue("hospitalGoldCount", "1,000", in: app)
        scrollCareerPage("hospitalDetailScroll", to: "hospitalTreatmentStatus", in: app)
        attachScreenshot(app, named: "Hospital — failed save preserves illness and wallet")
        scrollCareerPage("hospitalDetailScroll", to: "hospitalTreatButton", in: app)
        tapAnimationControl("hospitalTreatButton", in: app)
        waitForElement("hospitalHealthyState", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", "880", in: app)
        relaunchPreservingSave(app)
        waitForObservedValue("goldCount", "880", in: app)
    }

    @MainActor
    func testHospitalInsufficientGoldCanReturnToWorkFromCatProfile() throws {
        continueAfterFailure = false
        let app = hospitalFixture(["--hospital-low-gold"])
        tapAnimationControl("homeCatProfileButton", in: app)
        scrollCareerPage("catProfileScroll", to: "catHealthButton", in: app)
        tapAnimationControl("catHealthButton", in: app)
        XCTAssertFalse(element("hospitalTreatButton", in: app).exists, "Insufficient funds shows the work action instead of a disabled treatment button.")
        waitForObservedValue("hospitalGoldCount", "10", in: app)
        scrollCareerPage("hospitalDetailScroll", to: "hospitalWorkButton", in: app)
        attachScreenshot(app, named: "Hospital — insufficient coins and route to work")
        tapAnimationControl("hospitalWorkButton", in: app)
        waitForElement("startWorkButton", in: app)
        XCTAssertFalse(element("closeSheetButton", in: app).exists)
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", "10", in: app)
        tapAnimationControl("catNeedBubble", in: app)
        waitForObservedValue("hospitalCondition", "cold", in: app)
    }

    @MainActor
    func testHospitalLanguagesAndHealthyDirectoryPagination() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--cat-collection-fixture"]
        launchAndEnterHome(app)
        openHospitalDirectory(in: app)
        waitForObservedValue("hospitalSummary", "0/9", in: app)
        waitForObservedValue("hospitalPageSummary", "1/3", in: app)
        XCTAssertTrue(element("hospitalCat_cat_004", in: app).exists)
        XCTAssertFalse(element("hospitalCat_cat_005", in: app).exists)
        scrollCareerPage("hospitalDirectoryScroll", to: "hospitalPageNext", in: app)
        tapAnimationControl("hospitalPageNext", in: app)
        waitForObservedValue("hospitalPageSummary", "2/3", in: app)
        XCTAssertFalse(element("hospitalCat_cat_004", in: app).exists)
        scrollCareerPage("hospitalDirectoryScroll", to: "hospitalCat_cat_006", in: app)
        tapAnimationControl("hospitalCat_cat_006", in: app)
        waitForObservedValue("hospitalHealth", "96/100", in: app)
        XCTAssertFalse(element("hospitalTreatButton", in: app).exists)
        tapAnimationControl("tabHome", in: app)
        for (code, title) in [("zh-Hant", "寵物醫院"), ("en", "Pet hospital")] {
            selectCatTestLanguage(code, in: app)
            openHospitalDirectory(in: app)
            waitForLabel("hospitalPageTitle", title, in: app, contains: true)
            tapAnimationControl("hospitalCat_cat_001", in: app)
            waitForObservedValue("hospitalCondition", "healthy", in: app)
            attachScreenshot(app, named: "Hospital — localized health details in \(code)")
            tapAnimationControl("tabHome", in: app)
        }
    }

    @MainActor
    private func hospitalFixture(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--hospital-fixture"] + extra
        launchAndEnterHome(app)
        return app
    }

    @MainActor
    private func openHospitalDirectory(in app: XCUIApplication) {
        tapAnimationControl("tabTown", in: app)
        scrollCareerPage("townMapScroll", to: "townHospitalMarker", in: app)
        tapAnimationControl("townHospitalMarker", in: app)
        scrollCareerPage("townMapScroll", to: "townHospitalButton", in: app)
        tapAnimationControl("townHospitalButton", in: app)
        waitForElement("hospitalDirectoryScroll", in: app)
    }
}
