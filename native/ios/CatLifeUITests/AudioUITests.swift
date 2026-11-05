import XCTest

extension RoomHomeUITests {
    @MainActor
    func testEmbeddedSettingsInlineAudioAndLanguageKeepNavigationAndPersist() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--audio-test"]
        launchAndEnterHome(app)
        let roomFrame = element("roomScene", in: app).frame
        tapAnimationControl("settingsButton", in: app)
        waitForElement("settingsScroll", in: app)
        XCTAssertFalse(element("settingsCloseButton", in: app).exists)
        XCTAssertFalse(element("settingsBackButton", in: app).exists)
        assertFixedNavigationAvailable(in: app)
        scrollPage("settingsScroll", to: "audioMusicVolume", allowDisabled: false, maximumDrags: 6, in: app)
        let slider = app.sliders["audioMusicVolume"]
        slider.adjust(toNormalizedSliderPosition: 0.6)
        let displayed = try XCTUnwrap(slider.value as? String)
        let percent = try XCTUnwrap(Int(displayed.replacingOccurrences(of: "%", with: "")))
        XCTAssertNotEqual(percent, 35, "The inline control must perform a real volume edit.")
        let expectedVolume = Double(percent) / 100
        _ = try waitForAudio(in: app, description: "inline music volume is durably saved") {
            abs($0.musicVolume - expectedVolume) < 0.001 && $0.musicEnabled && $0.effectsEnabled
        }
        tapSettingsRootControl("audioEffectsToggle", in: app)
        _ = try waitForAudio(in: app, description: "inline effects toggle is durably saved") {
            !$0.effectsEnabled && $0.musicEnabled
        }
        tapSettingsRootControl("languageOption_en", in: app)
        assertSettingsLanguageSelection("en", in: app)
        waitForLabel("settingsLanguageTitle", "Game language", in: app)
        assertFixedNavigationAvailable(in: app)
        attachScreenshot(app, named: "Settings redesign — inline audio and language with persistent navigation")
        tapAnimationControl("tabHome", in: app)
        waitForLabel("tabHome", "Home", in: app)
        assertRoomFrame(roomFrame, in: app, context: "returning from inline settings")
        waitForObservedValue("goldCount", "200", in: app)
        waitForObservedValue("foodCount", "3", in: app)

        app.terminate()
        app.launchArguments = arguments(reset: false) + ["--audio-test"]
        launchAndEnterHome(app)
        waitForLabel("tabHome", "Home", in: app)
        _ = try waitForAudio(in: app, description: "inline settings survive cold launch") {
            abs($0.musicVolume - expectedVolume) < 0.001 && $0.musicEnabled && !$0.effectsEnabled
        }
        tapAnimationControl("settingsButton", in: app)
        assertSettingsLanguageSelection("en", in: app)
        waitForObservedValue("audioMusicVolume", displayed, in: app)
        waitForObservedValue("audioEffectsToggle", "0", in: app)
        assertFixedNavigationAvailable(in: app)
        tapAnimationControl("tabHome", in: app)
        waitForObservedValue("goldCount", "200", in: app)
        waitForObservedValue("foodCount", "3", in: app)
    }

    @MainActor
    func testAudioSettingsPersistAcrossRelaunchAndControlPlayback() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--audio-test"]
        launchAndEnterHome(app)
        assertKnownHomeViewportBaseline(in: app)
        let roomFrame = element("roomScene", in: app).frame
        let initial = try waitForAudio(in: app, description: "default home music playing") {
            $0.musicEnabled && $0.effectsEnabled && $0.musicPlaying && ["home", "night"].contains($0.currentTrack ?? "")
        }
        XCTAssertEqual(initial.musicVolume, 0.35, accuracy: 0.001)
        XCTAssertEqual(initial.effectsVolume, 0.65, accuracy: 0.001)
        XCTAssertEqual(initial.assetLoadFailures, 0)

        openAudioSettings(in: app)
        waitForObservedValue("audioMusicToggle", "1", in: app)
        waitForObservedValue("audioEffectsToggle", "1", in: app)
        waitForObservedValue("audioMusicVolume", "35%", in: app)
        waitForObservedValue("audioEffectsVolume", "65%", in: app)
        attachScreenshot(app, named: "Audio — independent music and effect controls")
        let chosenMusicVolume = try adjustAudioVolume("audioMusicVolume", toward: 0.2,
                                                       savedVolume: \.musicVolume, in: app)
        let chosenEffectsVolume = try adjustAudioVolume("audioEffectsVolume", toward: 0.4,
                                                         savedVolume: \.effectsVolume, in: app)
        XCTAssertNotEqual(chosenMusicVolume, chosenEffectsVolume)
        scrollAudioSettings(to: "audioMusicToggle", in: app)
        tapAnimationControl("audioMusicToggle", in: app)
        waitForObservedValue("audioMusicToggle", "0", in: app)
        XCTAssertFalse(element("audioMusicVolume", in: app).isEnabled)
        scrollAudioSettings(to: "audioEffectsToggle", in: app)
        tapAnimationControl("audioEffectsToggle", in: app)
        waitForObservedValue("audioEffectsToggle", "0", in: app)
        scrollAudioSettings(to: "audioPreviewButton", in: app)
        XCTAssertFalse(element("audioEffectsVolume", in: app).isEnabled)
        XCTAssertFalse(element("audioPreviewButton", in: app).isEnabled)
        scrollAudioSettings(to: "audioCatToggle", in: app)
        tapAnimationControl("audioCatToggle", in: app)
        waitForObservedValue("audioCatToggle", "0", in: app)
        attachScreenshot(app, named: "Audio — muted channels retain their independent volume preferences")
        closeAudioSettings(in: app)
        let muted = try waitForAudio(in: app, description: "saved mute preferences stop playback") {
            !$0.musicEnabled && !$0.effectsEnabled && !$0.catEnabled && !$0.musicPlaying
        }
        XCTAssertEqual(muted.musicVolume, chosenMusicVolume, accuracy: 0.001)
        XCTAssertEqual(muted.effectsVolume, chosenEffectsVolume, accuracy: 0.001)

        // This successful purchase normally plays a sound; muting must stop
        // actual player starts without suppressing the underlying game action.
        buyFoodForHomeNameProgressCheck(in: app)
        let afterPurchase = try waitForAudio(in: app, description: "muted purchase keeps audio silent") {
            !$0.effectsEnabled && !$0.musicPlaying
        }
        XCTAssertEqual(afterPurchase.effectPlayCount, muted.effectPlayCount)
        assertRoomFrame(roomFrame, in: app, context: "after changing sound settings and a muted purchase")

        app.terminate()
        app.launchArguments = arguments(reset: false) + ["--audio-test"]
        launchAndEnterHome(app)
        let reloaded = try waitForAudio(in: app, description: "muted preferences survive a genuine cold launch") {
            !$0.musicEnabled && !$0.effectsEnabled && !$0.catEnabled && !$0.musicPlaying
        }
        XCTAssertEqual(reloaded.musicVolume, chosenMusicVolume, accuracy: 0.001)
        XCTAssertEqual(reloaded.effectsVolume, chosenEffectsVolume, accuracy: 0.001)
        XCTAssertEqual(reloaded.effectPlayCount, 0,
                       "Loading or entering a saved-muted game must not start any effect.")
        waitForObservedValue("foodCount", "4", in: app)
        waitForObservedValue("goldCount", "180", in: app)

        openAudioSettings(in: app)
        waitForObservedValue("audioMusicToggle", "0", in: app)
        waitForObservedValue("audioEffectsToggle", "0", in: app)
        tapAnimationControl("audioMusicToggle", in: app)
        waitForObservedValue("audioMusicToggle", "1", in: app)
        scrollAudioSettings(to: "audioEffectsToggle", in: app)
        tapAnimationControl("audioEffectsToggle", in: app)
        waitForObservedValue("audioEffectsToggle", "1", in: app)
        scrollAudioSettings(to: "audioPreviewButton", in: app)
        tapAnimationControl("audioPreviewButton", in: app)
        _ = try waitForAudio(in: app, description: "the effects preview itself starts a real coin effect") {
            $0.lastEffect == "coins" && $0.effectPlayCount > 0
        }
        attachScreenshot(app, named: "Audio — restored preferences and playable effect preview")
        closeAudioSettings(in: app)
        let playing = try waitForAudio(in: app, description: "re-enabled music and a real preview playback") {
            $0.musicEnabled && $0.effectsEnabled && $0.musicPlaying && $0.effectPlayCount > 0
        }
        XCTAssertEqual(playing.assetLoadFailures, 0)

        XCUIDevice.shared.press(.home)
        let backgrounded = XCTNSPredicateExpectation(predicate: NSPredicate { object, _ in
            guard let application = object as? XCUIApplication else { return false }
            return application.state == .runningBackground || application.state == .runningBackgroundSuspended
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [backgrounded], timeout: 8), .completed)
        app.activate()
        waitForElement("feedButton", in: app)
        let resumed = try waitForAudio(in: app, description: "foreground music resumes after a recorded background pause") {
            $0.isForeground && $0.musicPlaying && $0.backgroundPauseCount > playing.backgroundPauseCount
        }
        XCTAssertTrue(["home", "night"].contains(resumed.currentTrack ?? ""))
        XCTAssertEqual(resumed.assetLoadFailures, 0)
        XCTAssertFalse(element("welcomeScreen", in: app).exists)
        assertRoomFrame(roomFrame, in: app, context: "after foreground audio resumes")
        waitForObservedValue("foodCount", "4", in: app)
        waitForObservedValue("goldCount", "180", in: app)
        attachScreenshot(app, named: "Audio — resumed home keeps music and saved game progress")
    }

    @MainActor
    func testColdLaunchSettlesOldWorkWithoutReplayingItsCompletionSound() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--career-completion-fixture", "--audio-test"]
        launchAndEnterHome(app)
        waitForObservedValue("goldCount", "260", in: app)
        _ = try waitForAudio(in: app, description: "enter plays normally after quiet offline settlement") {
            $0.effectsEnabled && $0.effectPlayCounts["enter", default: 0] == 1
        }
        assertWorkCompletionSoundCount(0, in: app)
        openCareerHome(in: app)
        openCareerResult(in: app)
        assertWorkCompletionSoundCount(0, in: app)
    }

    @MainActor
    func assertWorkCompletionSoundCount(_ expected: Int, in app: XCUIApplication,
                                       file: StaticString = #filePath, line: UInt = #line) {
        do {
            _ = try waitForAudio(in: app, description: "actual completion cue count is \(expected)", matching: {
                $0.effectsEnabled && $0.musicPlaying && $0.effectPlayCounts["work-complete", default: 0] == expected
            }, file: file, line: line)
        } catch {
            XCTFail("Cannot verify the real audio-player count: \(error)", file: file, line: line)
        }
    }

    @MainActor
    func testCatVoiceAndSceneOptionsAreIndependentAndPersist() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--audio-test"]
        launchAndEnterHome(app)
        openAudioSettings(in: app)
        scrollAudioSettings(to: "audioEffectsToggle", in: app)
        tapAnimationControl("audioEffectsToggle", in: app)
        _ = try waitForAudio(in: app, description: "muting effects leaves the cat channel enabled") {
            !$0.effectsEnabled && $0.catEnabled
        }
        scrollAudioSettings(to: "audioCatPreviewButton", in: app)
        tapAnimationControl("audioCatPreviewButton", in: app)
        _ = try waitForAudio(in: app, description: "cat preview plays through its independent channel") {
            $0.lastEffect == "cat-coax"
        }
        let chosen = try adjustAudioVolume("audioCatVolume", toward: 0.3, savedVolume: \.catVolume, in: app)
        for identifier in ["audioSceneMusicToggle", "audioNightQuietToggle", "audioHapticsToggle"] {
            scrollAudioSettings(to: identifier, in: app)
            tapAnimationControl(identifier, in: app)
            waitForObservedValue(identifier, "0", in: app)
        }
        _ = try waitForAudio(in: app, description: "all sound options are durable") {
            !$0.sceneMusic && !$0.nightQuiet && !$0.haptics && abs($0.catVolume - chosen) < 0.001
        }
        attachScreenshot(app, named: "Audio redesign — independent cat voice and saved playback options")
        closeAudioSettings(in: app)
        app.terminate()
        app.launchArguments = arguments(reset: false) + ["--audio-test"]
        launchAndEnterHome(app)
        _ = try waitForAudio(in: app, description: "all three channels and options survive reload") {
            !$0.effectsEnabled && $0.catEnabled && !$0.sceneMusic && !$0.nightQuiet && !$0.haptics
                && abs($0.catVolume - chosen) < 0.001 && $0.currentTrack == "home"
        }
        openCareerHome(in: app)
        _ = try waitForAudio(in: app, description: "disabled scene switching keeps the home track in Work") {
            $0.currentTrack == "home" && $0.musicPlaying
        }
    }

    @MainActor
    func testAudioTracksFollowSleepWorkAndCare() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--audio-test", "--navigation-test"]
        launchAndEnterHome(app)
        let beforeMeal = waitForNavigationPhase("idle", in: app, timeout: 15)
        let initialAudio = try waitForAudio(in: app, description: "home music before caring for the cat") {
            ["home", "night"].contains($0.currentTrack ?? "") && $0.musicPlaying
        }

        tapAnimationControl("feedButton", in: app)
        // Inspect immediately: the cat still needs to approach and lower its
        // mouth. A button-triggered eating sound would arrive too early.
        let approachingAudio = try XCTUnwrap(AudioState(value: element("audioDiagnostics", in: app).value))
        XCTAssertEqual(approachingAudio.effectPlayCounts["feed", default: 0], initialAudio.effectPlayCounts["feed", default: 0],
                          "Eating must sound at the bowl, not as soon as food is deducted.")
        let mealAudio = try waitForAudio(in: app, description: "eating sound after the cat reaches the bowl") {
            $0.effectPlayCounts["feed", default: 0] == initialAudio.effectPlayCounts["feed", default: 0] + 1
        }
        XCTAssertGreaterThan(navigationState(in: app).foodContactSamples, beforeMeal.foodContactSamples,
                             "The eating cue must coincide with actual mouth-to-food contact.")
        waitForObservedValue("foodCount", "2", in: app)
        let afterMeal = waitForNavigationPhase("idle", in: app, timeout: 35)
        XCTAssertEqual(afterMeal.completedMeals, beforeMeal.completedMeals + 1)
        waitForObservedValue("foodCount", "2", in: app)
        waitForObservedValue("catSatiety", "60", in: app)
        let settledMealAudio = try XCTUnwrap(AudioState(value: element("audioDiagnostics", in: app).value))
        XCTAssertEqual(settledMealAudio.effectPlayCounts["feed"], mealAudio.effectPlayCounts["feed"],
                       "One meal must not replay the eating cue or deduct another food item.")
        attachScreenshot(app, named: "Audio — feeding reaches the bowl and completes once")

        tapAnimationControl("cleanButton", in: app)
        _ = try waitForAudio(in: app, description: "cleaning cue from the committed care animation") {
            $0.effectPlayCounts["clean", default: 0] == mealAudio.effectPlayCounts["clean", default: 0] + 1
        }
        waitForNavigationPhase("idle", in: app, timeout: 12)

        // Use the real purchase path: the fresh save has no toy to play with.
        tapAnimationControl("playButton", in: app)
        scrollCareerPage("destinationScroll", to: "buyToyButton", in: app)
        tapAnimationControl("buyToyButton", in: app)
        waitForObservedValue("shopGoldCount", "165", in: app)
        tapAnimationControl("tabHome", in: app)
        let beforePlay = waitForNavigationPhase("idle", in: app, timeout: 10)
        let beforePlayAudio = try XCTUnwrap(AudioState(value: element("audioDiagnostics", in: app).value))
        tapAnimationControl("playButton", in: app)
        _ = try waitForAudio(in: app, description: "play cue at the cat's real pounce") {
            $0.effectPlayCounts["play", default: 0] == beforePlayAudio.effectPlayCounts["play", default: 0] + 1
        }
        let afterPlay = waitForNavigationPhase("idle", in: app, timeout: 25)
        XCTAssertEqual(afterPlay.completedPounces, beforePlay.completedPounces + 1)
        waitForObservedValue("foodCount", "2", in: app)
        waitForObservedValue("goldCount", "165", in: app)

        openCareerHome(in: app)
        _ = try waitForAudio(in: app, description: "opening Work selects its background music") {
            $0.currentTrack == "work" && $0.musicPlaying
        }
        openCareerRest(in: app)
        tapCareerRestControl("sleepStartButton", in: app)
        waitForObservedValue("sleepStatus", "asleep", in: app)
        _ = try waitForAudio(in: app, description: "sleep overrides the open Work page's music") {
            $0.currentTrack == "sleep" && $0.musicPlaying && $0.lastEffect == "sleep"
        }
        tapAnimationControl("tabHome", in: app)
        _ = try waitForAudio(in: app, description: "sleep music follows the saved activity back home") {
            $0.currentTrack == "sleep" && $0.musicPlaying
        }

        openCareerHome(in: app)
        openCareerRest(in: app)
        tapCareerRestControl("sleepWakeButton", in: app)
        waitForObservedValue("sleepStatus", "awake", in: app)
        _ = try waitForAudio(in: app, description: "waking restores the open Work page's music") {
            $0.currentTrack == "work" && $0.musicPlaying && $0.lastEffect == "wake"
        }
        closeCareerRest(in: app)
        bringWorkStartIntoView(in: app)
        tapAnimationControl("startWorkButton", in: app)
        waitForElement("workCountdown", in: app)
        _ = try waitForAudio(in: app, description: "a committed shift plays its start cue") {
            $0.currentTrack == "work" && $0.musicPlaying && $0.lastEffect == "work-start"
        }
        tapAnimationControl("tabHome", in: app)
        _ = try waitForAudio(in: app, description: "returning home selects the room track even during work") {
            ["home", "night"].contains($0.currentTrack ?? "") && $0.musicPlaying
        }
        waitForObservedValue("foodCount", "2", in: app)
        waitForObservedValue("goldCount", "165", in: app)
        waitForObservedValue("staminaCount", "70", in: app)
        attachScreenshot(app, named: "Audio — room music follows the visible location")
    }

    private struct AudioState: Decodable {
        let musicEnabled: Bool
        let effectsEnabled: Bool
        let musicVolume: Double
        let effectsVolume: Double
        let catEnabled: Bool
        let catVolume: Double
        let sceneMusic: Bool
        let nightQuiet: Bool
        let haptics: Bool
        let isForeground: Bool
        let musicPlaying: Bool
        let currentTrack: String?
        let effectPlayCount: Int
        let effectPlayCounts: [String: Int]
        let lastEffect: String
        let backgroundPauseCount: Int
        let assetLoadFailures: Int

        init?(value: Any?) {
            guard let text = value as? String, let data = text.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode(Self.self, from: data) else { return nil }
            self = decoded
        }
    }

    @MainActor
    private func openAudioSettings(in app: XCUIApplication) {
        tapAnimationControl("settingsButton", in: app)
        tapSettingsRootControl("settingsAudioRow", in: app)
        waitForElement("audioMusicToggle", in: app)
    }

    @MainActor
    private func closeAudioSettings(in app: XCUIApplication) {
        tapAnimationControl("settingsBackButton", in: app)
        tapAnimationControl("tabHome", in: app)
        waitForElement("feedButton", in: app)
    }

    @MainActor
    private func scrollAudioSettings(to identifier: String, in app: XCUIApplication) {
        scrollPage("audioSettingsScroll", to: identifier, allowDisabled: true, maximumDrags: 6, in: app)
    }

    @MainActor
    private func adjustAudioVolume(_ identifier: String, toward position: CGFloat,
                                    savedVolume: KeyPath<AudioState, Double>, in app: XCUIApplication,
                                    file: StaticString = #filePath, line: UInt = #line) throws -> Double {
        scrollAudioSettings(to: identifier, in: app)
        let slider = app.sliders[identifier]
        let previousText = try XCTUnwrap(slider.value as? String, file: file, line: line)
        let previousPercent = try XCTUnwrap(Int(previousText.replacingOccurrences(of: "%", with: "")),
                                           file: file, line: line)
        let frame = slider.frame
        XCTAssertGreaterThan(frame.width, 44, "A usable volume track must be visible", file: file, line: line)
        // The narrowed A1 track once ignored XCTest's normalized adjustment.
        // Its cause is unconfirmed; exercise a visible thumb drag and retain coordinates as evidence.
        let thumbInset = min(16, frame.height / 2)
        let travel = frame.width - thumbInset * 2
        let origin = slider.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
        let start = origin.withOffset(CGVector(dx: thumbInset + travel * CGFloat(previousPercent) / 100, dy: 0))
        let end = origin.withOffset(CGVector(dx: thumbInset + travel * position, dy: 0))
        start.press(forDuration: 0.15, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.15)
        if slider.value as? String == previousText {
            let changed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                slider.value as? String != previousText
            }, object: slider)
            _ = XCTWaiter.wait(for: [changed], timeout: 3)
        }
        let displayed = try XCTUnwrap(slider.value as? String, file: file, line: line)
        let gesture = XCTAttachment(string: "Frame: \(frame); start: \(start.screenPoint); end: \(end.screenPoint); before: \(previousText); after: \(displayed)")
        gesture.name = "Audio slider gesture — \(identifier)"
        gesture.lifetime = .keepAlways
        add(gesture)
        if displayed == previousText {
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Audio slider unchanged — \(identifier)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
        let percent = try XCTUnwrap(Int(displayed.replacingOccurrences(of: "%", with: "")),
                                   "Slider must expose its selected percentage", file: file, line: line)
        XCTAssertNotEqual(displayed, previousText, "A real drag must change the volume", file: file, line: line)
        XCTAssertTrue((5...95).contains(percent), "Select a nontrivial volume, not an endpoint", file: file, line: line)
        let chosen = Double(percent) / 100
        // XCTest's normalized drag lands on different stepped values across
        // runtimes. The contract is that the displayed user selection is the
        // one committed, muted without loss, and restored on a cold launch.
        _ = try waitForAudio(in: app, description: "\(identifier) saves the displayed \(displayed)", matching: {
            abs($0[keyPath: savedVolume] - chosen) < 0.001 && slider.isEnabled
        }, file: file, line: line)
        let evidence = XCTAttachment(string: "Before: \(previousText); after real drag: \(displayed); saved: \(chosen)")
        evidence.name = "Audio slider — \(identifier) displayed selection matches the persisted preference"
        evidence.lifetime = .keepAlways
        add(evidence)
        return chosen
    }

    @MainActor
    private func waitForAudio(in app: XCUIApplication, description: String,
                              matching condition: @escaping (AudioState) -> Bool,
                              file: StaticString = #filePath, line: UInt = #line) throws -> AudioState {
        let target = element("audioDiagnostics", in: app)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { object, _ in
            guard let value = object as? XCUIElement, value.exists,
                  let state = AudioState(value: value.value) else { return false }
            return state.assetLoadFailures > 0 || condition(state)
        }, object: target)
        let result = XCTWaiter.wait(for: [ready], timeout: 15)
        if result != .completed {
            let evidence = XCTAttachment(string: app.debugDescription)
            evidence.name = "Audio diagnostics — \(description)"
            evidence.lifetime = .keepAlways
            add(evidence)
        }
        XCTAssertEqual(result, .completed, "Expected \(description); got \(String(describing: target.value))",
                       file: file, line: line)
        let state = try XCTUnwrap(AudioState(value: target.value),
                                  "Missing decodable audio diagnostics", file: file, line: line)
        XCTAssertEqual(state.assetLoadFailures, 0, "Every requested bundled sound must load", file: file, line: line)
        return state
    }
}
