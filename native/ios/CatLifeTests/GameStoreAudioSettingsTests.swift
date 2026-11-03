import Foundation
import XCTest
import CatGameCore
@testable import CatLife

/// Deterministic save gates reproduce leaving Sound during another write.
/// These tests use an in-memory repository and never touch a player's save.
final class GameStoreAudioSettingsTests: XCTestCase {
    @MainActor
    func testAudioIntentWaitsForBusySaveAndPreservesItsPlayerChange() async throws {
        let repository = AudioSettingsSaveRepository(mutedSnapshot())
        let store = GameStore(repository: repository)
        await store.load()
        let original = try XCTUnwrap(store.snapshot)
        let baseline = await repository.attempts.count
        await repository.holdNextSaves(1)
        defer { Task { await repository.releaseAllSaves() } }

        let rename = Task { await store.renamePlayer(to: "保留这个名字") }
        try await eventually("The unrelated rename must own the save lock") {
            await repository.isSaveBlocked
        }
        let desired = AudioSettings(musicEnabled: false, effectsEnabled: false,
                                    musicVolume: 0.2, effectsVolume: 0.8)
        let audioSave = Task { await store.updateAudioSettings(desired) }
        try await eventually("Audio intent must survive while the Store is busy") {
            store.pendingAudioSettings == desired
        }
        XCTAssertTrue(store.isBusy)
        XCTAssertEqual(store.audioSettings, original.settings.audio,
                       "Queued intent is not a durable preference yet.")
        let queuedAttempts = await repository.attempts.count
        XCTAssertEqual(queuedAttempts, baseline + 1, "Audio cannot race the unrelated write.")

        await repository.releaseNextSave()
        let renamed = await rename.value
        let audioSaved = await audioSave.value
        XCTAssertTrue(renamed)
        XCTAssertTrue(audioSaved)
        try await eventually("Both serialized operations should settle") {
            !store.isBusy && store.pendingAudioSettings == nil
        }
        XCTAssertEqual(store.playerDisplayName, "保留这个名字")
        XCTAssertEqual(store.audioSettings, desired)
        XCTAssertFalse(store.audioSettingsSaveFailed)
        let durable = await repository.savedSnapshot
        XCTAssertEqual(durable.player.profile.name, "保留这个名字")
        XCTAssertEqual(durable.settings.audio, desired)
        XCTAssertEqual(durable.inventory, original.inventory)
        let maximumConcurrentSaves = await repository.maximumConcurrentSaveCalls
        XCTAssertEqual(maximumConcurrentSaves, 1)
    }

    @MainActor
    func testOlderAudioSuccessCannotDiscardNewerIntentReturningToSavedValues() async throws {
        let repository = AudioSettingsSaveRepository(mutedSnapshot())
        let store = GameStore(repository: repository)
        await store.load()
        let original = store.audioSettings
        let baseline = await repository.attempts.count
        await repository.holdNextSaves(2)
        defer { Task { await repository.releaseAllSaves() } }

        var earlier = original
        earlier.musicVolume = 0.9
        let firstSave = Task { await store.updateAudioSettings(earlier) }
        try await eventually("The older preference write must be in flight") {
            await repository.isSaveBlocked
        }
        // The player moves back to the currently saved value before the older
        // write finishes. A snapshot-only no-op check would lose this choice.
        let latestSave = Task { await store.updateAudioSettings(original) }
        try await eventually("Returning to saved values must supersede the in-flight intent") {
            store.pendingAudioSettings == original
        }
        await repository.releaseNextSave()
        try await eventually("The newer preference should start after the old write commits") {
            let count = await repository.attempts.count
            let blocked = await repository.isSaveBlocked
            return count == baseline + 2 && blocked
        }
        XCTAssertEqual(store.audioSettings, earlier)
        XCTAssertEqual(store.pendingAudioSettings, original,
                       "Publishing an older write must not clear the newer pending intent.")
        XCTAssertFalse(store.audioSettingsSaveFailed,
                       "A superseded request is not a storage failure.")
        await repository.releaseNextSave()
        _ = await firstSave.value // An intentionally superseded caller may return false.
        let latestSaved = await latestSave.value
        XCTAssertTrue(latestSaved)
        try await eventually("The latest intent should be the final durable value") {
            !store.isBusy && store.pendingAudioSettings == nil && store.audioSettings == original
        }
        let durable = await repository.savedSnapshot
        XCTAssertEqual(durable.settings.audio, original)
        let maximumConcurrentSaves = await repository.maximumConcurrentSaveCalls
        XCTAssertEqual(maximumConcurrentSaves, 1)
    }

    @MainActor
    func testFailedAudioIntentsRemainRetryableAndRetrySavesLatestSettings() async throws {
        let repository = AudioSettingsSaveRepository(mutedSnapshot())
        let store = GameStore(repository: repository)
        await store.load()
        let original = try XCTUnwrap(store.snapshot)
        await repository.setWritesFailing(true)
        let earlier = AudioSettings(musicEnabled: false, effectsEnabled: false,
                                    musicVolume: 0.15, effectsVolume: 0.4)
        let firstSaved = await store.updateAudioSettings(earlier)
        XCTAssertFalse(firstSaved)
        XCTAssertEqual(store.audioSettings, original.settings.audio)
        XCTAssertEqual(store.pendingAudioSettings, earlier)
        XCTAssertTrue(store.audioSettingsSaveFailed)
        XCTAssertTrue(store.showSaveError)

        let latest = AudioSettings(musicEnabled: false, effectsEnabled: false,
                                   musicVolume: 0.6, effectsVolume: 0.25)
        let latestSaved = await store.updateAudioSettings(latest)
        XCTAssertFalse(latestSaved)
        XCTAssertEqual(store.audioSettings, original.settings.audio)
        XCTAssertEqual(store.pendingAudioSettings, latest)
        XCTAssertTrue(store.audioSettingsSaveFailed)
        XCTAssertFalse(store.isBusy)
        store.showSaveError = false // Dismissing the alert must retain retry intent.
        store.isShowingSettings = false

        await repository.setWritesFailing(false)
        store.retrySaving()
        try await eventually("Retry outside Sound must persist the newest retained intent") {
            !store.isBusy && store.pendingAudioSettings == nil && store.audioSettings == latest
        }
        XCTAssertFalse(store.audioSettingsSaveFailed)
        let durable = await repository.savedSnapshot
        XCTAssertEqual(durable.settings.audio, latest)
        XCTAssertEqual(durable.player, original.player)
        XCTAssertEqual(durable.cats, original.cats)
        XCTAssertEqual(durable.inventory, original.inventory)
        XCTAssertEqual(durable.home, original.home)
        let lastAttempt = await repository.attempts.last
        XCTAssertEqual(lastAttempt?.settings.audio, latest)
        let maximumConcurrentSaves = await repository.maximumConcurrentSaveCalls
        XCTAssertEqual(maximumConcurrentSaves, 1)
    }

    @MainActor
    func testSupersededAudioFailureDoesNotAlertWhileNewestIntentStillSaves() async throws {
        try await verifySupersededAudioFailure(latestFails: false)
    }

    @MainActor
    func testNewestAudioFailureStillAlertsAfterSupersededFailure() async throws {
        try await verifySupersededAudioFailure(latestFails: true)
    }

    @MainActor
    private func verifySupersededAudioFailure(latestFails: Bool) async throws {
        let repository = AudioSettingsSaveRepository(mutedSnapshot())
        let store = GameStore(repository: repository)
        await store.load()
        let original = store.audioSettings
        await repository.setWritesFailing(true)
        await repository.holdNextSaves(2)
        defer { Task { await repository.releaseAllSaves() } }
        var earlier = original
        earlier.musicVolume = 0.8
        let first = Task { await store.updateAudioSettings(earlier) }
        try await eventually("The superseded write must be held in flight") {
            await repository.isSaveBlocked
        }
        let latest = Task { await store.updateAudioSettings(original) }
        try await eventually("The latest intent must replace the older request") {
            store.pendingAudioSettings == original
        }
        // Each write captures storage availability independently.
        await repository.setWritesFailing(latestFails)
        await repository.releaseNextSave()
        try await eventually("The new request must start after the older failure") {
            let blocked = await repository.isSaveBlocked
            return store.hasSaveFailure && blocked
        }
        XCTAssertFalse(store.showSaveError, "A stale preference failure must not interrupt the newer choice.")
        XCTAssertFalse(store.audioSettingsSaveFailed)
        XCTAssertEqual(store.pendingAudioSettings, original)
        await repository.releaseNextSave()
        let superseded = await first.value
        let saved = await latest.value
        XCTAssertFalse(superseded)
        XCTAssertEqual(saved, !latestFails)
        XCTAssertEqual(store.audioSettings, original)
        XCTAssertEqual(store.hasSaveFailure, latestFails)
        XCTAssertEqual(store.showSaveError, latestFails)
        XCTAssertEqual(store.audioSettingsSaveFailed, latestFails)
        XCTAssertEqual(store.pendingAudioSettings, latestFails ? original : nil)
    }

    private func mutedSnapshot() -> GameSnapshot {
        var snapshot = GameSnapshot.fresh(now: Date())
        snapshot.settings.audio = AudioSettings(musicEnabled: false, effectsEnabled: false)
        return snapshot
    }

    @MainActor
    private func eventually(_ message: String, timeout: TimeInterval = 3,
                            file: StaticString = #filePath, line: UInt = #line,
                            condition: @MainActor () async -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail(message, file: file, line: line)
        throw AudioSettingsTestWaitFailure.timedOut
    }
}

private enum AudioSettingsTestWaitFailure: Error { case timedOut }

private actor AudioSettingsSaveRepository: GameSaveRepository {
    private enum SimulatedWriteError: Error { case unavailable }
    let lastLoadDisposition = SaveLoadDisposition.loaded
    private(set) var savedSnapshot: GameSnapshot
    private(set) var attempts: [GameSnapshot] = []
    private(set) var activeSaveCalls = 0
    private(set) var maximumConcurrentSaveCalls = 0
    private var writesFailing = false
    private var savesToHold = 0
    private var heldSaves: [CheckedContinuation<Void, Never>] = []
    var isSaveBlocked: Bool { !heldSaves.isEmpty }

    init(_ snapshot: GameSnapshot) { savedSnapshot = snapshot }
    func setWritesFailing(_ failing: Bool) { writesFailing = failing }
    func holdNextSaves(_ count: Int) { savesToHold = count }
    func releaseNextSave() { if !heldSaves.isEmpty { heldSaves.removeFirst().resume() } }
    func releaseAllSaves() {
        savesToHold = 0
        let waiting = heldSaves
        heldSaves.removeAll()
        waiting.forEach { $0.resume() }
    }

    func loadOrCreate(now: Date) async throws -> GameSnapshot { savedSnapshot }

    func checkWritable() throws { if writesFailing { throw SimulatedWriteError.unavailable } }

    func save(_ snapshot: GameSnapshot) async throws {
        let fails = writesFailing
        attempts.append(snapshot)
        activeSaveCalls += 1
        maximumConcurrentSaveCalls = max(maximumConcurrentSaveCalls, activeSaveCalls)
        defer { activeSaveCalls -= 1 }
        if savesToHold > 0 {
            savesToHold -= 1
            await withCheckedContinuation { heldSaves.append($0) }
        }
        if fails { throw SimulatedWriteError.unavailable }
        savedSnapshot = snapshot
    }
}
