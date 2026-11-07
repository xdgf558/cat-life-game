import Foundation
import XCTest
import CatGameCore
@testable import CatLife

final class GameStoreExchangeTests: XCTestCase {
    @MainActor
    private func makeStore(_ repository: ExchangeTestRepository) -> GameStore {
        let suite = "CatLife-exchange-test-\(UUID())"
        addTeardownBlock { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        return GameStore(repository: repository, reminderDefaults: UserDefaults(suiteName: suite)!)
    }

    private func seed() -> GameSnapshot {
        var state = GameSnapshot.fresh()
        state.inventory.food = 8
        state.settings.language = .simplifiedChinese
        state.settings.audio.musicEnabled = false
        state.settings.audio.effectsEnabled = false
        state.settings.audio.catEnabled = false
        state.settings.audio.haptics = false
        return state
    }

    @MainActor
    func testFailedExchangeKeepsSuppliesAndDailyCountUntilSuccessfulRetry() async throws {
        let repository = ExchangeTestRepository(seed())
        let store = makeStore(repository)
        await store.load()
        store.enterHome()
        let original = try XCTUnwrap(store.snapshot)
        await repository.setWritesFailing(true)
        let failed = await store.exchange(offerID: "mira_food")
        XCTAssertFalse(failed)
        XCTAssertEqual(store.snapshot, original)
        let unchanged = await repository.savedState()
        XCTAssertEqual(unchanged, original)
        XCTAssertTrue(store.hasSaveFailure && store.showSaveError)
        XCTAssertFalse(store.toast?.contains(GameStrings.text("market.exchanged")) == true)

        await repository.setWritesFailing(false)
        let retried = await store.exchange(offerID: "mira_food")
        XCTAssertTrue(retried)
        XCTAssertEqual(store.snapshot?.inventory.food, original.inventory.food - 2)
        XCTAssertEqual(store.snapshot?.inventory.premiumFood, original.inventory.premiumFood + 1)
        XCTAssertEqual(store.snapshot?.community.exchangeCount(for: "neighbor_mira").today, 1)
        XCTAssertEqual(store.snapshot?.community.totalExchangeCount, 1)
        let committed = await repository.savedState()
        XCTAssertEqual(committed, store.snapshot)
        XCTAssertFalse(store.hasSaveFailure)
        XCTAssertTrue(store.toast?.contains(GameStrings.text("market.exchanged")) == true)
    }

    @MainActor
    func testPendingExchangeRejectsDoubleTapAndReportsSuccessAfterLeavingMarket() async throws {
        let repository = ExchangeTestRepository(seed())
        let store = makeStore(repository)
        await store.load()
        store.enterHome()
        store.openExchangeMarket()
        XCTAssertTrue(store.isShowingMarket)
        let original = try XCTUnwrap(store.snapshot)
        await repository.holdNextSave()
        defer { Task { await repository.releaseSave() } }
        let first = Task { await store.exchange(offerID: "mira_food") }
        try await eventually { await repository.isSaveHeld }
        XCTAssertTrue(store.isBusy)
        XCTAssertEqual(store.snapshot, original)
        let duplicate = await store.exchange(offerID: "mira_food")
        XCTAssertFalse(duplicate)
        store.activeSheet = .work
        XCTAssertFalse(store.isShowingMarket)
        await repository.releaseSave()
        let succeeded = await first.value
        XCTAssertTrue(succeeded)
        XCTAssertEqual(store.snapshot?.inventory.food, original.inventory.food - 2)
        XCTAssertEqual(store.snapshot?.community.totalExchangeCount, 1)
        XCTAssertTrue(store.toast?.contains(GameStrings.text("market.exchanged")) == true)
    }

    @MainActor
    func testTaskDestinationOpensMarketAndLockedPreviewUsesTranslatedStage() async throws {
        let store = makeStore(ExchangeTestRepository(seed()))
        await store.load()
        store.enterHome()
        store.goToTaskDestination(.market)
        XCTAssertEqual(store.activeSheet, .town)
        XCTAssertTrue(store.isShowingMarket)
        XCTAssertFalse(store.isShowingNeighbors)
        let offer = try XCTUnwrap(ExchangeCatalog.offer(id: "mira_feast"))
        let snapshot = try XCTUnwrap(store.snapshot)
        let previousLanguage = GameLocalization.shared.language
        defer { GameLocalization.shared.language = previousLanguage }
        for language in [GameLanguage.simplifiedChinese, .traditionalChinese, .english] {
            GameLocalization.shared.language = language
            let status = ExchangePresentation.status(offer, snapshot: snapshot)
            XCTAssertFalse(status.contains("market."))
            XCTAssertTrue(status.contains(GameStrings.text("community.stage.3")))
            XCTAssertFalse(GameActionNotice.message(for: .init(success: .exchanged), snapshot: snapshot).contains("market."))
        }
    }

    @MainActor
    private func eventually(_ condition: () async -> Bool) async throws {
        let deadline = Date().addingTimeInterval(3)
        while !(await condition()) {
            if Date() > deadline { throw ExchangeTestFailure.timeout }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}

private enum ExchangeTestFailure: Error { case storage, timeout }

private actor ExchangeTestRepository: GameSaveRepository {
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
    func checkWritable() throws { if writesFailing { throw ExchangeTestFailure.storage } }
    func loadOrCreate(now: Date) -> GameSnapshot { saved }
    func save(_ state: GameSnapshot) async throws {
        if shouldHold {
            shouldHold = false
            await withCheckedContinuation { heldSave = $0 }
        }
        if writesFailing { throw ExchangeTestFailure.storage }
        saved = state
    }
}
