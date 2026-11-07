import XCTest

extension RoomHomeUITests {
    @MainActor
    func testHigherCareersStayPagedShowRealQuotesAndPersistAnActiveShift() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--career-level20-fixture"]
        launchAndEnterHome(app)
        openCareerHome(in: app)
        waitForObservedValue("playerLevel", "20", in: app)
        waitForObservedValue("workGridPage", "1/2", in: app)
        tapCareerControl("careerChooseJobButton", in: app)
        tapCareerDirectoryControl("careerPageNext", in: app)
        waitForObservedValue("careerPageIndicator", "2/2", in: app)
        waitForElement("careerJobRow_job_pet_photographer", in: app)
        waitForElement("careerJobRow_job_pet_brand_designer", in: app)
        attachScreenshot(app, named: "Career 57 — seven careers remain in two bounded pages")
        openCareerDetailsFromDirectory("job_pet_photographer", in: app)
        XCTAssertTrue(element("careerSelect_job_pet_photographer", in: app).isEnabled)
        attachScreenshot(app, named: "Career 57 — pet photographer preview")
        tapAnimationControl("careerSelect_job_pet_photographer", in: app)
        waitForObservedValue("selectedCareerName", "job_pet_photographer", in: app)
        assertWorkQuote(duration: 2700, stamina: 65, mood: 24, in: app)
        XCTAssertFalse(element("workCountdown", in: app).exists)
        tapCareerControl("careerChooseJobButton", in: app)
        openCareerDetailsFromDirectory("job_pet_brand_designer", in: app)
        XCTAssertTrue(element("careerSelect_job_pet_brand_designer", in: app).isEnabled)
        tapAnimationControl("careerSelect_job_pet_brand_designer", in: app)
        waitForObservedValue("selectedCareerName", "job_pet_brand_designer", in: app)
        assertWorkQuote(duration: 3600, stamina: 80, mood: 28, in: app)
        attachScreenshot(app, named: "Career 57 — high-level jobs fit the second compact page")
        tapCareerControl("startWorkButton", in: app)
        waitForObservedValue("activeWorkDurationSeconds", "3600", in: app)
        assertWorkQuote(duration: 3600, stamina: 80, mood: 28, in: app)
        openCareerRest(in: app)
        waitForObservedValue("playerStamina", "20", in: app)
        waitForObservedValue("playerMood", "72", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        relaunchPreservingSave(app)
        openCareerHome(in: app)
        waitForObservedValue("selectedCareerName", "job_pet_brand_designer", in: app)
        waitForObservedValue("activeWorkDurationSeconds", "3600", in: app)
        XCTAssertFalse(element("startWorkButton", in: app).exists)
        attachScreenshot(app, named: "Career 57 — active designer shift restored without a second charge")
    }
}
