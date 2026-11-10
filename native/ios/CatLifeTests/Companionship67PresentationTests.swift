import XCTest
import CatGameCore
@testable import CatLife

@MainActor
final class Companionship67PresentationTests: XCTestCase {
    func testCompanionshipCopyIsRegisteredAndUsesTheSameFormatsInEveryLanguage() {
        let dictionaries = [GameStrings.companionship67Chinese, GameStrings.companionship67Traditional,
                            GameStrings.companionship67English]
        let registered = [GameStrings.chinese, GameStrings.traditionalChinese, GameStrings.english]
        let keys = Set(dictionaries[0].keys)
        for (index, dictionary) in dictionaries.enumerated() {
            XCTAssertEqual(Set(dictionary.keys), keys)
            for key in keys {
                XCTAssertFalse(dictionary[key]!.isEmpty)
                XCTAssertEqual(registered[index][key], dictionary[key])
                XCTAssertEqual(formats(dictionary[key]!), formats(dictionaries[0][key]!))
            }
            for memory in CatMemoryKind.allCases {
                XCTAssertNotNil(registered[index][memory.titleKey])
                XCTAssertNotNil(registered[index][memory.bodyKey])
            }
        }
        XCTAssertEqual(CompanionshipPresentation.pinnableMemories, [.favoritePlay, .littleCorner, .settledAfterMove])
    }

    func testNeighborAndPinnedPlayTextNeverDiscloseUnconfirmedPreferences() {
        let original = GameLocalization.shared.language
        defer { GameLocalization.shared.language = original }
        for language in GameLanguage.allCases {
            GameLocalization.shared.language = language
            for definition in CatHabitCatalog.all {
                var cat = CatState(id: definition.id, name: "Companion", now: Date())
                let rest = GameStrings.text("catHabits.restConfirmed.\(definition.rest.rawValue)")
                let play = GameStrings.text("catHabits.playConfirmed.\(definition.play.rawValue)")
                let unknown = CompanionshipPresentation.neighborDialogue(for: cat)!
                XCTAssertFalse(unknown.contains(rest)); XCTAssertFalse(unknown.contains(play))
                XCTAssertFalse(CompanionshipPresentation.guidance(for: .favoritePlay, cat: cat).contains(play))
                cat.habits.restClueSessionIDs = ["rest-1", "rest-2"]
                let restOnly = CompanionshipPresentation.neighborDialogue(for: cat)!
                XCTAssertTrue(restOnly.contains(rest)); XCTAssertFalse(restOnly.contains(play))
                cat.habits.playClueSessionIDs = ["play-1", "play-2"]
                let known = CompanionshipPresentation.neighborDialogue(for: cat)!
                XCTAssertTrue(known.contains(rest)); XCTAssertTrue(known.contains(play))
                XCTAssertTrue(CompanionshipPresentation.guidance(for: .favoritePlay, cat: cat).contains(play))
            }
        }
    }

    func testMovedRestMemoryUsesTheCatsActualStyleAndShopGoalsOnlyUseExistingRestOrPlaySystems() throws {
        let original = GameLocalization.shared.language
        defer { GameLocalization.shared.language = original }
        for language in GameLanguage.allCases {
            GameLocalization.shared.language = language
            var styleBodies = Set<String>()
            for definition in CatHabitCatalog.all {
                let cat = CatState(id: definition.id, name: "Companion", now: Date())
                let body = CompanionshipPresentation.memoryBody(for: .settledAfterMove, cat: cat)
                XCTAssertEqual(body, GameStrings.text("catMemories.settledAfterMove.body.\(definition.style.rawValue)"))
                styleBodies.insert(body)
            }
            XCTAssertEqual(styleBodies.count, CatBehaviorStyle.allCases.count)
            let cat = GameSnapshot.fresh().cats[0]
            let restProducts = ShopListing.list(.furniture).filter {
                ShopCatalog.furnitureOffer(id: $0.id).flatMap { CatRestPreference(kind: $0.kind) } != nil
            }
            XCTAssertFalse(restProducts.isEmpty)
            var rememberedCat = cat
            rememberedCat.habits.memories = [try JSONDecoder().decode(CatMemory.self,
                from: Data(#"{"kind":"settledAfterMove","createdAt":0}"#.utf8))]
            for product in restProducts {
                XCTAssertEqual(CompanionshipPresentation.shopGoal(for: product, cat: cat),
                               GameStrings.format("habit67.shop.restGoal", GameStrings.catName(cat)))
                XCTAssertEqual(CompanionshipPresentation.shopGoal(for: product, cat: rememberedCat),
                               GameStrings.text("habit67.memoryRecorded"),
                               "An already earned memory must not be advertised as another new memory.")
            }
            let toy = try XCTUnwrap(ShopListing.list(.supplies).first { $0.kind == .supply(.toy) })
            XCTAssertNotNil(CompanionshipPresentation.shopGoal(for: toy, cat: cat))
            let other = try XCTUnwrap(ShopListing.list(.furniture).first { $0.id == "potted_plant" })
            XCTAssertNil(CompanionshipPresentation.shopGoal(for: other, cat: cat))
            XCTAssertNil(CompanionshipPresentation.shopGoal(for: toy, cat: nil))
        }
    }

    private func formats(_ text: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: "%[@df]")
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            .map { String(text[Range($0.range, in: text)!]) }
    }
}
