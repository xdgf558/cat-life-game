import XCTest
import CatGameCore
@testable import CatLife

final class HomeFloorStoreTests: XCTestCase {
    @MainActor
    func testFloorsKeepIndependentLayoutsAndDoNotOfferPlacedFurnitureTwice() async throws {
        let repository = HomeFloorTestRepository(seed(level: 6))
        let store = GameStore(repository: repository)
        await store.load()
        let downstairs = try XCTUnwrap(store.snapshot).home.furniture
        await store.changeHomeFloor(to: .upper)
        XCTAssertEqual(store.visibleHomeFloor, .upper)
        XCTAssertEqual(store.sceneSnapshot?.home.furniture, [])
        XCTAssertEqual(store.storedFurniture.map(\.id), ["upstairsPlant"])
        store.beginDecorating()
        store.moveBowl(to: .init(x: 0.65, y: 0.8))
        store.placeFurniture(id: "upstairsPlant")
        store.moveFurniture(id: "upstairsPlant", to: .init(x: 0.6, y: 0.7))
        store.finishFurniturePlacement(id: "upstairsPlant", succeeded: true)
        await store.changeHomeFloor(to: .ground)
        XCTAssertEqual(store.visibleHomeFloor, .upper, "Do not silently discard an editing draft.")
        store.finishDecorating()
        try await settled(store)
        XCTAssertEqual(store.snapshot?.home.placements(on: .ground), downstairs)
        XCTAssertEqual(store.snapshot?.home.placements(on: .upper).map(\.itemID), ["upstairsPlant"])
        XCTAssertEqual(store.snapshot?.home.upperBowlPosition, .init(x: 0.65, y: 0.8))
        XCTAssertEqual(store.snapshot?.home.bowlPosition, HomeState.defaultBowlPosition)
        await store.changeHomeFloor(to: .ground)
        XCTAssertEqual(store.sceneSnapshot?.home.furniture, downstairs)
        XCTAssertTrue(store.storedFurniture.isEmpty)
        let relaunched = GameStore(repository: repository)
        await relaunched.load()
        await relaunched.changeHomeFloor(to: .upper)
        XCTAssertEqual(relaunched.sceneSnapshot?.home.furniture.map(\.itemID), ["upstairsPlant"])
        XCTAssertEqual(relaunched.sceneSnapshot?.home.bowlPosition, .init(x: 0.65, y: 0.8))
    }

    @MainActor
    func testUpgradeCelebrationRequiresDurableSuccessAndDoesNotReplayOnLoad() async throws {
        let repository = HomeFloorTestRepository(seed(level: 5))
        let store = GameStore(repository: repository)
        await store.load()
        await repository.setFailing(true)
        store.upgradeHome(toLevel: 6)
        try await settled(store)
        XCTAssertNil(store.homeUpgradeCelebration)
        XCTAssertEqual(store.snapshot?.home.roomLevel, 5)
        XCTAssertFalse(store.canChangeHomeFloor)
        await repository.setFailing(false)
        store.upgradeHome(toLevel: 6)
        try await settled(store)
        XCTAssertEqual(store.homeUpgradeCelebration?.level, 6)
        let gold = store.snapshot?.player.gold
        store.homeUpgradeCelebration = nil
        store.upgradeHome(toLevel: 6)
        try await settled(store)
        XCTAssertEqual(store.snapshot?.player.gold, gold)
        XCTAssertNil(store.homeUpgradeCelebration)
        let relaunched = GameStore(repository: repository)
        await relaunched.load()
        XCTAssertNil(relaunched.homeUpgradeCelebration)
        XCTAssertEqual(relaunched.snapshot?.home.roomLevel, 6)
    }

    @MainActor
    func testCancellingUpstairsDraftLeavesBothFloorsAndBowlUntouched() async throws {
        let repository = HomeFloorTestRepository(seed(level: 6))
        let store = GameStore(repository: repository)
        await store.load()
        let original = store.snapshot
        await store.changeHomeFloor(to: .upper)
        store.beginDecorating()
        store.moveBowl(to: .init(x: 0.2, y: 0.6))
        XCTAssertTrue(store.hasUnsavedLayoutChanges)
        store.cancelDecorating()
        XCTAssertEqual(store.snapshot, original)
        XCTAssertEqual(store.sceneSnapshot?.home.bowlPosition, HomeState.defaultBowlPosition)
    }

    @MainActor
    func testColdLaunchSettlesUpperFloorRestBeforePresentingGroundFloor() async throws {
        await RoomScene.preloadWelcomeResources()
        let initial = try upstairsRestSeed()
        let repository = HomeFloorTestRepository(initial)
        let store = GameStore(repository: repository)
        await store.load()
        let loaded = try XCTUnwrap(store.snapshot)
        var expected = initial
        XCTAssertTrue(GameEngine.endCatRest(&expected, catID: initial.cats[0].id,
            sessionID: "upstairs-cold-launch", now: loaded.meta.lastSyncAt).succeeded)
        XCTAssertEqual(loaded.cats, expected.cats, "Offline rest settles using the full save, including upstairs furniture.")
        XCTAssertNil(store.cat?.activeRest)
        XCTAssertNil(store.restingFurnitureID)
        XCTAssertFalse(store.loadFailed || store.isBusy || store.hasSaveFailure)
        XCTAssertEqual(store.visibleHomeFloor, .ground)
        XCTAssertEqual(loaded.home, initial.home)
        XCTAssertFalse(try XCTUnwrap(store.sceneSnapshot).home.furniture.contains { $0.itemID == "catBed" })
        XCTAssertTrue(loaded.home.placements(on: .upper).contains { $0.itemID == "catBed" })
        let durable = await repository.loadOrCreate(now: Date())
        XCTAssertEqual(durable, loaded)
        store.enterHome()
        await store.changeHomeFloor(to: .upper)
        XCTAssertEqual(store.visibleHomeFloor, .upper)
        XCTAssertTrue(try XCTUnwrap(store.sceneSnapshot).home.furniture.contains { $0.itemID == "catBed" })
        XCTAssertNil(store.cat?.activeRest, "Going upstairs must not restart the settled rest.")
    }

    @MainActor
    func testColdLaunchUpperRestWriteFailureRetainsExitAndRecoversWithoutReloading() async throws {
        await RoomScene.preloadWelcomeResources()
        let initial = try upstairsRestSeed()
        let repository = HomeFloorTestRepository(initial)
        await repository.setFailing(true)
        let store = GameStore(repository: repository)
        await store.load()
        XCTAssertEqual(store.snapshot, initial)
        XCTAssertFalse(store.loadFailed || store.isBusy)
        XCTAssertTrue(store.hasSaveFailure)
        XCTAssertEqual(store.visibleHomeFloor, .ground)
        XCTAssertNil(store.restingFurnitureID, "A stale durable rest must not recreate a ground-floor sleeping pose.")
        XCTAssertFalse(try XCTUnwrap(store.sceneSnapshot).home.furniture.contains { $0.itemID == "catBed" })
        let failedAttempts = await repository.attempts
        let capturedExit = try XCTUnwrap(failedAttempts.first)
        XCTAssertNil(capturedExit.cats[0].activeRest)
        XCTAssertEqual(capturedExit.home, initial.home)
        let preserved = await repository.loadOrCreate(now: Date())
        XCTAssertEqual(preserved, initial, "A failed reconciliation must preserve both floors and the original rest on disk.")
        store.enterHome()
        XCTAssertTrue(store.hasEnteredHome)
        await repository.setFailing(false)
        store.retrySaving()
        try await settled(store)
        let recovered = try XCTUnwrap(store.snapshot)
        XCTAssertFalse(store.hasSaveFailure || store.isBusy)
        XCTAssertEqual(recovered.cats, capturedExit.cats,
                       "Retry reuses the captured exit time and must not grant extra upstairs rest energy.")
        XCTAssertEqual(recovered.home, initial.home)
        XCTAssertNil(store.cat?.activeRest)
        let durable = await repository.loadOrCreate(now: Date())
        XCTAssertEqual(durable, recovered)
        await store.changeHomeFloor(to: .upper)
        XCTAssertEqual(store.visibleHomeFloor, .upper, "The failed startup write must not leave floor travel locked.")
    }

    private func upstairsRestSeed() throws -> GameSnapshot {
        let startedAt = Date().addingTimeInterval(-2)
        var value = seed(level: 6, now: startedAt)
        let bed = try XCTUnwrap(value.home.furniture.firstIndex { $0.itemID == "catBed" })
        value.home.furniture[bed].floor = .upper
        value.cats[0].energy = 40
        XCTAssertTrue(GameEngine.startCatRest(&value, catID: value.cats[0].id, furnitureID: "catBed",
            sessionID: "upstairs-cold-launch", now: startedAt).succeeded)
        _ = try NativeSaveTransfer.encode(snapshot: value)
        return value
    }

    private func seed(level: Int, now: Date = Date()) -> GameSnapshot {
        var value = GameSnapshot.fresh(now: now)
        value.player.level = 20
        value.player.gold = 30_000
        value.home = HomeState(roomLevel: level)
        value.inventory.furniture.append(.init(id: "upstairsPlant", kind: .plant))
        return value
    }

    @MainActor private func settled(_ store: GameStore) async throws {
        for _ in 0..<150 {
            if !store.isBusy { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTFail("Save did not finish")
    }
}

private actor HomeFloorTestRepository: GameSaveRepository {
    let lastLoadDisposition: SaveLoadDisposition = .loaded
    private var saved: GameSnapshot
    private var failing = false
    private(set) var attempts: [GameSnapshot] = []
    init(_ value: GameSnapshot) { saved = value }
    func setFailing(_ failing: Bool) { self.failing = failing }
    func loadOrCreate(now: Date) -> GameSnapshot { saved }
    func checkWritable() throws { if failing { throw CocoaError(.fileWriteUnknown) } }
    func save(_ value: GameSnapshot) throws {
        attempts.append(value)
        if failing { throw CocoaError(.fileWriteUnknown) }
        saved = value
    }
}
