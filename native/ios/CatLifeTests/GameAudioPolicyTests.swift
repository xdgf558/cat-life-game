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
            XCTAssertEqual(GameAudioPolicy.track(.work, settings: settings, hour: hour), .work)
        }
        XCTAssertEqual(GameAudioPolicy.track(.work, settings: settings, hour: 23), .work)
        settings.nightQuiet = false
        XCTAssertEqual(GameAudioPolicy.track(.home, settings: settings, hour: 23), .home)
        settings.sceneMusic = false
        for track in GameMusicTrack.allCases {
            XCTAssertEqual(GameAudioPolicy.track(track, settings: settings, hour: 23), .home)
        }
    }

    func testEveryDeclaredRuntimeAudioFileExistsAndDecodes() throws {
        XCTAssertEqual(GameMusicTrack.allCases.count, 11)
        XCTAssertEqual(GameSoundEffect.allCases.count, 10)
        let bundle = Bundle(for: GameAudioController.self)
        for track in GameMusicTrack.allCases {
            let url = try XCTUnwrap(
                bundle.url(forResource: track.fileName, withExtension: track.fileExtension, subdirectory: "Audio"),
                "Missing music \(track.fileName)"
            )
            let file = try AVAudioFile(forReading: url)
            XCTAssertGreaterThan(file.length, 0)
        }
        for effect in GameSoundEffect.allCases {
            let url = try XCTUnwrap(
                bundle.url(forResource: effect.fileName, withExtension: effect.fileExtension, subdirectory: "Audio"),
                "Missing SFX \(effect.fileName)"
            )
            let file = try AVAudioFile(forReading: url)
            XCTAssertGreaterThan(file.length, 0)
        }
    }

    @MainActor
    func testAdPauseSilencesEffectsAndHapticsUntilResumed() {
        let controller = GameAudioController()
        let settings = AudioSettings(musicEnabled: false, effectsEnabled: false, catEnabled: false, haptics: true)
        controller.configure(settings: settings, track: .home, foreground: true, ready: true)

        controller.setAdPaused(true)
        controller.play(.coins, userInitiated: true)
        XCTAssertEqual(controller.hapticPlayCount, 0)

        controller.setAdPaused(false)
        controller.play(.coins, userInitiated: true)
        XCTAssertEqual(controller.hapticPlayCount, 1)
    }
}
