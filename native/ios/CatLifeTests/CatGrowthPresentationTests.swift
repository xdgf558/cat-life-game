import XCTest
import CatGameCore
@testable import CatLife

final class CatGrowthPresentationTests: XCTestCase {
    @MainActor
    func testGrowthCopyIsCompleteAndConnectedInEveryLanguage() {
        let previous = GameLocalization.shared.language
        defer { GameLocalization.shared.language = previous }
        let dictionaries: [(GameLanguage, [String: String])] = [
            (.simplifiedChinese, GameStrings.catGrowth57Chinese),
            (.traditionalChinese, GameStrings.catGrowth57Traditional),
            (.english, GameStrings.catGrowth57English)
        ]
        let expectedKeys = Set(GameStrings.catGrowth57Chinese.keys)
        for (language, dictionary) in dictionaries {
            GameLocalization.shared.language = language
            XCTAssertEqual(Set(dictionary.keys), expectedKeys)
            for (key, value) in dictionary {
                XCTAssertFalse(value.isEmpty, key)
                XCTAssertEqual(GameStrings.text(key), value, "The growth dictionary must be registered for \(language).")
            }
            for sex in CatSex.allCases { XCTAssertNotNil(dictionary["catGrowth.sex.\(sex.rawValue)"]) }
            for stage in CatGrowthStage.allCases { XCTAssertNotNil(dictionary["catGrowth.stage.\(stage.rawValue)"]) }
            for stage in CatBondStage.allCases { XCTAssertNotNil(dictionary["catGrowth.bond.\(stage.rawValue)"]) }
            XCTAssertFalse(CatGrowthPresentation.age(95).contains("%d"))
            XCTAssertFalse(CatGrowthPresentation.nextBond(24).contains("%@"))
            XCTAssertFalse(GameStrings.format("catGrowth.clockHint", CatGrowthCatalog.ageMultiplier).contains("%d"))
        }
    }

    @MainActor
    func testAgeSwitchesToYearsAtTwelveGameMonthsInEveryLanguage() {
        let previous = GameLocalization.shared.language
        defer { GameLocalization.shared.language = previous }
        let cases: [(GameLanguage, String, String, String, String)] = [
            (.simplifiedChinese, "11 个月 29 天", "1 岁 0 个月", "1 岁 11 个月", "5 岁 2 个月"),
            (.traditionalChinese, "11 個月 29 天", "1 歲 0 個月", "1 歲 11 個月", "5 歲 2 個月"),
            (.english, "11 months, 29 days", "1 yr, 0 mo", "1 yr, 11 mo", "5 yr, 2 mo")
        ]
        for (language, beforeYear, firstYear, beforeSecondYear, olderCat) in cases {
            GameLocalization.shared.language = language
            XCTAssertEqual(CatGrowthPresentation.age(359), beforeYear)
            XCTAssertEqual(CatGrowthPresentation.age(360), firstYear)
            XCTAssertEqual(CatGrowthPresentation.age(365), firstYear)
            XCTAssertEqual(CatGrowthPresentation.age(719), beforeSecondYear)
            XCTAssertEqual(CatGrowthPresentation.age(720), GameStrings.format("catGrowth.yearsAndMonths", 2, 0))
            XCTAssertEqual(CatGrowthPresentation.age(1_865), olderCat)
        }
    }

    @MainActor
    func testStageAndBondMessagesUseTheNextThresholdAndHaveFriendlyFinalStates() {
        let previous = GameLocalization.shared.language
        defer { GameLocalization.shared.language = previous }
        GameLocalization.shared.language = .simplifiedChinese
        let now = Date(timeIntervalSince1970: 1_793_800_000)
        XCTAssertEqual(CatGrowthPresentation.age(95), "3 个月 5 天")
        for (age, expected) in [(179, "再成长 1 个游戏日，进入少年期。"),
                                 (180, "再成长 185 个游戏日，进入成年期。"),
                                 (364, "再成长 1 个游戏日，进入成年期。")] {
            let growth = CatGrowthState(recordedSince: now, adoptedAt: now, initialAgeDays: age, sex: .female)
            XCTAssertEqual(CatGrowthPresentation.nextGrowth(growth, at: now), expected)
        }
        let adult = CatGrowthState.adopted(appearance: .blue, now: now)
        XCTAssertEqual(CatGrowthPresentation.nextGrowth(adult, at: now), GameStrings.text("catGrowth.adultHint"))
        XCTAssertEqual(CatGrowthPresentation.nextBond(24), "再增加 1 点亲密，成为“渐渐熟悉”。")
        XCTAssertEqual(CatGrowthPresentation.nextBond(25), "再增加 25 点亲密，成为“信赖彼此”。")
        XCTAssertEqual(CatGrowthPresentation.nextBond(74), "再增加 1 点亲密，成为“亲密家人”。")
        for intimacy in [75, 100] {
            XCTAssertEqual(CatGrowthPresentation.nextBond(intimacy), GameStrings.text("catGrowth.closestHint"))
        }
    }
}
