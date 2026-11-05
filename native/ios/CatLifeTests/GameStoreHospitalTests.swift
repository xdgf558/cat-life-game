import Foundation
import XCTest
import CatGameCore
@testable import CatLife

final class GameStoreHospitalTests: XCTestCase {
    @MainActor
    func testFailedTreatmentKeepsIllnessAndGoldThenRetryChargesOnceAndSurvivesReload() async throws {
        let repository = HospitalSaveRepository(seed())
        let store = GameStore(repository: repository)
        await store.load()
        let original = try XCTUnwrap(store.snapshot)
        await repository.setFailing(true)

        let failed = await store.treatCat(catID: CatCatalog.initialCatID)
        XCTAssertFalse(failed)
        XCTAssertEqual(store.snapshot, original)
        let durableBefore = await repository.saved
        XCTAssertEqual(durableBefore, original)
        XCTAssertTrue(store.showSaveError && store.hasSaveFailure)
        XCTAssertFalse(store.isBusy)

        await repository.setFailing(false)
        let retried = await store.treatCat(catID: CatCatalog.initialCatID)
        XCTAssertTrue(retried)
        XCTAssertEqual(store.snapshot?.player.gold, original.player.gold - 120)
        XCTAssertNil(store.cat?.healthState?.illness)
        XCTAssertEqual(store.cat?.health, 80)
        XCTAssertFalse((store.toast ?? store.startupNotice)?.contains(GameStrings.text("hospital.treated")) == true,
                       "The recovery presentation replaces the treatment success toast.")
        XCTAssertFalse(store.hasSaveFailure)
        let duplicate = await store.treatCat(catID: CatCatalog.initialCatID)
        XCTAssertFalse(duplicate)
        XCTAssertEqual(store.snapshot?.player.gold, original.player.gold - 120)

        let reopened = GameStore(repository: repository)
        await reopened.load()
        XCTAssertNil(reopened.cat?.healthState?.illness)
        XCTAssertEqual(reopened.cat?.health, 80)
        XCTAssertEqual(reopened.snapshot?.player.gold, original.player.gold - 120)
        XCTAssertEqual(reopened.snapshot?.cats[1], original.cats[1])
    }

    @MainActor
    func testConcurrentTreatmentCannotPublishEarlyOrChargeTwice() async throws {
        let repository = HospitalSaveRepository(seed())
        let store = GameStore(repository: repository)
        await store.load()
        let original = try XCTUnwrap(store.snapshot)
        await repository.holdNextSave()
        defer { Task { await repository.release() } }
        let first = Task { await store.treatCat(catID: CatCatalog.initialCatID) }
        try await eventually { await repository.isHeld }
        XCTAssertEqual(store.snapshot, original)
        XCTAssertTrue(store.isBusy)
        let duplicate = await store.treatCat(catID: CatCatalog.initialCatID)
        XCTAssertFalse(duplicate)
        store.feed()
        XCTAssertEqual(store.snapshot?.inventory, original.inventory)
        await repository.release()
        let succeeded = await first.value
        XCTAssertTrue(succeeded)
        XCTAssertEqual(store.snapshot?.player.gold, original.player.gold - 120)
        XCTAssertNil(store.cat?.healthState?.illness)
        let maximum = await repository.maximumConcurrentSaves
        XCTAssertEqual(maximum, 1)
    }

    @MainActor
    func testTreatingAnotherCatPreservesCompanionAndOtherCat() async throws {
        var initial = seed()
        initial.cats[0].healthState?.illness = nil
        initial.cats[1].healthState = CatHealthState(illness: .skinProblem, riskPoints: 8,
            lastEvaluatedAt: initial.meta.lastSyncAt, protectedUntil: initial.meta.lastSyncAt)
        initial.cats[1].health = 35
        let repository = HospitalSaveRepository(initial)
        let store = GameStore(repository: repository)
        await store.load()
        let original = try XCTUnwrap(store.snapshot)
        let result = await store.treatCat(catID: CatCatalog.cowCatID)
        XCTAssertTrue(result)
        XCTAssertEqual(store.cat?.id, CatCatalog.initialCatID)
        XCTAssertEqual(store.snapshot?.cats[0], original.cats[0])
        XCTAssertEqual(store.snapshot?.cats[1].health, 80)
        XCTAssertNil(store.snapshot?.cats[1].healthState?.illness)
        XCTAssertEqual(store.snapshot?.player.gold, original.player.gold - 260)
        XCTAssertEqual(store.snapshot?.tasks, original.tasks)
    }

    @MainActor
    func testInsufficientGoldKeepsIllnessAndAllowsWorkNavigation() async throws {
        let repository = HospitalSaveRepository(seed(gold: 10))
        let store = GameStore(repository: repository)
        await store.load()
        let result = await store.treatCat(catID: CatCatalog.initialCatID)
        XCTAssertFalse(result)
        XCTAssertEqual(store.snapshot?.player.gold, 10)
        XCTAssertEqual(store.cat?.healthState?.illness, .cold)
        XCTAssertFalse(store.isBusy || store.showSaveError)
        XCTAssertEqual(store.toast ?? store.startupNotice,
                       GameStrings.format("hospital.goldRequired", 120))
        store.activeSheet = .work
        store.startWork()
        try await eventually { !store.isBusy }
        XCTAssertNotNil(store.snapshot?.player.activeWork)
    }

    @MainActor
    func testHospitalNavigationDismissesInspectionAndDoesNotChangeCompanion() async throws {
        let store = GameStore(repository: HospitalSaveRepository(seed()))
        await store.load()
        store.inspectedCatID = CatCatalog.initialCatID
        store.openHospital(catID: CatCatalog.cowCatID)
        XCTAssertNil(store.inspectedCatID)
        XCTAssertEqual(store.activeSheet, .hospital)
        XCTAssertEqual(store.hospitalCatID, CatCatalog.cowCatID)
        XCTAssertEqual(store.cat?.id, CatCatalog.initialCatID)
        store.openHospital(catID: "missing")
        XCTAssertNil(store.hospitalCatID)
    }

    private func seed(gold: Int = 1000) -> GameSnapshot {
        let now = Date()
        var state = GameSnapshot.fresh(now: now)
        state.settings.audio = AudioSettings(musicEnabled: false, effectsEnabled: false)
        state.player.gold = gold
        state.cats[0].health = 50
        state.cats[0].healthState = CatHealthState(illness: .cold, riskPoints: 8,
            lastEvaluatedAt: now, protectedUntil: now.addingTimeInterval(-3600))
        state.cats.append(CatState(id: CatCatalog.cowCatID, name: "牛奶", now: now, appearance: .cow))
        return state
    }

    @MainActor
    private func eventually(_ condition: @MainActor () async -> Bool) async throws {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Hospital transaction did not settle")
        throw CocoaError(.fileWriteUnknown)
    }
}

private actor HospitalSaveRepository: GameSaveRepository {
    let lastLoadDisposition = SaveLoadDisposition.loaded
    private(set) var saved: GameSnapshot
    private var failing = false
    private var hold = false
    private var continuation: CheckedContinuation<Void, Never>?
    private var concurrent = 0
    private(set) var maximumConcurrentSaves = 0
    var isHeld: Bool { continuation != nil }

    init(_ value: GameSnapshot) { saved = value }
    func setFailing(_ value: Bool) { failing = value }
    func holdNextSave() { hold = true }
    func release() { continuation?.resume(); continuation = nil }
    func loadOrCreate(now: Date) async throws -> GameSnapshot { saved }
    func checkWritable() throws { if failing { throw CocoaError(.fileWriteUnknown) } }
    func save(_ value: GameSnapshot) async throws {
        concurrent += 1
        maximumConcurrentSaves = max(maximumConcurrentSaves, concurrent)
        defer { concurrent -= 1 }
        if hold {
            hold = false
            await withCheckedContinuation { continuation = $0 }
        }
        if failing { throw CocoaError(.fileWriteUnknown) }
        saved = value
    }
}
