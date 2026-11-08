import Foundation
import XCTest
import CatGameCore
@testable import CatLife

final class HomePurchaseFloorTests: XCTestCase {
    @MainActor
    func testPurchaseUsesOtherFloorBeforeUpgradeOrMakeRoomInEitherDirection() async throws {
        for level in [6, 8] {
            for fullFloor in HomeFloor.allCases {
                let initial = seed(level: level, fullFloor: fullFloor)
                let repository = HomePurchaseFloorRepository(initial)
                let store = makeStore(repository)
                await store.load()
                store.enterHome()
                await store.changeHomeFloor(to: fullFloor)
                let target: HomeFloor = fullFloor == .ground ? .upper : .ground
                let itemID = try await purchase(store)
                let purchased = try XCTUnwrap(store.snapshot)
                let context = "level \(level), full floor \(fullFloor.rawValue)"
                XCTAssertFalse(store.canPlaceMoreFurniture, context)
                XCTAssertEqual(store.availableFurnitureFloor, target, context)
                XCTAssertEqual(store.furniturePurchaseActionKey, "homeInventory.arrange.\(target.rawValue)", context)
                XCTAssertEqual(store.furnitureCapacityNotice,
                    GameStrings.format("homeInventory.space.\(target.rawValue)", store.availableFurnitureSlots(on: target)), context)

                await store.decoratePurchasedFurniture()

                XCTAssertEqual(store.visibleHomeFloor, target, context)
                XCTAssertNil(store.activeSheet, context)
                XCTAssertTrue(store.isDecorating && store.isFurnitureTrayExpanded, context)
                XCTAssertEqual(store.selectedStoredFurnitureID, itemID, context)
                XCTAssertNil(store.placingFurnitureID, context)
                XCTAssertNil(store.furniturePurchaseNotice, context)
                XCTAssertEqual(store.snapshot, purchased, "Navigation must not spend upgrade gold or place the purchase: \(context)")
                XCTAssertEqual(store.draftFurniture, purchased.home.placements(on: target), context)
                let durable = await repository.saved
                XCTAssertEqual(durable, purchased, context)
                store.cancelDecorating()
            }
        }
    }

    @MainActor
    func testPurchaseKeepsCurrentFloorWhenBothFloorsHaveSpace() async throws {
        for currentFloor in HomeFloor.allCases {
            let store = makeStore(HomePurchaseFloorRepository(seed()))
            await store.load()
            store.enterHome()
            await store.changeHomeFloor(to: currentFloor)
            let itemID = try await purchase(store)
            let purchased = store.snapshot
            XCTAssertTrue(store.canPlaceMoreFurniture)
            XCTAssertEqual(store.availableFurnitureFloor, currentFloor)
            XCTAssertEqual(store.furniturePurchaseActionKey, "shop.design.decorate")
            await store.decoratePurchasedFurniture()
            XCTAssertEqual(store.visibleHomeFloor, currentFloor)
            XCTAssertEqual(store.selectedStoredFurnitureID, itemID)
            XCTAssertEqual(store.snapshot, purchased)
            store.cancelDecorating()
        }
    }

    @MainActor
    func testRestExitFailureKeepsPurchaseAndFloorUntilDurableRetry() async throws {
        let repository = HomePurchaseFloorRepository(seed(fullFloor: .ground))
        let store = makeStore(repository)
        await store.load()
        store.enterHome()
        let itemID = try await purchase(store)
        try await startRest(store)
        let original = try XCTUnwrap(store.snapshot)
        await repository.setWritesFailing(true)

        await store.decoratePurchasedFurniture()

        XCTAssertEqual(store.visibleHomeFloor, .ground)
        XCTAssertEqual(store.activeSheet, .shop)
        XCTAssertEqual(store.furniturePurchaseItemID, itemID)
        XCTAssertEqual(store.furniturePurchaseNotice, "sunrise_art")
        XCTAssertFalse(store.isChangingHomeFloor || store.isDecorating)
        XCTAssertNil(store.draftFurniture)
        XCTAssertNil(store.selectedStoredFurnitureID)
        XCTAssertEqual(store.snapshot, original)
        XCTAssertEqual(store.restingFurnitureID, "catBed")
        XCTAssertTrue(store.hasSaveFailure)
        let afterFailure = await repository.saved
        XCTAssertEqual(afterFailure, original)

        await repository.setWritesFailing(false)
        await store.decoratePurchasedFurniture()

        XCTAssertEqual(store.visibleHomeFloor, .upper)
        XCTAssertTrue(store.isDecorating)
        XCTAssertEqual(store.selectedStoredFurnitureID, itemID)
        XCTAssertNil(store.cat?.activeRest)
        XCTAssertNil(store.restingFurnitureID)
        XCTAssertNil(store.furniturePurchaseNotice)
        XCTAssertFalse(store.hasSaveFailure)
        XCTAssertEqual(store.snapshot?.home, original.home)
        XCTAssertEqual(store.snapshot?.player.gold, original.player.gold)
        let afterRetry = await repository.saved
        XCTAssertEqual(store.snapshot, afterRetry)
        store.cancelDecorating()
    }

    @MainActor
    func testBusyCareKeepsPurchaseOnOriginalFloorUntilSceneIsReady() async throws {
        let store = makeStore(HomePurchaseFloorRepository(seed(fullFloor: .ground)))
        await store.load()
        store.enterHome()
        let itemID = try await purchase(store)
        let purchased = store.snapshot
        store.roomFloorTravelReady = false
        await store.decoratePurchasedFurniture()
        XCTAssertEqual(store.visibleHomeFloor, .ground)
        XCTAssertEqual(store.activeSheet, .shop)
        XCTAssertEqual(store.furniturePurchaseItemID, itemID)
        XCTAssertEqual(store.snapshot, purchased)
        XCTAssertFalse(store.isDecorating)
        store.roomFloorTravelReady = true
        await store.decoratePurchasedFurniture()
        XCTAssertEqual(store.visibleHomeFloor, .upper)
        XCTAssertEqual(store.selectedStoredFurnitureID, itemID)
        store.cancelDecorating()
    }

    @MainActor
    func testLeavingShopWhileRestSaveIsPendingDoesNotOpenStaleEditor() async throws {
        for destination in ["work", "settings", "shopAgain"] {
            let opensSettings = destination == "settings"
            let repository = HomePurchaseFloorRepository(seed(fullFloor: .ground))
            let store = makeStore(repository)
            await store.load()
            store.enterHome()
            _ = try await purchase(store)
            try await startRest(store)
            let originalHome = store.snapshot?.home
            await repository.holdNextSave()
            defer { Task { await repository.releaseSave() } }
            let action = Task { await store.decoratePurchasedFurniture() }
            try await eventually { await repository.isSaveHeld }
            XCTAssertFalse(store.isDecorating)
            if opensSettings { store.isShowingSettings = true }
            else { store.activeSheet = .work }
            if destination == "shopAgain" { store.activeSheet = .shop }
            await repository.releaseSave()
            await action.value
            XCTAssertEqual(store.isShowingSettings, opensSettings)
            XCTAssertEqual(store.activeSheet, destination == "work" ? .work : .shop)
            XCTAssertFalse(store.isDecorating)
            XCTAssertNil(store.selectedStoredFurnitureID)
            XCTAssertNil(store.draftFurniture)
            XCTAssertNil(store.furniturePurchaseNotice)
            XCTAssertEqual(store.snapshot?.home, originalHome)
        }
    }

    @MainActor
    func testLegacyOverfilledFloorCannotOfferSlotsBeyondTotalHomeCapacity() async throws {
        var initial = seed()
        let room = try XCTUnwrap(HomeCatalog.level(initial.home.roomLevel))
        fill(&initial, floor: .ground, count: room.capacity + 1)
        XCTAssertNoThrow(try NativeSaveTransfer.encode(snapshot: initial))
        let store = makeStore(HomePurchaseFloorRepository(initial))
        await store.load()
        store.enterHome()
        _ = try await purchase(store)
        let purchased = store.snapshot
        XCTAssertTrue(store.snapshot?.home.placements(on: .upper).isEmpty == true)
        XCTAssertEqual(store.availableFurnitureSlots(on: .upper), 0)
        XCTAssertNil(store.availableFurnitureFloor)
        XCTAssertEqual(store.furniturePurchaseActionKey, "shop.design.upgrade")
        await store.decoratePurchasedFurniture()
        XCTAssertEqual(store.activeSheet, .upgrade)
        XCTAssertFalse(store.isDecorating)
        XCTAssertEqual(store.snapshot, purchased)
    }

    @MainActor
    private func makeStore(_ repository: HomePurchaseFloorRepository) -> GameStore {
        let suite = "CatLife-home-purchase-floor-\(UUID())"
        addTeardownBlock { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        return GameStore(repository: repository, reminderDefaults: UserDefaults(suiteName: suite)!)
    }

    private func seed(level: Int = 6, fullFloor: HomeFloor? = nil) -> GameSnapshot {
        var value = GameSnapshot.fresh()
        value.home = HomeState(roomLevel: level)
        value.player.gold = 30_000
        value.player.level = 20
        value.cats[0].energy = 40
        value.settings.language = .simplifiedChinese
        value.settings.audio.musicEnabled = false
        value.settings.audio.effectsEnabled = false
        value.settings.audio.catEnabled = false
        value.settings.audio.haptics = false
        if let fullFloor, let room = HomeCatalog.level(level) {
            for index in value.home.furniture.indices { value.home.furniture[index].floor = fullFloor }
            fill(&value, floor: fullFloor, count: room.capacity(on: fullFloor))
        }
        return value
    }

    private func fill(_ value: inout GameSnapshot, floor: HomeFloor, count: Int) {
        while value.home.placements(on: floor).count < count {
            let id = "floor-capacity-\(value.home.furniture.count)"
            value.inventory.furniture.append(.init(id: id, kind: .plant))
            value.home.furniture.append(.init(itemID: id, position: .init(x: 0.6, y: 0.7), floor: floor))
        }
    }

    @MainActor
    private func purchase(_ store: GameStore) async throws -> String {
        store.activeSheet = .shop
        store.buyFurniture(offerID: "sunrise_art")
        try await eventually { !store.isBusy }
        XCTAssertEqual(store.furniturePurchaseNotice, "sunrise_art")
        return try XCTUnwrap(store.furniturePurchaseItemID)
    }

    @MainActor
    private func startRest(_ store: GameStore) async throws {
        let catID = try XCTUnwrap(store.cat?.id)
        store.setRestingFurniture(id: "catBed", sessionID: "purchase-floor-rest", catID: catID)
        try await eventually { !store.isBusy }
        XCTAssertEqual(store.cat?.activeRest?.id, "purchase-floor-rest")
    }

    @MainActor
    private func eventually(_ condition: () async -> Bool) async throws {
        let deadline = Date().addingTimeInterval(3)
        while !(await condition()) {
            if Date() > deadline { throw HomePurchaseFloorFailure.timeout }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}

private enum HomePurchaseFloorFailure: Error { case storage, timeout }

private actor HomePurchaseFloorRepository: GameSaveRepository {
    let lastLoadDisposition = SaveLoadDisposition.loaded
    private(set) var saved: GameSnapshot
    private var writesFailing = false
    private var shouldHold = false
    private var heldSave: CheckedContinuation<Void, Never>?
    var isSaveHeld: Bool { heldSave != nil }
    init(_ value: GameSnapshot) { saved = value }
    func setWritesFailing(_ value: Bool) { writesFailing = value }
    func holdNextSave() { shouldHold = true }
    func releaseSave() { heldSave?.resume(); heldSave = nil }
    func checkWritable() throws { if writesFailing { throw HomePurchaseFloorFailure.storage } }
    func loadOrCreate(now: Date) -> GameSnapshot { saved }
    func save(_ value: GameSnapshot) async throws {
        if shouldHold {
            shouldHold = false
            await withCheckedContinuation { heldSave = $0 }
        }
        if writesFailing { throw HomePurchaseFloorFailure.storage }
        saved = value
    }
}
