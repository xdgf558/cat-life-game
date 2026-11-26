import XCTest
@testable import CatGameCore

final class GameSettingsTests: XCTestCase {
    func testPreferredLanguageResolution() {
        XCTAssertEqual(GameLanguage.preferred(in: ["zh-Hans-US"]), .simplifiedChinese)
        XCTAssertEqual(GameLanguage.preferred(in: ["zh-Hant-TW"]), .traditionalChinese)
        XCTAssertEqual(GameLanguage.preferred(in: ["zh-HK"]), .traditionalChinese)
        XCTAssertEqual(GameLanguage.preferred(in: ["en-US", "zh-Hans"]), .english)
        XCTAssertEqual(GameLanguage.preferred(in: ["ja-JP", "zh-TW"]), .traditionalChinese)
        XCTAssertEqual(GameLanguage.preferred(in: ["fr-FR"]), .simplifiedChinese)
    }

    func testAudioSettingsClampingAndDefaults() throws {
        var audio = AudioSettings(musicVolume: 2.5, effectsVolume: -1.0, catVolume: .nan)
        XCTAssertEqual(audio.musicVolume, 1.0)
        XCTAssertEqual(audio.effectsVolume, 0.0)
        XCTAssertEqual(audio.catVolume, AudioSettings.defaultEffectsVolume)

        audio.musicVolume = .infinity
        XCTAssertEqual(audio.musicVolume, AudioSettings.defaultMusicVolume)

        let data = try JSONEncoder().encode(GameSettings(language: .english, audio: audio))
        let decoded = try JSONDecoder().decode(GameSettings.self, from: data)
        XCTAssertEqual(decoded.language, .english)
        XCTAssertEqual(decoded.audio, audio)
    }

    func testUnsupportedLanguageInSaveFallsBackToNilWithoutFailingDecode() throws {
        let raw = Data("{\"language\":\"xx-YY\",\"audio\":{\"musicEnabled\":false}}".utf8)
        let decoded = try JSONDecoder().decode(GameSettings.self, from: raw)
        XCTAssertNil(decoded.language)
        XCTAssertFalse(decoded.audio.musicEnabled)
    }
}
