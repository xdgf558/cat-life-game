import XCTest
@testable import CatGameCore

final class DiaryAdsAndLedgerTests: XCTestCase {
    private let t0: Int64 = 1_760_000_000_000

    private func readyState() -> DiaryGameState {
        var state = DiaryGameState.fresh(now: t0)
        state.tutorialActive = false
        state.orders.completedTotal = 2 // past newbie guard
        state.energy.current = 0
        state.energy.updatedAt = t0
        return state
    }

    func testNewbieGuardBlocksOffersBeforeTwoCompletedOrders() {
        var state = DiaryGameState.fresh(now: t0)
        state.tutorialActive = false
        state.orders.completedTotal = 1
        XCTAssertEqual(DiaryAds.quotaBlock(state, slot: .wage, config: .default, now: t0), .newbie)
        state.orders.completedTotal = 2
        XCTAssertNil(DiaryAds.quotaBlock(state, slot: .wage, config: .default, now: t0))
    }

    func testMaterialOfferAutoTargetsOrderItemAndMutualExclusionBlocksWageBonus() {
        var state = readyState()
        let ball = MergeItem(chain: .cloth, level: 3) // costs 4 tier-1 units
        state.board.cells[0] = MergeItem(chain: .cloth, level: 2) // 2 units already on board -> gap = 2
        let order = CustomerOrder(id: "o10", customer: .ajian, items: [ball], wage: 25)
        state.orders.active = [order]

        let engine = DiaryGameEngine(state: state, adConfig: .default, rng: SeededRNG(seed: 1))
        let offerOut = engine.materialOfferFor(chain: .cloth, now: t0)
        guard let offer = offerOut.value else { return XCTFail("Expected auto material offer") }
        XCTAssertEqual(offer.count, 2)
        XCTAssertEqual(offer.completedUnits, 2)
        XCTAssertEqual(offer.totalUnits, 4)

        _ = engine.offerShown(.material(offer), now: t0)
        let claimID = engine.startAd(offer: .material(offer), now: t0).value
        XCTAssertNotNil(claimID)

        // Finishing once grants 2 cloth_1; repeating the same claimID must be a no-op!
        XCTAssertTrue(engine.finishAd(claimID: claimID!, result: .ended, now: t0 + 1000).value)
        XCTAssertFalse(engine.finishAd(claimID: claimID!, result: .ended, now: t0 + 1000).value)
        XCTAssertEqual(engine.state.ads.used[.material], 1)

        // Merge into ball and deliver order -> wage bonus must be suppressed (mutual exclusion).
        _ = engine.moveItem(from: 1, to: 2, now: t0 + 2000)
        _ = engine.moveItem(from: 0, to: 2, now: t0 + 2000)
        let deliverOut = engine.deliverOrder(orderID: "o10", now: t0 + 120_000)
        XCTAssertNil(deliverOut.value.bonusOffer)
    }

    func testRefusalLimitAndDailyReset() {
        let engine = DiaryGameEngine(state: readyState(), adConfig: .default)
        for _ in 0..<3 { _ = engine.refuseAd(slot: .wage, now: t0) }
        XCTAssertEqual(DiaryAds.quotaBlock(engine.state, slot: .wage, config: .default, now: t0), .refused)
        // Next day resets refusal & daily counts.
        let tomorrow = t0 + DayClock.dayMs + DayClock.hourMs
        _ = engine.refreshDay(now: tomorrow)
        XCTAssertNil(DiaryAds.quotaBlock(engine.state, slot: .wage, config: .default, now: tomorrow))
    }

    func testCrashRecoveryCancelsPendingWithoutGrantingOrUsingQuota() {
        var state = readyState()
        let offer = WageOffer(orderID: "o99", amount: 30, wishlistShortAfter: nil, furniture: nil, furniturePrice: nil)
        let claimID = DiaryLedger.createPending(&state, slot: .wage, reward: .coins(amount: 30), now: t0, key: offer.key)
        XCTAssertEqual(DiaryAds.remainingForSlot(state, slot: .wage, config: .default), 1)

        let recovered = DiaryLedger.recoverPendingOnStartup(&state)
        XCTAssertEqual(recovered, 1)
        XCTAssertEqual(state.coins, 0)
        XCTAssertEqual(DiaryLedger.findClaim(state, id: claimID)?.status, .cancelled)
        XCTAssertEqual(DiaryAds.remainingForSlot(state, slot: .wage, config: .default), 2)
    }

    func testSmallWageSuppressedUnlessCompletingWishlist() {
        var state = readyState()
        let smallOrder = CustomerOrder(id: "o5", customer: .ajian, items: [MergeItem(chain: .cloth, level: 3)], wage: 10)
        XCTAssertNil(DiaryAds.wageOffer(state, order: smallOrder, config: .default, now: t0))

        // Set wishlist window_cushion (120) with 110 coins -> 10 bonus finishes exact shortfall!
        state.coins = 110
        state.home.wishlist = .windowCushion
        let offer = DiaryAds.wageOffer(state, order: smallOrder, config: .default, now: t0)
        XCTAssertEqual(offer?.wishlistShortAfter, 0)
        XCTAssertEqual(offer?.furniture, .windowCushion)
    }
}
