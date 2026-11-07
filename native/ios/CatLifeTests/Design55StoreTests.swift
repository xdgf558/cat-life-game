import Foundation
import XCTest
import CatGameCore
@testable import CatLife

final class Design55StoreTests: XCTestCase {
    @MainActor
    private func makeStore(_ repository: Design55Repository) -> GameStore {
        let suite = "CatLife-design55-test-\(UUID())"
        addTeardownBlock { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        return GameStore(repository: repository, reminderDefaults: UserDefaults(suiteName: suite)!)
    }

    private func seed() -> GameSnapshot {
        var state = GameSnapshot.fresh()
        state.player.level = 8
        state.player.gold = 5_000
        state.inventory.premiumFood = 2
        state.inventory.premiumLitter = 2
        state.settings.language = .simplifiedChinese
        state.settings.audio.musicEnabled = false
        state.settings.audio.effectsEnabled = false
        state.settings.audio.catEnabled = false
        state.settings.audio.haptics = false
        return state
    }

    @MainActor
    func testFurnitureBannerWaitsForDurableRetryAndDecoratingDoesNotPlacePurchase() async throws {
        let repository = Design55Repository(seed())
        let store = makeStore(repository)
        await store.load()
        store.enterHome()
        store.activeSheet = .shop
        let original = try XCTUnwrap(store.snapshot)
        await repository.setWritesFailing(true)
        await repository.holdNextSave()
        defer { Task { await repository.releaseSave() } }
        store.buyFurniture(offerID: "oak_bookcase")
        try await eventually { await repository.isSaveHeld }
        XCTAssertNil(store.furniturePurchaseNotice)
        XCTAssertEqual(store.snapshot, original)
        await repository.releaseSave()
        try await eventually { !store.isBusy }
        XCTAssertNil(store.furniturePurchaseNotice)
        XCTAssertTrue(store.hasSaveFailure)
        XCTAssertEqual(store.snapshot, original)

        await repository.setWritesFailing(false)
        await repository.holdNextSave()
        store.buyFurniture(offerID: "oak_bookcase")
        try await eventually { await repository.isSaveHeld }
        XCTAssertNil(store.furniturePurchaseNotice)
        await repository.releaseSave()
        try await eventually { !store.isBusy }
        XCTAssertEqual(store.furniturePurchaseNotice, "oak_bookcase")
        let purchased = try XCTUnwrap(store.snapshot)
        let durable = await repository.savedState()
        XCTAssertEqual(purchased, durable)
        XCTAssertEqual(ShopCatalog.ownedFurnitureCount(offerID: "oak_bookcase", in: purchased.inventory.furniture), 1)
        XCTAssertEqual(purchased.home, original.home)

        store.decoratePurchasedFurniture()
        XCTAssertNil(store.activeSheet)
        XCTAssertNil(store.furniturePurchaseNotice)
        XCTAssertTrue(store.isDecorating && store.isFurnitureTrayExpanded)
        XCTAssertNil(store.placingFurnitureID)
        XCTAssertNil(store.selectedFurnitureID)
        XCTAssertEqual(store.draftFurniture, purchased.home.furniture)
        XCTAssertEqual(store.snapshot, purchased, "The purchase CTA opens the tray without placing or resaving furniture.")
    }

    @MainActor
    func testFurnitureSuccessAfterLeavingShopUsesToastAndNavigationClearsLaterBanner() async throws {
        let repository = Design55Repository(seed())
        let store = makeStore(repository)
        await store.load()
        store.enterHome()
        store.activeSheet = .shop
        await repository.holdNextSave()
        defer { Task { await repository.releaseSave() } }
        store.buyFurniture(offerID: "round_side_table")
        try await eventually { await repository.isSaveHeld }
        store.activeSheet = .work
        await repository.releaseSave()
        try await eventually { !store.isBusy }
        XCTAssertNil(store.furniturePurchaseNotice)
        XCTAssertTrue(store.toast?.contains(GameStrings.text("shop.furniturePurchased")) == true)
        let purchased = try XCTUnwrap(store.snapshot)
        XCTAssertEqual(ShopCatalog.ownedFurnitureCount(offerID: "round_side_table", in: purchased.inventory.furniture), 1)

        store.activeSheet = .shop
        store.buyFurniture(offerID: "sunrise_art")
        try await eventually { !store.isBusy }
        XCTAssertEqual(store.furniturePurchaseNotice, "sunrise_art")
        store.activeSheet = .inventory
        XCTAssertNil(store.furniturePurchaseNotice)
        store.decoratePurchasedFurniture()
        XCTAssertFalse(store.isDecorating, "A dismissed purchase must not retain a stale placement shortcut.")
    }

    @MainActor
    func testSupplyPickerRetainsSelectionOnFailureAndOnlyReportsCommittedActualEffects() async throws {
        var initial = seed()
        initial.cats[0].satiety = 98
        initial.cats[0].mood = 100
        initial.cats[0].intimacy = 100
        let repository = Design55Repository(initial)
        let store = makeStore(repository)
        await store.load()
        store.enterHome()
        store.openInventory()
        store.openSupplyPicker(for: .premiumFood)
        XCTAssertEqual(store.supplyPicker, .food)
        let original = try XCTUnwrap(store.snapshot)
        await repository.setWritesFailing(true)
        let failed = await store.useSupplyFromPicker(.premiumFood)
        XCTAssertFalse(failed)
        XCTAssertEqual(store.supplyPicker, .food)
        XCTAssertEqual(store.snapshot, original)
        XCTAssertTrue(store.hasSaveFailure)

        await repository.setWritesFailing(false)
        await repository.holdNextSave()
        defer { Task { await repository.releaseSave() } }
        let retried = Task { await store.useSupplyFromPicker(.premiumFood) }
        try await eventually { await repository.isSaveHeld }
        XCTAssertEqual(store.snapshot, original)
        XCTAssertEqual(store.supplyPicker, .food)
        await repository.releaseSave()
        let succeeded = await retried.value
        XCTAssertTrue(succeeded)
        XCTAssertNil(store.supplyPicker)
        XCTAssertNil(store.activeSheet)
        let committed = try XCTUnwrap(store.snapshot)
        XCTAssertEqual(committed.inventory.premiumFood, original.inventory.premiumFood - 1)
        XCTAssertEqual(committed.inventory.food, original.inventory.food)
        XCTAssertEqual(committed.inventory.premiumLitter, original.inventory.premiumLitter)
        XCTAssertEqual(committed.cats[0].satiety, 100)
        XCTAssertTrue(store.toast?.contains(GameStrings.text("stat.satiety") + " +2") == true)
        XCTAssertFalse(store.toast?.contains("+55") == true)
        let durable = await repository.savedState()
        XCTAssertEqual(committed, durable)
    }

    @MainActor
    func testPickerCancelAndWrongFamilyNeverSpendStockAndPregnancyUsesTwoSelectedFood() async throws {
        var initial = seed()
        initial.cats[0].isPregnant = true
        let repository = Design55Repository(initial)
        let store = makeStore(repository)
        await store.load()
        store.enterHome()
        let original = try XCTUnwrap(store.snapshot)
        store.openSupplyPicker(for: .premiumFood)
        let wrongFamily = await store.useSupplyFromPicker(.premiumLitter)
        let toy = await store.useSupplyFromPicker(.toy)
        XCTAssertFalse(wrongFamily)
        XCTAssertFalse(toy)
        XCTAssertEqual(store.snapshot, original)
        XCTAssertEqual(store.supplyPicker, .food)
        store.supplyPicker = nil
        let cancelled = await store.useSupplyFromPicker(.premiumFood)
        XCTAssertFalse(cancelled)
        XCTAssertEqual(store.snapshot, original)

        store.openSupplyPicker(for: .food)
        let succeeded = await store.useSupplyFromPicker(.premiumFood)
        XCTAssertTrue(succeeded)
        XCTAssertEqual(store.snapshot?.inventory.premiumFood, original.inventory.premiumFood - 2)
        XCTAssertEqual(store.snapshot?.inventory.food, original.inventory.food)
        XCTAssertEqual(store.snapshot?.inventory.litter, original.inventory.litter)
        XCTAssertEqual(store.snapshot?.tasks.totalFeedCount, original.tasks.totalFeedCount + 1)
        XCTAssertNil(store.supplyPicker)
    }

    @MainActor
    func testImportClearsPurchaseAndSupplyPresentationFromPreviousSave() async throws {
        let repository = Design55Repository(seed())
        let store = makeStore(repository)
        await store.load()
        store.enterHome()
        store.activeSheet = .shop
        store.buyFurniture(offerID: "sunrise_art")
        try await eventually { !store.isBusy }
        XCTAssertNotNil(store.furniturePurchaseNotice)
        store.openSupplyPicker(for: .premiumLitter)
        XCTAssertEqual(store.supplyPicker, .litter)
        let generation = store.saveSceneGeneration
        let archive = try NativeSaveTransfer.decode(NativeSaveTransfer.encode(snapshot: seed()))
        try await store.importSaveArchive(archive)
        XCTAssertNotEqual(store.saveSceneGeneration, generation)
        XCTAssertNil(store.furniturePurchaseNotice)
        XCTAssertNil(store.supplyPicker)
        store.decoratePurchasedFurniture()
        XCTAssertFalse(store.isDecorating)
        let beforeUse = store.snapshot
        let staleUse = await store.useSupplyFromPicker(.premiumLitter)
        XCTAssertFalse(staleUse)
        XCTAssertEqual(store.snapshot, beforeUse)
    }

    @MainActor
    private func eventually(_ condition: () async -> Bool) async throws {
        let deadline = Date().addingTimeInterval(3)
        while !(await condition()) {
            if Date() > deadline { throw Design55TestFailure.timeout }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}

private enum Design55TestFailure: Error { case storage, timeout }

private actor Design55Repository: GameSaveTransferRepository {
    let lastLoadDisposition = SaveLoadDisposition.loaded
    private var saved: GameSnapshot
    private var writesFailing = false
    private var shouldHold = false
    private var heldSave: CheckedContinuation<Void, Never>?
    var isSaveHeld: Bool { heldSave != nil }
    init(_ state: GameSnapshot) { saved = state }
    func savedState() -> GameSnapshot { saved }
    func setWritesFailing(_ value: Bool) { writesFailing = value }
    func holdNextSave() { shouldHold = true }
    func releaseSave() { heldSave?.resume(); heldSave = nil }
    func checkWritable() throws { if writesFailing { throw Design55TestFailure.storage } }
    func loadOrCreate(now: Date) -> GameSnapshot { saved }
    func importSnapshot(_ state: GameSnapshot) { saved = state }
    func restoreSnapshotAfterLoadFailure(_ state: GameSnapshot) { saved = state }
    func loadImportRecovery() -> GameSnapshot? { nil }
    func save(_ state: GameSnapshot) async throws {
        if shouldHold {
            shouldHold = false
            await withCheckedContinuation { heldSave = $0 }
        }
        if writesFailing { throw Design55TestFailure.storage }
        saved = state
    }
}
