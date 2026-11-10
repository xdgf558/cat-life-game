import XCTest

extension RoomHomeUITests {
    @MainActor
    func testCatGrowthDetailsKeepLegacyHistoryAndCompanionsIndependent() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--cat-growth-fixture"]
        launchAndEnterHome(app)
        let room = element("roomScene", in: app).frame
        let food = element("foodCount", in: app).value as? String
        let gold = element("goldCount", in: app).value as? String
        tapAnimationControl("homeCatProfileButton", in: app)
        XCTAssertFalse(element("catGrowthAge", in: app).exists, "Growth details belong on a separate page.")
        scrollCareerPage("catProfileScroll", to: "catGrowthEntry", in: app)
        tapAnimationControl("catGrowthEntry", in: app)
        waitForObservedValue("catGrowthScroll", "cat_001", in: app)
        waitForObservedValue("catGrowthName", "小橘", in: app)
        waitForObservedValue("catGrowthAge", "4 个月 0 天", in: app)
        waitForObservedValue("catGrowthSex", "公猫", in: app)
        waitForObservedValue("catGrowthStage", "幼猫期", in: app)
        attachScreenshot(app, named: "Growth — old companion has a separate game-age page")
        scrollCareerPage("catGrowthScroll", to: "catGrowthNextBond", in: app)
        waitForLabel("catGrowthNextBond", "再增加 1 点亲密，成为“渐渐熟悉”。", in: app)
        scrollCareerPage("catGrowthScroll", to: "catGrowthRecordHint", in: app)
        waitForObservedValue("catGrowthJoined", "此前已加入", in: app)
        waitForObservedValue("catGrowthCompanionship", "3 个完整天", in: app)
        waitForObservedValue("catGrowthRecordHint", "legacy", in: app)
        attachScreenshot(app, named: "Growth — old adoption date remains explicitly unknown")
        scrollCareerPage("catGrowthScroll", to: "catGrowthGoHome", in: app)
        tapAnimationControl("catGrowthGoHome", in: app)
        waitForObservedValue("homeCatName", "小橘", in: app)
        XCTAssertEqual(element("foodCount", in: app).value as? String, food)
        XCTAssertEqual(element("goldCount", in: app).value as? String, gold)
        assertRoomFrame(room, in: app, context: "viewing growth records")

        openTownCollection(in: app)
        scrollCareerPage("catCollectionScroll", to: "catProfile_cat_002", in: app)
        tapAnimationControl("catProfile_cat_002", in: app)
        scrollCareerPage("catProfileScroll", to: "catGrowthEntry", in: app)
        tapAnimationControl("catGrowthEntry", in: app)
        waitForObservedValue("catGrowthScroll", "cat_002", in: app)
        waitForObservedValue("catGrowthName", "牛奶", in: app)
        waitForObservedValue("catGrowthAge", "6 个月 20 天", in: app)
        waitForObservedValue("catGrowthSex", "母猫", in: app)
        waitForObservedValue("catGrowthStage", "少年期", in: app)
        scrollCareerPage("catGrowthScroll", to: "catGrowthBondStage", in: app)
        waitForObservedValue("catGrowthBondStage", "亲密家人", in: app)
        scrollCareerPage("catGrowthScroll", to: "catGrowthRecordHint", in: app)
        waitForObservedValue("catGrowthCompanionship", "2 个完整天", in: app)
        waitForObservedValue("catGrowthRecordHint", "adopted", in: app)
        scrollCareerPage("catGrowthScroll", to: "catGrowthGoHome", in: app)
        tapAnimationControl("catGrowthGoHome", in: app)
        waitForObservedValue("homeCatName", "牛奶", in: app)
        XCTAssertEqual(element("foodCount", in: app).value as? String, food)
        XCTAssertEqual(element("goldCount", in: app).value as? String, gold)
        relaunchPreservingSave(app)
        waitForObservedValue("homeCatName", "牛奶", in: app)
        tapAnimationControl("homeCatProfileButton", in: app)
        scrollCareerPage("catProfileScroll", to: "catGrowthEntry", in: app)
        tapAnimationControl("catGrowthEntry", in: app)
        waitForObservedValue("catGrowthAge", "6 个月 20 天", in: app)
    }

    @MainActor
    func testCatGrowthTimelineAndBondHeadersStayVisibleForBothFixtureCats() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--cat-growth-fixture"]
        launchAndEnterHome(app)
        let food = element("foodCount", in: app).value as? String
        let gold = element("goldCount", in: app).value as? String
        tapAnimationControl("homeCatProfileButton", in: app)
        scrollCareerPage("catProfileScroll", to: "catGrowthEntry", in: app)
        tapAnimationControl("catGrowthEntry", in: app)

        for (catID, age, stage, bond) in [
            ("cat_001", "4 个月 0 天", "幼猫期", "24 / 100"),
            ("cat_002", "6 个月 20 天", "少年期", "75 / 100")
        ] {
            scrollCareerPage("catGrowthScroll", to: "catGrowthSwitch_\(catID)", in: app)
            tapAnimationControl("catGrowthSwitch_\(catID)", in: app)
            waitForObservedValue("catGrowthScroll", catID, in: app)
            waitForObservedValue("catGrowthAge", age, in: app)
            waitForObservedValue("catGrowthStage", stage, in: app)
            scrollCareerPage("catGrowthScroll", to: "catGrowthNextStage", in: app)
            scrollCareerPage("catGrowthScroll", to: "catGrowth.growthHeading", in: app)
            let growthViewport = unobscuredScrollViewport(element("catGrowthScroll", in: app), in: app)
            for identifier in ["catGrowth.growthHeading", "catGrowthAge", "catGrowthNextStage"] {
                XCTAssertTrue(growthViewport.contains(element(identifier, in: app).frame), "\(catID): \(identifier)")
            }
            attachScreenshot(app, named: "Growth repair — \(catID) timeline and age share the visible section")

            scrollCareerPage("catGrowthScroll", to: "catGrowthNextBond", in: app)
            scrollCareerPage("catGrowthScroll", to: "catGrowth.bondHeading", in: app)
            waitForObservedValue("catGrowthBondValue", bond, in: app)
            let bondViewport = unobscuredScrollViewport(element("catGrowthScroll", in: app), in: app)
            for identifier in ["catGrowth.bondHeading", "catGrowthBondValue", "catGrowthNextBond"] {
                XCTAssertTrue(bondViewport.contains(element(identifier, in: app).frame), "\(catID): \(identifier)")
            }
            attachScreenshot(app, named: "Growth repair — \(catID) bond value remains beside its heading")
        }

        scrollCareerPage("catGrowthScroll", to: "catGrowthGoHome", in: app)
        tapAnimationControl("catGrowthGoHome", in: app)
        waitForObservedValue("homeCatName", "牛奶", in: app)
        XCTAssertEqual(element("foodCount", in: app).value as? String, food)
        XCTAssertEqual(element("goldCount", in: app).value as? String, gold)
    }

    @MainActor
    func testCatGrowthEnglishLargestTextKeepsRecordsAndReturnActionReachable() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--cat-growth-fixture",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        launchAndEnterHome(app)
        selectCatTestLanguage("en", in: app)
        tapAnimationControl("homeCatProfileButton", in: app)
        scrollCareerPage("catProfileScroll", to: "catGrowthEntry", in: app)
        tapAnimationControl("catGrowthEntry", in: app)
        for identifier in ["catGrowthAge", "catGrowthSex", "catGrowthStage", "catGrowthNextStage", "catGrowthNextBond", "catGrowthJoined"] {
            scrollCareerPage("catGrowthScroll", to: identifier, in: app)
            XCTAssertTrue(app.frame.contains(element(identifier, in: app).frame), identifier)
        }
        waitForObservedValue("catGrowthJoined", "Already part of your home", in: app)
        attachScreenshot(app, named: "Growth — English largest text uses stacked history fields")
        scrollCareerPage("catGrowthScroll", to: "catGrowthGoHome", in: app)
        XCTAssertTrue(element("catGrowthGoHome", in: app).isHittable)
        XCTAssertGreaterThanOrEqual(element("catGrowthGoHome", in: app).frame.height, 44)
        attachScreenshot(app, named: "Growth — English largest text can still return to the selected cat")
        tapAnimationControl("catGrowthGoHome", in: app)
        waitForObservedValue("homeCatName", "Sunny", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        waitForObservedValue("foodCount", "3", in: app)
    }
}
