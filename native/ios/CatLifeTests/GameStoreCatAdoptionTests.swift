import Foundation
import XCTest
import CatGameCore
@testable import CatLife

final class GameStoreCatAdoptionTests: XCTestCase {
    @MainActor
    func testThirdCatAdoptionFailurePreservesTwoCatsAndRetryChargesOnlyOnce() async throws {
        let repository = CatAdoptionSaveRepository(blueAdoptionSeed())
        let store = GameStore(repository: repository)
        await store.load()
        let original = try XCTUnwrap(store.snapshot)
        let baseline = await repository.attempts.count
        await repository.setWritesFailing(true)

        let failed = await store.adoptCat(catID: CatCatalog.blueCatID)

        XCTAssertFalse(failed)
        XCTAssertEqual(store.snapshot, original)
        XCTAssertEqual(store.cat?.id, CatCatalog.cowCatID)
        XCTAssertTrue(store.showSaveError && store.hasSaveFailure)
        XCTAssertFalse(store.isBusy)
        let unchanged = await repository.savedSnapshot
        XCTAssertEqual(unchanged, original)
        let failedAttempts = await repository.attempts
        XCTAssertEqual(failedAttempts.count, baseline + 1)
        XCTAssertEqual(failedAttempts.last?.cats.count, 3)
        XCTAssertEqual(failedAttempts.last?.player.gold, original.player.gold - 600)

        await repository.setWritesFailing(false)
        let retried = await store.adoptCat(catID: CatCatalog.blueCatID)
        XCTAssertTrue(retried)
        let adopted = try XCTUnwrap(store.snapshot)
        XCTAssertEqual(adopted.player.gold, original.player.gold - 600)
        XCTAssertEqual(adopted.cats.map(\.id), [CatCatalog.initialCatID, CatCatalog.cowCatID, CatCatalog.blueCatID])
        XCTAssertEqual(Array(adopted.cats.prefix(2)), original.cats)
        XCTAssertEqual(adopted.cats[2].appearance, .blue)
        XCTAssertEqual(adopted.activeCatID, original.activeCatID)
        XCTAssertFalse(store.hasSaveFailure)
        let attempts = await repository.attempts
        XCTAssertEqual(attempts.count, baseline + 2)
        let durable = await repository.savedSnapshot
        XCTAssertEqual(durable, adopted)

        let duplicate = await store.adoptCat(catID: CatCatalog.blueCatID)
        XCTAssertFalse(duplicate)
        XCTAssertEqual(store.snapshot?.player.gold, adopted.player.gold)
        XCTAssertEqual(store.snapshot?.cats, adopted.cats)
        XCTAssertEqual(store.cat?.id, CatCatalog.cowCatID)
        let reopened = GameStore(repository: repository)
        await reopened.load()
        XCTAssertEqual(reopened.snapshot?.cats, adopted.cats)
        XCTAssertEqual(reopened.snapshot?.player.gold, adopted.player.gold)
        XCTAssertEqual(reopened.cat?.id, CatCatalog.cowCatID)
    }

    @MainActor
    func testBlueCompanionRenameCareAndTreatmentStayIndependentAfterReopening() async throws {
        var initial = blueAdoptionSeed()
        XCTAssertTrue(GameEngine.adoptCat(&initial, catID: CatCatalog.blueCatID).succeeded)
        initial.cats[0].healthState?.illness = .cold
        initial.cats[0].healthState?.riskPoints = 8
        initial.cats[0].health = 50
        initial.cats[2].healthState?.illness = .skinProblem
        initial.cats[2].healthState?.riskPoints = 8
        initial.cats[2].health = 35
        let repository = CatAdoptionSaveRepository(initial)
        let store = GameStore(repository: repository)
        await store.load()
        let original = try XCTUnwrap(store.snapshot)
        let renamed = await store.renameCat(id: CatCatalog.blueCatID, to: "  蓝莓🐾  ")
        XCTAssertTrue(renamed)
        XCTAssertEqual(store.snapshot?.cats[2].customName, "蓝莓🐾")
        XCTAssertEqual(store.cat?.id, CatCatalog.cowCatID)
        let named = try XCTUnwrap(store.snapshot)

        await repository.setWritesFailing(true)
        let failedSwitch = await store.selectCompanion(catID: CatCatalog.blueCatID)
        XCTAssertFalse(failedSwitch)
        XCTAssertEqual(store.snapshot, named)
        await repository.setWritesFailing(false)
        let switched = await store.selectCompanion(catID: CatCatalog.blueCatID)
        XCTAssertTrue(switched)
        XCTAssertEqual(store.cat?.appearance, .blue)
        store.inspectCat()
        XCTAssertEqual(store.inspectedCatID, CatCatalog.blueCatID)
        store.clean()
        try await eventually { !store.isBusy && store.feedback?.kind == .clean }
        XCTAssertEqual(store.feedback?.catID, CatCatalog.blueCatID)
        XCTAssertEqual(store.cat?.healthState?.illness, .skinProblem)
        XCTAssertEqual(store.cat?.health, 39)
        XCTAssertEqual(Array(try XCTUnwrap(store.snapshot).cats.prefix(2)), Array(original.cats.prefix(2)))

        let treated = await store.treatCat(catID: CatCatalog.blueCatID)
        XCTAssertTrue(treated)
        XCTAssertNil(store.cat?.healthState?.illness)
        XCTAssertEqual(store.cat?.health, 80)
        XCTAssertEqual(store.snapshot?.player.gold, original.player.gold - 260)
        XCTAssertEqual(Array(try XCTUnwrap(store.snapshot).cats.prefix(2)), Array(original.cats.prefix(2)))
        let durable = await repository.savedSnapshot
        let roundTrip = try JSONDecoder().decode(GameSnapshot.self, from: JSONEncoder().encode(durable))
        let reopened = GameStore(repository: CatAdoptionSaveRepository(roundTrip))
        await reopened.load()
        XCTAssertEqual(reopened.snapshot?.schemaVersion, GameSnapshot.currentSchemaVersion)
        XCTAssertEqual(reopened.snapshot?.cats, durable.cats)
        XCTAssertEqual(reopened.cat?.id, CatCatalog.blueCatID)
        XCTAssertEqual(reopened.cat?.customName, "蓝莓🐾")
        XCTAssertEqual(reopened.cat?.appearance, .blue)
        XCTAssertEqual(reopened.snapshot?.cats[0].healthState?.illness, .cold)
        XCTAssertEqual(reopened.snapshot?.cats[1].customName, "Milk🐾")
        XCTAssertNil(reopened.inspectedCatID)
    }

    @MainActor
    func testFailedAdoptionKeepsWalletAndCatsUntilExplicitRetryChargesOnce() async throws {
        let repository = CatAdoptionSaveRepository(seed())
        let store = GameStore(repository: repository)
        await store.load()
        let original = try XCTUnwrap(store.snapshot)
        let baseline = await repository.attempts.count
        await repository.setWritesFailing(true)

        let failed = await store.adoptCat(catID: CatCatalog.cowCatID)

        XCTAssertFalse(failed)
        XCTAssertEqual(store.snapshot, original)
        XCTAssertEqual(store.cat?.id, CatCatalog.initialCatID)
        XCTAssertTrue(store.showSaveError && store.hasSaveFailure)
        XCTAssertFalse(store.isBusy)
        let unchanged = await repository.savedSnapshot
        XCTAssertEqual(unchanged, original)
        let failedAttempts = await repository.attempts
        XCTAssertEqual(failedAttempts.count, baseline + 1)
        XCTAssertEqual(failedAttempts.last?.cats.count, 2)
        XCTAssertEqual(failedAttempts.last?.player.gold, original.player.gold - 300)

        await repository.setWritesFailing(false)
        let retried = await store.adoptCat(catID: CatCatalog.cowCatID)
        XCTAssertTrue(retried)
        let adopted = try XCTUnwrap(store.snapshot)
        XCTAssertEqual(adopted.player.gold, original.player.gold - 300)
        XCTAssertEqual(adopted.cats.map(\.id), [CatCatalog.initialCatID, CatCatalog.cowCatID])
        XCTAssertEqual(adopted.cats[0], original.cats[0])
        XCTAssertEqual(adopted.activeCatID, original.activeCatID)
        XCTAssertFalse(store.hasSaveFailure)
        let attempts = await repository.attempts
        XCTAssertEqual(attempts.count, baseline + 2)
        let durable = await repository.savedSnapshot
        XCTAssertEqual(durable, adopted)
        let duplicate = await store.adoptCat(catID: CatCatalog.cowCatID)
        XCTAssertFalse(duplicate)
        XCTAssertEqual(store.snapshot?.player.gold, adopted.player.gold)
        XCTAssertEqual(store.snapshot?.cats, adopted.cats)
    }

    @MainActor
    func testFailedSwitchKeepsOriginalCompanionAndSuccessfulRetrySurvivesReload() async throws {
        let repository = CatAdoptionSaveRepository(seed(adopted: true))
        let store = GameStore(repository: repository)
        await store.load()
        let original = try XCTUnwrap(store.snapshot)
        await repository.setWritesFailing(true)
        let failed = await store.selectCompanion(catID: CatCatalog.cowCatID)
        XCTAssertFalse(failed)
        XCTAssertEqual(store.snapshot, original)
        XCTAssertEqual(store.cat?.id, CatCatalog.initialCatID)
        let unchanged = await repository.savedSnapshot
        XCTAssertEqual(unchanged, original)
        XCTAssertTrue(store.showSaveError && store.hasSaveFailure)

        await repository.setWritesFailing(false)
        let switched = await store.selectCompanion(catID: CatCatalog.cowCatID)
        XCTAssertTrue(switched)
        XCTAssertEqual(store.cat?.id, CatCatalog.cowCatID)
        XCTAssertEqual(store.cat?.customName, "Milk🐾")
        XCTAssertEqual(store.cat?.appearance, .cow)
        XCTAssertEqual(store.snapshot?.cats, original.cats)
        XCTAssertEqual(store.snapshot?.player, original.player)
        let reopened = GameStore(repository: repository)
        await reopened.load()
        XCTAssertEqual(reopened.cat?.id, CatCatalog.cowCatID)
        XCTAssertEqual(reopened.cat?.customName, "Milk🐾")
        XCTAssertEqual(reopened.snapshot?.cats[0].customName, "小太阳")
        XCTAssertNil(reopened.inspectedCatID)
    }

    @MainActor
    func testSlowCompanionSaveRejectsOldRestArrivalAndExitWithoutLateRecovery() async throws {
        let repository = CatAdoptionSaveRepository(seed(adopted: true))
        let store = GameStore(repository: repository)
        await store.load()
        store.setRestingFurniture(id: "catBed", sessionID: "old-cat-rest", catID: CatCatalog.initialCatID)
        try await eventually { store.cat?.activeRest?.id == "old-cat-rest" && !store.isBusy }
        await repository.holdNextSave()
        defer { Task { await repository.releaseSave() } }
        let switchTask = Task { await store.selectCompanion(catID: CatCatalog.cowCatID) }
        try await eventually { await repository.isSaveBlocked }
        let pendingCandidate = await repository.latestAttempt()
        let switchCandidate = try XCTUnwrap(pendingCandidate)
        XCTAssertNil(switchCandidate.cats[0].activeRest)
        XCTAssertEqual(store.cat?.id, CatCatalog.initialCatID, "Selection is published only after saving.")
        let cowBefore = try XCTUnwrap(store.snapshot?.cats[1])
        try await Task.sleep(for: .milliseconds(1_100))
        store.setRestingFurniture(id: "floorCushion", sessionID: "late-old-arrival", catID: CatCatalog.initialCatID)
        store.setRestingFurniture(id: nil, sessionID: "old-cat-rest", catID: CatCatalog.initialCatID)
        await repository.releaseSave()
        let switched = await switchTask.value
        XCTAssertTrue(switched)
        try await eventually { !store.isBusy }

        XCTAssertEqual(store.cat?.id, CatCatalog.cowCatID)
        XCTAssertNil(store.restingFurnitureID)
        XCTAssertNil(store.snapshot?.cats[0].activeRest)
        XCTAssertEqual(store.snapshot?.cats[0].energy, switchCandidate.cats[0].energy,
                       "A queued exit must not award time spent waiting for the switch save.")
        XCTAssertEqual(store.snapshot?.cats[1], cowBefore)
        XCTAssertNil(store.feedback)
        let durable = await repository.savedSnapshot
        XCTAssertEqual(durable, store.snapshot)
        let maximum = await repository.maximumConcurrentSaves
        XCTAssertEqual(maximum, 1)

        store.setRestingFurniture(id: "catBed", sessionID: "new-cat-rest", catID: CatCatalog.cowCatID)
        try await eventually { store.cat?.activeRest?.id == "new-cat-rest" && !store.isBusy }
        store.setRestingFurniture(id: nil, sessionID: "old-cat-rest", catID: CatCatalog.initialCatID)
        try await eventually { !store.isBusy }
        XCTAssertEqual(store.cat?.activeRest?.id, "new-cat-rest")
        XCTAssertEqual(store.restingFurnitureID, "catBed")
        store.setRestingFurniture(id: "floorCushion", sessionID: "even-later-old-arrival", catID: CatCatalog.initialCatID)
        XCTAssertEqual(store.cat?.activeRest?.id, "new-cat-rest")
        XCTAssertNil(store.snapshot?.cats[0].activeRest)
        XCTAssertEqual(store.restingFurnitureID, "catBed")
    }

    @MainActor
    func testSwitchAfterFailedSaveReplaysCapturedOldRestExitWithoutGivingNewCatRecovery() async throws {
        let repository = CatAdoptionSaveRepository(seed(adopted: true))
        let store = GameStore(repository: repository)
        await store.load()
        store.setRestingFurniture(id: "catBed", sessionID: "failed-switch-rest", catID: CatCatalog.initialCatID)
        try await eventually { store.cat?.activeRest?.id == "failed-switch-rest" && !store.isBusy }
        let original = try XCTUnwrap(store.snapshot)
        await repository.setWritesFailing(true)
        await repository.holdNextSave()
        defer { Task { await repository.releaseSave() } }
        let switchTask = Task { await store.selectCompanion(catID: CatCatalog.cowCatID) }
        try await eventually { await repository.isSaveBlocked }
        store.setRestingFurniture(id: nil, sessionID: "failed-switch-rest", catID: CatCatalog.initialCatID)
        await repository.releaseSave()
        let failed = await switchTask.value
        XCTAssertFalse(failed)
        XCTAssertEqual(store.snapshot, original)
        XCTAssertEqual(store.cat?.id, CatCatalog.initialCatID)
        await repository.setWritesFailing(false)
        let switched = await store.selectCompanion(catID: CatCatalog.cowCatID)
        XCTAssertTrue(switched)
        XCTAssertEqual(store.cat?.id, CatCatalog.cowCatID)
        XCTAssertNil(store.snapshot?.cats[0].activeRest)
        XCTAssertEqual(store.snapshot?.cats[1], original.cats[1])
        XCTAssertNil(store.restingFurnitureID)
        let durable = await repository.savedSnapshot
        XCTAssertEqual(durable, store.snapshot)
        let maximum = await repository.maximumConcurrentSaves
        XCTAssertEqual(maximum, 1)
    }

    @MainActor
    func testCareAndInspectionFollowSavedCompanionWhileOtherCatRemainsIndependent() async throws {
        let repository = CatAdoptionSaveRepository(seed(adopted: true))
        let store = GameStore(repository: repository)
        await store.load()
        let switched = await store.selectCompanion(catID: CatCatalog.cowCatID)
        XCTAssertTrue(switched)
        let original = try XCTUnwrap(store.snapshot)
        store.inspectCat()
        XCTAssertEqual(store.inspectedCatID, CatCatalog.cowCatID)
        XCTAssertNil(store.activeSheet)

        store.feed()
        try await eventually { !store.isBusy && store.feedback?.kind == .feed }
        XCTAssertEqual(store.feedback?.catID, CatCatalog.cowCatID)
        XCTAssertEqual(store.cat?.satiety, original.cats[1].satiety + 25)
        XCTAssertEqual(store.snapshot?.cats[0], original.cats[0])
        store.clean()
        try await eventually { !store.isBusy && store.feedback?.kind == .clean }
        XCTAssertEqual(store.feedback?.catID, CatCatalog.cowCatID)
        XCTAssertEqual(store.cat?.cleanliness, original.cats[1].cleanliness + 30)
        XCTAssertEqual(store.snapshot?.cats[0], original.cats[0])
        store.play()
        try await eventually { !store.isBusy && store.feedback?.kind == .play }
        XCTAssertEqual(store.feedback?.catID, CatCatalog.cowCatID)
        XCTAssertEqual(store.cat?.intimacy, original.cats[1].intimacy + 12)
        XCTAssertEqual(store.cat?.energy, original.cats[1].energy - 10)
        XCTAssertEqual(store.snapshot?.cats[0], original.cats[0])
        XCTAssertEqual(store.snapshot?.inventory.food, original.inventory.food - 1)
        XCTAssertEqual(store.snapshot?.inventory.litter, original.inventory.litter - 1)
        XCTAssertEqual(store.snapshot?.inventory.toys, original.inventory.toys - 1)

        let cowAfterCare = store.cat
        let switchedBack = await store.selectCompanion(catID: CatCatalog.initialCatID)
        XCTAssertTrue(switchedBack)
        XCTAssertNil(store.feedback)
        store.inspectCat()
        XCTAssertEqual(store.inspectedCatID, CatCatalog.initialCatID)
        store.feed()
        try await eventually { !store.isBusy && store.feedback?.kind == .feed }
        XCTAssertEqual(store.feedback?.catID, CatCatalog.initialCatID)
        XCTAssertEqual(store.snapshot?.cats[1], cowAfterCare)
        XCTAssertEqual(store.cat?.satiety, original.cats[0].satiety + 25)
    }

    @MainActor
    func testInFlightAdoptionBlocksSecondAdoptionSelectionAndCare() async throws {
        let repository = CatAdoptionSaveRepository(seed())
        let store = GameStore(repository: repository)
        await store.load()
        let original = try XCTUnwrap(store.snapshot)
        let baseline = await repository.attempts.count
        await repository.holdNextSave()
        defer { Task { await repository.releaseSave() } }
        let first = Task { await store.adoptCat(catID: CatCatalog.cowCatID) }
        try await eventually { await repository.isSaveBlocked }
        XCTAssertTrue(store.isBusy)
        let duplicate = await store.adoptCat(catID: CatCatalog.cowCatID)
        let blockedSwitch = await store.selectCompanion(catID: CatCatalog.cowCatID)
        XCTAssertFalse(duplicate || blockedSwitch)
        store.feed()
        store.clean()
        store.play()
        store.inspectCat()
        XCTAssertEqual(store.inspectedCatID, CatCatalog.initialCatID)
        XCTAssertEqual(store.snapshot, original)
        XCTAssertNil(store.feedback)
        let during = await repository.attempts.count
        XCTAssertEqual(during, baseline + 1)
        await repository.releaseSave()
        let saved = await first.value
        XCTAssertTrue(saved)
        XCTAssertFalse(store.isBusy)
        XCTAssertEqual(store.snapshot?.cats.count, 2)
        XCTAssertEqual(store.snapshot?.player.gold, original.player.gold - 300)
        XCTAssertEqual(store.snapshot?.cats[0], original.cats[0])
        XCTAssertEqual(store.snapshot?.inventory, original.inventory)
        XCTAssertEqual(store.cat?.id, CatCatalog.initialCatID)
        let maximum = await repository.maximumConcurrentSaves
        XCTAssertEqual(maximum, 1)
    }

    private func seed(adopted: Bool = false) -> GameSnapshot {
        let now = Date()
        var value = GameSnapshot.fresh(now: now)
        value.settings.audio = AudioSettings(musicEnabled: false, effectsEnabled: false)
        value.player.level = 2
        value.player.gold = 1_200
        value.home.roomLevel = 2
        value.inventory.food = 8
        value.inventory.litter = 8
        value.inventory.toys = 8
        value.cats[0].customName = "小太阳"
        value.cats[0].energy = 30
        if adopted {
            _ = GameEngine.adoptCat(&value, catID: CatCatalog.cowCatID, now: now)
            value.cats[1].customName = "Milk🐾"
            value.cats[1].cleanliness = 40
            value.cats[1].energy = 40
        }
        return value
    }

    private func blueAdoptionSeed() -> GameSnapshot {
        var value = seed(adopted: true)
        value.player.level = 4
        value.player.gold = 1800
        value.home.roomLevel = 3
        value.activeCatID = CatCatalog.cowCatID
        return value
    }

    @MainActor
    private func eventually(_ condition: @MainActor () async -> Bool) async throws {
        let deadline = Date().addingTimeInterval(4)
        while Date() < deadline {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("The serialized cat-adoption transaction did not settle.")
        throw CatAdoptionTestFailure.timedOut
    }
}

private enum CatAdoptionTestFailure: Error { case unavailable, timedOut }

private actor CatAdoptionSaveRepository: GameSaveRepository {
    let lastLoadDisposition = SaveLoadDisposition.loaded
    private(set) var savedSnapshot: GameSnapshot
    private(set) var attempts: [GameSnapshot] = []
    private(set) var maximumConcurrentSaves = 0
    private var activeSaves = 0
    private var writesFailing = false
    private var shouldHold = false
    private var heldSave: CheckedContinuation<Void, Never>?
    var isSaveBlocked: Bool { heldSave != nil }

    init(_ snapshot: GameSnapshot) { savedSnapshot = snapshot }
    func setWritesFailing(_ value: Bool) { writesFailing = value }
    func holdNextSave() { shouldHold = true }
    func releaseSave() { heldSave?.resume(); heldSave = nil }
    func latestAttempt() -> GameSnapshot? { attempts.last }
    func loadOrCreate(now: Date) async throws -> GameSnapshot { savedSnapshot }

    func checkWritable() throws { if writesFailing { throw CatAdoptionTestFailure.unavailable } }

    func save(_ snapshot: GameSnapshot) async throws {
        let fails = writesFailing
        attempts.append(snapshot)
        activeSaves += 1
        maximumConcurrentSaves = max(maximumConcurrentSaves, activeSaves)
        defer { activeSaves -= 1 }
        if shouldHold {
            shouldHold = false
            await withCheckedContinuation { heldSave = $0 }
        }
        if fails { throw CatAdoptionTestFailure.unavailable }
        savedSnapshot = snapshot
    }
}
