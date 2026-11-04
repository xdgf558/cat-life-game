import XCTest

extension RoomHomeUITests {
    @MainActor
    func testCustomHomeNamePersistsAcrossRelaunchAndLanguageChanges() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        buyFoodForHomeNameProgressCheck(in: app)
        let originalBowl = bowlPosition(in: app)
        let name = "橘子的午后与星光小屋🐾🏡"
        XCTAssertEqual(name.count, 12)
        tapAnimationControl("settingsButton", in: app)
        tapSettingsRootControl("settingsHomeNameRow", in: app)
        replaceHomeNameText(with: name, replacing: "", in: app)
        waitForLabel("homeNamePreview", name, in: app)
        attachScreenshot(app, named: "Home name — Chinese and emoji entered through the keyboard")
        bringIntoView("homeNameSaveButton", in: app)
        tapAnimationControl("homeNameSaveButton", in: app)
        waitForLabel("homeNameStatus", "小家的名字已保存", in: app)
        waitForLabel("homeNamePreview", name, in: app)
        attachScreenshot(app, named: "Home name — saved name and sign preview")
        tapAnimationControl("settingsBackButton", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForLabel("homeNamePlaque", name, in: app)
        assertHomeNamePreservedProgress(bowl: originalBowl, in: app)
        attachScreenshot(app, named: "Home name — custom Chinese and emoji on the room sign")

        relaunchPreservingSave(app)
        waitForLabel("homeNamePlaque", name, in: app)
        assertHomeNamePreservedProgress(bowl: originalBowl, in: app)
        tapAnimationControl("settingsButton", in: app)

        tapSettingsRootControl("languageOption_en", in: app)
        assertSettingsLanguageSelection("en", in: app)
        tapSettingsRootControl("settingsHomeNameRow", in: app)
        waitForObservedValue("homeNameField", name, in: app)
        waitForLabel("homeNamePreview", name, in: app)
        tapAnimationControl("settingsBackButton", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForLabel("tabHome", "Home", in: app)
        waitForLabel("homeNamePlaque", name, in: app)
        attachScreenshot(app, named: "Home name — English interface preserves the user-written name")
        relaunchPreservingSave(app)
        waitForLabel("tabHome", "Home", in: app)
        waitForLabel("homeNamePlaque", name, in: app)
        assertHomeNamePreservedProgress(bowl: originalBowl, in: app)
    }

    @MainActor
    func testHomeNameValidationDiscardedDraftAndLocalizedDefaultPreserveProgress() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        buyFoodForHomeNameProgressCheck(in: app)
        let originalBowl = bowlPosition(in: app)
        let name = "SunnyCorner!"
        XCTAssertEqual(name.count, 12)
        tapAnimationControl("settingsButton", in: app)
        tapSettingsRootControl("settingsHomeNameRow", in: app)
        replaceHomeNameText(with: name, replacing: "", in: app)
        bringIntoView("homeNameSaveButton", in: app)
        tapAnimationControl("homeNameSaveButton", in: app)
        waitForLabel("homeNameStatus", "小家的名字已保存", in: app)

        replaceHomeNameText(with: "   ", replacing: name, in: app)
        assertHomeNameSaveDisabled(in: app)
        replaceHomeNameText(with: "ABCDEFGHIJKLM", replacing: "   ", in: app)
        assertHomeNameSaveDisabled(in: app)
        attachScreenshot(app, named: "Home name — thirteen characters cannot be saved")
        tapAnimationControl("settingsBackButton", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForLabel("homeNamePlaque", name, in: app)
        assertHomeNamePreservedProgress(bowl: originalBowl, in: app)

        // Returning also discards an otherwise valid edit; it is not an
        // implicit Save action just because the draft passes validation.
        tapAnimationControl("settingsButton", in: app)
        tapSettingsRootControl("settingsHomeNameRow", in: app)
        waitForObservedValue("homeNameField", name, in: app)
        replaceHomeNameText(with: "Draft Nook", replacing: name, in: app)
        tapAnimationControl("settingsBackButton", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForLabel("homeNamePlaque", name, in: app)
        relaunchPreservingSave(app)
        waitForLabel("homeNamePlaque", name, in: app)

        tapAnimationControl("settingsButton", in: app)

        tapSettingsRootControl("languageOption_en", in: app)
        assertSettingsLanguageSelection("en", in: app)
        tapSettingsRootControl("settingsHomeNameRow", in: app)
        waitForObservedValue("homeNameField", name, in: app)
        bringIntoView("homeNameResetButton", in: app)
        tapAnimationControl("homeNameResetButton", in: app)
        waitForLabel("homeNameStatus", "Default name restored", in: app)
        waitForLabel("homeNamePreview", "My home", in: app)
        attachScreenshot(app, named: "Home name — restored English default in the sign preview")
        tapAnimationControl("settingsBackButton", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForLabel("homeNamePlaque", "My home", in: app)
        assertHomeNamePreservedProgress(bowl: originalBowl, in: app)
        relaunchPreservingSave(app)
        waitForLabel("homeNamePlaque", "My home", in: app)

        tapAnimationControl("settingsButton", in: app)

        tapSettingsRootControl("languageOption_zh-Hans", in: app)
        assertSettingsLanguageSelection("zh-Hans", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForLabel("homeNamePlaque", "我的小家", in: app)
        assertHomeNamePreservedProgress(bowl: originalBowl, in: app)
        attachScreenshot(app, named: "Home name — default name follows the language without resetting the save")
    }

    @MainActor
    func testSettingsLanguageChangesRefreshScreensAndPersistWithoutResettingProgress() throws {
        continueAfterFailure = false
        let app = launchFurnitureHome()
        waitForLabel("tabHome", "家", in: app)

        // Give the save non-default supplies and a real saved layout so a
        // language change that resets progress cannot pass on initial values.
        tapAnimationControl("tabShop", in: app)
        scrollCareerPage("destinationScroll", to: "buyFoodButton", in: app)
        tapAnimationControl("buyFoodButton", in: app)
        waitForObservedValue("shopGoldCount", "180", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("foodCount", "4", in: app)
        let original = furnitureState(in: app)
        tapAnimationControl("decorateButton", in: app)
        waitForElement("layoutDoneButton", in: app)
        dragBowl(from: original.bowl.position, to: CGVector(dx: 0.63, dy: 0.69), in: app)
        _ = waitForFurniture(in: app, description: "a non-default bowl placement to finish validation", matching: {
            !$0.pending && self.element("layoutDoneButton", in: app).isEnabled
                && hypot($0.bowl.x - original.bowl.x, $0.bowl.y - original.bowl.y) > 0.02
        })
        tapAnimationControl("layoutDoneButton", in: app)
        let savedRoom = waitForFurniture(in: app, description: "changed layout to be saved", matching: { $0.phase == "idle" })

        let languages: [SettingsLanguageText] = [
            .init(code: "en", title: "Settings", language: "Game language", updates: "Version updates", back: "Back",
                  home: "Home", shop: "Shop", bag: "Bag", shopTitle: "Little cat shop", food: "Cat food",
                  bagTitle: "Bag", bagFoodLabel: "Cat food in your bag",
                  welcomeTitle: "Cat Life Diary", welcomeEnter: "Enter home"),
            .init(code: "zh-Hant", title: "設定", language: "遊戲語言", updates: "版本更新", back: "返回",
                  home: "家", shop: "商店", bag: "背包", shopTitle: "貓咪小商店", food: "一般貓糧",
                  bagTitle: "背包", bagFoodLabel: "背包中的貓糧",
                  welcomeTitle: "打工養貓日記", welcomeEnter: "進入小家"),
            .init(code: "zh-Hans", title: "设置", language: "游戏语言", updates: "版本更新", back: "返回",
                  home: "家", shop: "商店", bag: "背包", shopTitle: "猫咪小商店", food: "普通猫粮",
                  bagTitle: "背包", bagFoodLabel: "背包中的猫粮",
                  welcomeTitle: "打工养猫日记", welcomeEnter: "进入小家")
        ]
        for language in languages {
            tapAnimationControl("settingsButton", in: app)
            if language.code == "en" {
                waitForElement("settingsLanguageSegments", in: app)
                attachScreenshot(app, named: "Settings — root with language and version destinations")
            }

            tapSettingsRootControl("languageOption_\(language.code)", in: app)
            assertSettingsLanguageSelection(language.code, in: app)
            waitForLabel("settingsLanguageTitle", language.language, in: app)
            assertFixedNavigationAvailable(in: app)
            attachScreenshot(app, named: "Settings — inline language immediately translated to \(language.code)")
            waitForLabel("settingsLanguageTitle", language.language, in: app, contains: true)
            waitForLabel("settingsUpdatesRow", language.updates, in: app, contains: true)
            XCTAssertTrue(app.staticTexts[language.title].firstMatch.exists)
            tapAnimationControl("tabHome", in: app)
            assertHomeControlRows(in: app, stage: "home in \(language.code)")
            assertLocalizedHomeAndDestinations(language, in: app)
            assertSettingsPreservedRoom(savedRoom, in: app)
            attachScreenshot(app, named: "Settings — \(language.code) applied without changing progress")

            // The process still starts with a Chinese system locale. A saved
            // English/Traditional choice must override it on the next launch.
            app.terminate()
            app.launchArguments = arguments(reset: false) + ["--furniture-test"]
            app.launch()
            waitForWelcomeEntryReady(in: app)
            waitForLabel("welcomeTitle", language.welcomeTitle, in: app)
            waitForLabel("welcomeEnterButton", language.welcomeEnter, in: app)
            waitForObservedValue("welcomeProgress", "100%", in: app)
            XCTAssertTrue(element("welcomeScreen", in: app).exists)
            XCTAssertFalse(element("roomScene", in: app).exists,
                           "The localized welcome page must wait for the user's Enter action.")
            attachScreenshot(app, named: "Welcome — saved \(language.code) after cold launch")
            tapAnimationControl("welcomeEnterButton", in: app)
            waitForElement("feedButton", in: app)
            waitForLabel("tabHome", language.home, in: app)
            waitForLabel("tabShop", language.shop, in: app)
            ensureHomeNavigationItemVisible("tabInventory", in: app)
            waitForLabel("tabInventory", language.bag, in: app)
            tapAnimationControl("tabHome", in: app)
            assertSettingsPreservedRoom(savedRoom, in: app)
            tapAnimationControl("settingsButton", in: app)
            waitForLabel("settingsLanguageTitle", language.language, in: app, contains: true)

            assertSettingsLanguageSelection(language.code, in: app)
            assertFixedNavigationAvailable(in: app)
            tapAnimationControl("tabHome", in: app)
        }
    }

    @MainActor
    func testSettingsUpdatesShowCurrentVersionAndOnlyThreeReleasesWithWorkingNavigation() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        let originalBowl = bowlPosition(in: app)
        tapAnimationControl("settingsButton", in: app)
        waitForLabel("settingsLanguageTitle", "游戏语言", in: app, contains: true)
        waitForLabel("settingsUpdatesRow", "版本更新", in: app, contains: true)
        XCTAssertFalse(element("settingsBackButton", in: app).exists,
                       "The settings root stays within the fixed bottom navigation.")
        tapSettingsRootControl("settingsUpdatesRow", in: app)
        waitForObservedValue("currentAppVersion", "0.9.2 (37)", in: app)
        waitForLabel("currentAppVersion", "当前版本", in: app)
        waitForLabel("settingsBackButton", "返回", in: app)
        XCTAssertTrue(app.navigationBars["版本更新"].waitForExistence(timeout: 8))
        attachScreenshot(app, named: "Settings — version page at the top before scrolling")
        for (release, version) in [(37, "0.9.2"), (36, "0.9.1"), (35, "0.9.0")] {
            let identifier = "releaseNote_\(release)"
            bringIntoView(identifier, in: app)
            waitForElement(identifier, in: app)
            waitForLabel(identifier, version, in: app, contains: true)
            XCTAssertTrue(element(identifier, in: app).isHittable,
                          "Release \(release) must be readable by scrolling on a small screen.")
        }
        XCTAssertFalse(element("releaseNote_34", in: app).exists,
                       "Older history may remain in data, but only the latest three entries belong on this page.")
        attachScreenshot(app, named: "Settings — the third recent release is reachable; older history is hidden")

        tapAnimationControl("settingsBackButton", in: app)
        waitForElement("settingsUpdatesRow", in: app)
        XCTAssertFalse(element("currentAppVersion", in: app).exists)

        assertSettingsLanguageSelection("zh-Hans", in: app)
        waitForElement("settingsLanguageSegments", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForLabel("tabHome", "家", in: app)
        waitForObservedValue("foodCount", "3", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        waitForObservedValue("catSatiety", "35", in: app)
        let restoredBowl = bowlPosition(in: app)
        XCTAssertEqual(restoredBowl.dx, originalBowl.dx, accuracy: 0.005)
        XCTAssertEqual(restoredBowl.dy, originalBowl.dy, accuracy: 0.005)
        XCTAssertFalse(element("settingsCloseButton", in: app).exists)
        XCTAssertTrue(element("feedButton", in: app).isHittable)
        attachScreenshot(app, named: "Settings — nested navigation closes back to the unchanged room")
    }

    @MainActor
    func testSettingsDismissalResumesAnInProgressMeal() throws {
        continueAfterFailure = false
        let app = launchNavigationHome()
        let before = navigationState(in: app)
        ensureHomeNavigationItemVisible("settingsButton", in: app)
        let settingsTouch = element("settingsButton", in: app).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let moreTouch = element("tabMore", in: app).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        tapAnimationControl("tabHome", in: app)
        tapAnimationControl("feedButton", in: app)
        let eating = waitForNavigation(in: app, timeout: 25, description: "an unfinished meal with real mouth contact",
                                       matching: { $0.phase == "feeding" && $0.foodContactSamples > before.foodContactSamples
                                           && $0.completedMeals == before.completedMeals })
        // Use the already known button coordinate immediately after observing
        // contact; extra existence/label queries could let the meal finish.
        moreTouch.tap()
        settingsTouch.tap()
        waitForElement("settingsLanguageSegments", in: app)
        let interruption = XCTAttachment(string: "phaseBeforeSettings=\(eating.phase)\ncompletedMealsBeforeSettings=\(eating.completedMeals)\nfoodContactSamplesBeforeSettings=\(eating.foodContactSamples)")
        interruption.name = "Settings — opened during a real unfinished meal"
        interruption.lifetime = .keepAlways
        add(interruption)

        // Real navigation and a saved language change keep the embedded
        // settings open while the room is inactive, without a timed sleep.

        tapSettingsRootControl("languageOption_en", in: app)
        assertSettingsLanguageSelection("en", in: app)
        waitForLabel("settingsLanguageTitle", "Game language", in: app, contains: true)
        assertFixedNavigationAvailable(in: app)
        waitForLabel("settingsUpdatesRow", "Version updates", in: app, contains: true)
        tapSettingsRootControl("settingsHomeNameRow", in: app)
        replaceHomeNameText(with: "Sunny Home", replacing: "", in: app)
        bringIntoView("homeNameSaveButton", in: app)
        tapAnimationControl("homeNameSaveButton", in: app)
        waitForLabel("homeNameStatus", "Home name saved", in: app)
        tapAnimationControl("settingsBackButton", in: app)
        tapSettingsRootControl("settingsUpdatesRow", in: app)
        waitForObservedValue("currentAppVersion", "0.9.2 (37)", in: app)
        attachScreenshot(app, named: "Settings — English updates before scrolling")
        bringIntoView("releaseNote_35", in: app)
        XCTAssertTrue(element("releaseNote_35", in: app).isHittable)
        XCTAssertFalse(element("releaseNote_34", in: app).exists)
        attachScreenshot(app, named: "Settings — English third update is readable")
        tapAnimationControl("settingsBackButton", in: app)
        tapAnimationControl("tabHome", in: app)

        let finished = waitForNavigationPhase("idle", in: app, timeout: 35)
        XCTAssertEqual(finished.completedMeals, before.completedMeals + 1,
                       "Closing settings must resume the same meal. Diagnostics: \(element("roomScene", in: app).value ?? "missing")")
        XCTAssertGreaterThanOrEqual(finished.foodContactSamples, eating.foodContactSamples,
                                    "Opening settings must preserve the active meal and its contact diagnostics.")
        XCTAssertGreaterThan(finished.foodContactSamples, before.foodContactSamples)
        waitForObservedValue("foodCount", "2", in: app)
        waitForObservedValue("catSatiety", "60", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        waitForLabel("tabHome", "Home", in: app)
        waitForLabel("homeNamePlaque", "Sunny Home", in: app)
        let completion = XCTAttachment(string: String(describing: element("roomScene", in: app).value))
        completion.name = "Settings — interrupted meal resumed and completed once"
        completion.lifetime = .keepAlways
        add(completion)
        attachScreenshot(app, named: "Settings — English home after the resumed meal with one portion consumed")
    }

    @MainActor
    private func replaceHomeNameText(with text: String, replacing previous: String, in app: XCUIApplication,
                                      file: StaticString = #filePath, line: UInt = #line) {
        waitForElement("homeNameField", in: app, file: file, line: line)
        let field = element("homeNameField", in: app)
        // A previous edit may leave this scroll view below the field. Find the
        // actual text control before using keyboard events on either screen size.
        for _ in 0..<3 {
            if field.isHittable { break }
            app.scrollViews.firstMatch.swipeDown()
        }
        if !field.isHittable { bringIntoView("homeNameField", in: app) }
        tapAnimationControl("homeNameField", in: app, file: file, line: line)
        // The accessible frame includes 14pt of decoration on either side.
        // Stay inside the UITextField when moving the insertion point to its end.
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.90, dy: 0.5)).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 8),
                      "The name field must open the keyboard before receiving text events.", file: file, line: line)
        // The caller tracks actual draft contents. The empty field's accessible
        // value can be its placeholder, which must never be mistaken for text.
        if !previous.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count))
        }
        field.typeText(text)
        waitForObservedValue("homeNameField", text, in: app, file: file, line: line)
        if previous.isEmpty {
            attachScreenshot(app, named: "Home name — keyboard input before Done (\(text.count) characters)")
        }
        // The SE keyboard covers the lower half of the scroll view. Its full
        // accessible frame makes a generic swipe start on the keyboard. Use
        // the real Done key first; onSubmit only ends editing, it never saves.
        field.typeText("\n")
        let keyboardDismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: app.keyboards.firstMatch)
        XCTAssertEqual(XCTWaiter.wait(for: [keyboardDismissed], timeout: 8), .completed,
                       "Done must dismiss the keyboard before scrolling to the separate Save button.",
                       file: file, line: line)
        waitForObservedValue("homeNameField", text, in: app, file: file, line: line)
    }

    @MainActor
    private func assertHomeNameSaveDisabled(in app: XCUIApplication,
                                            file: StaticString = #filePath, line: UInt = #line) {
        let save = element("homeNameSaveButton", in: app)
        let disabled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND enabled == false"), object: save)
        XCTAssertEqual(XCTWaiter.wait(for: [disabled], timeout: 8), .completed,
                       "Blank or overlong drafts must not offer Save.", file: file, line: line)
    }

    private struct SettingsLanguageText {
        let code: String
        let title: String
        let language: String
        let updates: String
        let back: String
        let home: String
        let shop: String
        let bag: String
        let shopTitle: String
        let food: String
        let bagTitle: String
        let bagFoodLabel: String
        let welcomeTitle: String
        let welcomeEnter: String
    }

    @MainActor
    private func assertLocalizedHomeAndDestinations(_ language: SettingsLanguageText, in app: XCUIApplication,
                                                    file: StaticString = #filePath, line: UInt = #line) {
        waitForLabel("tabHome", language.home, in: app, file: file, line: line)
        waitForLabel("tabShop", language.shop, in: app, file: file, line: line)
        ensureHomeNavigationItemVisible("tabInventory", in: app, file: file, line: line)
        waitForLabel("tabInventory", language.bag, in: app, file: file, line: line)
        tapAnimationControl("tabHome", in: app, file: file, line: line)
        waitForObservedValue("foodCount", "4", in: app, file: file, line: line)
        waitForObservedValue("goldCount", "180", in: app, file: file, line: line)

        tapAnimationControl("tabShop", in: app, file: file, line: line)
        XCTAssertTrue(app.staticTexts[language.shopTitle].firstMatch.waitForExistence(timeout: 8), file: file, line: line)
        assertFixedNavigationAvailable(in: app, file: file, line: line)
        XCTAssertTrue(app.staticTexts[language.food].firstMatch.waitForExistence(timeout: 8),
                      "Shop product names must use the newly selected language.", file: file, line: line)
        waitForObservedValue("shopGoldCount", "180", in: app, file: file, line: line)
        tapAnimationControl("tabHome", in: app, file: file, line: line)

        tapAnimationControl("tabInventory", in: app, file: file, line: line)
        XCTAssertTrue(app.staticTexts[language.bagTitle].firstMatch.waitForExistence(timeout: 8), file: file, line: line)
        assertFixedNavigationAvailable(in: app, file: file, line: line)
        waitForLabel("inventoryFoodCount", language.bagFoodLabel, in: app, file: file, line: line)
        waitForObservedValue("inventoryFoodCount", "4", in: app, file: file, line: line)
        waitForObservedValue("inventoryLitterCount", "2", in: app, file: file, line: line)
        bringIntoView("inventoryToyUses", in: app)
        waitForObservedValue("inventoryToyUses", "0", in: app, file: file, line: line)
        tapAnimationControl("tabHome", in: app, file: file, line: line)
    }

    @MainActor
    private func assertSettingsPreservedRoom(_ saved: FurnitureState, in app: XCUIApplication,
                                             file: StaticString = #filePath, line: UInt = #line) {
        let current = waitForFurniture(in: app, description: "the unchanged room after settings",
                                       matching: { $0.phase == "idle" && !$0.pending }, file: file, line: line)
        XCTAssertEqual(current.bowl.x, saved.bowl.x, accuracy: 0.005, file: file, line: line)
        XCTAssertEqual(current.bowl.y, saved.bowl.y, accuracy: 0.005, file: file, line: line)
        XCTAssertEqual(Set(current.items.map(\.id)), Set(saved.items.map(\.id)), file: file, line: line)
        for item in saved.items {
            guard let restored = current.items.first(where: { $0.id == item.id }) else {
                XCTFail("Settings removed placed furniture \(item.id).", file: file, line: line)
                return
            }
            XCTAssertEqual(restored.x, item.x, accuracy: 0.005, file: file, line: line)
            XCTAssertEqual(restored.y, item.y, accuracy: 0.005, file: file, line: line)
        }
        waitForObservedValue("foodCount", "4", in: app, file: file, line: line)
        waitForObservedValue("goldCount", "180", in: app, file: file, line: line)
        waitForObservedValue("catSatiety", "35", in: app, file: file, line: line)
    }
}
