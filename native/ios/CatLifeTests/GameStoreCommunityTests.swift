import Foundation
import XCTest
import CatGameCore
@testable import CatLife

final class GameStoreCommunityTests: XCTestCase {
    private let mira = "neighbor_mira"

    @MainActor
    private func makeStore(_ repository: CommunityTestRepository) -> GameStore {
        let suite = "CatLife-community-test-\(UUID())"
        addTeardownBlock { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        return GameStore(repository: repository, reminderDefaults: UserDefaults(suiteName: suite)!)
    }

    private func seed(friendship: Int = 19) -> GameSnapshot {
        var state = GameSnapshot.fresh()
        state.settings.language = .simplifiedChinese
        state.settings.audio.musicEnabled = false
        state.settings.audio.effectsEnabled = false
        state.settings.audio.catEnabled = false
        state.settings.audio.haptics = false
        state.inventory.gifts = ["flower": 2]
        state.community.relationships[mira]?.friendship = friendship
        state.community.relationships[mira]?.rewardedStageLevels = CommunityCatalog.stages
            .filter { $0.level > 1 && $0.minimumPoints <= friendship }.map(\.level)
        return state
    }

    @MainActor
    func testVisitStageRewardStaysUnpublishedOnWriteFailureAndRetryAwardsOnlyOnce() async throws {
        let repository = CommunityTestRepository(seed())
        let store = makeStore(repository)
        await store.load()
        store.enterHome()
        let original = try XCTUnwrap(store.snapshot)
        await repository.setWritesFailing(true)
        let succeeded = await store.visitNeighbor(id: mira)
        XCTAssertFalse(succeeded)
        XCTAssertEqual(store.snapshot, original)
        XCTAssertTrue(store.hasSaveFailure && store.showSaveError)
        let failedAttemptValue = await repository.lastAttempt()
        let failedAttempt = try XCTUnwrap(failedAttemptValue)
        XCTAssertEqual(failedAttempt.community.relationship(for: mira).friendship, 21)
        XCTAssertEqual(failedAttempt.player.gold, original.player.gold + 20)
        XCTAssertEqual(failedAttempt.inventory.food, original.inventory.food + 1)
        XCTAssertEqual(failedAttempt.community.relationship(for: mira).rewardedStageLevels, [2])
        let unchanged = await repository.saved
        XCTAssertEqual(unchanged, original)
        XCTAssertFalse(store.toast?.contains(GameStrings.format("community.visited", 2)) == true)

        await repository.setWritesFailing(false)
        let retried = await store.visitNeighbor(id: mira)
        XCTAssertTrue(retried)
        let committed = try XCTUnwrap(store.snapshot)
        XCTAssertEqual(committed.community.relationship(for: mira).friendship, 21)
        XCTAssertEqual(committed.community.relationship(for: mira).totalVisitCount, 1)
        XCTAssertEqual(committed.community.relationship(for: mira).rewardedStageLevels, [2])
        XCTAssertEqual(committed.player.gold, original.player.gold + 20)
        XCTAssertEqual(committed.inventory.food, original.inventory.food + 1)
        XCTAssertEqual(committed.inventory.gifts, original.inventory.gifts)
        XCTAssertFalse(store.hasSaveFailure || store.showSaveError)
        let duplicateChat = await store.visitNeighbor(id: mira)
        XCTAssertTrue(duplicateChat)
        XCTAssertEqual(store.snapshot?.community, committed.community)
        XCTAssertEqual(store.snapshot?.inventory, committed.inventory)
        XCTAssertEqual(store.snapshot?.player.gold, committed.player.gold)
        let durable = await repository.saved
        XCTAssertEqual(durable.community, committed.community)
        XCTAssertEqual(durable.player.gold, committed.player.gold)
    }

    @MainActor
    func testGiftStageFailurePreservesWalletGiftAndReceiptThenRetryConsumesExactlyOne() async throws {
        let repository = CommunityTestRepository(seed(friendship: 39))
        let store = makeStore(repository)
        await store.load()
        store.enterHome()
        let original = try XCTUnwrap(store.snapshot)
        await repository.setWritesFailing(true)
        let failed = await store.giveNeighborGift(neighborID: mira, giftID: "flower")
        XCTAssertFalse(failed)
        XCTAssertEqual(store.snapshot, original)
        XCTAssertTrue(store.hasSaveFailure && store.showSaveError)
        let attemptValue = await repository.lastAttempt()
        let attempt = try XCTUnwrap(attemptValue)
        XCTAssertEqual(attempt.inventory.giftCount("flower"), 1)
        XCTAssertEqual(attempt.community.relationship(for: mira).friendship, 47)
        XCTAssertEqual(attempt.community.relationship(for: mira).rewardedStageLevels, [2, 3])
        XCTAssertEqual(attempt.player.gold, original.player.gold + 30)
        XCTAssertEqual(attempt.inventory.litter, original.inventory.litter + 1)
        let unchanged = await repository.saved
        XCTAssertEqual(unchanged, original)

        await repository.setWritesFailing(false)
        let retried = await store.giveNeighborGift(neighborID: mira, giftID: "flower")
        XCTAssertTrue(retried)
        let committed = try XCTUnwrap(store.snapshot)
        XCTAssertEqual(committed.inventory.giftCount("flower"), 1)
        XCTAssertEqual(committed.community.relationship(for: mira).friendship, 47)
        XCTAssertEqual(committed.community.relationship(for: mira).giftsGivenToday, 1)
        XCTAssertEqual(committed.community.relationship(for: mira).totalGiftCount, 1)
        XCTAssertEqual(committed.community.relationship(for: mira).rewardedStageLevels, [2, 3])
        XCTAssertEqual(committed.player.gold, original.player.gold + 30)
        XCTAssertEqual(committed.inventory.litter, original.inventory.litter + 1)
        XCTAssertFalse(store.hasSaveFailure)
        let duplicate = await store.giveNeighborGift(neighborID: mira, giftID: "flower")
        XCTAssertFalse(duplicate)
        XCTAssertEqual(store.snapshot?.community, committed.community)
        XCTAssertEqual(store.snapshot?.inventory, committed.inventory)
        XCTAssertEqual(store.snapshot?.player.gold, committed.player.gold)
    }

    @MainActor
    func testGiftPurchaseFailureDoesNotChargeOrAddStockBeforeSuccessfulRetry() async throws {
        let repository = CommunityTestRepository(seed())
        let store = makeStore(repository)
        await store.load()
        let original = try XCTUnwrap(store.snapshot)
        let price = try XCTUnwrap(CommunityCatalog.gift(id: "flower")).price
        await repository.setWritesFailing(true)
        let failed = await store.buyCommunityGift(id: "flower")
        XCTAssertFalse(failed)
        XCTAssertTrue(store.hasSaveFailure)
        XCTAssertEqual(store.snapshot, original)
        let unchanged = await repository.saved
        XCTAssertEqual(unchanged, original)
        await repository.setWritesFailing(false)
        let retried = await store.buyCommunityGift(id: "flower")
        XCTAssertTrue(retried)
        XCTAssertEqual(store.snapshot?.player.gold, original.player.gold - price)
        XCTAssertEqual(store.snapshot?.inventory.giftCount("flower"), original.inventory.giftCount("flower") + 1)
        XCTAssertEqual(store.snapshot?.community, original.community)
        XCTAssertFalse(store.hasSaveFailure)
    }

    @MainActor
    func testLeavingNeighborsDuringPendingSaveStillReportsDurableVisitAndStageReward() async throws {
        let repository = CommunityTestRepository(seed())
        let store = makeStore(repository)
        await store.load()
        store.enterHome()
        store.openNeighbors()
        XCTAssertTrue(store.isShowingNeighbors)
        let original = try XCTUnwrap(store.snapshot)
        await repository.holdNextSave()
        defer { Task { await repository.releaseSave() } }
        let visit = Task { await store.visitNeighbor(id: mira) }
        try await eventually { await repository.isSaveHeld }
        XCTAssertTrue(store.isBusy)
        XCTAssertEqual(store.snapshot, original)
        XCTAssertFalse(store.toast?.contains(GameStrings.format("community.visited", 2)) == true)
        store.activeSheet = .work
        XCTAssertFalse(store.isShowingNeighbors)
        await repository.releaseSave()
        let succeeded = await visit.value
        XCTAssertTrue(succeeded)
        XCTAssertFalse(store.isBusy || store.isShowingNeighbors)
        XCTAssertEqual(store.activeSheet, .work)
        XCTAssertEqual(store.snapshot?.community.relationship(for: mira).friendship, 21)
        XCTAssertEqual(store.snapshot?.player.gold, original.player.gold + 20)
        XCTAssertTrue(store.toast?.contains(GameStrings.format("community.visited", 2)) == true)
        XCTAssertTrue(store.toast?.contains(GameStrings.format("community.stageReached", GameStrings.text("community.stage.2"))) == true)
    }

    @MainActor
    func testImportClosesNeighborNavigationAndPreservesCommunityAndClaimedRewardsWithoutReplay() async throws {
        var incoming = seed(friendship: 39)
        incoming.player.level = 4
        XCTAssertTrue(GameEngine.visitNeighbor(&incoming, neighborID: mira).succeeded)
        XCTAssertTrue(GameEngine.giveNeighborGift(&incoming, neighborID: mira, giftID: "flower").succeeded)
        XCTAssertTrue(GameEngine.claimTask(&incoming, id: "achievement_friend40").succeeded)
        let dayKey = incoming.tasks.dailyDayKey
        XCTAssertTrue(GameEngine.claimTask(&incoming, id: "daily_visit", expectedDayKey: dayKey).succeeded)
        let archive = try NativeSaveTransfer.decode(NativeSaveTransfer.encode(snapshot: incoming))
        let repository = CommunityTestRepository(seed())
        let store = makeStore(repository)
        await store.load()
        store.enterHome()
        store.openNeighbors()
        let generation = store.saveSceneGeneration
        try await store.importSaveArchive(archive)
        XCTAssertFalse(store.isShowingNeighbors)
        XCTAssertNotEqual(store.saveSceneGeneration, generation)
        XCTAssertEqual(store.snapshot?.community, archive.snapshot.community)
        XCTAssertEqual(store.snapshot?.inventory.gifts, archive.snapshot.inventory.gifts)
        XCTAssertEqual(store.snapshot?.tasks.claimedTaskIDs, archive.snapshot.tasks.claimedTaskIDs)
        XCTAssertEqual(store.snapshot?.tasks.dailyClaimedTaskIDs, archive.snapshot.tasks.dailyClaimedTaskIDs)
        let importedGold = try XCTUnwrap(store.snapshot?.player.gold)
        let importedInventory = try XCTUnwrap(store.snapshot?.inventory)
        let alreadyClaimed = await store.claimTask(id: "achievement_friend40")
        XCTAssertFalse(alreadyClaimed)
        let chatted = await store.visitNeighbor(id: mira)
        XCTAssertTrue(chatted)
        let alreadyGifted = await store.giveNeighborGift(neighborID: mira, giftID: "flower")
        XCTAssertFalse(alreadyGifted)
        XCTAssertEqual(store.snapshot?.player.gold, importedGold)
        XCTAssertEqual(store.snapshot?.inventory, importedInventory)
        XCTAssertEqual(store.snapshot?.community, archive.snapshot.community)

        store.openNeighbors()
        try await store.importSaveArchive(archive)
        XCTAssertFalse(store.isShowingNeighbors)
        XCTAssertEqual(store.snapshot?.player.gold, importedGold)
        let reopened = makeStore(repository)
        await reopened.load()
        XCTAssertEqual(reopened.snapshot?.community, archive.snapshot.community)
        XCTAssertEqual(reopened.snapshot?.tasks.claimedTaskIDs, archive.snapshot.tasks.claimedTaskIDs)
        XCTAssertEqual(reopened.snapshot?.tasks.dailyClaimedTaskIDs, archive.snapshot.tasks.dailyClaimedTaskIDs)
        XCTAssertEqual(reopened.snapshot?.inventory, importedInventory)
        XCTAssertEqual(reopened.snapshot?.player.gold, importedGold)
    }

    @MainActor
    private func eventually(_ condition: () async -> Bool) async throws {
        let deadline = Date().addingTimeInterval(3)
        while !(await condition()) {
            if Date() > deadline { throw CommunityTestFailure.timeout }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}

private enum CommunityTestFailure: Error { case storage, timeout }

private actor CommunityTestRepository: GameSaveTransferRepository {
    let lastLoadDisposition = SaveLoadDisposition.loaded
    private(set) var saved: GameSnapshot
    private var recovery: GameSnapshot?
    private var attempts: [GameSnapshot] = []
    private var writesFailing = false
    private var shouldHold = false
    private var heldSave: CheckedContinuation<Void, Never>?
    var isSaveHeld: Bool { heldSave != nil }

    init(_ state: GameSnapshot) { saved = state }
    func setWritesFailing(_ value: Bool) { writesFailing = value }
    func holdNextSave() { shouldHold = true }
    func releaseSave() { heldSave?.resume(); heldSave = nil }
    func lastAttempt() -> GameSnapshot? { attempts.last }
    func checkWritable() throws { if writesFailing { throw CommunityTestFailure.storage } }
    func loadOrCreate(now: Date) -> GameSnapshot { saved }

    func save(_ state: GameSnapshot) async throws {
        attempts.append(state)
        if shouldHold {
            shouldHold = false
            await withCheckedContinuation { heldSave = $0 }
        }
        if writesFailing { throw CommunityTestFailure.storage }
        saved = state
    }

    func importSnapshot(_ state: GameSnapshot) {
        recovery = saved
        saved = state
    }
    func restoreSnapshotAfterLoadFailure(_ state: GameSnapshot) { saved = state }
    func loadImportRecovery() -> GameSnapshot? { recovery }
}
