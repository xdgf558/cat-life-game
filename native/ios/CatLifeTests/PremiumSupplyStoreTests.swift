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
                        "room.inspectResident", "releases.59.title", "releases.59.body",
                        "roomView.current", "roomView.angle.left", "roomView.angle.front", "roomView.angle.right",
                        "roomView.whole", "roomView.close", "roomView.turnLeft", "roomView.turnRight",
                        "roomView.showWhole", "roomView.showClose", "releases.62.title", "releases.62.body",
                        "releases.64.title", "releases.64.body"] {
                XCTAssertNotNil(dictionary[key], "Each language must register \(key) without relying on a fallback.")
            }
        }
        XCTAssertEqual(AppVersion.current.version, "0.20.1")
        XCTAssertEqual(AppVersion.current.build, "64")
        XCTAssertEqual(AppRelease.recent.map(\.build), [64, 62, 61])
    }

    @MainActor
    func testHomeHUDStringsAreRegisteredAndFormatInEveryLanguage() {
        let previous = GameLocalization.shared.language
        defer { GameLocalization.shared.language = previous }
        let keys: Set<String> = ["home63.switchSummary", "home63.switchShort", "home63.profileAction", "home63.closeCat",
                                 "home63.needFor", "home63.need.food", "home63.need.clean", "home63.need.play",
                                 "home63.need.hospital", "home63.level"]
        for dictionary in [GameStrings.chinese, GameStrings.traditionalChinese, GameStrings.english] {
            XCTAssertEqual(Set(dictionary.keys.filter { $0.hasPrefix("home63.") }), keys)
            for key in keys {
                XCTAssertFalse(dictionary[key, default: ""].isEmpty, "Each language must register \(key).")
            }
        }
        for (language, summary, closeCat, needFor) in [
            (GameLanguage.simplifiedChinese, "2只猫 · 点猫或这里切换", "近看Mochi", "Mochi想要"),
            (.traditionalChinese, "2隻貓 · 點貓或這裡切換", "近看Mochi", "Mochi想要"),
            (.english, "2 cats · Tap a cat or here to switch", "Close up: Mochi", "Mochi wants")
        ] {
            GameLocalization.shared.language = language
            XCTAssertEqual(GameStrings.format("home63.switchSummary", 2), summary)
            XCTAssertEqual(GameStrings.format("home63.closeCat", "Mochi"), closeCat)
            XCTAssertEqual(GameStrings.format("home63.needFor", "Mochi"), needFor)
            XCTAssertEqual(GameStrings.format("home63.level", 6), "Lv6")
        }
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
