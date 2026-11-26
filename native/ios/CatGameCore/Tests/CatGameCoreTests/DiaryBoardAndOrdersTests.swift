import XCTest
@testable import CatGameCore

final class DiaryBoardAndOrdersTests: XCTestCase {
    private let t0: Int64 = 1_760_000_000_000

    func testTutorialTapCostsZeroEnergyAndOnlyProducesLevel1() {
        var state = DiaryGameState.fresh(now: t0)
        var rng = SequenceRNG([0.0]) // would trigger lv2 if not in tutorial
        let result = DiaryBoard.tapGenerator(&state, chain: .cloth, now: t0, rng: &rng)
        XCTAssertEqual(result, .generated(item: MergeItem(chain: .cloth, level: 1), cell: 0))
        XCTAssertEqual(state.energy.current, DiaryBalance.default.energy.max)
    }

    func testPostTutorialGeneratorSpendsEnergyAndCanTriggerLuckyLv2() {
        var state = DiaryGameState.fresh(now: t0)
        state.tutorialActive = false
        var rng = SequenceRNG([0.05, 0.5])
        let r1 = DiaryBoard.tapGenerator(&state, chain: .cloth, now: t0, rng: &rng)
        let r2 = DiaryBoard.tapGenerator(&state, chain: .cloth, now: t0, rng: &rng)
        XCTAssertEqual(r1, .generated(item: MergeItem(chain: .cloth, level: 2), cell: 0))
        XCTAssertEqual(r2, .generated(item: MergeItem(chain: .cloth, level: 1), cell: 1))
        XCTAssertEqual(state.energy.current, DiaryBalance.default.energy.max - 2)
    }

    func testMoveMergeSwapAndPendingOverflow() {
        var state = DiaryGameState.fresh(now: t0)
        let c1 = MergeItem(chain: .cloth, level: 1)
        let c2 = MergeItem(chain: .cloth, level: 2)
        state.board.cells[0] = c1
        state.board.cells[1] = c1
        XCTAssertEqual(DiaryBoard.moveItem(&state, from: 0, to: 1), .merged(c2))
        XCTAssertNil(state.board.cells[0])
        XCTAssertEqual(state.board.cells[1], c2)

        state.board.cells[2] = c1
        XCTAssertEqual(DiaryBoard.moveItem(&state, from: 1, to: 2), .swapped)
        XCTAssertEqual(state.board.cells[1], c1)
        XCTAssertEqual(state.board.cells[2], c2)

        // Fill entire board to verify pending overflow and claiming.
        for i in state.board.cells.indices { state.board.cells[i] = c1 }
        XCTAssertEqual(DiaryBoard.placeItem(&state, item: c2), -1)
        XCTAssertEqual(state.board.pending, [c2])

        let sold = DiaryBoard.sellItem(&state, at: 0)
        XCTAssertGreaterThan(sold, 0)
        XCTAssertEqual(DiaryBoard.claimPending(&state), c2)
        XCTAssertEqual(state.board.cells[0], c2)
        XCTAssertTrue(state.board.pending.isEmpty)
    }

    func testEnergyRegenAndClockRollbackSafety() {
        var state = DiaryGameState.fresh(now: t0)
        state.tutorialActive = false
        XCTAssertTrue(DiaryEnergy.spend(&state, amount: 5, now: t0))
        XCTAssertEqual(state.energy.current, 25)
        // Clock moves backward: must not grant energy.
        XCTAssertEqual(DiaryEnergy.settle(&state, now: t0 - 600_000), 25)
        // 6 minutes forward => +3 energy.
        XCTAssertEqual(DiaryEnergy.settle(&state, now: t0 - 600_000 + 6 * DayClock.minuteMs), 28)
    }

    func testDeliverOrderAwardsWageCustomerGiftAndReplacesOrder() {
        var state = DiaryGameState.fresh(now: t0)
        state.tutorialActive = false
        state.orders.customerProgress[.ajian] = DiaryBalance.default.orders.giftEveryOrders - 1
        let ball = MergeItem(chain: .cloth, level: 3)
        let order = CustomerOrder(id: "o1", customer: .ajian, items: [ball], wage: DiaryOrders.wage(for: [ball]))
        state.orders.active = [order]
        state.board.cells[0] = ball
        var rng = SeededRNG(seed: 42)
        let res = DiaryOrders.deliverOrder(&state, orderID: "o1", rng: &rng)
        guard case .delivered(let delivered, let wage, let gift, let replacement) = res else {
            return XCTFail("Expected order delivery")
        }
        XCTAssertEqual(delivered.id, "o1")
        XCTAssertEqual(wage, 10)
        XCTAssertEqual(state.coins, 10)
        XCTAssertEqual(gift, .giftAjian)
        XCTAssertTrue(state.home.furnitureOwned.contains(.giftAjian))
        XCTAssertEqual(state.orders.active.first?.id, replacement.id)
    }

    func testFurnitureShopAndWishlistShortfall() {
        var state = DiaryGameState.fresh(now: t0)
        state.coins = 80
        state.home.wishlist = .windowCushion
        XCTAssertEqual(DiaryOrders.wishlistShortfall(state), 40)
        XCTAssertEqual(DiaryOrders.buyFurniture(&state, id: .windowCushion), .notEnoughCoins)
        XCTAssertEqual(DiaryOrders.buyFurniture(&state, id: .catBed), .roomLocked(.bedroom))

        state.coins = 120
        XCTAssertEqual(DiaryOrders.buyFurniture(&state, id: .windowCushion), .bought(furniture: .windowCushion, price: 120))
        XCTAssertNil(state.home.wishlist)
        XCTAssertEqual(state.home.layout.first?.id, .windowCushion)
    }
}
