import Foundation
import XCTest
import CatGameCore
@testable import CatLife

final class GameStoreFurnitureOrientationTests: XCTestCase {
    @MainActor
    func testFlippingOnlyChangesSelectedDraftAndCancelRestoresSavedDirections() async throws {
        let repository = OrientationSaveRepository(seed())
        let store = GameStore(repository: repository)
        await store.load()
        let original = try XCTUnwrap(store.snapshot)
        let baseline = await repository.attempts.count
        store.beginDecorating()
        store.selectFurniture(id: "plantSmall")
        XCTAssertTrue(store.canFlipSelectedFurniture)
        store.flipSelectedFurniture()
        XCTAssertEqual(store.selectedFurniture?.orientation, .mirrored)
        XCTAssertEqual(item("plantSmall", in: store.sceneSnapshot)?.orientation, .mirrored)
        XCTAssertEqual(item("plantLarge", in: store.sceneSnapshot)?.orientation, .mirrored)
        XCTAssertEqual(store.snapshot, original)
        store.flipSelectedFurniture()
        XCTAssertEqual(store.selectedFurniture?.orientation, .normal)
        store.selectFurniture(id: "catBed")
        store.flipSelectedFurniture()
        store.cancelDecorating()
        XCTAssertFalse(store.isDecorating)
        XCTAssertNil(store.draftFurnitureOrientations)
        XCTAssertEqual(store.sceneSnapshot, original)
        let count = await repository.attempts.count
        XCTAssertEqual(count, baseline, "Draft previews and cancellation must not write a save.")
    }

    @MainActor
    func testWallsBowlValidationAndBusyStatePreventFlipsWithoutLosingTheDraft() async throws {
        let repository = OrientationSaveRepository(seed())
        let store = GameStore(repository: repository)
        await store.load()
        store.beginDecorating()
        let unsupportedIDs: [String?] = [nil, "wallCat", "wallFlower"]
        for id in unsupportedIDs {
            store.selectFurniture(id: id)
            XCTAssertFalse(store.canFlipSelectedFurniture)
            store.flipSelectedFurniture()
        }
        XCTAssertEqual(store.draftFurnitureOrientations, [:])
        store.selectFurniture(id: "cabinet")
        store.setLayoutResolving(true)
        XCTAssertFalse(store.canFlipSelectedFurniture)
        store.flipSelectedFurniture()
        XCTAssertEqual(store.selectedFurniture?.orientation, .normal)
        store.setLayoutResolving(false)
        store.flipSelectedFurniture()
        XCTAssertEqual(store.selectedFurniture?.orientation, .mirrored)

        await repository.holdNextSave()
        defer { Task { await repository.release() } }
        store.upgradeHome(toLevel: 2)
        try await eventually { await repository.isHeld }
        XCTAssertFalse(store.canFlipSelectedFurniture)
        store.flipSelectedFurniture()
        XCTAssertEqual(store.selectedFurniture?.orientation, .mirrored)
        await repository.release()
        try await eventually { !store.isBusy }
        XCTAssertEqual(store.snapshot?.home.roomLevel, 2)
        XCTAssertEqual(item("cabinet", in: store.snapshot)?.orientation, .normal)
        XCTAssertEqual(store.selectedFurniture?.orientation, .mirrored,
                       "An independent durable update must retain the unsaved orientation draft.")
        XCTAssertTrue(store.canFlipSelectedFurniture)
        store.cancelDecorating()
        XCTAssertEqual(store.snapshot?.home.roomLevel, 2)
        XCTAssertEqual(item("cabinet", in: store.sceneSnapshot)?.orientation, .normal)
    }

    @MainActor
    func testFailedSaveRetainsPositionAndDirectionDraftUntilOneAtomicRetry() async throws {
        let repository = OrientationSaveRepository(seed())
        let store = GameStore(repository: repository)
        await store.load()
        let original = try XCTUnwrap(store.snapshot)
        let destination = NormalizedPoint(x: 0.58, y: 0.68)
        store.beginDecorating()
        store.selectFurniture(id: "cabinet")
        store.flipSelectedFurniture()
        store.moveFurniture(id: "cabinet", to: destination)
        await repository.setFailing(true)
        let baseline = await repository.attempts.count
        store.finishDecorating()
        try await eventually {
            let count = await repository.attempts.count
            return count == baseline + 1 && !store.isBusy
        }
        XCTAssertEqual(store.snapshot, original)
        XCTAssertTrue(store.isDecorating && store.showSaveError && store.hasSaveFailure)
        XCTAssertFalse(store.isSavingLayout)
        XCTAssertEqual(store.selectedFurniture?.orientation, .mirrored)
        XCTAssertEqual(store.draftFurniture?.first { $0.itemID == "cabinet" }?.position, destination)
        let unchanged = await repository.saved
        XCTAssertEqual(unchanged, original)

        await repository.setFailing(false)
        await repository.holdNextSave()
        defer { Task { await repository.release() } }
        store.finishDecorating()
        try await eventually { await repository.isHeld }
        XCTAssertTrue(store.isBusy && store.isSavingLayout)
        XCTAssertFalse(store.canFlipSelectedFurniture)
        store.flipSelectedFurniture()
        store.moveFurniture(id: "cabinet", to: NormalizedPoint(x: 0.1, y: 0.1))
        store.cancelDecorating()
        XCTAssertTrue(store.isDecorating)
        XCTAssertEqual(store.snapshot, original)
        let pending = await repository.latestAttempt()
        let candidate = try XCTUnwrap(pending)
        XCTAssertEqual(item("cabinet", in: candidate)?.orientation, .mirrored)
        XCTAssertEqual(candidate.home.furniture.first { $0.itemID == "cabinet" }?.position, destination)
        await repository.release()
        try await eventually { !store.isBusy && !store.isDecorating }
        XCTAssertNil(store.draftFurnitureOrientations)
        XCTAssertFalse(store.hasSaveFailure)
        XCTAssertEqual(item("cabinet", in: store.snapshot)?.orientation, .mirrored)
        XCTAssertEqual(store.snapshot?.home.furniture.first { $0.itemID == "cabinet" }?.position, destination)
        let durable = await repository.saved
        XCTAssertEqual(store.snapshot, durable)
        let reopened = GameStore(repository: repository)
        await reopened.load()
        XCTAssertEqual(reopened.snapshot?.home, durable.home)
        XCTAssertEqual(reopened.snapshot?.inventory, durable.inventory)
    }

    @MainActor
    func testStoringAndReplacingFurniturePreservesItsSavedOrientation() async throws {
        let repository = OrientationSaveRepository(seed())
        let store = GameStore(repository: repository)
        await store.load()
        let position = try XCTUnwrap(store.snapshot?.home.furniture.first { $0.itemID == "cabinet" }?.position)
        store.beginDecorating()
        store.selectFurniture(id: "cabinet")
        store.flipSelectedFurniture()
        store.storeSelectedFurniture()
        XCTAssertEqual(store.storedFurniture.first { $0.id == "cabinet" }?.orientation, .mirrored)
        store.finishDecorating()
        try await eventually { !store.isBusy && !store.isDecorating }
        XCTAssertFalse(try XCTUnwrap(store.snapshot).home.furniture.contains { $0.itemID == "cabinet" })
        XCTAssertEqual(item("cabinet", in: store.snapshot)?.orientation, .mirrored)
        let stored = try XCTUnwrap(store.snapshot)

        store.placeFurniture(id: "cabinet")
        XCTAssertEqual(store.selectedFurniture?.orientation, .mirrored)
        XCTAssertFalse(store.canFlipSelectedFurniture)
        store.flipSelectedFurniture()
        store.moveFurniture(id: "cabinet", to: position)
        store.finishFurniturePlacement(id: "cabinet", succeeded: true)
        XCTAssertTrue(store.canFlipSelectedFurniture)
        store.cancelDecorating()
        XCTAssertEqual(store.snapshot, stored)
        XCTAssertEqual(store.storedFurniture.first { $0.id == "cabinet" }?.orientation, .mirrored)

        store.placeFurniture(id: "cabinet")
        store.moveFurniture(id: "cabinet", to: position)
        store.finishFurniturePlacement(id: "cabinet", succeeded: true)
        store.finishDecorating()
        try await eventually { !store.isBusy && !store.isDecorating }
        let reopened = GameStore(repository: repository)
        await reopened.load()
        XCTAssertEqual(item("cabinet", in: reopened.snapshot)?.orientation, .mirrored)
        XCTAssertEqual(reopened.snapshot?.home.furniture.first { $0.itemID == "cabinet" }?.position, position)
    }

    private func seed() -> GameSnapshot {
        var value = GameSnapshot.fresh()
        value.settings.audio = AudioSettings(musicEnabled: false, effectsEnabled: false)
        value.player.level = 4
        value.player.gold = 2000
        if let index = value.inventory.furniture.firstIndex(where: { $0.id == "plantLarge" }) {
            value.inventory.furniture[index].orientation = .mirrored
        }
        return value
    }

    private func item(_ id: String, in snapshot: GameSnapshot?) -> FurnitureItem? {
        snapshot?.inventory.furniture.first { $0.id == id }
    }

    @MainActor
    private func eventually(_ condition: @MainActor () async -> Bool) async throws {
        let deadline = Date().addingTimeInterval(4)
        while Date() < deadline {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("The furniture orientation transaction did not settle.")
        throw CocoaError(.fileWriteUnknown)
    }
}

private actor OrientationSaveRepository: GameSaveRepository {
    let lastLoadDisposition = SaveLoadDisposition.loaded
    private(set) var saved: GameSnapshot
    private(set) var attempts: [GameSnapshot] = []
    private var failing = false
    private var hold = false
    private var continuation: CheckedContinuation<Void, Never>?
    var isHeld: Bool { continuation != nil }

    init(_ value: GameSnapshot) { saved = value }
    func setFailing(_ value: Bool) { failing = value }
    func holdNextSave() { hold = true }
    func release() { continuation?.resume(); continuation = nil }
    func latestAttempt() -> GameSnapshot? { attempts.last }
    func loadOrCreate(now: Date) throws -> GameSnapshot {
        try JSONDecoder().decode(GameSnapshot.self, from: JSONEncoder().encode(saved))
    }
    func checkWritable() throws { if failing { throw CocoaError(.fileWriteUnknown) } }
    func save(_ value: GameSnapshot) async throws {
        attempts.append(value)
        if hold {
            hold = false
            await withCheckedContinuation { continuation = $0 }
        }
        if failing { throw CocoaError(.fileWriteUnknown) }
        saved = value
    }
}
