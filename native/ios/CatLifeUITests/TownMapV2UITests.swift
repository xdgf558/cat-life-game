import XCTest

extension RoomHomeUITests {
    @MainActor
    func testTownMapNightAndLargestEnglishTypeKeepPlacesAndActionsReachable() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        let mapArguments = ["--town-night", "--town-reduce-motion"]
        app.launchArguments = arguments(reset: true) + mapArguments
        launchAndEnterHome(app)
        selectCatTestLanguage("en", in: app)
        tapAnimationControl("tabTown", in: app)
        waitForObservedValue("townPlaceDetail", "home", in: app)
        waitForObservedValue("townTimeOfDay", "night", in: app)
        waitForObservedValue("townMapCanvas", "static", in: app)
        assertTownBuildingVisible("townHomeMarker", in: app)
        attachScreenshot(app, named: "Town v2 — English night map with reduced motion")
        scrollCareerPage("townMapScroll", to: "townPlot_work", in: app)
        tapAnimationControl("townPlot_work", in: app)
        waitForObservedValue("townPlaceDetail", "work", in: app)
        assertTownBuildingVisible("townPlot_work", in: app)
        attachScreenshot(app, named: "Town v2 — northern work district at night")

        app.terminate()
        app.launchArguments = arguments(reset: false) + mapArguments
            + ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        launchAndEnterHome(app)
        tapAnimationControl("tabTown", in: app)
        waitForObservedValue("townPlaceDetail", "home", in: app)
        waitForObservedValue("townTimeOfDay", "night", in: app)
        waitForObservedValue("townMapCanvas", "static", in: app)
        assertTownBuildingVisible("townHomeMarker", in: app)
        for (marker, place, action, enabled) in [
            ("townHospitalMarker", "hospital", "townHospitalButton", true),
            ("townPlot_cafe", "cafe", "townEnter_cafe", false),
            ("townAdoptionMarker", "adoption", "townAdoptionCollectionButton", true)
        ] {
            selectTownPlaceAtVisibleCenter(marker, in: app)
            waitForObservedValue("townPlaceDetail", place, in: app)
            assertTownBuildingVisible(marker, in: app)
            let button = element(action, in: app)
            XCTAssertTrue(button.exists)
            XCTAssertEqual(button.isEnabled, enabled)
            XCTAssertGreaterThanOrEqual(button.frame.width, 44)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            XCTAssertLessThanOrEqual(button.frame.maxY, element("homeNavigationBar", in: app).frame.minY + 1,
                                    "The action must remain above the tabs at the largest accessibility size.")
            XCTAssertGreaterThanOrEqual(button.frame.minY, element("townMapToolbar", in: app).frame.maxY - 1)
            XCTAssertFalse(button.label.contains("town."), "Visible actions must use the selected language.")
            if enabled { XCTAssertTrue(button.isHittable) }
            attachScreenshot(app, named: "Town v2 — English largest text \(place) with fixed action")
        }
        tapAnimationControl("townMapFocusHome", in: app)
        waitForObservedValue("townPlaceDetail", "home", in: app)
        assertTownBuildingVisible("townHomeMarker", in: app)
        tapAnimationControl("townEnter_home", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        waitForObservedValue("foodCount", "3", in: app)
    }

    @MainActor
    private func selectTownPlaceAtVisibleCenter(_ identifier: String, in app: XCUIApplication,
                                               file: StaticString = #filePath, line: UInt = #line) {
        let scroll = element("townMapScroll", in: app)
        let marker = element(identifier, in: app)
        waitForElement("townMapScroll", in: app, file: file, line: line)
        waitForElement(identifier, in: app, file: file, line: line)
        let origin = app.coordinate(withNormalizedOffset: .zero)
        for step in 0...9 {
            let viewport = unobscuredScrollViewport(scroll, in: app)
            let center = CGPoint(x: marker.frame.midX, y: marker.frame.midY)
            if marker.isHittable, viewport.insetBy(dx: 8, dy: 8).contains(center) {
                // A player can select a partly visible building. The assertion
                // after selection still requires its complete frame to be clear
                // of the fixed panels after the map automatically centres it.
                origin.withOffset(CGVector(dx: center.x, dy: center.y)).tap()
                return
            }
            guard step < 9, viewport.height > 60 else { break }
            let distance = viewport.midY - center.y
            let magnitude = min(viewport.height * 0.6, max(36, abs(distance)))
            let delta = distance < 0 ? -magnitude : magnitude
            let start = origin.withOffset(CGVector(dx: viewport.midX, dy: viewport.midY - delta / 2))
            let end = origin.withOffset(CGVector(dx: viewport.midX, dy: viewport.midY + delta / 2))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.15)
        }
        let diagnostic = XCTAttachment(string:
            "marker=\(identifier), frame=\(marker.frame), hittable=\(marker.isHittable)\n"
            + "viewport=\(unobscuredScrollViewport(scroll, in: app))\n\n" + app.debugDescription)
        diagnostic.name = "Town selection failure — \(identifier)"
        diagnostic.lifetime = .keepAlways
        add(diagnostic)
        XCTFail("The building centre must be visible and tappable before selecting it.", file: file, line: line)
    }

    @MainActor
    private func assertTownBuildingVisible(_ identifier: String, in app: XCUIApplication,
                                          file: StaticString = #filePath, line: UInt = #line) {
        let marker = element(identifier, in: app)
        let visible = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            marker.exists && marker.isHittable
                && self.unobscuredScrollViewport(self.element("townMapScroll", in: app), in: app)
                    .insetBy(dx: -1, dy: -1).contains(marker.frame)
        }, object: nil)
        let result = XCTWaiter.wait(for: [visible], timeout: 8)
        if result != .completed {
            let scroll = element("townMapScroll", in: app)
            let controls = [identifier, "townMapScroll", "townMapToolbar", "townPlaceDetail",
                            "homeNavigationBar", "townMapFocusHome", "townHospitalButton",
                            "townEnter_cafe", "townAdoptionCollectionButton", "townMeetCatButton",
                            "townEnter_home"]
            let frames = controls.map { name in
                let control = element(name, in: app)
                guard control.exists else { return "\(name): exists=false" }
                return "\(name): exists=true, hittable=\(control.isHittable), frame=\(control.frame)"
            }
            let diagnostic = XCTAttachment(string:
                "viewport=\(unobscuredScrollViewport(scroll, in: app))\n"
                + frames.joined(separator: "\n") + "\n\n" + app.debugDescription)
            diagnostic.name = "Town focus failure — \(identifier)"
            diagnostic.lifetime = .keepAlways
            add(diagnostic)
        }
        XCTAssertEqual(result, .completed,
                       "Selecting or focusing a place must scroll its entire tappable building clear of fixed panels.",
                       file: file, line: line)
    }
}
