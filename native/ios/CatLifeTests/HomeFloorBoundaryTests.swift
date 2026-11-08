import Foundation
import XCTest
import CatGameCore
@testable import CatLife

final class HomeFloorBoundaryTests: XCTestCase {
    @MainActor
    private func store(_ repository: HomeFloorBoundaryRepository) -> GameStore {
        let suite = "CatLife-home-floor-boundary-\(UUID())"
        addTeardownBlock { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        return GameStore(repository: repository, reminderDefaults: UserDefaults(suiteName: suite)!)
    }

    private func seed(level: Int = 6) -> GameSnapshot {
        var value = GameSnapshot.fresh()
        value.home = HomeState(roomLevel: level)
        value.player.gold = 30_000
        value.player.level = 20
        value.settings.audio.musicEnabled = false
        value.settings.audio.effectsEnabled = false
        value.settings.audio.catEnabled = false
        value.settings.audio.haptics = false
        if level >= 6 {
            value.home.furniture[0].floor = .upper
            value.home.upperBowlPosition = .init(x: 0.4, y: 0.7)
        }
        return value
    }

    @MainActor
    func testInventoryFindsBothFloorsAndSelectsExistingFurnitureAfterTravelling() async throws {
        let repository = HomeFloorBoundaryRepository(seed())
        let store = store(repository)
        await store.load()
        let originalHome = store.snapshot?.home
        XCTAssertEqual(store.furnitureFloor(for: "cabinet"), .upper)
        XCTAssertEqual(store.furnitureFloor(for: "catBed"), .ground)
        XCTAssertEqual(store.totalPlacedFurnitureCount, 9)
        XCTAssertTrue(store.storedFurniture.isEmpty)
        store.activeSheet = .inventory
        let reachedUpper = await store.arrangeInventoryFurniture(id: "cabinet")
        XCTAssertTrue(reachedUpper)
        XCTAssertNil(store.activeSheet)
        XCTAssertEqual(store.visibleHomeFloor, .upper)
        XCTAssertTrue(store.isDecorating)
        XCTAssertEqual(store.selectedFurnitureID, "cabinet")
        XCTAssertFalse(store.hasUnsavedLayoutChanges)
        let refusedDuringDraft = await store.arrangeInventoryFurniture(id: "catBed")
        XCTAssertFalse(refusedDuringDraft)
        XCTAssertEqual(store.visibleHomeFloor, .upper)
        store.storeSelectedFurniture()
        XCTAssertNil(store.furnitureFloor(for: "cabinet"))
        XCTAssertEqual(store.storedFurniture.map(\.id), ["cabinet"])
        XCTAssertEqual(store.totalPlacedFurnitureCount, 8)
        store.cancelDecorating()
        XCTAssertEqual(store.furnitureFloor(for: "cabinet"), .upper)
        XCTAssertEqual(store.snapshot?.home, originalHome)
        let reachedGround = await store.arrangeInventoryFurniture(id: "catBed")
        XCTAssertTrue(reachedGround)
        XCTAssertEqual(store.visibleHomeFloor, .ground)
        XCTAssertEqual(store.selectedFurnitureID, "catBed")
        XCTAssertEqual(store.snapshot?.home, originalHome)
        store.cancelDecorating()
    }

    @MainActor
    func testFailedRestExitKeepsFloorAndInventoryDestinationUntilSuccessfulRetry() async throws {
        let repository = HomeFloorBoundaryRepository(seed())
        let store = store(repository)
        await store.load()
        let catID = try XCTUnwrap(store.cat?.id)
        store.setRestingFurniture(id: "catBed", sessionID: "downstairs-rest", catID: catID)
        try await settled(store)
        XCTAssertEqual(store.cat?.activeRest?.id, "downstairs-rest")
        let original = store.snapshot
        await repository.setFailing(true)
        store.activeSheet = .inventory
        let failed = await store.arrangeInventoryFurniture(id: "cabinet")
        XCTAssertFalse(failed)
        XCTAssertEqual(store.visibleHomeFloor, .ground)
        XCTAssertEqual(store.activeSheet, .inventory)
        XCTAssertFalse(store.isChangingHomeFloor || store.isDecorating)
        XCTAssertEqual(store.snapshot, original)
        XCTAssertEqual(store.restingFurnitureID, "catBed")
        XCTAssertTrue(store.hasSaveFailure)
        await repository.setFailing(false)
        let succeeded = await store.arrangeInventoryFurniture(id: "cabinet")
        XCTAssertTrue(succeeded)
        XCTAssertEqual(store.visibleHomeFloor, .upper)
        XCTAssertNil(store.cat?.activeRest)
        XCTAssertNil(store.restingFurnitureID)
        XCTAssertEqual(store.snapshot?.home, original?.home)
        XCTAssertEqual(store.selectedFurnitureID, "cabinet")
        XCTAssertFalse(store.hasSaveFailure)
        store.cancelDecorating()
    }

    @MainActor
    func testSceneProjectionNeverLeaksToPurchasesOrExportAndImportResetsFloor() async throws {
        let repository = HomeFloorBoundaryRepository(seed())
        let store = store(repository)
        await store.load()
        let originalHome = try XCTUnwrap(store.snapshot?.home)
        await store.changeHomeFloor(to: .upper)
        XCTAssertEqual(store.sceneSnapshot?.home.furniture.map(\.itemID), ["cabinet"])
        XCTAssertEqual(store.sceneSnapshot?.home.bowlPosition, originalHome.upperBowlPosition)
        store.buyFood()
        try await settled(store)
        let purchased = await repository.saved
        XCTAssertEqual(purchased.home, originalHome)
        let exported = try await store.exportSaveArchive()
        XCTAssertEqual(try NativeSaveTransfer.decode(exported).snapshot.home, originalHome)
        let generation = store.saveSceneGeneration
        let incoming = seed(level: 5)
        let archive = try NativeSaveTransfer.decode(NativeSaveTransfer.encode(snapshot: incoming))
        try await store.importSaveArchive(archive)
        XCTAssertEqual(store.visibleHomeFloor, .ground)
        XCTAssertNotEqual(store.saveSceneGeneration, generation)
        XCTAssertNil(store.homeUpgradeCelebration)
        XCTAssertFalse(store.isDecorating || store.isChangingHomeFloor)
        XCTAssertEqual(store.snapshot?.home, incoming.home)
        XCTAssertEqual(store.sceneSnapshot?.home, incoming.home)
        XCTAssertEqual(store.furnitureFloor(for: "cabinet"), .ground)
    }

    @MainActor
    private func settled(_ store: GameStore) async throws {
        let deadline = Date().addingTimeInterval(3)
        while store.isBusy {
            if Date() > deadline { throw WaitError.timeout }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
    private enum WaitError: Error { case timeout }
}

private actor HomeFloorBoundaryRepository: GameSaveTransferRepository {
    let lastLoadDisposition = SaveLoadDisposition.loaded
    private(set) var saved: GameSnapshot
    private var recovery: GameSnapshot?
    private var failing = false
    init(_ state: GameSnapshot) { saved = state }
    func setFailing(_ value: Bool) { failing = value }
    func loadOrCreate(now: Date) -> GameSnapshot { saved }
    func checkWritable() throws { if failing { throw CocoaError(.fileWriteUnknown) } }
    func save(_ state: GameSnapshot) throws {
        try checkWritable()
        saved = state
    }
    func importSnapshot(_ state: GameSnapshot) throws {
        try checkWritable()
        recovery = saved
        saved = state
    }
    func restoreSnapshotAfterLoadFailure(_ state: GameSnapshot) throws { try importSnapshot(state) }
    func loadImportRecovery() -> GameSnapshot? { recovery }
}
