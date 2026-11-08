import Foundation
import XCTest
import CatGameCore
@testable import CatLife

@MainActor
final class TownMusic58Tests: XCTestCase {
    private func store(_ repository: TownMusic58Repository) -> GameStore {
        let suite = "CatLife-town-music-\(UUID())"
        addTeardownBlock { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        return GameStore(repository: repository, reminderDefaults: UserDefaults(suiteName: suite)!)
    }

    private func seed() -> GameSnapshot {
        var state = GameSnapshot.fresh()
        state.home = HomeState(roomLevel: 6)
        state.player.stamina = 50
        state.cats[0].energy = 60
        state.settings.audio = AudioSettings(musicEnabled: false, effectsEnabled: false,
                                            catEnabled: false, nightQuiet: false, haptics: false)
        return state
    }

    func testMapUsesNewMusicWhileNeighborsMarketAndCollectionKeepTownMusic() async {
        let store = store(TownMusic58Repository(seed()))
        await store.load()
        XCTAssertEqual(store.currentMusicTrack, .cover)
        store.enterHome()
        XCTAssertEqual(store.currentMusicTrack, .home)
        await store.changeHomeFloor(to: .upper)
        XCTAssertEqual(store.currentMusicTrack, .upstairs)
        store.activeSheet = .town
        XCTAssertEqual(store.currentMusicTrack, .promenade)
        store.openNeighbors()
        XCTAssertEqual(store.currentMusicTrack, .town)
        store.isShowingNeighbors = false
        XCTAssertEqual(store.currentMusicTrack, .promenade)
        store.openExchangeMarket()
        XCTAssertEqual(store.currentMusicTrack, .town)
        store.isShowingMarket = false
        XCTAssertEqual(store.currentMusicTrack, .promenade)
        store.openCatCollection(filter: .all)
        XCTAssertEqual(store.currentMusicTrack, .town)
        store.catCollectionFilter = nil
        XCTAssertEqual(store.currentMusicTrack, .promenade)
        store.activeSheet = nil
        XCTAssertEqual(store.currentMusicTrack, .upstairs)
        await store.changeHomeFloor(to: .ground)
        XCTAssertEqual(store.currentMusicTrack, .home)
    }

    func testFailedRestExitKeepsMusicAndFloorUntilSavedTravelSucceeds() async throws {
        let repository = TownMusic58Repository(seed())
        let store = store(repository)
        await store.load()
        store.enterHome()
        store.setRestingFurniture(id: "catBed", sessionID: "audio-rest")
        try await settled(store)
        XCTAssertEqual(store.currentMusicTrack, .sleep)
        XCTAssertNotNil(store.cat?.activeRest)
        await repository.setFailing(true)
        await store.changeHomeFloor(to: .upper)
        XCTAssertEqual(store.visibleHomeFloor, .ground)
        XCTAssertEqual(store.currentMusicTrack, .sleep)
        XCTAssertNotNil(store.cat?.activeRest)
        await repository.setFailing(false)
        await store.changeHomeFloor(to: .upper)
        XCTAssertEqual(store.visibleHomeFloor, .upper)
        XCTAssertEqual(store.currentMusicTrack, .upstairs)
        XCTAssertNil(store.cat?.activeRest)
    }

    func testSleepKeepsPriorityInBothFloorsAndSceneMusicSwitchStillUsesHome() async throws {
        let store = store(TownMusic58Repository(seed()))
        await store.load()
        store.enterHome()
        await store.changeHomeFloor(to: .upper)
        store.startSleep()
        try await settled(store)
        XCTAssertNotNil(store.snapshot?.player.activeSleep)
        XCTAssertEqual(store.currentMusicTrack, .sleep)
        await store.changeHomeFloor(to: .ground)
        XCTAssertEqual(store.currentMusicTrack, .sleep)
        store.wakeUp()
        try await settled(store)
        XCTAssertEqual(store.currentMusicTrack, .home)
        await store.changeHomeFloor(to: .upper)
        XCTAssertEqual(store.currentMusicTrack, .upstairs)
        var settings = store.audioSettings
        settings.sceneMusic = false
        let saved = await store.updateAudioSettings(settings)
        XCTAssertTrue(saved)
        XCTAssertEqual(store.currentMusicTrack, .home)
        store.activeSheet = .town
        XCTAssertEqual(store.currentMusicTrack, .home)
    }

    func testNewSceneNamesExistInEveryLanguage() {
        for dictionary in [GameStrings.chinese, GameStrings.traditionalChinese, GameStrings.english] {
            for track in [GameMusicTrack.promenade, .upstairs] {
                XCTAssertFalse(dictionary[track.sceneKey]?.isEmpty ?? true, track.sceneKey)
            }
        }
    }

    private func settled(_ store: GameStore) async throws {
        let deadline = Date().addingTimeInterval(3)
        while store.isBusy {
            if Date() > deadline { throw WaitError.timeout }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
    private enum WaitError: Error { case timeout }
}

private actor TownMusic58Repository: GameSaveRepository {
    let lastLoadDisposition = SaveLoadDisposition.loaded
    private var saved: GameSnapshot
    private var failing = false
    init(_ state: GameSnapshot) { saved = state }
    func setFailing(_ value: Bool) { failing = value }
    func loadOrCreate(now: Date) -> GameSnapshot { saved }
    func checkWritable() throws { if failing { throw CocoaError(.fileWriteUnknown) } }
    func save(_ state: GameSnapshot) throws {
        try checkWritable()
        saved = state
    }
}
