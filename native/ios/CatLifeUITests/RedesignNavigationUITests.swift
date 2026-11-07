import XCTest

extension RoomHomeUITests {
    @MainActor
    func testRedesignFiveFixedTabsAndMoreKeepUtilitiesReachableWithoutChangingSave() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        let roomFrame = element("roomScene", in: app).frame
        let fixed = ["tabHome", "tabWork", "tabShop", "tabTown", "tabMore"]
        let bar = element("homeNavigationBar", in: app)
        XCTAssertEqual(bar.descendants(matching: .button).allElementsBoundByIndex.map(\.identifier).filter { fixed.contains($0) }.count, 5)
        for id in fixed { XCTAssertTrue(homeNavigationItemIsFullyVisible(id, in: app)) }
        XCTAssertFalse(element("tabInventory", in: app).exists)
        XCTAssertFalse(element("tabPlayer", in: app).exists)
        tapAnimationControl("tabMore", in: app)
        for id in ["tabInventory", "tabPlayer", "decorateButton", "settingsButton"] {
            let item = element(id, in: app)
            XCTAssertTrue(item.waitForExistence(timeout: 5) && item.isHittable)
            XCTAssertGreaterThanOrEqual(item.frame.width, 44)
            XCTAssertGreaterThanOrEqual(item.frame.height, 44)
            XCTAssertLessThanOrEqual(item.frame.maxY, bar.frame.minY + 1)
        }
        attachScreenshot(app, named: "Redesign — fixed tabs and four-item More menu")
        tapAnimationControl("tabInventory", in: app)
        waitForObservedValue("inventoryFoodCount", "3", in: app)
        let hiddenRoom = element("roomScene", in: app)
        if hiddenRoom.exists {
            let evidence = XCTAttachment(string: "Room type: \(hiddenRoom.elementType), hittable: \(hiddenRoom.isHittable)\n" + app.debugDescription)
            evidence.name = "Background room accessibility hierarchy"
            evidence.lifetime = .keepAlways
            add(evidence)
        }
        XCTAssertFalse(hiddenRoom.exists,
                       "The persistent SpriteKit scene must be hidden from accessibility off Home.")
        for id in fixed { XCTAssertTrue(homeNavigationItemIsFullyVisible(id, in: app)) }
        tapAnimationControl("tabPlayer", in: app)
        waitForElement("profileScroll", in: app)
        tapAnimationControl("settingsButton", in: app)
        waitForElement("settingsScroll", in: app)
        for id in fixed { XCTAssertTrue(homeNavigationItemIsFullyVisible(id, in: app)) }
        tapAnimationControl("tabTown", in: app)
        waitForElement("townMapScroll", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        waitForObservedValue("foodCount", "3", in: app)
        waitForObservedValue("staminaCount", "80", in: app)
        assertRoomFrame(roomFrame, in: app, context: "returning through every fixed navigation destination")
        assertHomeControlRows(in: app, stage: "redesign HUD after navigation")
        relaunchPreservingSave(app)
        waitForObservedValue("goldCount", "200", in: app)
        waitForObservedValue("foodCount", "3", in: app)
    }

    @MainActor
    func testRedesignQuickCareerSelectionAndShopCardsChargeOnceAndPersist() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--career-level10-fixture"]
        launchAndEnterHome(app)
        tapAnimationControl("tabWork", in: app)
        waitForObservedValue("workGridPage", "1/2", in: app)
        scrollCareerPage("destinationScroll", to: "workGridNext", in: app)
        tapAnimationControl("workGridNext", in: app)
        waitForObservedValue("workGridPage", "2/2", in: app)
        scrollCareerPage("destinationScroll", to: "workJobTile_job_cat_cafe_manager", in: app)
        tapAnimationControl("workJobTile_job_cat_cafe_manager", in: app)
        waitForObservedValue("selectedCareerName", "job_cat_cafe_manager", in: app)
        waitForObservedValue("workStaminaSummary", "100", in: app)
        XCTAssertFalse(element("workCountdown", in: app).exists, "Selection alone cannot charge or start work.")
        XCTAssertTrue(element("startWorkButton", in: app).isHittable)
        attachScreenshot(app, named: "Redesign — selected second-page job with fixed start button")
        tapAnimationControl("startWorkButton", in: app)
        waitForObservedValue("activeWorkDurationSeconds", "1800", in: app)
        waitForObservedValue("workStaminaSummary", "50", in: app)
        XCTAssertFalse(element("startWorkButton", in: app).exists)
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        waitForObservedValue("staminaCount", "50", in: app)
        tapAnimationControl("tabShop", in: app)
        scrollCareerPage("destinationScroll", to: "buyFoodButton", in: app)
        waitForLabel("buyFoodButton", "20 金币", in: app, contains: true)
        tapAnimationControl("buyFoodButton", in: app)
        waitForObservedValue("shopGoldCount", "180", in: app)
        scrollCareerPage("destinationScroll", to: "shopCategory_furniture", in: app)
        tapAnimationControl("shopCategory_furniture", in: app)
        scrollCareerPage("destinationScroll", to: "shopQuickBuy_potted_plant", in: app)
        waitForLabel("shopQuickBuy_potted_plant", "120 金币", in: app, contains: true)
        tapAnimationControl("shopQuickBuy_potted_plant", in: app)
        waitForObservedValue("shopGoldCount", "60", in: app)
        XCTAssertFalse(element("shopQuickBuy_potted_plant", in: app).isEnabled)
        attachScreenshot(app, named: "Redesign — direct furniture purchase with disabled insufficient-gold price")
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("foodCount", "4", in: app)
        waitForObservedValue("goldCount", "60", in: app)
        relaunchPreservingSave(app)
        waitForObservedValue("foodCount", "4", in: app)
        waitForObservedValue("goldCount", "60", in: app)
        tapAnimationControl("tabWork", in: app)
        waitForObservedValue("selectedCareerName", "job_cat_cafe_manager", in: app)
        waitForObservedValue("activeWorkDurationSeconds", "1800", in: app)
        XCTAssertFalse(element("startWorkButton", in: app).exists)
    }

    @MainActor
    func testRedesignReferenceScreensCapture() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--shop-upgrade-fixture", "--furniture-test"]
        app.launch()
        waitForWelcomeEntryReady(in: app)
        XCTAssertTrue(element("welcomeEnterButton", in: app).isEnabled)
        attachScreenshot(app, named: "Reference 01 — welcome ready")
        tapAnimationControl("welcomeEnterButton", in: app)
        waitForElement("feedButton", in: app)
        _ = waitForFurniture(in: app, description: "reference home is fully prepared", matching: {
            $0.phase == "idle" && !$0.pending
        })
        attachScreenshot(app, named: "Reference 02 — home HUD")

        tapAnimationControl("tabWork", in: app)
        waitForObservedValue("playerLevel", "4", in: app)
        attachScreenshot(app, named: "Reference 03 — work dashboard")
        XCTAssertTrue(element("startWorkButton", in: app).isHittable)
        XCTAssertTrue(element("careerChooseJobButton", in: app).isHittable)

        tapAnimationControl("tabShop", in: app)
        waitForObservedValue("shopGoldCount", "5,000", in: app)
        attachScreenshot(app, named: "Reference 05 — shop supplies")
        XCTAssertTrue(element("shopItem_premiumFood", in: app).isHittable)
        XCTAssertTrue(element("buyPremiumFoodButton", in: app).isHittable)
        XCTAssertTrue(element("shopCategory_supplies", in: app).isHittable)

        tapAnimationControl("tabTown", in: app)
        waitForElement("townMapScroll", in: app)
        waitForElement("townCollectionButton", in: app)
        attachScreenshot(app, named: "Reference 06 — town map")

        tapAnimationControl("tabInventory", in: app)
        waitForObservedValue("inventoryFoodCount", "3", in: app)
        attachScreenshot(app, named: "Reference 07 — inventory tiles")
        XCTAssertTrue(element("useFoodButton", in: app).isHittable)

        openPlayerProfile(in: app)
        tapProfileControl("profileChooseAvatar", in: app)
        tapProfilePageControl("avatarFilterFemale", scroll: "avatarPickerScroll", in: app)
        tapProfilePageControl("avatarSelect_female_scholarly", scroll: "avatarPickerScroll", in: app)
        scrollCareerPage("avatarPickerScroll", to: "avatarSelectedID", in: app)
        waitForObservedValue("avatarSelectedID", "female_scholarly", in: app)
        tapAnimationControl("profileBackButton", in: app)
        tapProfileControl("profileEquipAllButton", in: app)
        waitForObservedValue("profileEquippedCount", "4", in: app)
        returnToProfileRoot(in: app)
        scrollCareerPage("profileScroll", to: "profilePlayerName", in: app)
        attachScreenshot(app, named: "Reference 09 — profile dressing stage")
        XCTAssertTrue(element("profileAttributesButton", in: app).isHittable)

        tapAnimationControl("settingsButton", in: app)
        waitForElement("settingsScroll", in: app)
        attachScreenshot(app, named: "Reference 10 — settings groups")
        XCTAssertTrue(element("audioMusicToggle", in: app).isHittable)
        scrollCareerPage("settingsScroll", to: "settingsUpdatesRow", in: app)
        attachScreenshot(app, named: "Reference 10b — settings language and updates")
        XCTAssertTrue(element("settingsUpdatesRow", in: app).isHittable)

        tapAnimationControl("tabHome", in: app)
        tapAnimationControl("decorateButton", in: app)
        _ = waitForFurniture(in: app, description: "reference arrangement ready", matching: {
            $0.phase == "editing" && !$0.pending
        })
        attachScreenshot(app, named: "Reference 08 — room arrangement")
        XCTAssertTrue(element("layoutDoneButton", in: app).isHittable)
        XCTAssertTrue(element("layoutCancelButton", in: app).isHittable)
        tapAnimationControl("layoutCancelButton", in: app)
        waitForObservedValue("goldCount", "5,000", in: app)
        waitForObservedValue("foodCount", "3", in: app)
    }

    @MainActor
    func testRedesignReferenceWorkResultCapture() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--career-completion-fixture"]
        launchAndEnterHome(app)
        waitForObservedValue("goldCount", "260", in: app)
        tapAnimationControl("tabWork", in: app)
        waitForElement("workResultID", in: app)
        attachScreenshot(app, named: "Reference 04 — completed work receipt")
        let bar = element("homeNavigationBar", in: app)
        let actionFrames = ["careerResultHomeButton", "careerResultDoneButton"].map { identifier in
            let button = element(identifier, in: app)
            XCTAssertTrue(button.waitForExistence(timeout: 5) && button.isHittable,
                          "\(identifier) must be tappable on the result's first screen without scrolling.")
            XCTAssertTrue(app.frame.contains(button.frame))
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            XCTAssertLessThanOrEqual(button.frame.maxY, bar.frame.minY)
            return button.frame
        }
        XCTAssertLessThanOrEqual(actionFrames[0].maxY, actionFrames[1].minY)
        _ = try assertCareerResult(job: "job_flyer", gold: 60, experience: 22,
                                   levelBefore: 1, levelAfter: 2, expAfter: 12, in: app)
        scrollCareerPage("careerResultScroll", to: "careerResultDoneButton", in: app)
        attachScreenshot(app, named: "Reference 04b — work receipt return actions")
        XCTAssertTrue(element("careerResultHomeButton", in: app).isHittable)
        XCTAssertTrue(element("careerResultDoneButton", in: app).isHittable)
        tapAnimationControl("careerResultHomeButton", in: app)
        waitForObservedValue("goldCount", "260", in: app)
        waitForObservedValue("foodCount", "3", in: app)
    }


    @MainActor
    func testRedesignHUDAndArrangementTrayToggleWithoutResizingOrChangingFurniture() throws {
        continueAfterFailure = false
        let app = launchFurnitureHome()
        let roomFrame = element("roomScene", in: app).frame
        let original = furnitureState(in: app)
        waitForObservedValue("homeCareVisibilityButton", "visible", in: app)
        tapAnimationControl("homeCareVisibilityButton", in: app)
        waitForObservedValue("homeCareVisibilityButton", "hidden", in: app)
        for id in ["feedButton", "cleanButton", "playButton", "homeCatInfo", "foodCount"] {
            XCTAssertFalse(element(id, in: app).exists, "\(id) should leave the accessibility tree when care HUD is hidden.")
        }
        XCTAssertTrue(element("homeCareVisibilityButton", in: app).isHittable)
        waitForObservedValue("goldCount", "200", in: app)
        assertRoomFrame(roomFrame, in: app, context: "hiding care controls to view the floor")
        attachScreenshot(app, named: "Redesign — unobstructed room with care HUD hidden")
        tapAnimationControl("homeCareVisibilityButton", in: app)
        waitForObservedValue("homeCareVisibilityButton", "visible", in: app)
        for id in ["feedButton", "cleanButton", "playButton", "homeCatInfo"] {
            waitForElement(id, in: app)
        }
        assertRoomFrame(roomFrame, in: app, context: "restoring care controls")
        assertHomeControlRows(in: app, stage: "restored adaptive care HUD")

        tapAnimationControl("homeDecorateButton", in: app)
        _ = waitForFurniture(in: app, description: "editing before collapsing arrangement tray", matching: {
            $0.phase == "editing" && !$0.pending
        })
        waitForObservedValue("layoutTrayToggle", "expanded", in: app)
        waitForElement("selectedFurnitureName", in: app)
        tapAnimationControl("layoutTrayToggle", in: app)
        waitForObservedValue("layoutTrayToggle", "collapsed", in: app)
        for id in ["selectedFurnitureName", "storeFurnitureButton", "furnitureInventoryButton"] {
            XCTAssertFalse(element(id, in: app).exists, "Collapsed tray must not leave invisible controls accessible.")
        }
        for id in ["layoutCancelButton", "layoutDoneButton", "layoutTrayToggle"] {
            XCTAssertTrue(element(id, in: app).isHittable, "\(id) must stay reachable with the tray collapsed.")
        }
        assertRoomFrame(roomFrame, in: app, context: "collapsing the arrangement tray")
        attachScreenshot(app, named: "Redesign — collapsed arrangement tray with fixed cancel and done")
        tapAnimationControl("layoutTrayToggle", in: app)
        waitForObservedValue("layoutTrayToggle", "expanded", in: app)
        waitForElement("selectedFurnitureName", in: app)
        XCTAssertTrue(element("furnitureInventoryButton", in: app).isHittable)
        assertRoomFrame(roomFrame, in: app, context: "expanding the arrangement tray")
        tapAnimationControl("layoutTrayToggle", in: app)
        waitForObservedValue("layoutTrayToggle", "collapsed", in: app)
        tapAnimationControl("layoutCancelButton", in: app)
        let restored = waitForFurniture(in: app, description: "cancel preserves the original room after tray toggles", matching: {
            $0.phase == "idle" && !$0.pending
        })
        XCTAssertEqual(restored.items.map(\.id).sorted(), original.items.map(\.id).sorted())
        for item in original.items {
            let saved = try XCTUnwrap(restored.items.first { $0.id == item.id })
            XCTAssertEqual(saved.x, item.x, accuracy: 0.0001, "Tray visibility cannot move \(item.id).")
            XCTAssertEqual(saved.y, item.y, accuracy: 0.0001, "Tray visibility cannot move \(item.id).")
        }
        XCTAssertEqual(restored.bowl.x, original.bowl.x, accuracy: 0.0001)
        XCTAssertEqual(restored.bowl.y, original.bowl.y, accuracy: 0.0001)
        assertRoomFrame(roomFrame, in: app, context: "cancelling from the collapsed arrangement tray")
        waitForObservedValue("foodCount", "3", in: app)
        waitForObservedValue("goldCount", "200", in: app)
    }

    @MainActor
    func testArrangementCartoonShortcutsOpenBagUpgradeAndShopWithoutChangingProgress() throws {
        continueAfterFailure = false
        let app = launchFurnitureHome()
        let original = furnitureState(in: app)
        let roomFrame = element("roomScene", in: app).frame
        tapAnimationControl("homeDecorateButton", in: app)
        _ = waitForFurniture(in: app, description: "arrangement shortcuts ready") {
            $0.phase == "editing" && !$0.pending
        }
        waitForObservedValue("layoutTrayToggle", "expanded", in: app)
        attachScreenshot(app, named: "Arrangement — cartoon furniture bag, room upgrade and shop shortcuts")

        for identifier in ["furnitureInventoryButton", "homeUpgradeButton", "layoutShopButton"] {
            let shortcut = element(identifier, in: app)
            XCTAssertTrue(shortcut.isHittable)
            XCTAssertEqual(shortcut.frame.width, 70, accuracy: 1)
            XCTAssertEqual(shortcut.frame.height, 70, accuracy: 1)
            XCTAssertFalse(shortcut.label.isEmpty)
            tapAnimationControl(identifier, in: app)
            switch identifier {
            case "furnitureInventoryButton":
                waitForObservedValue("inventoryPlacedFurnitureCount", "\(original.items.count)", in: app)
                XCTAssertTrue(element("inventoryFurnitureTab", in: app).isHittable)
            case "homeUpgradeButton":
                waitForObservedValue("homeUpgradeCurrentLevel", "1", in: app)
            default:
                waitForObservedValue("shopGoldCount", "200", in: app)
                XCTAssertTrue(element("shopCategory_supplies", in: app).isHittable)
            }
            tapAnimationControl("layoutReturnButton", in: app)
            let returned = waitForFurniture(in: app, description: "return from \(identifier) preserves the arrangement") {
                $0.phase == "editing" && !$0.pending
            }
            waitForObservedValue("layoutTrayToggle", "expanded", in: app)
            XCTAssertEqual(returned.items.map(\.id).sorted(), original.items.map(\.id).sorted())
            for item in original.items {
                let unchanged = try XCTUnwrap(returned.items.first { $0.id == item.id })
                XCTAssertEqual(unchanged.x, item.x, accuracy: 0.0001)
                XCTAssertEqual(unchanged.y, item.y, accuracy: 0.0001)
                XCTAssertEqual(unchanged.orientation, item.orientation)
            }
            XCTAssertEqual(returned.bowl.x, original.bowl.x, accuracy: 0.0001)
            XCTAssertEqual(returned.bowl.y, original.bowl.y, accuracy: 0.0001)
            assertRoomFrame(roomFrame, in: app, context: "returning from \(identifier)")
            waitForObservedValue("goldCount", "200", in: app)
        }
        tapAnimationControl("layoutCancelButton", in: app)
        _ = waitForFurniture(in: app, description: "shortcut browsing leaves the room unchanged") {
            $0.phase == "idle" && !$0.pending
        }
        waitForObservedValue("foodCount", "3", in: app)
        app.terminate()
        app.launchArguments = arguments(reset: false) + ["--furniture-test"]
        launchAndEnterHome(app)
        let reopened = waitForFurniture(in: app, description: "shortcut browsing persists no layout or purchase") {
            $0.phase == "idle" && !$0.pending
        }
        XCTAssertEqual(reopened.items.map(\.id).sorted(), original.items.map(\.id).sorted())
        waitForObservedValue("goldCount", "200", in: app)
        waitForObservedValue("foodCount", "3", in: app)
    }

    @MainActor
    func testRedesignProfilePortraitAndAllFourStageSlotsRemainTappable() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        openPlayerProfile(in: app)
        tapProfileControl("profileChooseAvatar", in: app)
        tapProfilePageControl("avatarFilterFemale", scroll: "avatarPickerScroll", in: app)
        tapProfilePageControl("avatarSelect_female_scholarly", scroll: "avatarPickerScroll", in: app)
        scrollCareerPage("avatarPickerScroll", to: "avatarSelectedID", in: app)
        waitForObservedValue("avatarSelectedID", "female_scholarly", in: app)
        tapAnimationControl("profileBackButton", in: app)
        waitForObservedValue("profileAvatarName", "female_scholarly", in: app)
        scrollCareerPage("profileScroll", to: "profilePlayerName", in: app)
        attachScreenshot(app, named: "Redesign profile — full figure between four equipment slots")

        scrollCareerPage("profileScroll", to: "profileAttributesButton", in: app)
        let portrait = element("profileAttributesButton", in: app)
        XCTAssertTrue(portrait.isHittable, "The enlarged figure must retain its own attribute action.")
        XCTAssertGreaterThanOrEqual(portrait.frame.width, 44)
        XCTAssertGreaterThanOrEqual(portrait.frame.height, 44)
        tapAnimationControl("profileAttributesButton", in: app)
        waitForElement("profileAttributesSheet", in: app)
        waitForObservedValue("profileLevel", "1", in: app)
        closeProfileAttributes(in: app)

        for slot in ["head", "body", "feet", "accessory"] {
            let identifier = "profileStageSlot_\(slot)"
            scrollCareerPage("profileScroll", to: identifier, in: app)
            let button = element(identifier, in: app)
            XCTAssertTrue(button.isEnabled && button.isHittable,
                          "The enlarged figure must not cover the \(slot) equipment action.")
            XCTAssertGreaterThanOrEqual(button.frame.width, 44)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            tapAnimationControl(identifier, in: app)
            waitForElement("equipmentScroll", in: app)
            waitForObservedValue("equippedItem_\(slot)", "none", in: app)
            tapAnimationControl("profileBackButton", in: app)
            waitForElement("profileScroll", in: app)
            XCTAssertFalse(element("profileWardrobeScroll", in: app).exists,
                           "A stage slot must return directly to the profile.")
        }

        waitForObservedValue("profileAvatarName", "female_scholarly", in: app)
        scrollCareerPage("profileScroll", to: "profilePlayerName", in: app)
        attachScreenshot(app, named: "Redesign profile — figure and controls after all four slot round trips")
        closePlayerProfile(in: app)
        waitForObservedValue("goldCount", "200", in: app)
        waitForObservedValue("foodCount", "3", in: app)
    }

}
