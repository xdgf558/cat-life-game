import XCTest
import CatGameCore
@testable import CatLife

final class PremiumSupplyStoreTests: XCTestCase {
    @MainActor
    func testPremiumCareFailureKeepsBothStocksAndRetryUsesOnlyChosenSupply() async throws {
        var initial = GameSnapshot.fresh(now: Date())
        initial.inventory.premiumFood = 2
        initial.inventory.premiumLitter = 2
        initial.cats[0].satiety = 10
        initial.cats[0].cleanliness = 10
        initial.settings.audio = AudioSettings(musicEnabled: false, effectsEnabled: false)
        let repository = PremiumSupplyRepository(initial)
        let suite = "CatLife-premium-\(UUID())"
        addTeardownBlock { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let store = GameStore(repository: repository, reminderDefaults: UserDefaults(suiteName: suite)!)
        await store.load()
        store.enterHome()
        let original = try XCTUnwrap(store.snapshot)
        await repository.failWrites(true)
        store.feed(supply: .premiumFood)
        try await idle(store)
        XCTAssertEqual(store.snapshot, original)
        XCTAssertTrue(store.showSaveError)
        await repository.failWrites(false)
        store.feed(supply: .premiumFood)
        try await idle(store)
        XCTAssertEqual(store.snapshot?.inventory.premiumFood, 1)
        XCTAssertEqual(store.snapshot?.inventory.food, original.inventory.food)
        XCTAssertEqual(store.snapshot?.activeCat?.satiety, 65)
        XCTAssertEqual(store.snapshot?.activeCat?.intimacy, original.activeCat!.intimacy + 3)
        store.clean(supply: .premiumLitter)
        try await idle(store)
        XCTAssertEqual(store.snapshot?.inventory.premiumLitter, 1)
        XCTAssertEqual(store.snapshot?.inventory.litter, original.inventory.litter)
        XCTAssertEqual(store.snapshot?.activeCat?.cleanliness, 75)
        let saved = await repository.saved
        XCTAssertEqual(saved.inventory, store.snapshot?.inventory)
    }

    @MainActor
    func testNewSupplyStringsAndReleaseMatchAllLanguages() {
        let previous = GameLocalization.shared.language
        defer { GameLocalization.shared.language = previous }
        for language in GameLanguage.allCases {
            GameLocalization.shared.language = language
            for kind in SupplyKind.allCases {
                let supply = SupplyCatalog.definition(for: kind)
                XCTAssertNotEqual(GameStrings.text(supply.nameKey), supply.nameKey)
                XCTAssertNotEqual(GameStrings.text(supply.detailKey), supply.detailKey)
            }
            XCTAssertNotEqual(GameStrings.text("releases.59.body"), "releases.59.body")
        }
        for dictionary in [GameStrings.chinese, GameStrings.traditionalChinese, GameStrings.english] {
            for key in ["catDirectory.sharedHomeLocked", "catDirectory.sharedHomeUnlocked",
                        "room.inspectResident", "releases.59.title", "releases.59.body"] {
                XCTAssertNotNil(dictionary[key], "Each language must register \(key) without relying on a fallback.")
            }
        }
        XCTAssertEqual(AppVersion.current.version, "0.19.1")
        XCTAssertEqual(AppVersion.current.build, "61")
        XCTAssertEqual(AppRelease.recent.map(\.build), [61, 60, 59])
    }

    @MainActor
    func testPremiumOnlyHomeActionsOpenPickerWithoutConsuming() async throws {
        var initial = GameSnapshot.fresh(now: Date())
        initial.inventory.food = 0
        initial.inventory.litter = 0
        initial.inventory.premiumFood = 1
        initial.inventory.premiumLitter = 1
        let suite = "CatLife-premium-routing-\(UUID())"
        addTeardownBlock { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let store = GameStore(repository: PremiumSupplyRepository(initial), reminderDefaults: UserDefaults(suiteName: suite)!)
        await store.load()
        store.enterHome()
        XCTAssertTrue(store.hasFood)
        store.feed()
        XCTAssertNil(store.activeSheet)
        XCTAssertEqual(store.supplyPicker, .food)
        XCTAssertEqual(store.snapshot?.inventory.premiumFood, 1)
        store.activeSheet = nil
        store.clean()
        XCTAssertNil(store.activeSheet)
        XCTAssertEqual(store.supplyPicker, .litter)
        XCTAssertEqual(store.snapshot?.inventory.premiumLitter, 1)
    }

    @MainActor
    private func idle(_ store: GameStore) async throws {
        let deadline = Date().addingTimeInterval(4)
        while store.isBusy && Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(store.isBusy)
    }
}

private actor PremiumSupplyRepository: GameSaveRepository {
    let lastLoadDisposition = SaveLoadDisposition.loaded
    private(set) var saved: GameSnapshot
    private var fails = false
    init(_ state: GameSnapshot) { saved = state }
    func failWrites(_ value: Bool) { fails = value }
    func loadOrCreate(now: Date) -> GameSnapshot { saved }
    func checkWritable() throws { if fails { throw CocoaError(.fileWriteOutOfSpace) } }
    func save(_ state: GameSnapshot) throws {
        if fails { throw CocoaError(.fileWriteOutOfSpace) }
        saved = state
    }
}
