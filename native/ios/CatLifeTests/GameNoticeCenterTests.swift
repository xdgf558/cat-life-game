import Foundation
import XCTest
import CatGameCore
@testable import CatLife

final class GameNoticeCenterTests: XCTestCase {
    @MainActor
    func testStartupPreservesWorkRecoveryAndRestTogetherWhenEnteringHome() {
        let notices = GameNoticeCenter()
        let messages = [GameStrings.format("action.workFinished", 60),
                        GameStrings.text("save.recovered"), GameStrings.text("rest.ended")]
        for message in messages { notices.show(message, ready: false) }
        XCTAssertEqual(notices.startupNotice, messages.joined(separator: "\n"))
        XCTAssertNil(notices.toast)
        notices.enterHome()
        XCTAssertNil(notices.startupNotice)
        XCTAssertEqual(notices.toast, messages.joined(separator: "\n"))
    }

    @MainActor
    func testReadyAndStartupQueuesKeepOnlyThreeMostRecentDistinctMessages() {
        for ready in [false, true] {
            let notices = GameNoticeCenter()
            for message in ["First", "Second", "Third", "Fourth", "Second"] {
                notices.show(message, ready: ready)
            }
            XCTAssertEqual(ready ? notices.toast : notices.startupNotice, "Third\nFourth\nSecond")
            notices.show("\n  \nFifth\nFifth\nSixth\n", ready: ready)
            XCTAssertEqual(ready ? notices.toast : notices.startupNotice, "Second\nFifth\nSixth")
            notices.show("\n  \n", ready: ready)
            XCTAssertEqual(ready ? notices.toast : notices.startupNotice, "Second\nFifth\nSixth")
        }
    }

    @MainActor
    func testEveryPurchaseCategoryUsesItsIntendedNoticeInAllLanguages() {
        let previousLanguage = GameLocalization.shared.language
        defer { GameLocalization.shared.language = previousLanguage }
        let now = Date(timeIntervalSince1970: 1_793_600_000)
        let purchases: [(ActionSuccess, String, (inout GameSnapshot) -> ActionOutcome)] = [
            (.foodPurchased, "action.purchase", { GameEngine.buyFood(&$0, now: now) }),
            (.litterPurchased, "action.purchase", { GameEngine.buyLitter(&$0, now: now) }),
            (.toyPurchased, "action.purchase", { GameEngine.buyToy(&$0, now: now) }),
            (.equipmentPurchased, "shop.equipmentPurchased", {
                GameEngine.purchaseEquipment(&$0, itemID: "advanced_cap", now: now)
            }),
            (.furniturePurchased, "shop.furniturePurchased", {
                GameEngine.purchaseFurniture(&$0, offerID: "potted_plant", now: now)
            }),
            (.homeUpgraded, "home.upgraded", { GameEngine.upgradeHome(&$0, toLevel: 3, now: now) }),
            (.catAdopted, "cat.adopted", { GameEngine.adoptCat(&$0, catID: CatCatalog.cowCatID, now: now) })
        ]
        for language in [GameLanguage.simplifiedChinese, .traditionalChinese, .english] {
            GameLocalization.shared.language = language
            for (success, key, action) in purchases {
                var state = GameSnapshot.fresh(now: now)
                state.player.gold = 5000
                state.player.level = 4
                state.home.roomLevel = 2
                let outcome = action(&state)
                XCTAssertTrue(outcome.succeeded)
                XCTAssertEqual(outcome.success, success)
                XCTAssertEqual(outcome.kind, .purchase)
                XCTAssertEqual(GameActionNotice.message(for: outcome, snapshot: state), GameStrings.text(key))
                XCTAssertNotEqual(GameStrings.text(key), key)
            }
        }
    }

    @MainActor
    func testEmptySynchronizationAndWorkNoticesKeepTheirDistinctSemantics() {
        XCTAssertEqual(GameActionNotice.message(for: ActionOutcome(), snapshot: nil), "")
        let work = ActionOutcome(success: .workFinished, amount: 73)
        XCTAssertEqual(work.kind, .workFinished)
        XCTAssertEqual(GameActionNotice.message(for: work, snapshot: nil), GameStrings.format("action.workFinished", 73))
        XCTAssertEqual(GameActionNotice.message(for: ActionOutcome(success: .workStarted), snapshot: nil),
                       GameStrings.text("action.workStarted"))
        XCTAssertEqual(GameActionNotice.message(for: ActionOutcome(success: .layoutSaved), snapshot: nil),
                       GameStrings.text("layout.saved"))
    }
}
