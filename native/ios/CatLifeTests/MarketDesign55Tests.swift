import XCTest
import CatGameCore
@testable import CatLife

final class MarketDesign55Tests: XCTestCase {
    @MainActor
    func testInventoryPreviewMatchesEveryCatalogTradeWithoutChangingTheSource() throws {
        let now = Date(timeIntervalSince1970: 1_793_800_000)
        for offer in ExchangeCatalog.offers {
            var state = GameSnapshot.fresh(now: now)
            state.inventory = InventoryState(food: 10, litter: 10, toys: 12,
                gifts: ["flower": 3, "drink": 3, "dessert": 3, "cat_snack": 3],
                premiumFood: 4, premiumLitter: 4)
            state.community.relationships[offer.neighborID] = NeighborRelationship(friendship: 40,
                rewardedStageLevels: [2, 3])
            let before = state
            let items = Set((offer.inputs + offer.outputs).map(\.item))
            let preview = Dictionary(uniqueKeysWithValues: items.map {
                ($0, ExchangePresentation.countAfterTrade($0, offer: offer, inventory: state.inventory))
            })
            XCTAssertEqual(state, before, "Opening or cancelling the preview must not spend stock.")
            XCTAssertTrue(GameEngine.exchange(&state, offerID: offer.id, now: now).succeeded, offer.id)
            for item in items {
                XCTAssertEqual(preview[item], item.count(in: state.inventory), offer.id)
            }
        }
    }

    @MainActor
    func testPreviewSeparatesTradeFromStageAwardsAndCapsFriendship() throws {
        let now = Date(timeIntervalSince1970: 1_793_800_000)
        let offer = try XCTUnwrap(ExchangeCatalog.offer(id: "mira_food"))
        var state = GameSnapshot.fresh(now: now)
        state.community.relationships[offer.neighborID]?.friendship = 18
        XCTAssertEqual(ExchangePresentation.countAfterTrade(.supply(.food), offer: offer, inventory: state.inventory), 1)
        XCTAssertEqual(ExchangePresentation.countAfterTrade(.supply(.premiumFood), offer: offer, inventory: state.inventory), 1)
        XCTAssertEqual(ExchangePresentation.friendshipAfterTrade(18), 20)
        XCTAssertTrue(GameEngine.exchange(&state, offerID: offer.id, now: now).succeeded)
        XCTAssertEqual(state.inventory.food, 2, "The stage's one serving is shown separately on the saved result.")
        XCTAssertEqual(ExchangePresentation.friendshipAfterTrade(99), 100)
        XCTAssertEqual(ExchangePresentation.friendshipAfterTrade(100), 100)
    }

    @MainActor
    func testCardActionsFollowSharedEligibilityInAllLanguages() throws {
        let offer = try XCTUnwrap(ExchangeCatalog.offer(id: "mira_food"))
        let locked = try XCTUnwrap(ExchangeCatalog.offer(id: "mira_feast"))
        let previousLanguage = GameLocalization.shared.language
        defer { GameLocalization.shared.language = previousLanguage }
        for language in [GameLanguage.simplifiedChinese, .traditionalChinese, .english] {
            GameLocalization.shared.language = language
            var state = GameSnapshot.fresh()
            state.community.relationships[offer.neighborID]?.friendship = 18
            XCTAssertNil(ExchangeCatalog.eligibility(of: offer, in: state))
            XCTAssertEqual(ExchangePresentation.actionTitle(offer, snapshot: state), GameStrings.text("market.preview"))
            XCTAssertEqual(ExchangeCatalog.eligibility(of: locked, in: state), .exchangeStageRequired)
            XCTAssertEqual(ExchangePresentation.actionTitle(locked, snapshot: state), GameStrings.format("market.visitForFriendship", 22))
            XCTAssertFalse(ExchangePresentation.actionTitle(locked, snapshot: state).contains("market."))
            state.inventory.food = 1
            XCTAssertEqual(ExchangeCatalog.eligibility(of: offer, in: state), .exchangeMaterialsRequired)
            XCTAssertEqual(ExchangePresentation.actionTitle(offer, snapshot: state), GameStrings.text("market.restock"))
            state.inventory.food = 3
            state.inventory.premiumFood = GameSnapshot.maximumStock
            XCTAssertEqual(ExchangeCatalog.eligibility(of: offer, in: state), .shopInventoryFull)
            XCTAssertEqual(ExchangePresentation.actionTitle(offer, snapshot: state), GameStrings.text("market.openBag"))
            state.community.exchangeCounts[offer.neighborID] = NeighborExchangeCount(today: 2, total: 2)
            XCTAssertEqual(ExchangeCatalog.eligibility(of: offer, in: state), .exchangeDailyLimit)
            XCTAssertEqual(ExchangePresentation.actionTitle(offer, snapshot: state), GameStrings.text("market.tomorrow"))
        }
    }
}
