import XCTest

extension RoomHomeUITests {
    @MainActor
    func testSaveManagementPreparesExportAndPreservesProgressWhenLeaving() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        let gold = try XCTUnwrap(element("goldCount", in: app).value as? String)
        let food = try XCTUnwrap(element("foodCount", in: app).value as? String)
        tapAnimationControl("settingsButton", in: app)
        tapSettingsRootControl("settingsSaveManagementRow", in: app)
        waitForElement("saveManagementScroll", in: app)
        waitForElement("saveCurrentSummary", in: app)
        attachScreenshot(app, named: "Save design S1 — current progress and backup actions")
        waitForLabel("saveExportButton", "制作备份", in: app, contains: true)
        scrollSaveManagement(to: "saveExportButton", in: app)
        tapAnimationControl("saveExportButton", in: app)
        waitForElement("saveExportPrepared", in: app)
        scrollSaveManagement(to: "saveExportShareButton", in: app)
        XCTAssertTrue(element("saveExportFilesButton", in: app).exists)
        XCTAssertTrue(element("saveExportShareButton", in: app).isHittable)
        attachScreenshot(app, named: "Save management — prepared iOS backup with Files and Share actions")
        scrollSaveManagement(to: "saveRecoveryCard", in: app)
        XCTAssertFalse(element("saveRecoveryButton", in: app).exists,
                       "Exporting must not create a before-import recovery point.")
        tapAnimationControl("settingsBackButton", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForElement("goldCount", in: app)
        XCTAssertEqual(element("goldCount", in: app).value as? String, gold)
        XCTAssertEqual(element("foodCount", in: app).value as? String, food)
    }

    @MainActor
    func testSaveManagementSystemFilePanelsCancelWithoutChangingProgress() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        let gold = try XCTUnwrap(element("goldCount", in: app).value as? String)
        let food = try XCTUnwrap(element("foodCount", in: app).value as? String)
        tapAnimationControl("settingsButton", in: app)
        tapSettingsRootControl("settingsSaveManagementRow", in: app)
        scrollSaveManagement(to: "saveImportButton", in: app)
        tapAnimationControl("saveImportButton", in: app)
        cancelSystemSaveFilePanel(app, screenshot: "Save management — native Files import picker")
        XCTAssertFalse(element("saveImportPreview", in: app).exists)
        XCTAssertFalse(element("saveRecoveryButton", in: app).exists)

        scrollSaveManagement(to: "saveExportButton", in: app)
        tapAnimationControl("saveExportButton", in: app)
        waitForElement("saveExportPrepared", in: app)
        scrollSaveManagement(to: "saveExportFilesButton", in: app)
        tapAnimationControl("saveExportFilesButton", in: app)
        cancelSystemSaveFilePanel(app, screenshot: "Save management — native Files export panel")
        scrollSaveManagement(to: "saveRecoveryCard", in: app)
        XCTAssertFalse(element("saveRecoveryButton", in: app).exists)
        waitForLabel("saveTransferStatus", "当前进度未更改", in: app, contains: true)
        tapAnimationControl("settingsBackButton", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", gold, in: app)
        waitForObservedValue("foodCount", food, in: app)
    }

    @MainActor
    private func cancelSystemSaveFilePanel(_ app: XCUIApplication, screenshot: String,
                                           file: StaticString = #filePath, line: UInt = #line) {
        // Use one stable query: enumerating every system bar repeatedly can
        // stall snapshots while the document provider is still launching.
        let bar = app.navigationBars.matching(NSPredicate(format: "NOT (identifier IN %@)",
            ["存档管理", "存檔管理", "Save management"])).firstMatch
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard bar.exists else { return false }
            let frame = bar.frame
            return frame.width > 0 && frame.height > 0
        }, object: nil)
        let appeared = XCTWaiter.wait(for: [ready], timeout: 90)
        attachScreenshot(app, named: screenshot)
        XCTAssertEqual(appeared, .completed, app.debugDescription, file: file, line: line)
        bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)))
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: bar)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 10), .completed, file: file, line: line)
        waitForElement("saveManagementScroll", in: app, file: file, line: line)
    }

    @MainActor
    func testSaveManagementRealFilesRoundTripAndRecoveryPreview() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        let gold = try XCTUnwrap(element("goldCount", in: app).value as? String)
        let food = try XCTUnwrap(element("foodCount", in: app).value as? String)
        let filename = try exportNativeBackupToFiles(in: app)

        chooseNativeBackup(named: filename, in: app)
        waitForElement("saveImportPreview", in: app)
        assertUnacknowledgedSavePreview(in: app)
        attachScreenshot(app, named: "Save management — real exported file preview before replacement")
        acknowledgeSaveReplacement(in: app)
        attachScreenshot(app, named: "Save design S4 — acknowledgement enables replacement")
        tapSavePreviewControl("saveCancelImportButton", in: app)
        XCTAssertFalse(element("saveRecoveryButton", in: app).exists,
                       "Preview cancellation must not replace progress or create a recovery point.")
        chooseNativeBackup(named: filename, in: app)
        waitForElement("saveImportPreview", in: app)
        assertUnacknowledgedSavePreview(in: app)
        acknowledgeSaveReplacement(in: app)
        tapSavePreviewControl("saveConfirmImportButton", in: app)
        waitForElement("saveImportSuccess", in: app)
        attachScreenshot(app, named: "Save design S6 — imported progress and recovery point")
        tapSavePreviewControl("saveStayManagementButton", in: app)
        // A subsequent file import would replace the single recovery point.
        // The confirmation must disclose that point before any write occurs.
        chooseNativeBackup(named: filename, in: app)
        waitForElement("saveRecoveryReplacementWarning", in: app)
        waitForLabel("saveExistingRecoverySummary", "等级 1 · 1 只猫咪", in: app, contains: true)
        waitForElement("saveExistingRecoveryTime", in: app)
        assertUnacknowledgedSavePreview(in: app)
        attachScreenshot(app, named: "Save management — existing recovery point replacement disclosed")
        tapSavePreviewControl("saveCancelImportButton", in: app)
        scrollSaveManagement(to: "saveRecoveryButton", in: app)
        tapAnimationControl("saveRecoveryButton", in: app)
        waitForElement("saveImportPreview", in: app)
        waitForLabel("saveConfirmImportButton", "恢复这份进度", in: app, contains: true)
        assertUnacknowledgedSavePreview(in: app)
        attachScreenshot(app, named: "Save management — pre-import recovery point confirmation")
        acknowledgeSaveReplacement(in: app)
        tapSavePreviewControl("saveConfirmImportButton", in: app)
        waitForElement("saveImportSuccess", in: app)
        tapSavePreviewControl("saveReturnHomeButton", in: app)
        waitForObservedValue("goldCount", gold, in: app)
        waitForObservedValue("foodCount", food, in: app)
    }

    @MainActor
    func testWelcomeFailedSaveOffersImportOnlyAndCancelPreservesFailure() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        for fixture in ["--save-load-damaged-fixture", "--save-load-future-fixture"] {
            app.launchArguments = arguments(reset: true) + [fixture]
            app.launch()
            waitForElement("welcomeLoadError", in: app)
            if fixture == "--save-load-future-fixture" {
                waitForElement("welcomeUpdateButton", in: app)
            } else {
                XCTAssertFalse(element("welcomeUpdateButton", in: app).exists)
                waitForElement("welcomeRetryButton", in: app)
                tapAnimationControl("welcomeRetryButton", in: app)
                waitForElement("welcomeLoadError", in: app)
            }
            attachScreenshot(app, named: "Welcome design W1 — failure " + fixture)
            tapWelcomeRestoreButton(in: app)
            waitForElement("saveImportButton", in: app)
            XCTAssertFalse(element("saveExportButton", in: app).exists)
            XCTAssertFalse(element("saveRecoveryButton", in: app).exists)
            XCTAssertFalse(element("saveCurrentSummary", in: app).exists)
            attachScreenshot(app, named: "Welcome save recovery — import-only " + fixture)
            tapAnimationControl("saveRecoveryDismissButton", in: app)
            waitForElement("welcomeLoadError", in: app)
            XCTAssertFalse(element("welcomeEnterButton", in: app).exists)
            app.terminate()
            app.launchArguments = arguments(reset: false)
            app.launch()
            waitForElement("welcomeLoadError", in: app)
            XCTAssertFalse(element("welcomeEnterButton", in: app).exists,
                           "Cancelling recovery must not reset or replace the damaged/newer save.")
            app.terminate()
        }
    }

    @MainActor
    func testWelcomeRestoresARealFilesBackupAfterDamagedSave() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        let gold = try XCTUnwrap(element("goldCount", in: app).value as? String)
        let food = try XCTUnwrap(element("foodCount", in: app).value as? String)
        let filename = try exportNativeBackupToFiles(in: app)
        app.terminate()
        app.launchArguments = arguments(reset: true) + ["--save-load-damaged-fixture"]
        app.launch()
        waitForElement("welcomeLoadError", in: app)
        tapWelcomeRestoreButton(in: app)
        chooseNativeBackup(named: filename, in: app)
        waitForElement("saveFailureRawPreservationNotice", in: app)
        XCTAssertFalse(element("saveExistingRecoverySummary", in: app).exists)
        assertUnacknowledgedSavePreview(in: app)
        acknowledgeSaveReplacement(in: app)
        attachScreenshot(app, named: "Welcome save recovery — raw preservation explained before confirmation")
        tapSavePreviewControl("saveCancelImportButton", in: app)
        tapAnimationControl("saveRecoveryDismissButton", in: app)
        waitForElement("welcomeLoadError", in: app)

        tapWelcomeRestoreButton(in: app)
        chooseNativeBackup(named: filename, in: app)
        assertUnacknowledgedSavePreview(in: app)
        acknowledgeSaveReplacement(in: app)
        tapSavePreviewControl("saveConfirmImportButton", in: app)
        let entry = element("welcomeEnterButton", in: app)
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND enabled == true"), object: entry)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 45), .completed, app.debugDescription)
        XCTAssertFalse(element("welcomeLoadError", in: app).exists)
        waitForElement("welcomeRecoverySuccess", in: app)
        waitForElement("welcomeRecoverySummary", in: app)
        XCTAssertFalse(element("feedButton", in: app).exists,
                       "Successful recovery must still wait for the player's Enter action.")
        attachScreenshot(app, named: "Welcome save recovery — recovered and waiting to enter home")
        tapAnimationControl("welcomeEnterButton", in: app)
        waitForObservedValue("goldCount", gold, in: app)
        waitForObservedValue("foodCount", food, in: app)
        relaunchPreservingSave(app)
        waitForObservedValue("goldCount", gold, in: app)
        waitForObservedValue("foodCount", food, in: app)
    }

    @MainActor
    func testFutureOriginalCanBeExportedThroughFilesAfterStartupRecovery() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        let gold = try XCTUnwrap(element("goldCount", in: app).value as? String)
        let food = try XCTUnwrap(element("foodCount", in: app).value as? String)
        let backup = try exportNativeBackupToFiles(in: app)
        app.terminate()
        app.launchArguments = arguments(reset: true) + ["--save-load-future-fixture"]
        app.launch()
        waitForElement("welcomeLoadError", in: app)
        tapWelcomeRestoreButton(in: app)
        chooseNativeBackup(named: backup, in: app)
        waitForElement("saveFailureRawPreservationNotice", in: app)
        acknowledgeSaveReplacement(in: app)
        tapSavePreviewControl("saveConfirmImportButton", in: app)
        let entry = element("welcomeEnterButton", in: app)
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND enabled == true"), object: entry)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 45), .completed, app.debugDescription)
        XCTAssertFalse(element("feedButton", in: app).exists)
        tapAnimationControl("welcomeEnterButton", in: app)
        waitForObservedValue("goldCount", gold, in: app)
        waitForObservedValue("foodCount", food, in: app)
        tapAnimationControl("settingsButton", in: app)
        tapSettingsRootControl("settingsSaveManagementRow", in: app)
        scrollSaveManagement(to: "savePreservedTitle", in: app)
        let exportButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "savePreservedExportButton_"))
        XCTAssertEqual(exportButtons.count, 2, "Keep both newer primary and automatic backup reachable.")
        let exportID = exportButtons.firstMatch.identifier
        scrollSaveManagement(to: exportID, in: app)
        attachScreenshot(app, named: "Save management — newer originals retained with export actions")
        tapAnimationControl(exportID, in: app)
        let original = try savePresentedBackupToFiles(in: app,
            statusIdentifier: "savePreservedExportStatus", defaultFilename: "CatLife-Preserved")
        chooseNativeBackup(named: original, in: app)
        waitForLabel("saveImportErrorTitle", "这份备份来自更新的版本", in: app, contains: true)
        waitForLabel("saveImportErrorSafety", "当前进度未更改", in: app, contains: true)
        XCTAssertFalse(element("saveConfirmImportButton", in: app).exists)
        attachScreenshot(app, named: "Save management — exported newer original remains version-gated")
        tapSavePreviewControl("saveErrorCloseButton", in: app)
        tapAnimationControl("settingsBackButton", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", gold, in: app)
        waitForObservedValue("foodCount", food, in: app)
    }

    @MainActor
    func testSavePreviewRemainsUsableAtAccessibilityTextSize() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true)
            + ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        waitForElement("welcomeEnterButton", in: app)
        bringIntoView("welcomeEnterButton", in: app)
        waitForWelcomeEntryReady(in: app)
        tapAnimationControl("welcomeEnterButton", in: app)
        waitForElement("feedButton", in: app)
        let gold = try XCTUnwrap(element("goldCount", in: app).value as? String)
        let filename = try exportNativeBackupToFiles(in: app)
        chooseNativeBackup(named: filename, in: app)
        waitForElement("saveImportPreview", in: app)
        assertUnacknowledgedSavePreview(in: app)
        attachScreenshot(app, named: "Save design — accessibility text comparison before scrolling")
        scrollPage("saveImportPreview", to: "saveComparison_saveTransfer.stat.level",
                   allowDisabled: true, maximumDrags: 24, requiresHitPoint: false, in: app)
        attachScreenshot(app, named: "Save design — accessibility text complete level comparison")
        acknowledgeSaveReplacement(in: app)
        attachScreenshot(app, named: "Save design — accessibility text acknowledgement and actions")
        tapSavePreviewControl("saveCancelImportButton", in: app)
        waitForLabel("saveTransferStatus", "当前进度未更改", in: app, contains: true)
        tapAnimationControl("settingsBackButton", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", gold, in: app)
    }

    @MainActor
    func testSaveManagementInvalidFilesShowSafetyAndCanChooseAgain() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        let gold = try XCTUnwrap(element("goldCount", in: app).value as? String)
        let food = try XCTUnwrap(element("foodCount", in: app).value as? String)
        tapAnimationControl("settingsButton", in: app)
        tapSettingsRootControl("settingsSaveManagementRow", in: app)
        scrollSaveManagement(to: "saveImportButton", in: app)
        tapAnimationControl("saveImportButton", in: app)
        // This integration fixture is placed in the isolated simulator's Files
        // provider by the host QA runner, never in a player's save directory.
        let filename = "CatLife-QA-invalid-build48"
        let item = app.descendants(matching: .any).matching(NSPredicate(
            format: "label CONTAINS %@ AND (elementType == %d OR elementType == %d)",
            filename, XCUIElement.ElementType.cell.rawValue, XCUIElement.ElementType.staticText.rawValue)).firstMatch
        if !item.waitForExistence(timeout: 5) {
            // A host-created file is not necessarily indexed in Recents. Use
            // the real local Files location rather than assuming that index.
            let browse = app.buttons.matching(NSPredicate(format: "label IN %@",
                ["浏览", "瀏覽", "Browse"])).firstMatch
            if browse.waitForExistence(timeout: 10), browse.isHittable { browse.tap() }
            let local = app.descendants(matching: .any).matching(NSPredicate(
                format: "label IN %@ AND (elementType == %d OR elementType == %d)",
                ["我的iPhone", "我的 iPhone", "On My iPhone"], XCUIElement.ElementType.cell.rawValue,
                XCUIElement.ElementType.staticText.rawValue)).firstMatch
            if !local.waitForExistence(timeout: 3), browse.exists, browse.isHittable { browse.tap() }
            if local.waitForExistence(timeout: 10), local.isHittable { local.tap() }
        }
        attachScreenshot(app, named: "Save design — locating the host-provided invalid file in local Files")
        XCTAssertTrue(item.waitForExistence(timeout: 30),
                      "The isolated simulator's local Files fixture must be installed and reachable.\n" + app.debugDescription)
        XCTAssertTrue(item.isHittable)
        item.tap()
        waitForElement("saveImportErrorTitle", in: app)
        waitForLabel("saveImportErrorSafety", "当前进度未更改", in: app, contains: true)
        XCTAssertFalse(element("saveConfirmImportButton", in: app).exists)
        attachScreenshot(app, named: "Save design S7 — invalid file with unchanged-progress reassurance")
        tapSavePreviewControl("saveErrorChooseAgainButton", in: app)
        cancelSystemSaveFilePanel(app, screenshot: "Save design — choose again returns to native Files")
        XCTAssertFalse(element("saveRecoveryButton", in: app).exists)
        tapAnimationControl("settingsBackButton", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", gold, in: app)
        waitForObservedValue("foodCount", food, in: app)
    }

    @MainActor
    private func scrollSaveManagement(to identifier: String, in app: XCUIApplication,
                                      file: StaticString = #filePath, line: UInt = #line) {
        // At the largest accessible size, the backup card spans several screens.
        scrollPage("saveManagementScroll", to: identifier, allowDisabled: true, maximumDrags: 24,
                   in: app, file: file, line: line)
    }

    @MainActor
    private func tapWelcomeRestoreButton(in app: XCUIApplication) {
        waitForElement("welcomeRestoreBackupButton", in: app)
        if !element("welcomeRestoreBackupButton", in: app).isHittable {
            app.scrollViews.firstMatch.swipeUp()
        }
        tapAnimationControl("welcomeRestoreBackupButton", in: app)
    }

    @MainActor
    private func exportNativeBackupToFiles(in app: XCUIApplication) throws -> String {
        tapAnimationControl("settingsButton", in: app)
        tapSettingsRootControl("settingsSaveManagementRow", in: app)
        scrollSaveManagement(to: "saveExportButton", in: app)
        tapAnimationControl("saveExportButton", in: app)
        waitForElement("saveExportPrepared", in: app)
        let filenameText = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@",
            "CatLife-Backup-[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}\\.json")).firstMatch
        XCTAssertTrue(filenameText.exists, app.debugDescription)
        let defaultFilename = (filenameText.label as NSString).deletingPathExtension
        scrollSaveManagement(to: "saveExportFilesButton", in: app)
        tapAnimationControl("saveExportFilesButton", in: app)
        return try savePresentedBackupToFiles(in: app, defaultFilename: defaultFilename)
    }

    @MainActor
    private func savePresentedBackupToFiles(in app: XCUIApplication,
                                            statusIdentifier: String = "saveTransferStatus",
                                            defaultFilename: String) throws -> String {
        var filename = "CatLife-QA-" + String(UUID().uuidString.prefix(8))
        let save = app.buttons.matching(NSPredicate(
            format: "identifier == %@ OR label IN %@", "DOCPicker.actionButton",
            ["保存", "儲存", "Save"])).firstMatch
        let exportReady = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND enabled == true AND hittable == true"), object: save)
        let exportReadyResult = XCTWaiter.wait(for: [exportReady], timeout: 90)
        attachScreenshot(app, named: "Save management — system Files export presentation")
        XCTAssertEqual(exportReadyResult, .completed, app.debugDescription)
        let nameField = app.textFields["DOCPicker.filenameTextField"]
        if nameField.waitForExistence(timeout: 3) {
            let previousName = try XCTUnwrap(nameField.value as? String)
            if defaultFilename.hasPrefix("CatLife-Backup-") {
                XCTAssertTrue(previousName == defaultFilename || previousName == defaultFilename + ".json",
                              "The Files default must match the prepared dated backup: " + previousName)
            }
            nameField.tap()
            nameField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previousName.count) + filename)
        } else {
            // Some system layouts omit the name editor and use our supplied
            // default. This isolated simulator's file is owned by this QA flow.
            filename = defaultFilename
        }
        XCTAssertTrue(save.isEnabled && save.isHittable, app.debugDescription)
        attachScreenshot(app, named: "Save management — saving an owned QA backup through Files")
        save.tap()
        let exportStatus = element(statusIdentifier, in: app)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let replacePredicate = NSPredicate(format: "label IN %@", ["替换", "取代", "Replace"])
        let systemReplace = springboard.buttons.matching(replacePredicate).firstMatch
        let actionFinished = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.alerts.firstMatch.exists || springboard.alerts.firstMatch.exists
                || systemReplace.exists || exportStatus.exists
        }, object: nil)
        let actionResult = XCTWaiter.wait(for: [actionFinished], timeout: 60)
        if actionResult != .completed {
            attachScreenshot(app, named: "Save management — export completion or replacement alert timeout")
            let hierarchy = XCTAttachment(string: "APP\n" + app.debugDescription
                + "\nSPRINGBOARD\n" + springboard.debugDescription)
            hierarchy.name = "Files export completion timeout hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
        XCTAssertEqual(actionResult, .completed, app.debugDescription + "\n" + springboard.debugDescription)
        let replacementPrompt: XCUIElement?
        if app.alerts.firstMatch.exists { replacementPrompt = app.alerts.firstMatch }
        else if springboard.alerts.firstMatch.exists { replacementPrompt = springboard.alerts.firstMatch }
        else if systemReplace.exists { replacementPrompt = springboard }
        else { replacementPrompt = nil }
        if let replacementPrompt {
            let text = replacementPrompt.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " ")
            XCTAssertTrue(text.contains(filename), "Only replace this test's own named backup: " + text)
            let replace = replacementPrompt.buttons.matching(replacePredicate).firstMatch
            XCTAssertTrue(replace.exists && replace.isHittable, replacementPrompt.debugDescription)
            replace.tap()
        }
        // The Save control can disappear before a same-name replacement alert
        // appears. Only the app's actual export completion confirms the write.
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard exportStatus.exists else { return false }
            return exportStatus.label.contains("备份文件已保存")
        }, object: nil)
        let savedResult = XCTWaiter.wait(for: [saved], timeout: 30)
        if savedResult != .completed {
            attachScreenshot(app, named: "Save management — fileExporter success callback timeout")
            let hierarchy = XCTAttachment(string: "APP\n" + app.debugDescription
                + "\nSPRINGBOARD\n" + springboard.debugDescription)
            hierarchy.name = "Files export callback timeout hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
        XCTAssertEqual(savedResult, .completed, app.debugDescription)
        scrollSaveManagement(to: statusIdentifier, in: app)
        return filename
    }

    @MainActor
    private func chooseNativeBackup(named filename: String, in app: XCUIApplication,
                                    file: StaticString = #filePath, line: UInt = #line) {
        scrollSaveManagement(to: "saveImportButton", in: app)
        tapAnimationControl("saveImportButton", in: app)
        let item = app.descendants(matching: .any).matching(NSPredicate(
            format: "label CONTAINS %@ AND (elementType == %d OR elementType == %d)",
            filename, XCUIElement.ElementType.cell.rawValue, XCUIElement.ElementType.staticText.rawValue)).firstMatch
        let appeared = item.waitForExistence(timeout: 45)
        attachScreenshot(app, named: "Save management — finding own exported file in system picker")
        XCTAssertTrue(appeared, app.debugDescription, file: file, line: line)
        XCTAssertTrue(item.isHittable, file: file, line: line)
        item.tap()
    }

    @MainActor
    private func tapSavePreviewControl(_ identifier: String, in app: XCUIApplication,
                                       file: StaticString = #filePath, line: UInt = #line) {
        let target = element(identifier, in: app)
        waitForElement(identifier, in: app, file: file, line: line)
        for _ in 0..<6 where !target.isHittable {
            let sheet = app.scrollViews.containing(.button, identifier: identifier).firstMatch
            sheet.swipeUp()
        }
        tapAnimationControl(identifier, in: app, file: file, line: line)
    }

    @MainActor
    private func assertUnacknowledgedSavePreview(in app: XCUIApplication,
                                                 file: StaticString = #filePath, line: UInt = #line) {
        waitForElement("saveImportAcknowledgement", in: app, file: file, line: line)
        waitForObservedValue("saveImportAcknowledgement", "0", in: app, file: file, line: line)
        XCTAssertFalse(element("saveConfirmImportButton", in: app).isEnabled,
                       "Each new preview requires its own explicit replacement acknowledgement.",
                       file: file, line: line)
    }

    @MainActor
    private func acknowledgeSaveReplacement(in app: XCUIApplication,
                                             file: StaticString = #filePath, line: UInt = #line) {
        tapSavePreviewControl("saveImportAcknowledgement", in: app, file: file, line: line)
        waitForObservedValue("saveImportAcknowledgement", "1", in: app, file: file, line: line)
        XCTAssertTrue(element("saveConfirmImportButton", in: app).isEnabled,
                      file: file, line: line)
    }

    @MainActor
    func testSaveManagementLocalizesInAllThreeLanguages() throws {
        continueAfterFailure = false
        let app = launchFreshHome()
        tapAnimationControl("settingsButton", in: app)
        for (language, title, export) in [("zh-Hans", "存档管理", "制作备份"),
                                           ("en", "Save management", "Prepare backup"),
                                           ("zh-Hant", "存檔管理", "製作備份")] {
            tapSettingsRootControl("languageOption_" + language, in: app)
            assertSettingsLanguageSelection(language, in: app)
            tapSettingsRootControl("settingsSaveManagementRow", in: app)
            waitForLabel("saveManagementTitle", title, in: app, contains: true)
            waitForLabel("saveExportButton", export, in: app, contains: true)
            scrollSaveManagement(to: "saveRecoveryCard", in: app)
            attachScreenshot(app, named: "Save management — " + language)
            tapAnimationControl("settingsBackButton", in: app)
        }
    }
}
