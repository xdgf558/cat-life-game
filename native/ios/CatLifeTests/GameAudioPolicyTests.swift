import XCTest
import AVFoundation
import CatGameCore
@testable import CatLife

final class GameAudioPolicyTests: XCTestCase {
    func testSceneAndNightChoicesRespectBoundariesAndPlayerPreferences() {
        var settings = AudioSettings()
        for hour in [0, 6, 22, 23] {
            XCTAssertEqual(GameAudioPolicy.track(.home, settings: settings, hour: hour), .night)
            XCTAssertEqual(GameAudioPolicy.track(.upstairs, settings: settings, hour: hour), .night)
            XCTAssertEqual(GameAudioPolicy.musicVolume(settings: settings, hour: hour, ducked: false), 0.245, accuracy: 0.0001)
        }
        for hour in [7, 12, 21] {
            XCTAssertEqual(GameAudioPolicy.track(.home, settings: settings, hour: hour), .home)
            XCTAssertEqual(GameAudioPolicy.track(.upstairs, settings: settings, hour: hour), .upstairs)
        }
        XCTAssertEqual(GameAudioPolicy.track(.hospital, settings: settings, hour: 23), .hospital)
        XCTAssertEqual(GameAudioPolicy.track(.sleep, settings: settings, hour: 23), .sleep)
        XCTAssertEqual(GameAudioPolicy.track(.promenade, settings: settings, hour: 23), .promenade)
        settings.nightQuiet = false
        XCTAssertEqual(GameAudioPolicy.track(.home, settings: settings, hour: 23), .home)
        XCTAssertEqual(GameAudioPolicy.track(.upstairs, settings: settings, hour: 23), .upstairs)
        XCTAssertEqual(GameAudioPolicy.musicVolume(settings: settings, hour: 23, ducked: false), 0.35, accuracy: 0.0001)
        settings.sceneMusic = false
        for scene in GameMusicTrack.allCases {
            XCTAssertEqual(GameAudioPolicy.track(scene, settings: settings, hour: 23), .home)
        }
    }

    func testCatChannelIsIndependentAndDuckingNeverOverridesVolumeChoice() {
        var settings = AudioSettings(effectsEnabled: false, catEnabled: true, catVolume: 0.8)
        XCTAssertEqual(GameAudioPolicy.effectVolume(.purchase, settings: settings), 0)
        XCTAssertEqual(GameAudioPolicy.effectVolume(.catHappy, settings: settings), 0.8, accuracy: 0.0001)
        settings.catEnabled = false
        settings.effectsEnabled = true
        XCTAssertEqual(GameAudioPolicy.effectVolume(.catCoax, settings: settings), 0)
        XCTAssertEqual(GameAudioPolicy.effectVolume(.purchase, settings: settings), 0.65, accuracy: 0.0001)
        settings.musicVolume = 0.2
        XCTAssertEqual(GameAudioPolicy.musicVolume(settings: settings, hour: 12, ducked: true), 0.1, accuracy: 0.0001)
        settings.musicVolume = 0
        XCTAssertEqual(GameAudioPolicy.musicVolume(settings: settings, hour: 23, ducked: true), 0)
    }

    func testRewardsPreemptLowPriorityEffectsButNavigationCannotInterruptACat() {
        XCTAssertEqual(GameAudioPolicy.simultaneousEffects, 3)
        XCTAssertEqual(GameAudioPolicy.replacementIndex(for: .claim, active: [.feed, .tap, .catCoax]), 1)
        XCTAssertNil(GameAudioPolicy.replacementIndex(for: .tap, active: [.catHappy, .feed, .claim]))
        XCTAssertNil(GameAudioPolicy.replacementIndex(for: .claim, active: [.claim, .levelUp, .workComplete]))
        XCTAssertNil(GameAudioPolicy.replacementIndex(for: .claim, active: [.tap]))
        XCTAssertTrue(GameSoundEffect.catPurr.ducksMusic)
        XCTAssertTrue(GameSoundEffect.claim.successHaptic)
        XCTAssertTrue(GameSoundEffect.treatDone.lightHaptic)
        XCTAssertFalse(GameSoundEffect.tap.ducksMusic)
    }

    func testEveryDeclaredRuntimeCueHasABundledResource() throws {
        XCTAssertEqual(GameMusicTrack.allCases.count, 10)
        XCTAssertEqual(GameSoundEffect.allCases.count, 35)
        let bundle = Bundle(for: GameAudioController.self)
        for name in GameMusicTrack.allCases.map(\.fileName) + GameSoundEffect.allCases.map(\.fileName) {
            XCTAssertNotNil(bundle.url(forResource: name, withExtension: "caf", subdirectory: "Audio"), name)
        }
        for track in [GameMusicTrack.promenade, .upstairs] {
            let url = try XCTUnwrap(bundle.url(forResource: track.fileName, withExtension: "caf", subdirectory: "Audio"))
            let file = try AVAudioFile(forReading: url)
            XCTAssertGreaterThan(file.length, 0)
            let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 4_096))
            try file.read(into: buffer)
            XCTAssertGreaterThan(buffer.frameLength, 0, "\(track.fileName) must contain decodable audio, not just a named file.")
        }
    }

    @MainActor
    func testHapticsRespectTheirSwitchIndependentlyOfMutedAudio() {
        let controller = GameAudioController()
        var settings = AudioSettings(musicEnabled: false, effectsEnabled: false, catEnabled: false, haptics: false)
        controller.configure(settings: settings, track: .home, foreground: true, ready: true)
        for effect in GameSoundEffect.allCases { controller.play(effect, userInitiated: true) }
        XCTAssertEqual(controller.hapticPlayCount, 0)

        settings.haptics = true
        controller.configure(settings: settings, track: .home, foreground: true, ready: true)
        controller.play(.claim)
        XCTAssertEqual(controller.hapticPlayCount, 1, "Muted effects must not disable an enabled haptic.")
        XCTAssertEqual(controller.effectPlayCount, 0)

        settings.haptics = false
        controller.configure(settings: settings, track: .home, foreground: true, ready: true)
        controller.play(.treatDone)
        controller.play(.levelUp)
        XCTAssertEqual(controller.hapticPlayCount, 1)
    }

    @MainActor
    func testRewardAndLevelUpShareOneHapticButLaterTreatmentStillResponds() async throws {
        let settings = AudioSettings(musicEnabled: false, effectsEnabled: false, catEnabled: false)
        for cues: [GameSoundEffect] in [[.levelUp, .claim], [.claim, .levelUp]] {
            let controller = GameAudioController()
            controller.configure(settings: settings, track: .home, foreground: true, ready: true)
            for cue in cues { controller.play(cue) }
            XCTAssertEqual(controller.hapticPlayCount, 1)

            try await Task.sleep(for: .milliseconds(160))
            controller.play(.tap)
            controller.play(.catPurr)
            controller.play(.treatDone)
            controller.play(.treatDone)
            XCTAssertEqual(controller.hapticPlayCount, 2, "Non-haptic cues must not consume the next feedback.")
        }
    }

    @MainActor
    func testHapticsStaySilentUntilReadyAndForeground() {
        let controller = GameAudioController()
        let settings = AudioSettings(musicEnabled: false, effectsEnabled: false, catEnabled: false)
        controller.configure(settings: settings, track: .home, foreground: false, ready: true)
        controller.play(.claim, userInitiated: true)
        controller.configure(settings: settings, track: .home, foreground: true, ready: false)
        controller.play(.treatDone, userInitiated: true)
        XCTAssertEqual(controller.hapticPlayCount, 0)

        controller.configure(settings: settings, track: .home, foreground: true, ready: true)
        controller.play(.treatDone)
        XCTAssertEqual(controller.hapticPlayCount, 1)
    }
}
