import XCTest
import CatGameCore
@testable import CatLife

final class CatGrowthTimelineGeometryTests: XCTestCase {
    func testStageNodesAndProgressUseTheSameAgeAxisAtEveryThreshold() {
        let axis = CatGrowthTimelineGeometry(width: 300)
        XCTAssertEqual(axis.startX, 50)
        XCTAssertEqual(axis.length, 200)
        XCTAssertEqual(axis.x(forAge: CatGrowthStage.kitten.minimumAgeDays), 50)
        XCTAssertEqual(axis.x(forAge: CatGrowthStage.junior.minimumAgeDays), 148.6301369863, accuracy: 0.000001)
        XCTAssertEqual(axis.x(forAge: CatGrowthStage.adult.minimumAgeDays), 250)
        XCTAssertLessThan(axis.x(forAge: 179), axis.x(forAge: 180))
        XCTAssertLessThan(axis.x(forAge: 180), axis.x(forAge: 181))
    }

    func testAgeExtremesStayAtTheFirstAndLastNodesAcrossScreenWidths() {
        for width: CGFloat in [0, 120, 279, 520] {
            let axis = CatGrowthTimelineGeometry(width: width)
            XCTAssertEqual(axis.x(forAge: Int.min), axis.startX)
            XCTAssertEqual(axis.x(forAge: 0), axis.startX)
            XCTAssertEqual(axis.x(forAge: 365), axis.startX + axis.length)
            XCTAssertEqual(axis.x(forAge: Int.max), axis.startX + axis.length)
            XCTAssertGreaterThanOrEqual(axis.startX - axis.columnWidth / 2, 0)
            XCTAssertLessThanOrEqual(axis.x(forAge: 365) + axis.columnWidth / 2, width + 0.000001)
        }
    }

    @MainActor
    func testBondHeaderAndUpstairsExplanationAreRegisteredInAllThreeLanguages() {
        let previous = GameLocalization.shared.language
        defer { GameLocalization.shared.language = previous }
        for (language, summary) in [(GameLanguage.simplifiedChinese, "亲密 24 / 100"),
                                    (.traditionalChinese, "親密 24 / 100"), (.english, "Bond 24 / 100")] {
            GameLocalization.shared.language = language
            XCTAssertEqual(GameStrings.format("catGrowth.bondSummary", 24), summary)
            let title = GameStrings.text("homeUpgrade.upperOpened")
            let body = GameStrings.text("homeUpgrade.upperOpenedBody")
            XCTAssertNotEqual(body, "homeUpgrade.upperOpenedBody")
            XCTAssertFalse(body.contains(title), "The explanation must not repeat its heading.")
        }
    }
}
