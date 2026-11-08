import Foundation
import XCTest
import CatGameCore
@testable import CatLife

@MainActor
final class SharedHomeNoticeStoreTests: XCTestCase {
    func testCrowdedLayoutIsRememberedAcrossFloorTravelAndColdLaunch() async throws {
        let defaults = try isolatedDefaults()
        let repository = SharedHomeNoticeRepository(try seed())
        let store = GameStore(repository: repository, reminderDefaults: defaults)
        await store.load()
        store.enterHome()
        expectNewHint(store)
        expectNoHint(store)

        await store.changeHomeFloor(to: .upper)
        XCTAssertEqual(store.visibleHomeFloor, .upper)
        expectNewHint(store)
        await store.changeHomeFloor(to: .ground)
        expectNoHint(store)

        // Round-trip the real save codec; presentation history must survive its date precision loss.
        let loaded = try XCTUnwrap(store.snapshot)
        await repository.replace(try NativeSaveTransfer.decode(NativeSaveTransfer.encode(snapshot: loaded)).snapshot)
        let relaunched = GameStore(repository: repository, reminderDefaults: defaults)
        await relaunched.load()
        relaunched.enterHome()
        expectNoHint(relaunched)
        await relaunched.changeHomeFloor(to: .upper)
        expectNoHint(relaunched)
    }

    func testOnlySavedLayoutAndRosterChangesMakeHintEligibleAgain() async throws {
        let defaults = try isolatedDefaults()
        let repository = SharedHomeNoticeRepository(try seed())
        let store = GameStore(repository: repository, reminderDefaults: defaults)
        await store.load()
        store.enterHome()
        expectNewHint(store)

        store.beginDecorating()
        store.moveBowl(to: .init(x: 0.7, y: 0.8))
        let historyBeforeDraft = defaults.data(forKey: GameStore.sharedHomeSpaceNoticesKey)
        expectNoHint(store)
        XCTAssertEqual(defaults.data(forKey: GameStore.sharedHomeSpaceNoticesKey), historyBeforeDraft)
        store.cancelDecorating()
        expectNoHint(store)

        var changed = try XCTUnwrap(store.snapshot)
        changed.activeCatID = CatCatalog.cowCatID
        changed.player.gold += 10
        changed.cats.reverse()
        changed.home.furniture.reverse()
        changed.inventory.furniture.reverse()
        changed.inventory.furniture.append(.init(id: "stored-plant", kind: .plant))
        await repository.replace(changed)
        await store.load()
        expectNoHint(store)

        changed.home.bowlPosition = .init(x: 0.72, y: 0.8)
        await repository.replace(changed)
        await store.load()
        expectNewHint(store)

        let adoptionTime = changed.meta.lastSyncAt
        XCTAssertTrue(GameEngine.adoptCat(&changed, catID: CatCatalog.blueCatID, now: adoptionTime).succeeded)
        await repository.replace(changed)
        await store.load()
        expectNewHint(store)
        expectNoHint(store)

        let bed = try XCTUnwrap(changed.inventory.furniture.firstIndex { $0.kind == .catBed })
        changed.inventory.furniture[bed].orientation = .mirrored
        await repository.replace(changed)
        await store.load()
        expectNewHint(store)
    }

    func testImportResetsHintHistoryOnlyAfterSuccessfulReplacement() async throws {
        let defaults = try isolatedDefaults()
        let repository = SharedHomeNoticeRepository(try seed())
        let store = GameStore(repository: repository, reminderDefaults: defaults)
        await store.load()
        store.enterHome()
        expectNewHint(store)
        let history = defaults.data(forKey: GameStore.sharedHomeSpaceNoticesKey)
        let archive = try NativeSaveTransfer.decode(NativeSaveTransfer.encode(snapshot: XCTUnwrap(store.snapshot)))

        await repository.setImportFailure(true)
        do {
            try await store.importSaveArchive(archive)
            XCTFail("The injected import failure must propagate.")
        } catch { XCTAssertEqual(error as? SaveTransferError, .writeFailed) }
        let failedAttempts = await repository.importAttempts
        XCTAssertEqual(failedAttempts, 1, "The failure must come from the injected repository write, not a missing transfer capability.")
        XCTAssertEqual(defaults.data(forKey: GameStore.sharedHomeSpaceNoticesKey), history)
        expectNoHint(store)

        await repository.setImportFailure(false)
        try await store.importSaveArchive(archive)
        let successfulAttempts = await repository.importAttempts
        XCTAssertEqual(successfulAttempts, 2)
        XCTAssertNil(defaults.data(forKey: GameStore.sharedHomeSpaceNoticesKey))
        expectNewHint(store)

        // A different saved game using the same local preferences starts its own notice history.
        await repository.replace(try seed(createdAt: Date().addingTimeInterval(-60)))
        await store.load()
        expectNewHint(store)
    }

    private func expectNewHint(_ store: GameStore, file: StaticString = #filePath, line: UInt = #line) {
        store.showFurnitureNotice("layout.saved")
        let before = store.toast
        store.showSharedHomeSpaceNotice()
        XCTAssertNotEqual(store.toast, before, file: file, line: line)
        XCTAssertEqual(store.toast?.components(separatedBy: "\n").last,
                       GameStrings.text("room.sharedHomeNoSpace"), file: file, line: line)
    }

    private func expectNoHint(_ store: GameStore, file: StaticString = #filePath, line: UInt = #line) {
        store.showFurnitureNotice("layout.saved")
        let before = store.toast
        store.showSharedHomeSpaceNotice()
        XCTAssertEqual(store.toast, before, file: file, line: line)
    }

    private func seed(createdAt: Date? = nil) throws -> GameSnapshot {
        let now = createdAt ?? Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970) - 1 + 0.123654)
        var value = GameSnapshot.fresh(now: now)
        value.settings.audio = AudioSettings(musicEnabled: false, effectsEnabled: false, catEnabled: false, haptics: false)
        value.player.level = 20
        value.player.gold = 30_000
        value.home = HomeState(roomLevel: 6)
        XCTAssertTrue(GameEngine.adoptCat(&value, catID: CatCatalog.cowCatID, now: now).succeeded)
        _ = try NativeSaveTransfer.encode(snapshot: value)
        return value
    }

    private func isolatedDefaults() throws -> UserDefaults {
        let name = "CatLife-SharedHomeNotices-Tests-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        addTeardownBlock { UserDefaults(suiteName: name)?.removePersistentDomain(forName: name) }
        return defaults
    }
}

private actor SharedHomeNoticeRepository: GameSaveTransferRepository {
    let lastLoadDisposition = SaveLoadDisposition.loaded
    private var saved: GameSnapshot
    private var importFails = false
    private var recovery: GameSnapshot?
    private(set) var importAttempts = 0
    init(_ saved: GameSnapshot) { self.saved = saved }
    func replace(_ value: GameSnapshot) { saved = value }
    func setImportFailure(_ fails: Bool) { importFails = fails }
    func loadOrCreate(now: Date) -> GameSnapshot { saved }
    func checkWritable() {}
    func save(_ value: GameSnapshot) { saved = value }
    func importSnapshot(_ value: GameSnapshot) throws {
        importAttempts += 1
        if importFails { throw CocoaError(.fileWriteUnknown) }
        recovery = saved
        saved = value
    }
    func loadImportRecovery() -> GameSnapshot? { recovery }
    func restoreSnapshotAfterLoadFailure(_ value: GameSnapshot) throws { try importSnapshot(value) }
}
