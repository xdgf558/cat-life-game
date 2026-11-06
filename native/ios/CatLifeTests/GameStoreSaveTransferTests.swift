import Foundation
import XCTest
import CatGameCore
@testable import CatLife

final class GameStoreSaveTransferTests: XCTestCase {
    @MainActor
    private func makeStore(_ repository: any GameSaveRepository) -> GameStore {
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
    func testExportStillProducesBackupAfterSaveFailureWithoutClaimingLocalSaveSuccess() async throws {
        let repository = TransferTestRepository(seed())
        let store = makeStore(repository)
        await store.load()
        store.enterHome()
        await repository.setSaveFailure(true)
        let attemptedName = "Draft home"
        XCTAssertNotNil(HomeNameRules.normalized(attemptedName))
        let attemptsBefore = await repository.saveAttemptCount
        let renamed = await store.setHomeName(attemptedName)
        XCTAssertFalse(renamed)
        let attemptsAfter = await repository.saveAttemptCount
        XCTAssertGreaterThan(attemptsAfter, attemptsBefore, "Exercise a real failed write, not name validation.")
        XCTAssertTrue(store.hasSaveFailure)
        store.showSaveError = false
        let original = try XCTUnwrap(store.snapshot)
        let failures = store.saveRetry.failures
        let data = try await store.exportSaveArchive()
        let exported = try NativeSaveTransfer.decode(data)
        let serializedOriginal = try archive(original).snapshot
        XCTAssertEqual(exported.snapshot.home.name, original.home.name)
        XCTAssertEqual(exported.snapshot.player, serializedOriginal.player)
        XCTAssertEqual(exported.snapshot.inventory, original.inventory)
        XCTAssertEqual(exported.snapshot.tasks, original.tasks)
        XCTAssertGreaterThanOrEqual(exported.snapshot.meta.lastSyncAt, serializedOriginal.meta.lastSyncAt)
        XCTAssertEqual(store.snapshot, original)
        XCTAssertTrue(store.hasSaveFailure)
        XCTAssertGreaterThanOrEqual(store.saveRetry.failures, failures)
        XCTAssertFalse(store.showSaveError, "The visible backup warning must not be covered by another save alert.")
        XCTAssertFalse(store.isBusy || store.saveTransferInProgress)
        let durable = await repository.saved
        XCTAssertEqual(durable, original)
        let recovery = try await store.importRecoveryPreview()
        XCTAssertNil(recovery)
        store.setForeground(false)
    }

    @MainActor
    func testConfirmationRejectsFutureProgressBeforeNormalOrStartupReplacement() async throws {
        let future = Date().addingTimeInterval(2 * 86_400)
        let incoming = try archive(GameSnapshot.fresh(now: future))
        for startup in [false, true] {
            let repository = TransferTestRepository(seed())
            if startup { await repository.setLoadFailure(.unreadableSave) }
            let store = makeStore(repository)
            await store.load()
            let before = store.snapshot
            let generation = store.saveSceneGeneration
            let durable = await repository.saved
            do {
                if startup { try await store.restoreSaveArchiveAfterLoadFailure(incoming) }
                else { try await store.importSaveArchive(incoming) }
                XCTFail("A stale preview must never bypass the time check at confirmation.")
            } catch {
                XCTAssertEqual(SaveTransferError.reason(for: error), .futureProgress)
                XCTAssertEqual(SaveTransferError.messageKey(for: error), "saveTransfer.futureProgress")
            }
            XCTAssertEqual(store.snapshot, before)
            XCTAssertEqual(store.saveSceneGeneration, generation)
            XCTAssertEqual(store.loadFailed, startup)
            XCTAssertFalse(store.isBusy || store.isLoading || store.saveTransferInProgress)
            let imported = await repository.importEntered
            let restored = await repository.startupRestoreEntered
            let after = await repository.saved
            XCTAssertFalse(imported || restored)
            XCTAssertEqual(after, durable)
            let recovery = try await store.importRecoveryPreview()
            XCTAssertNil(recovery)
        }
    }

    @MainActor
    func testStartupRecoveryWaitsForDurableWriteAndKeepsExplicitWelcomeEntry() async throws {
        let repository = TransferTestRepository(seed())
        await repository.setLoadFailure(.unsupportedSchemaVersion(GameSnapshot.currentSchemaVersion + 1))
        let store = makeStore(repository)
        await store.load()
        XCTAssertTrue(store.loadFailed && store.needsNewerVersion)
        XCTAssertNil(store.snapshot)
        let generation = store.saveSceneGeneration
        var incoming = seed()
        incoming.player.gold = 621
        incoming.settings.language = .english
        let preview = try archive(incoming)
        await repository.holdImports(true)
        let restore = Task { try await store.restoreSaveArchiveAfterLoadFailure(preview) }
        try await eventually { await repository.startupRestoreEntered }
        XCTAssertNil(store.snapshot)
        XCTAssertTrue(store.isLoading && store.isBusy && store.saveTransferInProgress)
        store.enterHome()
        await store.load()
        XCTAssertFalse(store.hasEnteredHome)
        XCTAssertTrue(store.loadFailed && store.needsNewerVersion)
        XCTAssertEqual(store.saveSceneGeneration, generation)
        await repository.holdImports(false)
        try await restore.value
        XCTAssertEqual(store.snapshot?.player.gold, 621)
        XCTAssertEqual(store.language, .english)
        XCTAssertFalse(store.loadFailed || store.needsNewerVersion || store.isBusy || store.isLoading)
        XCTAssertFalse(store.saveTransferInProgress || store.hasEnteredHome)
        XCTAssertEqual(store.startupProgress, 1)
        XCTAssertEqual(store.startupPhase, "welcome.ready")
        XCTAssertNotEqual(store.saveSceneGeneration, generation)
        XCTAssertNotNil(store.startupNotice)
        let undo = try await store.importRecoveryPreview()
        XCTAssertNil(undo, "Startup repair must not mislabel unreadable bytes as a usable undo point.")
        store.enterHome()
        XCTAssertTrue(store.hasEnteredHome)
        let renamed = await store.setHomeName("Recovered")
        XCTAssertTrue(renamed, "A repaired timeline must accept subsequent normal saves.")
    }

    @MainActor
    func testFailedStartupRecoveryRetainsFailureFlagsAndNeedsExplicitRetry() async throws {
        let repository = TransferTestRepository(seed())
        await repository.setLoadFailure(.unreadableSave)
        await repository.setImportFailure(true)
        let store = makeStore(repository)
        await store.load()
        let original = await repository.saved
        let generation = store.saveSceneGeneration
        let preview = try archive(seed())
        do {
            try await store.restoreSaveArchiveAfterLoadFailure(preview)
            XCTFail("Storage failure must be reported.")
        } catch { XCTAssertEqual(error as? SaveTransferError, .writeFailed) }
        XCTAssertTrue(store.loadFailed)
        XCTAssertFalse(store.needsNewerVersion || store.isLoading || store.isBusy || store.saveTransferInProgress)
        XCTAssertNil(store.snapshot)
        XCTAssertEqual(store.saveSceneGeneration, generation)
        XCTAssertEqual(store.saveRetry.failures, 0)
        store.setForeground(true)
        await Task.yield()
        let attempts = await repository.startupRestoreCount
        XCTAssertEqual(attempts, 1)
        let durable = await repository.saved
        XCTAssertEqual(durable, original)
        await repository.setImportFailure(false)
        try await store.restoreSaveArchiveAfterLoadFailure(preview)
        XCTAssertFalse(store.loadFailed)
        XCTAssertNotNil(store.snapshot)
        XCTAssertEqual(store.startupNotice, GameStrings.text("saveTransfer.failureRestored"))
        store.setForeground(false)
    }

    @MainActor
    func testStartupRecoveryCannotBypassNormalImportOrAnInitialLoad() async throws {
        let repository = TransferTestRepository(seed())
        let store = makeStore(repository)
        let preview = try archive(seed())
        do { try await store.restoreSaveArchiveAfterLoadFailure(preview); XCTFail("Load must finish first.") }
        catch { XCTAssertEqual(error as? SaveTransferError, .busy) }
        await store.load()
        do { try await store.restoreSaveArchiveAfterLoadFailure(preview); XCTFail("Normal play uses ordinary import.") }
        catch { XCTAssertEqual(error as? SaveTransferError, .busy) }
        let attempts = await repository.startupRestoreCount
        XCTAssertEqual(attempts, 0)
    }

    @MainActor
    func testStartupRecoveryStopsWhenCurrentSaveBecomesReadableAndRetryLoadsIt() async throws {
        var original = seed()
        original.player.gold = 843
        let repository = TransferTestRepository(original)
        await repository.setLoadFailure(.unreadableSave)
        let store = makeStore(repository)
        await store.load()
        let generation = store.saveSceneGeneration
        await repository.setLoadFailure(nil)
        await repository.setStartupRestoreFailure(.currentSaveReadable)
        do {
            try await store.restoreSaveArchiveAfterLoadFailure(archive(seed()))
            XCTFail("A readable current save must be loaded, never replaced with an older backup.")
        } catch {
            XCTAssertEqual(error as? SaveTransferError, .currentSaveReadable)
            XCTAssertEqual(SaveTransferError.reason(for: error), .currentSaveReadable)
        }
        XCTAssertTrue(store.loadFailed)
        XCTAssertNil(store.snapshot)
        XCTAssertFalse(store.isBusy || store.isLoading || store.saveTransferInProgress || store.hasEnteredHome)
        XCTAssertEqual(store.saveSceneGeneration, generation)
        XCTAssertEqual(store.saveRetry.failures, 0)
        XCTAssertFalse(store.showSaveError)
        XCTAssertFalse(store.toast?.contains(GameStrings.text("saveTransfer.writeFailed")) == true)
        let durable = await repository.saved
        XCTAssertEqual(durable, original)
        let recovery = try await store.importRecoveryPreview()
        XCTAssertNil(recovery)

        await store.load()
        XCTAssertEqual(store.snapshot?.player.gold, 843)
        XCTAssertFalse(store.loadFailed || store.needsNewerVersion || store.isBusy || store.isLoading)
        XCTAssertFalse(store.hasEnteredHome, "Retry still requires the player's explicit welcome entry.")
    }

    @MainActor
    func testPreservedFutureSaveExportsWithoutRewritingProgressEvenWhenCurrentSaveCannotBeWritten() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CatLife-PreservedStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileSaveRepository(directory: directory)
        let futureSchema = GameSnapshot.currentSchemaVersion + 1
        let raw = Data("{\"schemaVersion\":\(futureSchema),\"futureOnlyData\":{\"name\":\"未来小家🐾\",\"value\":9007199254740993}}".utf8)
        try raw.write(to: repository.saveURL)
        let store = makeStore(repository)
        await store.load()
        XCTAssertTrue(store.loadFailed && store.needsNewerVersion)
        try await store.restoreSaveArchiveAfterLoadFailure(archive(seed()))
        let preserved = try await store.preservedNewerSaves()
        XCTAssertEqual(preserved.count, 1)
        let record = try XCTUnwrap(preserved.first)
        XCTAssertEqual(record.schemaVersion, futureSchema)
        XCTAssertEqual(record.byteCount, raw.count)
        let retainedURL = directory.appendingPathComponent(record.id)
        XCTAssertEqual(try Data(contentsOf: retainedURL), raw)
        let snapshot = try XCTUnwrap(store.snapshot)
        let generation = store.saveSceneGeneration

        // An isolated directory at the primary path makes the next save fail;
        // exporting the retained original must not depend on fixing that write.
        try FileManager.default.removeItem(at: repository.saveURL)
        try FileManager.default.createDirectory(at: repository.saveURL, withIntermediateDirectories: false)
        var changedAudio = store.audioSettings
        changedAudio.musicVolume = 0.73
        let audioSaved = await store.updateAudioSettings(changedAudio)
        XCTAssertFalse(audioSaved)
        XCTAssertTrue(store.hasSaveFailure)
        let data = try await store.exportPreservedNewerSave(id: record.id)
        XCTAssertNotNil(data.range(of: raw), "The archive must retain every unknown field and exact numeric bytes.")
        XCTAssertThrowsError(try NativeSaveTransfer.decode(data)) { error in
            XCTAssertEqual(error as? SaveRepositoryError, .unsupportedSchemaVersion(futureSchema))
            XCTAssertEqual(SaveTransferError.reason(for: error), .unsupportedVersion)
        }
        XCTAssertEqual(try Data(contentsOf: retainedURL), raw)
        XCTAssertEqual(store.snapshot, snapshot)
        XCTAssertEqual(store.saveSceneGeneration, generation)
        XCTAssertTrue(store.hasSaveFailure)
        XCTAssertNotNil(store.pendingAudioSettings)
        XCTAssertFalse(store.isBusy || store.isLoading || store.saveTransferInProgress)
        XCTAssertFalse(FileManager.default.fileExists(atPath: repository.importRecoveryURL.path))
        XCTAssertTrue(try repository.saveURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true)
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
    private var loadFailure: SaveRepositoryError?
    private var startupRestoreFailure: SaveRepositoryError?
    private var held = false
    private(set) var importEntered = false
    private(set) var startupRestoreEntered = false
    private(set) var startupRestoreCount = 0
    private(set) var saveAttemptCount = 0

    init(_ state: GameSnapshot) { saved = state }
    func loadOrCreate(now: Date) throws -> GameSnapshot {
        if let loadFailure { throw loadFailure }
        return saved
    }
    func setLoadFailure(_ failure: SaveRepositoryError?) { loadFailure = failure }
    func setStartupRestoreFailure(_ failure: SaveRepositoryError?) { startupRestoreFailure = failure }
    func setSaveFailure(_ fails: Bool) { saveFails = fails }
    func setImportFailure(_ fails: Bool) { importFails = fails }
    func holdImports(_ hold: Bool) { held = hold }
    func checkWritable() throws { if saveFails { throw Failure.storage } }
    func save(_ state: GameSnapshot) throws {
        saveAttemptCount += 1
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
    func restoreSnapshotAfterLoadFailure(_ state: GameSnapshot) async throws {
        startupRestoreEntered = true
        startupRestoreCount += 1
        while held { try await Task.sleep(for: .milliseconds(10)) }
        if importFails { throw Failure.storage }
        if let startupRestoreFailure { throw startupRestoreFailure }
        saved = state
        loadFailure = nil
    }
    private enum Failure: Error { case storage }
}
