import Foundation
import XCTest
import CatGameCore
@testable import CatLife

final class CareerDirectoryTests: XCTestCase {
    @MainActor
    func testHigherTierCareersHaveDistinctArtworkAndSearchableNamesInEveryLanguage() {
        let previous = GameLocalization.shared.language
        defer { GameLocalization.shared.language = previous }
        let expected = ["job_pet_photographer": "job-photographer-cartoon",
                        "job_pet_brand_designer": "job-designer-cartoon"]
        for language in GameLanguage.allCases {
            GameLocalization.shared.language = language
            for (id, asset) in expected {
                let name = WorkJobPresentation.name(id)
                XCTAssertNotEqual(name, "jobs.\(id).name")
                XCTAssertNotEqual(GameStrings.text("jobs.\(id).detail"), "jobs.\(id).detail")
                XCTAssertEqual(WorkJobPresentation.asset(id), asset)
                let matches = CareerDirectory.matching(WorkCatalog.all, level: 20, query: name, filter: .available,
                                                       locale: Locale(identifier: language.rawValue)) {
                    WorkJobPresentation.name($0.id)
                }
                XCTAssertEqual(matches.map(\.id), [id])
            }
        }
    }

    func testLocalizedNameSearchAndUnlockFilterComposeWithoutReorderingJobs() {
        let names = ["job_flyer": "Hand out flyers", "job_store": "Store assistant",
                     "job_petshop": "Pet shop assistant", "job_it_engineer": "IT engineer",
                     "job_cat_cafe_manager": "Cat café manager", "job_pet_photographer": "Pet Photographer",
                     "job_pet_brand_designer": "Pet Brand Designer"]
        let all = CareerDirectory.matching(WorkCatalog.all, level: 1, query: " \n", filter: .all,
                                          locale: Locale(identifier: "en")) { names[$0.id]! }
        XCTAssertEqual(all, WorkCatalog.all)
        let available = CareerDirectory.matching(WorkCatalog.all, level: 2, query: "  ASSISTANT\n",
            filter: .available, locale: Locale(identifier: "en")) { names[$0.id]! }
        XCTAssertEqual(available.map(\.id), ["job_store"])
        let locked = CareerDirectory.matching(WorkCatalog.all, level: 2, query: "assistant",
            filter: .locked, locale: Locale(identifier: "en")) { names[$0.id]! }
        XCTAssertEqual(locked.map(\.id), ["job_petshop"])
        let cafe = CareerDirectory.matching(WorkCatalog.all, level: 10, query: "cafe",
            filter: .all, locale: Locale(identifier: "en")) { names[$0.id]! }
        XCTAssertEqual(cafe.map(\.id), ["job_cat_cafe_manager"])
        let highLevel = CareerDirectory.matching(WorkCatalog.all, level: 15, query: "pet",
            filter: .available, locale: Locale(identifier: "en")) { names[$0.id]! }
        XCTAssertEqual(highLevel.map(\.id), ["job_petshop", "job_pet_photographer"])
        XCTAssertEqual(CareerDirectory.pageRange(1, count: WorkCatalog.all.count), 4..<7)
        let localized = CareerDirectory.matching(WorkCatalog.all, level: 1, query: "传单",
            filter: .all, locale: Locale(identifier: "zh-Hans")) { $0.id == "job_flyer" ? "发传单" : "其他职业" }
        XCTAssertEqual(localized.map(\.id), ["job_flyer"])
        let noMatch = CareerDirectory.matching(WorkCatalog.all, level: 10, query: "job_flyer",
            filter: .all, locale: Locale(identifier: "en")) { names[$0.id]! }
        XCTAssertTrue(noMatch.isEmpty, "Search follows visible localized names, not internal IDs.")
    }

    func testOneHundredAndOneJobsStayInFourRowPagesWithNoGapsOrDuplicates() {
        let count = 101
        XCTAssertEqual(CareerDirectory.pageCount(for: count), 26)
        let pages = (0..<26).map { CareerDirectory.pageRange($0, count: count) }
        XCTAssertTrue(pages.allSatisfy { $0.count <= 4 })
        XCTAssertEqual(pages.flatMap { Array($0) }, Array(0..<count))
        XCTAssertEqual(pages.last, 100..<101)
    }

    func testEmptyShrinkingAndOutOfRangePagesRemainSafe() {
        XCTAssertEqual(CareerDirectory.pageRange(25, count: 5), 4..<5)
        XCTAssertEqual(CareerDirectory.pageRange(-10, count: 5), 0..<4)
        XCTAssertEqual(CareerDirectory.pageRange(Int.max, count: 1), 0..<1)
        XCTAssertEqual(CareerDirectory.pageRange(Int.max, count: 0), 0..<0)
        XCTAssertEqual(CareerDirectory.pageRange(0, count: -1), 0..<0)
        XCTAssertEqual(CareerDirectory.pageCount(for: 0), 1)
        XCTAssertEqual(CareerDirectory.clampedPage(1, count: 0), 0)
        let largest = CareerDirectory.pageRange(Int.max, count: Int.max)
        XCTAssertEqual(largest.upperBound, Int.max)
        XCTAssertLessThanOrEqual(largest.count, 4)
    }
}
