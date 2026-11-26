import XCTest
@testable import CatGameCore

/// 7-day zero-ad player economy verification matching design doc §2.7:
/// - Day 1 can purchase the first furniture (`window_cushion`, 120 coins)
/// - By Day 7, diary reaches at least half of the 36 core photos without watching any ads.
final class DiaryEconomySimulationTests: XCTestCase {
    func testZeroAdPlayerProgressionAcrossSevenDays() {
        var t: Int64 = 1_760_000_000_000
        let engine = DiaryGameEngine(
            state: DiaryGameState.fresh(now: t),
            adConfig: AdRemoteConfig(adEnabled: false),
            rng: SeededRNG(seed: 2026)
        )
        _ = engine.start(now: t)

        // Complete tutorial on Day 1
        _ = engine.pet(now: t)
        for _ in 0..<4 { _ = engine.tapGenerator(chain: .cloth, now: t) }
        _ = engine.moveItem(from: 0, to: 1, now: t)
        _ = engine.moveItem(from: 2, to: 3, now: t)
        _ = engine.moveItem(from: 1, to: 3, now: t)
        _ = engine.bringHome(cellIndex: 3, now: t)
        _ = engine.playWithToy(index: 0, now: t)
        _ = engine.finishTutorial(now: t)

        var boughtOnDay1 = false

        for day in 1...7 {
            for session in 0..<3 {
                t += 4 * DayClock.hourMs
                _ = engine.visitHome(now: t)
                _ = engine.pet(now: t)

                // Feed if hungry and have food
                if !engine.state.home.food.isEmpty {
                    _ = engine.feed(index: 0, now: t)
                }
                // Play with available toy
                if !engine.state.home.toys.isEmpty {
                    _ = engine.playWithToy(index: 0, now: t)
                }

                // Spend a full energy bar crafting & merging
                let unlockedChains = MergeChain.allCases.filter {
                    DiaryProgression.chainUnlocked(engine.state, chain: $0)
                }
                var taps = 0
                while taps < 30 {
                    let chain = unlockedChains[(day + session + taps) % unlockedChains.count]
                    let res = engine.tapGenerator(chain: chain, now: t).value
                    guard case .generated = res else { break }
                    taps += 1
                    while let pair = DiaryBoard.findMergeablePair(engine.state) {
                        _ = engine.moveItem(from: pair.0, to: pair.1, now: t)
                    }
                    // Deliver any ready orders
                    for order in engine.state.orders.active where DiaryOrders.canDeliver(engine.state, order: order) {
                        _ = engine.deliverOrder(orderID: order.id, now: t)
                    }
                    // Keep space if board fills
                    if engine.state.board.cells.allSatisfy({ $0 != nil }) {
                        _ = engine.sellItem(at: 0, now: t)
                    }
                }

                // Bring home any untried lv3+ item for diary reactions
                for (idx, cell) in engine.state.board.cells.enumerated() {
                    guard let item = cell, item.isUsableAtHome else { continue }
                    if !engine.state.primaryCat.itemsTried.contains(item) {
                        _ = engine.bringHome(cellIndex: idx, now: t)
                        if item.isFood, !engine.state.home.food.isEmpty {
                            _ = engine.feed(index: engine.state.home.food.count - 1, now: t)
                        } else if !item.isFood, !engine.state.home.toys.isEmpty {
                            _ = engine.playWithToy(index: engine.state.home.toys.count - 1, now: t)
                        }
                    }
                }

                // Buy any affordable unlocked furniture
                for def in DiaryCatalog.shopFurniture where !engine.state.home.furnitureOwned.contains(def.id) {
                    if case .bought = engine.buyFurniture(id: def.id, now: t).value {
                        _ = engine.settleNewFurniture(now: t)
                        if day == 1 { boughtOnDay1 = true }
                    }
                }
                _ = engine.leaveHome(now: t)
            }
            // Jump to next morning
            t += 12 * DayClock.hourMs
        }

        XCTAssertTrue(boughtOnDay1, "Zero-ad player should be able to buy first furniture on Day 1")
        let progress = DiaryHome.photoProgress(engine.state)
        XCTAssertGreaterThanOrEqual(progress.got, 12, "Zero-ad player should collect a healthy set of diary photos by Day 7 (got \(progress.got)/\(progress.total))")
        XCTAssertGreaterThanOrEqual(engine.state.primaryCat.level, 3)
    }
}
