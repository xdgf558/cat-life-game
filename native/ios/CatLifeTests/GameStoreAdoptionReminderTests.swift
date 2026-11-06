import Foundation
import XCTest
import CatGameCore
@testable import CatLife

final class GameStoreAdoptionReminderTests: XCTestCase {
    @MainActor
    func testFailedRoomUpgradeCannotNotifyOrConsumeReminderAndRetryCan() async throws {
        let defaults = try isolatedDefaults()
        let repository = AdoptionReminderSaveRepository(upgradeSeed())
        let store = GameStore(repository: repository, reminderDefaults: defaults)
        await makeLive(store)
        defer { store.setForeground(false) }
        try await eventually { !store.isBusy }
        let original = try XCTUnwrap(store.snapshot)
        await repository.setWritesFailing(true)

        store.upgradeHome(toLevel: 2)
        try await eventually { !store.isBusy && store.hasSaveFailure }
        XCTAssertEqual(store.snapshot, original)
        XCTAssertNil(store.adoptionReminders.pendingOffer)
        XCTAssertNil(defaults.stringArray(forKey: GameAdoptionReminderCenter.presentedIDsKey))
        let lastAttempt = await repository.lastAttempt
        let rejected = try XCTUnwrap(lastAttempt)
        XCTAssertEqual(rejected.home.roomLevel, 2, "The failed write must be the qualifying upgrade.")
        XCTAssertEqual(rejected.player.gold, 550)

        await repository.setWritesFailing(false)
        store.upgradeHome(toLevel: 2)
        try await eventually { !store.isBusy && store.snapshot?.home.roomLevel == 2 }
        XCTAssertEqual(store.adoptionReminders.pendingOffer?.id, CatCatalog.cowCatID)
        XCTAssertNil(defaults.stringArray(forKey: GameAdoptionReminderCenter.presentedIDsKey),
                     "A durable upgrade queues the notice without pretending it was displayed.")
        store.adoptionReminders.markPresented(CatCatalog.cowCatID)
        XCTAssertEqual(defaults.stringArray(forKey: GameAdoptionReminderCenter.presentedIDsKey), [CatCatalog.cowCatID])
        store.setForeground(false)
        XCTAssertNil(store.adoptionReminders.pendingOffer)
        XCTAssertEqual(defaults.stringArray(forKey: GameAdoptionReminderCenter.presentedIDsKey), [CatCatalog.cowCatID])
    }

    @MainActor
    func testOfflineWorkUpgradeWaitsForHomeBeforeQueuingUnseenReminder() async throws {
        let defaults = try isolatedDefaults()
        let repository = AdoptionReminderSaveRepository(completedWorkSeed())
        let store = GameStore(repository: repository, reminderDefaults: defaults)
        store.setForeground(true)
        defer { store.setForeground(false) }
        await store.load()
        XCTAssertEqual(store.snapshot?.player.level, 3)
        XCTAssertEqual(store.snapshot?.player.gold, 350)
        XCTAssertNil(store.snapshot?.player.activeWork)
        XCTAssertNil(store.adoptionReminders.pendingOffer)
        XCTAssertNil(defaults.stringArray(forKey: GameAdoptionReminderCenter.presentedIDsKey))
        store.enterHome()
        XCTAssertEqual(store.adoptionReminders.pendingOffer?.id, CatCatalog.cowCatID)
        XCTAssertNil(defaults.stringArray(forKey: GameAdoptionReminderCenter.presentedIDsKey),
                     "Entering the room can queue a reminder, but only its visible banner records presentation.")
    }

    @MainActor
    func testFailedOfflineWorkSettlementQueuesReminderOnlyAfterSuccessfulRetry() async throws {
        let defaults = try isolatedDefaults()
        let repository = AdoptionReminderSaveRepository(completedWorkSeed(), writesFailing: true)
        let store = GameStore(repository: repository, reminderDefaults: defaults)
        await store.load()
        XCTAssertTrue(store.hasSaveFailure)
        XCTAssertEqual(store.snapshot?.player.level, 2)
        store.enterHome()
        store.setForeground(true)
        defer { store.setForeground(false) }
        XCTAssertNil(store.adoptionReminders.pendingOffer)
        XCTAssertNil(defaults.stringArray(forKey: GameAdoptionReminderCenter.presentedIDsKey))
        await repository.setWritesFailing(false)
        store.retrySaving()
        try await eventually { !store.isBusy && !store.hasSaveFailure && store.snapshot?.player.level == 3 }
        XCTAssertEqual(store.snapshot?.player.gold, 350)
        XCTAssertEqual(store.adoptionReminders.pendingOffer?.id, CatCatalog.cowCatID)
        XCTAssertNil(defaults.stringArray(forKey: GameAdoptionReminderCenter.presentedIDsKey))
    }

    @MainActor
    func testUpgradeSavedInBackgroundQueuesUnseenReminderOnReturn() async throws {
        let defaults = try isolatedDefaults()
        let repository = AdoptionReminderSaveRepository(upgradeSeed())
        let store = GameStore(repository: repository, reminderDefaults: defaults)
        await makeLive(store)
        defer { store.setForeground(false); Task { await repository.releaseSave() } }
        try await eventually { !store.isBusy }
        await repository.holdNextSave()
        store.upgradeHome(toLevel: 2)
        try await eventually { await repository.isSaveBlocked }
        XCTAssertNil(store.adoptionReminders.pendingOffer)
        store.setForeground(false)
        await repository.releaseSave()
        try await eventually { !store.isBusy && store.snapshot?.home.roomLevel == 2 }
        XCTAssertNil(store.adoptionReminders.pendingOffer)
        store.setForeground(true)
        try await eventually { !store.isBusy }
        XCTAssertEqual(store.snapshot?.player.gold, 550)
        XCTAssertEqual(store.adoptionReminders.pendingOffer?.id, CatCatalog.cowCatID)
        XCTAssertNil(defaults.stringArray(forKey: GameAdoptionReminderCenter.presentedIDsKey))
    }

    @MainActor
    func testEarningGoldAfterRoomUpgradeQueuesBlueCatOnlyAfterRewardIsSaved() async throws {
        let defaults = try isolatedDefaults()
        var seed = upgradeSeed()
        seed.player.level = 4
        seed.home.roomLevel = 2
        seed.player.gold = 1_499
        seed.tasks.totalFeedCount = 1
        seed.cats.append(CatState(id: CatCatalog.cowCatID, name: "牛奶", now: seed.meta.lastSyncAt, appearance: .cow))
        let repository = AdoptionReminderSaveRepository(seed)
        let store = GameStore(repository: repository, reminderDefaults: defaults)
        await makeLive(store)
        defer { store.setForeground(false) }
        try await eventually { !store.isBusy }

        store.upgradeHome(toLevel: 3)
        try await eventually { !store.isBusy && store.snapshot?.home.roomLevel == 3 }
        XCTAssertEqual(store.snapshot?.player.gold, 599)
        XCTAssertNil(store.adoptionReminders.pendingOffer)
        await repository.setWritesFailing(true)
        let failedReceipt = await store.claimTaskWithReceipt(id: "tutorial_feed")
        XCTAssertNil(failedReceipt)
        XCTAssertEqual(store.snapshot?.player.gold, 599)
        XCTAssertNil(store.adoptionReminders.pendingOffer)

        await repository.setWritesFailing(false)
        let receipt = await store.claimTaskWithReceipt(id: "tutorial_feed")
        XCTAssertNotNil(receipt)
        XCTAssertEqual(store.snapshot?.player.gold, 619)
        XCTAssertEqual(store.snapshot?.player.level, 4, "A level increase must not be required to restore the reminder.")
        XCTAssertEqual(store.snapshot?.home.roomLevel, 3)
        XCTAssertEqual(store.adoptionReminders.pendingOffer?.id, CatCatalog.blueCatID)
        XCTAssertNil(defaults.stringArray(forKey: GameAdoptionReminderCenter.presentedIDsKey))
    }

    @MainActor
    func testBackgroundReturnRestoresUndisplayedSecondOfferWithoutAnotherSaveOrUpgrade() async throws {
        let defaults = try isolatedDefaults()
        var seed = upgradeSeed()
        seed.player.level = 4
        seed.home.roomLevel = 3
        seed.player.gold = 2_000
        let repository = AdoptionReminderSaveRepository(seed)
        let store = GameStore(repository: repository, reminderDefaults: defaults)
        await makeLive(store)
        defer { store.setForeground(false) }
        try await eventually { !store.isBusy }
        XCTAssertEqual(store.adoptionReminders.pendingOffer?.id, CatCatalog.cowCatID)
        store.adoptionReminders.markPresented(CatCatalog.cowCatID)
        store.adoptionReminders.dismiss(CatCatalog.cowCatID)
        XCTAssertEqual(store.adoptionReminders.pendingOffer?.id, CatCatalog.blueCatID)
        let savedBeforeBackground = try XCTUnwrap(store.snapshot)
        let saveCount = await repository.saveCount

        store.setForeground(false)
        XCTAssertNil(store.adoptionReminders.pendingOffer)
        store.setForeground(true)
        try await eventually { !store.isBusy }

        XCTAssertEqual(store.snapshot, savedBeforeBackground)
        let savesAfterReturn = await repository.saveCount
        XCTAssertEqual(savesAfterReturn, saveCount, "A timestamp-only return must not need another disk write to restore the queue.")
        XCTAssertEqual(store.adoptionReminders.pendingOffer?.id, CatCatalog.blueCatID)
        XCTAssertEqual(defaults.stringArray(forKey: GameAdoptionReminderCenter.presentedIDsKey), [CatCatalog.cowCatID])
    }

    @MainActor
    func testOpeningAdoptionReminderLeavesNeighborPageEvenWithinTheSameTownTab() async throws {
        var seed = upgradeSeed()
        seed.home.roomLevel = 2
        seed.player.gold = 299
        seed.community.relationships["neighbor_mira"]?.friendship = 19
        let store = GameStore(repository: AdoptionReminderSaveRepository(seed), reminderDefaults: try isolatedDefaults())
        await makeLive(store)
        defer { store.setForeground(false) }
        try await eventually { !store.isBusy }
        XCTAssertNil(store.adoptionReminders.pendingOffer)
        store.openNeighbors()
        XCTAssertEqual(store.activeSheet, .town)
        XCTAssertTrue(store.isShowingNeighbors)

        let visited = await store.visitNeighbor(id: "neighbor_mira")
        XCTAssertTrue(visited)
        XCTAssertEqual(store.adoptionReminders.pendingOffer?.id, CatCatalog.cowCatID)
        let saved = store.snapshot
        store.adoptionReminders.markPresented(CatCatalog.cowCatID)
        store.adoptionReminders.dismiss(CatCatalog.cowCatID)
        store.openCatCollection(filter: .unowned, adoptionID: CatCatalog.cowCatID)

        XCTAssertEqual(store.activeSheet, .town)
        XCTAssertFalse(store.isShowingNeighbors)
        XCTAssertEqual(store.catCollectionFilter, .unowned)
        XCTAssertEqual(store.adoptionCatID, CatCatalog.cowCatID)
        XCTAssertEqual(store.snapshot, saved)
    }

    @MainActor
    private func makeLive(_ store: GameStore) async {
        await store.load()
        store.enterHome()
        store.setForeground(true)
    }

    private func upgradeSeed() -> GameSnapshot {
        var seed = GameSnapshot.fresh()
        seed.settings.audio = AudioSettings(musicEnabled: false, effectsEnabled: false, catEnabled: false, haptics: false)
        seed.player.level = 2
        seed.player.gold = 1_000
        return seed
    }

    private func completedWorkSeed() -> GameSnapshot {
        let started = Date().addingTimeInterval(-130)
        var seed = GameSnapshot.fresh(now: started)
        seed.settings.audio = AudioSettings(musicEnabled: false, effectsEnabled: false, catEnabled: false, haptics: false)
        seed.player.level = 2
        seed.player.exp = 190
        seed.player.gold = 290
        seed.home.roomLevel = 2
        seed.player.activeWork = ActiveWork(startedAt: started, endsAt: started.addingTimeInterval(120))
        return seed
    }

    private func isolatedDefaults() throws -> UserDefaults {
        let name = "CatLife-Store-AdoptionReminders-Tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        addTeardownBlock { UserDefaults(suiteName: name)?.removePersistentDomain(forName: name) }
        return defaults
    }

    @MainActor
    private func eventually(_ condition: @MainActor () async -> Bool) async throws {
        let deadline = Date().addingTimeInterval(4)
        while Date() < deadline {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("The adoption reminder transaction did not settle.")
        throw AdoptionReminderSaveError.timedOut
    }
}

private enum AdoptionReminderSaveError: Error { case unavailable, timedOut }

private actor AdoptionReminderSaveRepository: GameSaveRepository {
    let lastLoadDisposition = SaveLoadDisposition.loaded
    private var saved: GameSnapshot
    private var writesFailing: Bool
    private var shouldHold = false
    private var heldSave: CheckedContinuation<Void, Never>?
    private(set) var lastAttempt: GameSnapshot?
    private(set) var saveCount = 0
    var isSaveBlocked: Bool { heldSave != nil }

    init(_ snapshot: GameSnapshot, writesFailing: Bool = false) {
        saved = snapshot
        self.writesFailing = writesFailing
    }

    func setWritesFailing(_ value: Bool) { writesFailing = value }
    func holdNextSave() { shouldHold = true }
    func releaseSave() { heldSave?.resume(); heldSave = nil }
    func loadOrCreate(now: Date) async throws -> GameSnapshot { saved }
    func checkWritable() throws { if writesFailing { throw AdoptionReminderSaveError.unavailable } }

    func save(_ snapshot: GameSnapshot) async throws {
        lastAttempt = snapshot
        let fails = writesFailing
        if shouldHold {
            shouldHold = false
            await withCheckedContinuation { heldSave = $0 }
        }
        if fails { throw AdoptionReminderSaveError.unavailable }
        saved = snapshot
        saveCount += 1
    }
}
