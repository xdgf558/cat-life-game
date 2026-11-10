import Foundation
import XCTest
import CatGameCore
@testable import CatLife

final class GameStoreHabitTests: XCTestCase {
    @MainActor
    func testUnoperatedTutorialCanResumeButNeverSpendsOrCreatesExtraEntitlements() async throws {
        let (store, _) = try await makeStore(seed: fresh())
        let before = try XCTUnwrap(store.snapshot)
        let opened = await store.openPlayTogether()
        XCTAssertTrue(opened)
        let first = try XCTUnwrap(store.snapshot?.catPlay.activeSession)
        let entitlement = store.snapshot?.catPlay.tutorialID
        XCTAssertTrue(first.isTutorial)
        store.requestPlayEnd(catID: first.catID, sessionID: first.id, generation: store.saveSceneGeneration)
        try await eventually { store.snapshot?.catPlay.activeSession == nil && !store.isBusy }
        store.isShowingPlayTogether = false
        let reopened = await store.openPlayTogether()
        XCTAssertTrue(reopened)
        XCTAssertNotEqual(store.snapshot?.catPlay.activeSession?.id, first.id)
        XCTAssertEqual(store.snapshot?.catPlay.tutorialID, entitlement)
        XCTAssertEqual(store.snapshot?.inventory, before.inventory)
        XCTAssertEqual(store.snapshot?.tasks, before.tasks)
        XCTAssertEqual(store.snapshot?.cats, before.cats)
        store.setForeground(false)
        try await eventually { !store.isBusy }
    }

    @MainActor
    func testCompletedTutorialWithoutToysRoutesToTheExistingSupplyShop() async throws {
        var seed = try completedTutorial()
        seed.inventory.toys = 0
        let (store, _) = try await makeStore(seed: seed)
        let before = store.snapshot
        let opened = await store.openPlayTogether()
        XCTAssertFalse(opened)
        XCTAssertEqual(store.activeSheet, .shop)
        XCTAssertEqual(store.shopCategory, .supplies)
        XCTAssertFalse(store.isShowingPlayTogether)
        XCTAssertEqual(store.snapshot, before)
        store.setForeground(false)
    }

    @MainActor
    func testPaidInputPublishesOnlyAfterSaveAndRetryCannotDoubleChargeOrCount() async throws {
        let (store, repository) = try await makeStore(seed: completedTutorial())
        let opened = await store.openPlayTogether()
        XCTAssertTrue(opened)
        let session = try XCTUnwrap(store.snapshot?.catPlay.activeSession)
        let before = try XCTUnwrap(store.snapshot)
        await repository.setFailing(true)
        let report = CatPlayInputReport(sequence: 1, kind: .moveAndPause, control: .tap, duration: 0, movementDuration: 0)
        let failed = await store.submitPlayInput(catID: session.catID, sessionID: session.id, report: report)
        XCTAssertFalse(failed)
        XCTAssertEqual(store.snapshot, before)
        XCTAssertTrue(store.hasSaveFailure)
        await repository.setFailing(false)
        let retried = await store.submitPlayInput(catID: session.catID, sessionID: session.id, report: report)
        XCTAssertTrue(retried)
        XCTAssertEqual(store.snapshot?.inventory.toys, 5)
        XCTAssertEqual(store.snapshot?.tasks.dailyPlayCount, 1)
        let repeated = await store.submitPlayInput(catID: session.catID, sessionID: session.id, report: report)
        XCTAssertTrue(repeated)
        XCTAssertEqual(store.snapshot?.inventory.toys, 5)
        XCTAssertEqual(store.snapshot?.tasks.dailyPlayCount, 1)
        try await Task.sleep(for: .seconds(1.3))
        let observation = CatPlayInputReport(sequence: 2, kind: .moveAndPause, control: .tap, duration: 1.25, movementDuration: 0)
        let observed = await store.submitPlayInput(catID: session.catID, sessionID: session.id, report: observation)
        XCTAssertTrue(observed)
        XCTAssertEqual(store.cat?.habits.playClueSessionIDs.count, 2)
        XCTAssertEqual(store.cat?.habits.memories.filter { $0.kind == .favoritePlay }.count, 1)
        XCTAssertEqual(store.snapshot?.inventory.toys, 5)
        store.setForeground(false)
        try await eventually { store.snapshot?.catPlay.lastResult?.id == session.id && !store.isBusy }
        let saved = await repository.saved
        XCTAssertEqual(saved, store.snapshot)
    }

    @MainActor
    func testBackgroundDuringHeldInputEndsTheSameSessionAfterOneDurableCharge() async throws {
        let (store, repository) = try await makeStore(seed: completedTutorial())
        let opened = await store.openPlayTogether()
        XCTAssertTrue(opened)
        let session = try XCTUnwrap(store.snapshot?.catPlay.activeSession)
        await repository.holdNextSave()
        let input = Task { await store.submitPlayInput(catID: session.catID, sessionID: session.id,
            report: .init(sequence: 1, kind: .slowMove, control: .tap, duration: 0, movementDuration: 0)) }
        try await eventually { await repository.blocked }
        XCTAssertNil(store.snapshot?.catPlay.activeSession?.paidAt)
        store.setForeground(false)
        let captured = try XCTUnwrap(store.pendingCatPlayEnd?.occurredAt)
        await repository.release()
        let accepted = await input.value
        XCTAssertTrue(accepted)
        try await eventually { store.snapshot?.catPlay.activeSession == nil && !store.isBusy }
        XCTAssertEqual(store.snapshot?.catPlay.lastResult?.id, session.id)
        XCTAssertEqual(store.snapshot?.catPlay.lastResult?.endedAt, captured)
        XCTAssertEqual(store.snapshot?.inventory.toys, 5)
        XCTAssertEqual(store.snapshot?.tasks.dailyPlayCount, 1)
        XCTAssertNotNil(store.presentedPlaySession, "Returning to foreground must show the result, not a resumed scene.")
        store.setForeground(true)
        try await eventually { !store.isBusy }
        XCTAssertEqual(store.snapshot?.inventory.toys, 5)
        let maximum = await repository.maximumConcurrentSaves
        XCTAssertEqual(maximum, 1)
        store.setForeground(false)
    }

    @MainActor
    func testBackgroundWhileOpeningDoesNotPresentAnUnseenLiveSession() async throws {
        let (store, repository) = try await makeStore(seed: fresh())
        await repository.holdNextSave()
        let opening = Task { await store.openPlayTogether() }
        try await eventually { await repository.blocked }
        store.setForeground(false)
        await repository.release()
        let opened = await opening.value
        XCTAssertFalse(opened)
        try await eventually { store.snapshot?.catPlay.activeSession == nil && !store.isBusy }
        XCTAssertFalse(store.isShowingPlayTogether)
        XCTAssertEqual(store.snapshot?.catPlay.lastResult?.session.effects.toysSpent, 0)
        XCTAssertEqual(store.snapshot?.inventory.toys, 0)
    }

    @MainActor
    func testFailedEndPreservesItsCapturedTimeAcrossManualRetries() async throws {
        let (store, repository) = try await makeStore(seed: completedTutorial())
        let opened = await store.openPlayTogether()
        XCTAssertTrue(opened)
        let session = try XCTUnwrap(store.snapshot?.catPlay.activeSession)
        let accepted = await store.submitPlayInput(catID: session.catID, sessionID: session.id,
            report: .init(sequence: 1, kind: .slowMove, control: .tap, duration: 0, movementDuration: 0))
        XCTAssertTrue(accepted)
        await repository.setFailing(true)
        store.requestPlayEnd(catID: session.catID, sessionID: session.id, generation: store.saveSceneGeneration)
        try await eventually { store.hasSaveFailure && !store.isBusy }
        let captured = try XCTUnwrap(store.pendingCatPlayEnd?.occurredAt)
        store.requestPlayEnd(catID: session.catID, sessionID: session.id, generation: store.saveSceneGeneration)
        try await eventually { !store.isBusy }
        XCTAssertEqual(store.pendingCatPlayEnd?.occurredAt, captured)
        await repository.setFailing(false)
        store.retrySaving()
        try await eventually { !store.hasSaveFailure && !store.isBusy }
        XCTAssertNil(store.pendingCatPlayEnd)
        XCTAssertEqual(store.snapshot?.catPlay.lastResult?.endedAt, captured)
        XCTAssertEqual(store.snapshot?.inventory.toys, 5)
        XCTAssertEqual(store.snapshot?.tasks.dailyPlayCount, 1)
        store.setForeground(false)
    }

    @MainActor
    func testColdLaunchEndsSavedPaidPlayWithoutReplayingItsSettlement() async throws {
        var seed = try completedTutorial()
        let start = Date().addingTimeInterval(-2)
        XCTAssertTrue(CatHabitEngine.beginPlay(&seed, catID: seed.activeCatID, now: start).succeeded)
        let session = try XCTUnwrap(seed.catPlay.activeSession)
        XCTAssertTrue(CatHabitEngine.recordPlayInput(&seed, catID: session.catID, sessionID: session.id,
            report: .init(sequence: 1, kind: .slowMove, control: .tap, duration: 0, movementDuration: 0), now: start).succeeded)
        let (store, repository) = try await makeStore(seed: seed)
        XCTAssertNil(store.snapshot?.catPlay.activeSession)
        XCTAssertEqual(store.snapshot?.catPlay.lastResult?.id, session.id)
        XCTAssertEqual(store.snapshot?.inventory.toys, 5)
        XCTAssertEqual(store.snapshot?.tasks.dailyPlayCount, 1)
        let reopened = GameStore(repository: repository)
        await reopened.load()
        XCTAssertEqual(reopened.snapshot?.inventory.toys, 5)
        XCTAssertEqual(reopened.snapshot?.tasks.dailyPlayCount, 1)
        XCTAssertEqual(reopened.snapshot?.cats.map(\.habits), seed.cats.map(\.habits))
        store.setForeground(false)
    }

    @MainActor
    func testRestArrivalMetadataIsAcceptedOnlyFromAVisiblePlayerRoom() async throws {
        let (store, _) = try await makeStore(seed: fresh())
        let originalHabits = try XCTUnwrap(store.cat?.habits)
        let point = try XCTUnwrap(store.snapshot?.home.furniture.first { $0.itemID == "floorCushion" }?.position)
        let observation = CatRestObservation(floor: .ground, position: point)
        for (index, visible) in [false, true].enumerated() {
            store.activeSheet = visible ? nil : .work
            let id = "visibility-\(index)"
            store.setRestingFurniture(id: "floorCushion", sessionID: id, observation: observation)
            try await eventually { !store.isBusy && store.cat?.activeRest?.id == id }
            XCTAssertEqual(store.cat?.activeRest?.observation, visible ? observation : nil)
            store.setRestingFurniture(id: nil, sessionID: id)
            try await eventually { !store.isBusy && store.cat?.activeRest == nil }
        }
        XCTAssertEqual(store.cat?.habits, originalHabits, "Interrupted or invisible rests must preserve the actual location references without creating clues.")
        store.setForeground(false)
    }

    @MainActor
    func testOptionalStudyLogsNeverIncludeCustomNamesAndRemainOutsideTheSave() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("HabitStudy-\(UUID())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let log = HabitStudyLog(directory: directory)
        var seed = try completedTutorial()
        seed.cats[0].customName = "PRIVATE_CAT"
        seed.player.profile.name = "PRIVATE_USER"
        let repository = HabitTestRepository(seed)
        let store = GameStore(repository: repository, studyLog: log)
        await store.load(); store.enterHome(); store.setForeground(true)
        try await eventually { !store.isBusy }
        XCTAssertFalse(store.habitStudyMode)
        store.recordHabitStudy("playOpened", catID: seed.activeCatID)
        let empty = try await log.export()
        XCTAssertEqual(try JSONDecoder().decode([HabitStudyLog.Entry].self, from: empty).count, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
        store.habitStudyMode = true
        let opened = await store.openPlayTogether()
        XCTAssertTrue(opened)
        let session = try XCTUnwrap(store.snapshot?.catPlay.activeSession)
        let accepted = await store.submitPlayInput(catID: session.catID, sessionID: session.id,
            report: .init(sequence: 1, kind: .slowMove, control: .tap, duration: 0, movementDuration: 0))
        XCTAssertTrue(accepted)
        store.setForeground(false)
        try await eventually { store.snapshot?.catPlay.activeSession == nil && !store.isBusy }
        try await eventually {
            let data = try await log.export()
            return try JSONDecoder().decode([HabitStudyLog.Entry].self, from: data).contains { $0.event == "playEnded" }
        }
        let data = try await log.export()
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(text.contains("PRIVATE_CAT") || text.contains("PRIVATE_USER"))
        let entries = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        let allowed = Set(["date", "event", "catID", "sessionID", "detail", "control", "duration"])
        XCTAssertTrue(entries.allSatisfy { Set($0.keys).isSubset(of: allowed) })
        XCTAssertEqual(entries.filter { $0["event"] as? String == "firstHabitAction" }.count, 1)
        let durable = await repository.saved
        XCTAssertEqual(durable, store.snapshot)
        let savedJSON = String(decoding: try JSONEncoder().encode(durable), as: UTF8.self)
        XCTAssertFalse(savedJSON.contains("firstHabitAction"))
    }

    @MainActor
    func testPinnedCompanionHintPublishesAfterSaveAndSurvivesReopeningAndReplacement() async throws {
        let (store, repository) = try await makeStore(seed: fresh())
        let catID = try XCTUnwrap(store.cat?.id)
        let before = try XCTUnwrap(store.snapshot)
        await repository.setFailing(true)
        let failed = await store.pinHabitMemory(catID: catID, memory: .littleCorner)
        XCTAssertFalse(failed)
        XCTAssertNil(store.cat?.habits.pinnedMemory)
        XCTAssertTrue(store.hasSaveFailure)
        await repository.setFailing(false)
        let pinned = await store.pinHabitMemory(catID: catID, memory: .littleCorner)
        XCTAssertTrue(pinned)
        let folded = await store.setPinnedHabitHintCollapsed(catID: catID, collapsed: true)
        XCTAssertTrue(folded)
        XCTAssertEqual(store.cat?.habits.pinnedMemory, .littleCorner)
        XCTAssertEqual(store.cat?.habits.pinnedHintCollapsed, true)
        store.setForeground(false)
        try await eventually { !store.isBusy }
        let reopened = GameStore(repository: repository)
        await reopened.load()
        XCTAssertEqual(reopened.cat?.habits.pinnedMemory, .littleCorner)
        XCTAssertEqual(reopened.cat?.habits.pinnedHintCollapsed, true)
        let replaced = await reopened.pinHabitMemory(catID: catID, memory: .settledAfterMove)
        XCTAssertTrue(replaced)
        XCTAssertEqual(reopened.cat?.habits.pinnedMemory, .settledAfterMove)
        XCTAssertEqual(reopened.cat?.habits.pinnedHintCollapsed, false)
        let invalid = await reopened.pinHabitMemory(catID: catID, memory: .firstResponse)
        XCTAssertFalse(invalid)
        XCTAssertEqual(reopened.cat?.habits.pinnedMemory, .settledAfterMove)
        let removed = await reopened.pinHabitMemory(catID: catID, memory: nil)
        XCTAssertTrue(removed)
        XCTAssertNil(reopened.cat?.habits.pinnedMemory)
        XCTAssertEqual(reopened.cat?.habits.pinnedHintCollapsed, false)
        XCTAssertEqual(reopened.snapshot?.player.gold, before.player.gold)
        XCTAssertEqual(reopened.snapshot?.inventory, before.inventory)
        XCTAssertEqual(reopened.snapshot?.tasks, before.tasks)
        XCTAssertEqual(reopened.cat?.habits.memories, before.activeCat?.habits.memories)
        reopened.setForeground(false)
    }

    @MainActor
    func testPinnedCompanionHintYieldsToCareNeedsLowEnergyAndSceneWork() async throws {
        for needs in [(100, 100, 100, 100), (49, 100, 100, 100), (100, 39, 100, 100),
                      (100, 100, 44, 100), (100, 100, 100, 29)] {
            var seed = fresh()
            seed.cats[0].satiety = needs.0; seed.cats[0].cleanliness = needs.1
            seed.cats[0].mood = needs.2; seed.cats[0].energy = needs.3
            XCTAssertTrue(CatHabitEngine.pinMemory(&seed, catID: seed.activeCatID, memory: .littleCorner).succeeded)
            let (store, _) = try await makeStore(seed: seed)
            XCTAssertEqual(store.canShowPinnedHabitHint, needs == (100, 100, 100, 100))
            store.roomFloorTravelReady = false
            XCTAssertFalse(store.canShowPinnedHabitHint)
            store.setForeground(false)
        }
    }

    @MainActor
    func testPinnedCompanionHintYieldsToAdoptionBannersAndReturnsAfterTheirDismissal() async throws {
        var seed = fresh()
        seed.player.level = 8; seed.player.gold = 5_000; seed.home.roomLevel = 3
        seed.cats[0].satiety = 80
        XCTAssertTrue(CatHabitEngine.pinMemory(&seed, catID: seed.activeCatID, memory: .settledAfterMove).succeeded)
        let (store, _) = try await makeStore(seed: seed)
        store.adoptionReminders.consider(seed)
        XCTAssertNotNil(store.adoptionReminders.pendingOffer)
        XCTAssertFalse(store.canShowPinnedHabitHint, "The two prompts must not cover one another.")
        while let offer = store.adoptionReminders.pendingOffer {
            store.adoptionReminders.dismiss(offer.id)
        }
        XCTAssertTrue(store.canShowPinnedHabitHint)
        XCTAssertEqual(store.cat?.habits.pinnedMemory, .settledAfterMove)
        store.setForeground(false)
    }

    private func fresh(now: Date = Date()) -> GameSnapshot {
        var value = GameSnapshot.fresh(now: now)
        value.settings.audio = AudioSettings(musicEnabled: false, effectsEnabled: false, catEnabled: false, haptics: false)
        return value
    }

    private func completedTutorial() throws -> GameSnapshot {
        let date = Date().addingTimeInterval(-10)
        var value = fresh(now: date)
        XCTAssertTrue(CatHabitEngine.beginPlay(&value, catID: value.activeCatID, now: date).succeeded)
        let session = try XCTUnwrap(value.catPlay.activeSession)
        for (sequence, kind) in [CatPlayInputKind.slowMove, .moveAndPause].enumerated() {
            XCTAssertTrue(CatHabitEngine.recordPlayInput(&value, catID: session.catID, sessionID: session.id,
                report: .init(sequence: sequence + 1, kind: kind, control: .tap, duration: 2, movementDuration: 0),
                now: date.addingTimeInterval(Double(sequence + 1) * 2)).succeeded)
        }
        _ = CatHabitEngine.endPlay(&value, catID: session.catID, sessionID: session.id, now: date.addingTimeInterval(5))
        value.inventory.toys = 6
        return value
    }

    @MainActor private func makeStore(seed: GameSnapshot) async throws -> (GameStore, HabitTestRepository) {
        let repository = HabitTestRepository(seed)
        let store = GameStore(repository: repository)
        await store.load(); store.enterHome(); store.setForeground(true)
        try await eventually { !store.isBusy }
        return (store, repository)
    }

    @MainActor private func eventually(file: StaticString = #filePath, line: UInt = #line,
                                       _ condition: @MainActor () async throws -> Bool) async throws {
        let deadline = Date().addingTimeInterval(4)
        while Date() < deadline {
            if try await condition() { return }
            try await Task.sleep(for: .milliseconds(15))
        }
        XCTFail("The habit transaction did not settle.", file: file, line: line)
        throw CocoaError(.coderInvalidValue)
    }
}

private actor HabitTestRepository: GameSaveRepository {
    let lastLoadDisposition = SaveLoadDisposition.loaded
    private(set) var saved: GameSnapshot
    private(set) var blocked = false
    private(set) var maximumConcurrentSaves = 0
    private var activeSaves = 0
    private var failing = false
    private var holdsNext = false
    private var continuation: CheckedContinuation<Void, Never>?
    init(_ saved: GameSnapshot) { self.saved = saved }
    func setFailing(_ value: Bool) { failing = value }
    func holdNextSave() { holdsNext = true }
    func release() { continuation?.resume(); continuation = nil; blocked = false }
    func loadOrCreate(now: Date) -> GameSnapshot { saved }
    func checkWritable() throws { if failing { throw CocoaError(.fileWriteUnknown) } }
    func save(_ state: GameSnapshot) async throws {
        activeSaves += 1; maximumConcurrentSaves = max(maximumConcurrentSaves, activeSaves)
        defer { activeSaves -= 1 }
        if holdsNext {
            holdsNext = false; blocked = true
            await withCheckedContinuation { continuation = $0 }
        }
        try checkWritable()
        saved = state
    }
}
