import Foundation
import XCTest
import CatGameCore
@testable import CatLife

final class GameStoreOnboardingTests: XCTestCase {
    @MainActor
    private func makeStore(_ repository: OnboardingTestRepository) -> GameStore {
        let suite = "CatLife-onboarding-store-\(UUID())"
        addTeardownBlock { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        return GameStore(repository: repository, reminderDefaults: UserDefaults(suiteName: suite)!)
    }

    private func seed() -> GameSnapshot {
        var state = GameSnapshot.fresh()
        state.settings.language = .simplifiedChinese
        state.settings.audio = AudioSettings(musicEnabled: false, effectsEnabled: false)
        state.settings.audio.catEnabled = false
        state.settings.audio.haptics = false
        return state
    }

    @MainActor
    func testNewSavePreparesGuideButOnlyExplicitHomeEntryPresentsIt() async throws {
        let store = makeStore(OnboardingTestRepository(seed(), disposition: .created))
        await store.load()
        XCTAssertFalse(store.loadFailed)
        XCTAssertFalse(store.hasEnteredHome)
        XCTAssertEqual(store.onboarding.step, .care)
        XCTAssertFalse(store.onboarding.isPresented)
        let original = try XCTUnwrap(store.snapshot)

        store.enterHome()
        XCTAssertTrue(store.onboarding.isPresented)
        store.onboarding.finish()
        store.enterHome()
        XCTAssertFalse(store.onboarding.isActive)
        XCTAssertFalse(store.onboarding.isPresented)
        XCTAssertEqual(store.snapshot, original, "Starting or skipping a guide must not award or spend anything.")
    }

    @MainActor
    func testExistingAndRecoveredSavesDoNotAutomaticallyPresentGuideEvenWithoutProgress() async throws {
        for disposition in [SaveLoadDisposition.loaded, .recoveredBackup] {
            let store = makeStore(OnboardingTestRepository(seed(), disposition: disposition))
            await store.load()
            store.enterHome()
            XCTAssertFalse(store.onboarding.isActive)
            XCTAssertFalse(store.onboarding.isPresented)
            let original = try XCTUnwrap(store.snapshot)
            store.replayOnboarding()
            XCTAssertEqual(store.onboarding.step, .care)
            XCTAssertTrue(store.onboarding.isPresented)
            XCTAssertEqual(store.snapshot, original)
        }
    }

    @MainActor
    func testGuideDestinationsAreNavigationOnlyAndPreserveTheCurrentStep() async throws {
        let repository = OnboardingTestRepository(seed(), disposition: .created)
        let store = makeStore(repository)
        await store.load()
        store.enterHome()
        let original = try XCTUnwrap(store.snapshot)
        let writesBefore = await repository.saveCount
        let destinations: [(GameOnboardingStep, HomeSheet?)] = [
            (.care, nil), (.work, .work), (.supplies, .shop), (.tasks, .tasks), (.town, .town)
        ]
        for (step, destination) in destinations {
            XCTAssertEqual(store.onboarding.step, step)
            store.exploreOnboarding(step)
            XCTAssertFalse(store.onboarding.isPresented)
            XCTAssertTrue(store.onboarding.isActive)
            XCTAssertEqual(store.onboarding.step, step)
            XCTAssertEqual(store.activeSheet, destination)
            XCTAssertFalse(store.isShowingSettings)
            XCTAssertNil(store.inspectedCatID)
            if step == .supplies { XCTAssertEqual(store.shopCategory, .supplies) }
            if step == .town {
                XCTAssertFalse(store.isShowingNeighbors)
                XCTAssertNil(store.catCollectionFilter)
            }
            XCTAssertEqual(store.snapshot, original)
            store.onboarding.show()
            store.onboarding.next()
        }
        XCTAssertFalse(store.onboarding.isActive)
        XCTAssertFalse(store.onboarding.isPresented)
        let writesAfter = await repository.saveCount
        XCTAssertEqual(writesAfter, writesBefore, "A tour must not create gameplay transactions.")
    }

    @MainActor
    func testSuccessfulImportDismissesGuideButFailedReplacementKeepsItsProgress() async throws {
        let repository = OnboardingTestRepository(seed(), disposition: .created)
        let store = makeStore(repository)
        await store.load()
        store.enterHome()
        store.onboarding.next()
        XCTAssertEqual(store.onboarding.step, .work)
        let original = try XCTUnwrap(store.snapshot)
        var incoming = seed()
        incoming.player.gold = 777
        incoming.meta.createdAt = incoming.meta.createdAt.addingTimeInterval(-60)
        let archive = try NativeSaveTransfer.decode(NativeSaveTransfer.encode(snapshot: incoming))
        await repository.setImportsFailing(true)
        do {
            try await store.importSaveArchive(archive)
            XCTFail("The injected import failure should propagate.")
        } catch {}
        XCTAssertEqual(store.snapshot, original)
        XCTAssertTrue(store.onboarding.isActive)
        XCTAssertEqual(store.onboarding.step, .work)

        await repository.setImportsFailing(false)
        try await store.importSaveArchive(archive)
        XCTAssertEqual(store.snapshot?.player.gold, 777)
        XCTAssertFalse(store.onboarding.isActive)
        XCTAssertFalse(store.onboarding.isPresented)
    }

    @MainActor
    func testFailedLoadCannotPresentOrRestartOnboarding() async {
        let repository = OnboardingTestRepository(seed(), disposition: .created, loadFails: true)
        let store = makeStore(repository)
        await store.load()
        XCTAssertTrue(store.loadFailed)
        XCTAssertNil(store.snapshot)
        store.enterHome()
        store.replayOnboarding()
        XCTAssertFalse(store.hasEnteredHome)
        XCTAssertFalse(store.onboarding.isActive)
        XCTAssertFalse(store.onboarding.isPresented)
    }
}

private actor OnboardingTestRepository: GameSaveTransferRepository {
    let lastLoadDisposition: SaveLoadDisposition
    private var saved: GameSnapshot
    private let loadFails: Bool
    private var importFails = false
    private var recovery: GameSnapshot?
    private(set) var saveCount = 0

    init(_ state: GameSnapshot, disposition: SaveLoadDisposition, loadFails: Bool = false) {
        saved = state
        lastLoadDisposition = disposition
        self.loadFails = loadFails
    }
    func loadOrCreate(now: Date) throws -> GameSnapshot {
        if loadFails { throw SaveRepositoryError.unreadableSave }
        return saved
    }
    func save(_ state: GameSnapshot) {
        saved = state
        saveCount += 1
    }
    func checkWritable() {}
    func setImportsFailing(_ fails: Bool) { importFails = fails }
    func importSnapshot(_ state: GameSnapshot) throws {
        if importFails { throw CocoaError(.fileWriteUnknown) }
        recovery = saved
        saved = state
    }
    func restoreSnapshotAfterLoadFailure(_ state: GameSnapshot) throws {
        try importSnapshot(state)
    }
    func loadImportRecovery() -> GameSnapshot? { recovery }
}
