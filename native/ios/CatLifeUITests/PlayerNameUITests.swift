import XCTest

extension RoomHomeUITests {
    @MainActor
    func testCompactPlayerProfileSeparatesDetailsAndPreservesEdits() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        openPlayerProfile(in: app)
        assertCompactProfileRoot(in: app)
        assertProfileValue("profilePlayerName", "铲屎官", in: app)

        tapProfileControl("profileAttributesButton", in: app)
        waitForElement("profileAttributesSheet", in: app)
        for (identifier, value) in [("profileLevel", "1"), ("profileExp", "0"),
                                    ("profileStamina", "80"), ("profileMood", "80"),
                                    ("profileGold", "200"), ("profileCompletedWork", "0")] {
            scrollCareerPage("profileAttributesSheet", to: identifier, in: app)
            waitForObservedValue(identifier, value, in: app)
        }
        attachScreenshot(app, named: "Compact profile — portrait opens the separate attribute sheet")
        closeProfileAttributes(in: app)
        assertCompactProfileRoot(in: app)

        tapProfileControl("profileWardrobeButton", in: app)
        waitForElement("profileWardrobeScroll", in: app)
        tapProfilePageControl("profileEquipAllButton", scroll: "profileWardrobeScroll", in: app)
        assertProfileValue("profileEquippedCount", "4", in: app)
        for (slot, item) in playerStarterEquipment {
            assertProfileValue("equipmentSlot_\(slot)", item, in: app)
        }
        attachScreenshot(app, named: "Compact profile — the wardrobe owns all four equipped slots")
        tapProfileControl("equipmentSlot_head", in: app)
        waitForElement("equipmentScroll", in: app)
        tapProfilePageControl("unequipSlot_head", scroll: "equipmentScroll", in: app)
        waitForObservedValue("equippedItem_head", "none", in: app)
        tapProfilePageControl("equipItem_starter_cap", scroll: "equipmentScroll", in: app)
        waitForObservedValue("equippedItem_head", "starter_cap", in: app)
        tapAnimationControl("profileBackButton", in: app)
        waitForElement("profileWardrobeScroll", in: app)
        XCTAssertFalse(element("profileAttributesButton", in: app).exists,
                       "The equipment Back button returns one level to the wardrobe.")
        tapAnimationControl("profileSectionBackButton", in: app)
        assertCompactProfileRoot(in: app)

        tapProfileControl("profileBonusesButton", in: app)
        waitForElement("profileBonusesScroll", in: app)
        for (identifier, value) in [("profileDurationBonus", "15"), ("profileStaminaBonus", "15"),
                                    ("profileMoodBonus", "20")] {
            assertProfileValue(identifier, value, in: app)
        }
        attachScreenshot(app, named: "Compact profile — bonuses have their own detail page")
        tapAnimationControl("profileSectionBackButton", in: app)
        assertCompactProfileRoot(in: app)

        let name = "暖阳伙伴🐾"
        openPlayerNameEditor(in: app)
        replacePlayerNameText(with: name, replacing: "", in: app)
        tapPlayerNameControl("playerNameSaveButton", in: app)
        waitForLabel("playerNameStatus", "名字已保存", in: app)
        tapAnimationControl("playerNameBackButton", in: app)
        selectPlayerNameTestAvatar("female_forest", in: app)
        assertProfileValue("profilePlayerName", name, in: app)
        assertProfileValue("profileAvatarName", "female_forest", in: app)
        assertCompactProfileRoot(in: app)
        attachScreenshot(app, named: "Compact profile — saved name and selected portrait on the short root page")
        closePlayerProfile(in: app)

        relaunchPreservingSave(app)
        waitForObservedValue("goldCount", "200", in: app)
        waitForObservedValue("foodCount", "3", in: app)
        openPlayerProfile(in: app)
        assertCompactProfileRoot(in: app)
        assertProfileValue("profilePlayerName", name, in: app)
        assertProfileValue("profileAvatarName", "female_forest", in: app)
        assertProfileValue("profileEquippedCount", "4", in: app)
        for (slot, item) in playerStarterEquipment {
            assertProfileValue("equipmentSlot_\(slot)", item, in: app)
        }
        assertProfileValue("profileDurationBonus", "15", in: app)
        returnToProfileRoot(in: app)
        assertCompactProfileRoot(in: app)
        closePlayerProfile(in: app)
        assertKnownHomeViewportBaseline(in: app)
    }

    @MainActor
    func testPlayerNamePersistsAndPreservesAppearanceAndProgress() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        buyFoodForPlayerNameProgressCheck(in: app)
        let originalBowl = bowlPosition(in: app)
        let originalRoomFrame = element("roomScene", in: app).frame
        openPlayerProfile(in: app)
        assertProfileValue("profilePlayerName", "铲屎官", in: app)
        selectPlayerNameTestAvatar("male_sunny", in: app)
        tapProfileControl("profileEquipAllButton", in: app)
        assertProfileValue("profileEquippedCount", "4", in: app)

        let name = "橘子的午后与星光伙伴🐾🏡"
        XCTAssertEqual(name.count, 12)
        openPlayerNameEditor(in: app)
        replacePlayerNameText(with: name, replacing: "", in: app)
        waitForLabel("playerNamePreview", name, in: app)
        scrollCareerPage("playerNameScroll", to: "playerNameSaveButton", in: app)
        XCTAssertTrue(element("playerNameSaveButton", in: app).isEnabled,
                      "Keyboard Done must finish editing without committing the name.")
        XCTAssertFalse(element("playerNameStatus", in: app).exists)
        tapPlayerNameControl("playerNameSaveButton", in: app)
        scrollCareerPage("playerNameScroll", to: "playerNameStatus", in: app)
        waitForLabel("playerNameStatus", "名字已保存", in: app)
        attachScreenshot(app, named: "Player name — Chinese and emoji saved at the twelve-character limit")
        tapAnimationControl("playerNameBackButton", in: app)
        assertProfileValue("profilePlayerName", name, in: app)
        assertProfileValue("profileAvatarName", "male_sunny", in: app)
        waitForLabel("profileAvatarName", "晴日男生", in: app)
        selectPlayerNameTestAvatar("female_forest", in: app)
        assertProfileValue("profilePlayerName", name, in: app)
        assertProfileValue("profileAvatarName", "female_forest", in: app)
        waitForLabel("profileAvatarName", "森系女生", in: app)
        attachScreenshot(app, named: "Player name — the saved name remains separate from the new appearance")
        closePlayerProfile(in: app)
        assertPlayerNameProgress(bowl: originalBowl, room: originalRoomFrame, in: app)

        relaunchPreservingSave(app)
        assertPlayerNameProgress(bowl: originalBowl, room: originalRoomFrame, in: app)
        openPlayerProfile(in: app)
        assertProfileValue("profilePlayerName", name, in: app)
        assertProfileValue("profileAvatarName", "female_forest", in: app)
        assertProfileValue("profileEquippedCount", "4", in: app)
        for (slot, item) in playerStarterEquipment {
            assertProfileValue("equipmentSlot_\(slot)", item, in: app)
        }
        assertProfileValue("profileGold", "180", in: app)
        assertProfileValue("profileLevel", "1", in: app)
        assertProfileValue("profileExp", "0", in: app)
        openPlayerNameEditor(in: app)
        waitForObservedValue("playerNameField", name, in: app)
        replacePlayerNameText(with: "   ", replacing: name, in: app)
        assertPlayerNameSaveDisabled(in: app)
        replacePlayerNameText(with: "ABCDEFGHIJKLM", replacing: "   ", in: app)
        assertPlayerNameSaveDisabled(in: app)
        attachScreenshot(app, named: "Player name — thirteen characters cannot be saved")
        tapAnimationControl("playerNameBackButton", in: app)
        assertProfileValue("profilePlayerName", name, in: app)

        openPlayerNameEditor(in: app)
        waitForObservedValue("playerNameField", name, in: app)
        replacePlayerNameText(with: "未保存的名字🐾", replacing: name, in: app)
        waitForObservedValue("playerNameValidation", "valid", in: app)
        scrollCareerPage("playerNameScroll", to: "playerNameSaveButton", in: app)
        XCTAssertTrue(element("playerNameSaveButton", in: app).isEnabled)
        tapAnimationControl("playerNameBackButton", in: app)
        assertProfileValue("profilePlayerName", name, in: app)
        openPlayerNameEditor(in: app)
        waitForObservedValue("playerNameField", name, in: app)
        waitForLabel("playerNamePreview", name, in: app)
        tapPlayerNameControl("playerNameResetButton", in: app)
        scrollCareerPage("playerNameScroll", to: "playerNameStatus", in: app)
        waitForLabel("playerNameStatus", "已恢复默认称呼", in: app)
        waitForLabel("playerNamePreview", "铲屎官", in: app)
        tapAnimationControl("playerNameBackButton", in: app)
        assertProfileValue("profilePlayerName", "铲屎官", in: app)
        closePlayerProfile(in: app)
        relaunchPreservingSave(app)
        assertPlayerNameProgress(bowl: originalBowl, room: originalRoomFrame, in: app)
        openPlayerProfile(in: app)
        assertProfileValue("profilePlayerName", "铲屎官", in: app)
        assertProfileValue("profileAvatarName", "female_forest", in: app)
        assertProfileValue("profileEquippedCount", "4", in: app)
        returnToProfileRoot(in: app)
        attachScreenshot(app, named: "Player name — default restored after cold launch without losing appearance or equipment")
    }

    @MainActor
    func testPlayerNameRemainsUntranslatedAcrossLanguages() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        let name = "小橘的伙伴🐾"
        openPlayerProfile(in: app)
        openPlayerNameEditor(in: app)
        assertPlayerNameLabels(title: "角色名字", field: "你的名字", save: "保存名字",
                               reset: "恢复默认称呼", back: "返回", in: app)
        replacePlayerNameText(with: name, replacing: "", in: app)
        tapPlayerNameControl("playerNameSaveButton", in: app)
        waitForLabel("playerNameStatus", "名字已保存", in: app)
        tapAnimationControl("playerNameBackButton", in: app)
        assertProfileValue("profilePlayerName", name, in: app)
        closePlayerProfile(in: app)

        let languages = [
            (code: "en", title: "Character name", field: "Your name", save: "Save name",
             reset: "Use default name", back: "Back", edit: "Edit name"),
            (code: "zh-Hant", title: "角色名字", field: "你的名字", save: "儲存名字",
             reset: "恢復預設稱呼", back: "返回", edit: "修改名字")
        ]
        for language in languages {
            selectPlayerNameTestLanguage(language.code, in: app)
            openPlayerProfile(in: app)
            assertProfileValue("profilePlayerName", name, in: app)
            scrollCareerPage("profileScroll", to: "profileRenameButton", in: app)
            waitForLabel("profileRenameButton", language.edit, in: app)
            openPlayerNameEditor(in: app)
            assertPlayerNameLabels(title: language.title, field: language.field, save: language.save,
                                   reset: language.reset, back: language.back, in: app)
            waitForObservedValue("playerNameField", name, in: app)
            waitForLabel("playerNamePreview", name, in: app)
            attachScreenshot(app, named: "Player name — translated controls preserve the custom name in \(language.code)")
            tapAnimationControl("playerNameBackButton", in: app)
            assertProfileValue("profilePlayerName", name, in: app)
            closePlayerProfile(in: app)
        }

        selectPlayerNameTestLanguage("en", in: app)
        openPlayerProfile(in: app)
        openPlayerNameEditor(in: app)
        tapPlayerNameControl("playerNameResetButton", in: app)
        waitForLabel("playerNameStatus", "Default name restored", in: app)
        waitForLabel("playerNamePreview", "Cat parent", in: app)
        tapAnimationControl("playerNameBackButton", in: app)
        assertProfileValue("profilePlayerName", "Cat parent", in: app)
        closePlayerProfile(in: app)
        relaunchPreservingSave(app)
        waitForLabel("tabHome", "Home", in: app)
        openPlayerProfile(in: app)
        assertProfileValue("profilePlayerName", "Cat parent", in: app)
        openPlayerNameEditor(in: app)
        assertPlayerNameLabels(title: "Character name", field: "Your name", save: "Save name",
                               reset: "Use default name", back: "Back", in: app)
        waitForObservedValue("playerNameValidation", "invalid", in: app)
        XCTAssertFalse(element("playerNameSaveButton", in: app).isEnabled)
        XCTAssertFalse(element("playerNameResetButton", in: app).isEnabled)
        attachScreenshot(app, named: "Player name — English default and cleared custom name survive cold launch")
    }

    @MainActor
    private func assertCompactProfileRoot(in app: XCUIApplication,
                                          file: StaticString = #filePath, line: UInt = #line) {
        waitForElement("profileScroll", in: app, file: file, line: line)
        for identifier in ["profileAttributesSheet", "profileWardrobeScroll", "profileBonusesScroll",
                           "profileLevel", "profileExp", "profileStamina", "profileMood", "profileGold",
                           "profileCompletedWork", "profileEquippedCount", "profileEquipAllButton",
                           "equipmentSlot_head", "equipmentSlot_body", "equipmentSlot_feet", "equipmentSlot_accessory",
                           "profileDurationBonus", "profileStaminaBonus", "profileMoodBonus"] {
            XCTAssertFalse(element(identifier, in: app).exists,
                "\(identifier) belongs to a detail page, not the compact profile root.", file: file, line: line)
        }
        let viewport = unobscuredScrollViewport(element("profileScroll", in: app), in: app)
        for identifier in ["profileAttributesButton", "profileRenameButton", "profileChooseAvatar",
                           "profileWardrobeButton", "profileBonusesButton"] {
            let target = element(identifier, in: app)
            XCTAssertTrue(target.exists && target.isEnabled && target.isHittable,
                          "The compact root must expose \(identifier) directly.", file: file, line: line)
            XCTAssertTrue(viewport.contains(target.frame),
                          "\(identifier) should fit without scrolling the root page.", file: file, line: line)
        }
    }

    @MainActor
    private func buyFoodForPlayerNameProgressCheck(in app: XCUIApplication) {
        tapAnimationControl("tabShop", in: app)
        let shopBalance = element("shopGoldCount", in: app)
        if !shopBalance.waitForExistence(timeout: 3) {
            let shopTab = element("tabShop", in: app)
            // The SE recording captured one correctly placed initial tab tap
            // that left the original home unchanged. Retry that navigation
            // once, with evidence; never retry the purchase or another state.
            if element("roomScene", in: app).exists,
               element("feedButton", in: app).exists,
               element("goldCount", in: app).value as? String == "200",
               element("foodCount", in: app).value as? String == "3",
               !element("buyFoodButton", in: app).exists,
               !element("closeSheetButton", in: app).exists,
               !element("settingsCloseButton", in: app).exists,
               app.alerts.count == 0,
               shopTab.exists, shopTab.isEnabled, shopTab.isHittable {
                let evidence = XCTAttachment(string: "One initial Shop tap left the unchanged home.\n\(app.debugDescription)")
                evidence.name = "Player name setup — unchanged home before one navigation retry"
                evidence.lifetime = .keepAlways
                add(evidence)
                attachScreenshot(app, named: "Player name setup — unchanged home after initial Shop tap")
                shopTab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
        }
        waitForObservedValue("shopGoldCount", "200", in: app)
        tapAnimationControl("buyFoodButton", in: app)
        waitForObservedValue("shopGoldCount", "180", in: app)
        tapAnimationControl("closeSheetButton", in: app)
        waitForObservedValue("foodCount", "4", in: app)
        waitForObservedValue("goldCount", "180", in: app)
    }

    @MainActor
    private func openPlayerNameEditor(in app: XCUIApplication) {
        tapProfileControl("profileRenameButton", in: app)
        waitForElement("playerNameScroll", in: app)
        waitForElement("playerNameField", in: app)
    }

    @MainActor
    private func tapPlayerNameControl(_ identifier: String, in app: XCUIApplication) {
        tapProfilePageControl(identifier, scroll: "playerNameScroll", in: app)
    }

    @MainActor
    private func selectPlayerNameTestAvatar(_ identifier: String, in app: XCUIApplication) {
        tapProfileControl("profileChooseAvatar", in: app)
        tapProfilePageControl("avatarSelect_\(identifier)", scroll: "avatarPickerScroll", in: app)
        scrollCareerPage("avatarPickerScroll", to: "avatarSelectedID", in: app)
        waitForObservedValue("avatarSelectedID", identifier, in: app)
        tapAnimationControl("profileBackButton", in: app)
        assertProfileValue("profileAvatarName", identifier, in: app)
    }

    @MainActor
    private func selectPlayerNameTestLanguage(_ code: String, in app: XCUIApplication) {
        tapAnimationControl("settingsButton", in: app)
        tapAnimationControl("settingsLanguageRow", in: app)
        tapAnimationControl("languageOption_\(code)", in: app)
        assertSettingsLanguageSelection(code, in: app)
        tapAnimationControl("settingsBackButton", in: app)
        tapAnimationControl("settingsCloseButton", in: app)
    }

    @MainActor
    private func replacePlayerNameText(with text: String, replacing previous: String, in app: XCUIApplication,
                                       file: StaticString = #filePath, line: UInt = #line) {
        scrollCareerPage("playerNameScroll", to: "playerNameField", in: app, file: file, line: line)
        let field = element("playerNameField", in: app)
        tapAnimationControl("playerNameField", in: app, file: file, line: line)
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.90, dy: 0.5)).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 8), file: file, line: line)
        if !previous.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count))
        }
        field.typeText(text)
        waitForObservedValue("playerNameField", text, in: app, file: file, line: line)
        // Match the existing home-name flow: actual keyboard events only.
        // Done ends editing; the separate Save button is the only commit action.
        field.typeText("\n")
        let dismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: app.keyboards.firstMatch)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 8), .completed,
                       "Done must dismiss the keyboard without saving.", file: file, line: line)
        waitForObservedValue("playerNameField", text, in: app, file: file, line: line)
    }

    @MainActor
    private func assertPlayerNameSaveDisabled(in app: XCUIApplication) {
        scrollCareerPage("playerNameScroll", to: "playerNameSaveButton", in: app)
        let disabled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND enabled == false"),
            object: element("playerNameSaveButton", in: app))
        XCTAssertEqual(XCTWaiter.wait(for: [disabled], timeout: 8), .completed)
        waitForObservedValue("playerNameValidation", "invalid", in: app)
    }

    @MainActor
    private func assertPlayerNameLabels(title: String, field: String, save: String, reset: String,
                                       back: String, in app: XCUIApplication) {
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 8))
        waitForLabel("playerNameBackButton", back, in: app)
        for (identifier, label) in [("playerNameField", field), ("playerNameSaveButton", save),
                                    ("playerNameResetButton", reset)] {
            scrollCareerPage("playerNameScroll", to: identifier, in: app)
            waitForLabel(identifier, label, in: app)
        }
    }

    @MainActor
    private func assertPlayerNameProgress(bowl: CGVector, room: CGRect, in app: XCUIApplication) {
        waitForObservedValue("goldCount", "180", in: app)
        waitForObservedValue("foodCount", "4", in: app)
        waitForObservedValue("staminaCount", "80", in: app)
        let current = bowlPosition(in: app)
        XCTAssertEqual(current.dx, bowl.dx, accuracy: 0.005)
        XCTAssertEqual(current.dy, bowl.dy, accuracy: 0.005)
        assertRoomFrame(room, in: app, context: "after player name changes", file: #filePath, line: #line)
    }
}
