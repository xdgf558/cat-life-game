import Foundation
import XCTest
import CatGameCore
@testable import CatLife

final class GameStoreExchangeTests: XCTestCase {
    @MainActor
    private func makeStore(_ repository: ExchangeTestRepository) -> GameStore {
        let suite = "CatLife-exchange-test-\(UUID())"
        addTeardownBlock { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        return GameStore(repository: repository, reminderDefaults: UserDefaults(suiteName: suite)!)
    }

    private func seed(friendship: Int = 0, neighborID: String = "neighbor_mira") -> GameSnapshot {
        var state = GameSnapshot.fresh()
        state.inventory.food = 8
        state.community.relationships[neighborID]?.friendship = friendship
        state.community.relationships[neighborID]?.rewardedStageLevels = CommunityCatalog.stages
            .filter { $0.level > 1 && $0.minimumPoints <= friendship }.map(\.level)
        state.settings.language = .simplifiedChinese
        state.settings.audio.musicEnabled = false
        state.settings.audio.effectsEnabled = false
        state.settings.audio.catEnabled = false
        state.settings.audio.haptics = false
        return state
    }

    @MainActor
    func testFailedExchangeKeepsSuppliesAndDailyCountUntilSuccessfulRetry() async throws {
        let repository = ExchangeTestRepository(seed(friendship: 19))
        let store = makeStore(repository)
        await store.load()
        store.enterHome()
        let original = try XCTUnwrap(store.snapshot)
        await repository.setWritesFailing(true)
        var presentations = 0
        let failed = await store.exchange(offerID: "mira_food", presentResult: { _ in
            presentations += 1
            return true
        })
        XCTAssertNil(failed)
        XCTAssertEqual(presentations, 0)
        XCTAssertEqual(store.snapshot, original)
        let unchanged = await repository.savedState()
        XCTAssertEqual(unchanged, original)
        XCTAssertTrue(store.hasSaveFailure && store.showSaveError)
        XCTAssertFalse(store.toast?.contains(GameStrings.format("market.completedWithFriendship", 2)) == true)

        await repository.setWritesFailing(false)
        let retried = await store.exchange(offerID: "mira_food")
        XCTAssertNotNil(retried)
        XCTAssertEqual(retried?.stageReached?.level, 2)
        XCTAssertEqual(retried?.foodAwarded, 1)
        XCTAssertEqual(store.snapshot?.inventory.food, original.inventory.food - 1)
        XCTAssertEqual(store.snapshot?.inventory.premiumFood, original.inventory.premiumFood + 1)
        XCTAssertEqual(store.snapshot?.community.exchangeCount(for: "neighbor_mira").today, 1)
        XCTAssertEqual(store.snapshot?.community.totalExchangeCount, 1)
        let committed = await repository.savedState()
        XCTAssertEqual(committed, store.snapshot)
        XCTAssertFalse(store.hasSaveFailure)
        XCTAssertTrue(store.toast?.contains(GameStrings.format("market.completedWithFriendship", 2)) == true)
    }

    @MainActor
    func testPendingExchangeRejectsDoubleTapAndReportsSuccessAfterLeavingMarket() async throws {
        let repository = ExchangeTestRepository(seed(friendship: 19))
        let store = makeStore(repository)
        await store.load()
        store.enterHome()
        store.openExchangeMarket()
        XCTAssertTrue(store.isShowingMarket)
        let original = try XCTUnwrap(store.snapshot)
        await repository.holdNextSave()
        defer { Task { await repository.releaseSave() } }
        var presentationAttempts = 0
        let first = Task {
            await store.exchange(offerID: "mira_food", presentResult: { _ in
                presentationAttempts += 1
                return store.isShowingMarket
            })
        }
        try await eventually { await repository.isSaveHeld }
        XCTAssertTrue(store.isBusy)
        XCTAssertEqual(presentationAttempts, 0)
        XCTAssertEqual(store.snapshot, original)
        let duplicate = await store.exchange(offerID: "mira_food")
        XCTAssertNil(duplicate)
        store.activeSheet = .work
        XCTAssertFalse(store.isShowingMarket)
        await repository.releaseSave()
        let succeeded = await first.value
        XCTAssertNotNil(succeeded)
        XCTAssertEqual(succeeded?.stageReached?.level, 2)
        XCTAssertEqual(presentationAttempts, 1)
        XCTAssertEqual(store.snapshot?.inventory.food, original.inventory.food - 1)
        XCTAssertEqual(store.snapshot?.community.totalExchangeCount, 1)
        XCTAssertTrue(store.toast?.contains(GameStrings.format("market.completedWithFriendship", 2)) == true)
        XCTAssertTrue(store.toast?.contains(GameStrings.format("community.stageReached", GameStrings.text("community.stage.2"))) == true)
        XCTAssertTrue(store.toast?.contains(GameStrings.format("community.rewardFood", 1)) == true)
    }

    @MainActor
    func testMissingOfferFullFriendshipAndFullRewardCapacityHaveAccurateFeedback() async throws {
        let missing = makeStore(ExchangeTestRepository(seed()))
        await missing.load()
        missing.enterHome()
        let original = try XCTUnwrap(missing.snapshot)
        var presentations = 0
        let absent = await missing.exchange(offerID: "retired_offer", presentResult: { _ in
            presentations += 1
            return true
        })
        XCTAssertNil(absent)
        XCTAssertEqual(presentations, 0)
        XCTAssertEqual(missing.snapshot?.inventory, original.inventory)
        XCTAssertEqual(missing.snapshot?.community, original.community)
        XCTAssertTrue(missing.toast?.contains(GameStrings.text("market.error.missing")) == true)

        let closest = makeStore(ExchangeTestRepository(seed(friendship: 100)))
        await closest.load()
        closest.enterHome()
        let fullFriendship = await closest.exchange(offerID: "mira_food")
        XCTAssertEqual(fullFriendship?.friendshipGained, 0)
        XCTAssertNil(fullFriendship?.stageReached)
        XCTAssertTrue(closest.toast?.contains(GameStrings.text("market.exchanged")) == true)
        XCTAssertFalse(closest.toast?.contains("+0") == true)
        XCTAssertEqual(closest.snapshot?.community.totalExchangeCount, 1)

        var initial = seed(friendship: 19, neighborID: "neighbor_grace")
        initial.player.gold = 1_000_000_000
        initial.inventory.food = GameSnapshot.maximumStock - 2
        initial.inventory.gifts = ["cat_snack": 1]
        let capped = makeStore(ExchangeTestRepository(initial))
        await capped.load()
        capped.enterHome()
        let result = await capped.exchange(offerID: "grace_pantry")
        let receipt = try XCTUnwrap(result)
        XCTAssertEqual(receipt.stageReached?.level, 2)
        XCTAssertEqual(receipt.goldAwarded + receipt.foodAwarded + receipt.litterAwarded + receipt.toyUsesAwarded, 0)
        XCTAssertEqual(capped.snapshot?.inventory.food, GameSnapshot.maximumStock)
        XCTAssertTrue(capped.toast?.contains(GameStrings.text("community.relationshipUpgraded")) == true)
        XCTAssertTrue(capped.toast?.contains(GameStrings.text("community.stage.2")) == true)
        XCTAssertTrue(capped.toast?.contains(GameStrings.text("community.rewardAtCapacity")) == true)
        XCTAssertFalse(capped.toast?.contains(GameStrings.format("community.stageReached", GameStrings.text("community.stage.2"))) == true)
    }

    @MainActor
    func testStageReceiptExcludesTradeInputsAndOutputsAndDoesNotRepeatStageRewards() async throws {
        let cases: [(offerID: String, friendship: Int, gold: Int, food: Int, litter: Int, toys: Int)] = [
            ("mira_food", 19, 20, 1, 0, 0),
            ("grace_pantry", 19, 20, 1, 0, 0),
            ("luna_litter", 39, 30, 0, 1, 0),
            ("ken_picnic", 79, 60, 0, 0, 6)
        ]
        for item in cases {
            let offer = try XCTUnwrap(ExchangeCatalog.offer(id: item.offerID))
            var initial = seed(friendship: item.friendship, neighborID: offer.neighborID)
            initial.inventory.litter = 8
            initial.inventory.toys = 12
            initial.inventory.gifts = ["cat_snack": 2]
            let repository = ExchangeTestRepository(initial)
            let store = makeStore(repository)
            await store.load()
            let result = await store.exchange(offerID: offer.id)
            let receipt = try XCTUnwrap(result, offer.id)
            XCTAssertEqual(receipt.neighborID, offer.neighborID, offer.id)
            XCTAssertEqual(receipt.friendshipGained, 2, offer.id)
            XCTAssertEqual(receipt.stageReached?.level,
                           CommunityCatalog.stage(friendship: item.friendship + 2).level, offer.id)
            XCTAssertEqual(receipt.goldAwarded, item.gold, offer.id)
            XCTAssertEqual(receipt.foodAwarded, item.food, offer.id)
            XCTAssertEqual(receipt.litterAwarded, item.litter, offer.id)
            XCTAssertEqual(receipt.toyUsesAwarded, item.toys, offer.id)
            let saved = await repository.savedState()
            XCTAssertEqual(saved, store.snapshot)

            let repeated = await store.exchange(offerID: offer.id)
            let next = try XCTUnwrap(repeated, offer.id)
            XCTAssertNil(next.stageReached, offer.id)
            XCTAssertEqual(next.goldAwarded + next.foodAwarded + next.litterAwarded + next.toyUsesAwarded,
                           0, "A second trade is not another stage reward: \(offer.id)")
        }
    }

    @MainActor
    func testStageReceiptReportsOnlyRewardCapacityRemainingAfterTrade() async throws {
        var initial = seed(friendship: 79, neighborID: "neighbor_ken")
        initial.player.gold = 1_000_000_000 - 7
        initial.inventory.toys = GameSnapshot.maximumStock - 8
        initial.inventory.gifts = ["drink": 1]
        let store = makeStore(ExchangeTestRepository(initial))
        await store.load()
        let result = await store.exchange(offerID: "ken_toy")
        let receipt = try XCTUnwrap(result)
        XCTAssertEqual(receipt.stageReached?.level, 5)
        XCTAssertEqual(receipt.goldAwarded, 7)
        XCTAssertEqual(receipt.foodAwarded, 0)
        XCTAssertEqual(receipt.litterAwarded, 0)
        XCTAssertEqual(receipt.toyUsesAwarded, 2, "Six traded toy uses are separate from the two reward uses that fit.")
        XCTAssertEqual(store.snapshot?.inventory.toys, GameSnapshot.maximumStock)
        XCTAssertEqual(store.snapshot?.player.gold, 1_000_000_000)
    }

    @MainActor
    func testVisibleStageResultWaitsForSaveAndSuppressesDuplicateToast() async throws {
        let repository = ExchangeTestRepository(seed(friendship: 19))
        let store = makeStore(repository)
        await store.load()
        store.enterHome()
        store.openExchangeMarket()
        let original = store.snapshot
        var presentations: [NeighborActionReceipt] = []
        await repository.holdNextSave()
        defer { Task { await repository.releaseSave() } }
        let exchange = Task {
            await store.exchange(offerID: "mira_food", presentResult: { receipt in
                XCTAssertEqual(store.snapshot?.community.relationship(for: "neighbor_mira").friendship, 21)
                presentations.append(receipt)
                return true
            })
        }
        try await eventually { await repository.isSaveHeld }
        XCTAssertTrue(presentations.isEmpty)
        XCTAssertEqual(store.snapshot, original)
        await repository.releaseSave()
        let receipt = await exchange.value
        XCTAssertEqual(presentations, [try XCTUnwrap(receipt)])
        XCTAssertEqual(receipt?.stageReached?.level, 2)
        XCTAssertFalse(store.toast?.contains(GameStrings.format("market.completedWithFriendship", 2)) == true)
        XCTAssertFalse(store.toast?.contains(GameStrings.format("community.stageReached", GameStrings.text("community.stage.2"))) == true)
    }

    @MainActor
    func testDismissedStageResultCanFallbackButCannotReplayAfterImport() async throws {
        let store = makeStore(ExchangeTestRepository(seed(friendship: 19)))
        await store.load()
        store.enterHome()
        let result = await store.exchange(offerID: "mira_food", presentResult: { _ in true })
        let receipt = try XCTUnwrap(result)
        store.showNeighborActionResult(receipt)
        XCTAssertTrue(store.toast?.contains(GameStrings.format("community.stageReached", GameStrings.text("community.stage.2"))) == true)

        let archive = try NativeSaveTransfer.decode(NativeSaveTransfer.encode(snapshot: seed()))
        try await store.importSaveArchive(archive)
        let importNotice = store.toast
        XCTAssertNotEqual(receipt.saveSceneGeneration, store.saveSceneGeneration)
        store.showNeighborActionResult(receipt)
        XCTAssertEqual(store.toast, importNotice)
    }

    @MainActor
    func testTaskDestinationOpensMarketAndLockedPreviewUsesTranslatedStage() async throws {
        let store = makeStore(ExchangeTestRepository(seed()))
        await store.load()
        store.enterHome()
        store.goToTaskDestination(.market)
        XCTAssertEqual(store.activeSheet, .town)
        XCTAssertTrue(store.isShowingMarket)
        XCTAssertFalse(store.isShowingNeighbors)
        let offer = try XCTUnwrap(ExchangeCatalog.offer(id: "mira_feast"))
        let snapshot = try XCTUnwrap(store.snapshot)
        let previousLanguage = GameLocalization.shared.language
        defer { GameLocalization.shared.language = previousLanguage }
        for language in [GameLanguage.simplifiedChinese, .traditionalChinese, .english] {
            GameLocalization.shared.language = language
            let status = ExchangePresentation.status(offer, snapshot: snapshot)
            XCTAssertFalse(status.contains("market."))
            XCTAssertTrue(status.contains(GameStrings.text("community.stage.3")))
            XCTAssertFalse(GameActionNotice.message(for: .init(success: .exchanged), snapshot: snapshot).contains("market."))
            XCTAssertFalse(GameStrings.format("market.completedWithFriendship", 2).contains("market."))
        }
    }

    @MainActor
    private func eventually(_ condition: () async -> Bool) async throws {
        let deadline = Date().addingTimeInterval(3)
        while !(await condition()) {
            if Date() > deadline { throw ExchangeTestFailure.timeout }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}

private enum ExchangeTestFailure: Error { case storage, timeout }

private actor ExchangeTestRepository: GameSaveTransferRepository {
    let lastLoadDisposition = SaveLoadDisposition.loaded
    private var saved: GameSnapshot
    private var writesFailing = false
    private var shouldHold = false
    private var heldSave: CheckedContinuation<Void, Never>?
    var isSaveHeld: Bool { heldSave != nil }
    init(_ state: GameSnapshot) { saved = state }
    func savedState() -> GameSnapshot { saved }
    func setWritesFailing(_ value: Bool) { writesFailing = value }
    func holdNextSave() { shouldHold = true }
    func releaseSave() { heldSave?.resume(); heldSave = nil }
    func checkWritable() throws { if writesFailing { throw ExchangeTestFailure.storage } }
    func loadOrCreate(now: Date) -> GameSnapshot { saved }
    func importSnapshot(_ state: GameSnapshot) { saved = state }
    func restoreSnapshotAfterLoadFailure(_ state: GameSnapshot) { saved = state }
    func loadImportRecovery() -> GameSnapshot? { nil }
    func save(_ state: GameSnapshot) async throws {
        if shouldHold {
            shouldHold = false
            await withCheckedContinuation { heldSave = $0 }
        }
        if writesFailing { throw ExchangeTestFailure.storage }
        saved = state
    }
}
