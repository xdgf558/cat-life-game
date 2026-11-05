import Foundation
import XCTest
import CatGameCore
@testable import CatLife

final class GameStoreSaveTransferTests: XCTestCase {
    @MainActor
    private func makeStore(_ repository: TransferTestRepository) -> GameStore {
        let suite = "CatLife-save-transfer-test-\(UUID())"
        addTeardownBlock { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        return GameStore(repository: repository, reminderDefaults: UserDefaults(suiteName: suite)!)
    }

    private func seed() -> GameSnapshot {
        var state = GameSnapshot.fresh()
        state.settings.audio.musicEnabled = false
        state.settings.audio.effectsEnabled = false
        state.settings.audio.catEnabled = false
        state.settings.audio.haptics = false
        state.settings.language = .simplifiedChinese
        return state
    }

    private func archive(_ state: GameSnapshot) throws -> NativeSaveArchive {
        try NativeSaveTransfer.decode(NativeSaveTransfer.encode(snapshot: state))
    }

    @MainActor
    func testImportPublishesOnlyAfterWriteAndSerializesActionsAndBackgroundSync() async throws {
        let repository = TransferTestRepository(seed())
        let store = makeStore(repository)
        await store.load()
        store.enterHome()
        let original = try XCTUnwrap(store.snapshot)
        let generation = store.saveSceneGeneration
        var incoming = seed()
        incoming.player.gold = 987
        incoming.player.profile.name = "Milo"
        incoming.home.name = "New home"
        let preview = try archive(incoming)
        await repository.holdImports(true)
        let transfer = Task { try await store.importSaveArchive(preview) }
        try await eventually { await repository.importEntered }
        XCTAssertEqual(store.snapshot, original)
        XCTAssertTrue(store.isBusy && store.saveTransferInProgress)
        store.buyFood()
        store.setForeground(false)
        store.setRestingFurniture(id: "catBed", sessionID: "old-scene", catID: original.activeCatID)
        XCTAssertEqual(store.snapshot, original)
        await repository.holdImports(false)
        try await transfer.value
        try await eventually { !store.isBusy }
        XCTAssertEqual(store.snapshot?.player.gold, 987)
        XCTAssertEqual(store.snapshot?.player.profile.name, "Milo")
        XCTAssertNil(store.cat?.activeRest)
        XCTAssertNil(store.restingFurnitureID)
        XCTAssertNotEqual(store.saveSceneGeneration, generation)
        XCTAssertFalse(store.saveTransferInProgress)
        let recovery = try await store.importRecoveryPreview()
        XCTAssertEqual(recovery?.snapshot, try archive(original).snapshot)
        let durable = await repository.saved
        XCTAssertEqual(durable.player.gold, 987)
        XCTAssertTrue(store.toast?.contains(GameStrings.text("saveTransfer.imported")) == true)
    }

    @MainActor
    func testFailedImportKeepsPublishedProgressRecoveryAndRoomIdentity() async throws {
        let repository = TransferTestRepository(seed())
        let store = makeStore(repository)
        await store.load()
        store.enterHome()
        let original = try XCTUnwrap(store.snapshot)
        let generation = store.saveSceneGeneration
        var incoming = seed()
        incoming.player.gold = 999
        await repository.setImportFailure(true)
        do {
            try await store.importSaveArchive(archive(incoming))
            XCTFail("A failed replacement must throw")
        } catch { XCTAssertEqual(error as? SaveTransferError, .writeFailed) }
        XCTAssertEqual(store.snapshot, original)
        XCTAssertEqual(store.saveSceneGeneration, generation)
        XCTAssertFalse(store.isBusy || store.saveTransferInProgress)
        XCTAssertFalse(store.hasSaveFailure, "Do not schedule an unconfirmed automatic import retry")
        let recovery = try await store.importRecoveryPreview()
        XCTAssertNil(recovery)
        XCTAssertTrue(store.toast?.contains(GameStrings.text("saveTransfer.writeFailed")) == true)
        let durable = await repository.saved
        XCTAssertEqual(durable, original)
    }

    @MainActor
    func testImportClearsOldFailedAudioIntentAndRestoresLanguage() async throws {
        let repository = TransferTestRepository(seed())
        let store = makeStore(repository)
        await store.load()
        await repository.setSaveFailure(true)
        var staleAudio = store.audioSettings
        staleAudio.musicVolume = 0.7
        let changed = await store.updateAudioSettings(staleAudio)
        XCTAssertFalse(changed)
        XCTAssertNotNil(store.pendingAudioSettings)
        var incoming = seed()
        incoming.settings.audio.musicVolume = 0.2
        incoming.settings.language = .english
        await repository.setSaveFailure(false)
        try await store.importSaveArchive(archive(incoming))
        try await eventually { !store.isBusy }
        XCTAssertNil(store.pendingAudioSettings)
        XCTAssertFalse(store.audioSettingsSaveFailed)
        XCTAssertEqual(store.audioSettings.musicVolume, 0.2)
        XCTAssertEqual(store.language, .english)
        XCTAssertEqual(GameLocalization.shared.language, .english)
        let durable = await repository.saved
        XCTAssertEqual(durable.settings.audio.musicVolume, 0.2)
        XCTAssertFalse(store.hasSaveFailure)
    }

    @MainActor
    func testRepeatedImportSettlesWorkOnceAndKeepsClaimedTaskReceiptAndRecoveryWorks() async throws {
        let repository = TransferTestRepository(seed())
        let store = makeStore(repository)
        await store.load()
        let originalGold = try XCTUnwrap(store.snapshot).player.gold
        let past = Date().addingTimeInterval(-300)
        var incoming = GameSnapshot.fresh(now: past)
        incoming.settings = seed().settings
        XCTAssertTrue(GameEngine.feed(&incoming, catID: incoming.activeCatID, now: past).succeeded)
        XCTAssertTrue(GameEngine.claimTask(&incoming, id: "tutorial_feed", now: past).succeeded)
        XCTAssertTrue(GameEngine.startWork(&incoming, now: past).succeeded)
        let preview = try archive(incoming)
        try await store.importSaveArchive(preview)
        let first = try XCTUnwrap(store.snapshot)
        XCTAssertNil(first.player.activeWork)
        XCTAssertEqual(first.player.completedWorkCount, 1)
        XCTAssertNotNil(first.player.lastWorkResult)
        let beforeImportValue = try await store.importRecoveryPreview()
        let beforeImport = try XCTUnwrap(beforeImportValue)
        XCTAssertEqual(beforeImport.snapshot.player.gold, originalGold)
        try await store.importSaveArchive(preview)
        XCTAssertEqual(store.snapshot?.player.gold, first.player.gold)
        XCTAssertEqual(store.snapshot?.player.completedWorkCount, 1)
        let reclaimed = await store.claimTask(id: "tutorial_feed")
        XCTAssertFalse(reclaimed)
        XCTAssertEqual(store.snapshot?.player.gold, first.player.gold)
        try await store.importSaveArchive(beforeImport, isRecovery: true)
        XCTAssertEqual(store.snapshot?.player.gold, originalGold)
        XCTAssertEqual(store.snapshot?.player.completedWorkCount, 0)
        let undoRestoreValue = try await store.importRecoveryPreview()
        let undoRestore = try XCTUnwrap(undoRestoreValue)
        XCTAssertEqual(undoRestore.snapshot.player.gold, first.player.gold)
    }

    @MainActor
    func testExportMatchesDurableProgressWithoutCreatingRecoveryPoint() async throws {
        let repository = TransferTestRepository(seed())
        let store = makeStore(repository)
        await store.load()
        let renamed = await store.setHomeName("Sunny home")
        XCTAssertTrue(renamed)
        let data = try await store.exportSaveArchive()
        let exported = try NativeSaveTransfer.decode(data)
        let durable = await repository.saved
        XCTAssertEqual(exported.snapshot.home.name, "Sunny home")
        XCTAssertEqual(exported.snapshot, try archive(durable).snapshot)
        XCTAssertEqual(exported.snapshot.inventory, durable.inventory)
        let recovery = try await store.importRecoveryPreview()
        XCTAssertNil(recovery)
        XCTAssertFalse(store.isBusy || store.saveTransferInProgress)
    }

    @MainActor
    private func eventually(_ condition: () async -> Bool) async throws {
        let deadline = Date().addingTimeInterval(3)
        while !(await condition()) {
            if Date() > deadline { throw WaitError.timeout }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    private enum WaitError: Error { case timeout }
}

private actor TransferTestRepository: GameSaveTransferRepository {
    let lastLoadDisposition = SaveLoadDisposition.loaded
    private(set) var saved: GameSnapshot
    private var recovery: GameSnapshot?
    private var saveFails = false
    private var importFails = false
    private var held = false
    private(set) var importEntered = false

    init(_ state: GameSnapshot) { saved = state }
    func loadOrCreate(now: Date) -> GameSnapshot { saved }
    func setSaveFailure(_ fails: Bool) { saveFails = fails }
    func setImportFailure(_ fails: Bool) { importFails = fails }
    func holdImports(_ hold: Bool) { held = hold }
    func checkWritable() throws { if saveFails { throw Failure.storage } }
    func save(_ state: GameSnapshot) throws {
        if saveFails { throw Failure.storage }
        saved = state
    }
    func importSnapshot(_ state: GameSnapshot) async throws {
        importEntered = true
        while held { try await Task.sleep(for: .milliseconds(10)) }
        if importFails { throw Failure.storage }
        recovery = saved
        saved = state
    }
    func loadImportRecovery() -> GameSnapshot? { recovery }
    private enum Failure: Error { case storage }
}
