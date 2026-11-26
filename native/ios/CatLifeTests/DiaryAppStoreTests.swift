import XCTest
import CatGameCore
@testable import CatLife

@MainActor
final class DiaryAppStoreTests: XCTestCase {
    private func makeTempStore(adOutcome: AdPlayResult = .ended) -> (DiaryAppStore, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let repo = DiarySaveRepository(directory: dir)
        let ad = MockRewardedAdService(immediateOutcome: adOutcome)
        let store = DiaryAppStore(repository: repo, adService: ad)
        return (store, dir)
    }

    func testBootstrapAndCompleteTutorialUpdatesStoreAndDiary() async {
        let (store, dir) = makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        await store.bootstrap()
        XCTAssertTrue(store.isLoaded)
        XCTAssertEqual(store.state.tutorialStep, .meet)

        store.petCat()
        XCTAssertEqual(store.state.tutorialStep, .gather)

        store.switchScreen(to: .workshop)
        for _ in 0..<4 { store.tapGenerator(.cloth) }
        XCTAssertEqual(store.state.tutorialStep, .merge)

        XCTAssertEqual(store.moveItem(from: 0, to: 1), .merged(MergeItem(chain: .cloth, level: 2)))
        XCTAssertEqual(store.moveItem(from: 2, to: 3), .merged(MergeItem(chain: .cloth, level: 2)))
        XCTAssertEqual(store.moveItem(from: 1, to: 3), .merged(MergeItem(chain: .cloth, level: 3)))
        XCTAssertEqual(store.state.tutorialStep, .bringHome)

        store.bringHome(cellIndex: 3)
        XCTAssertEqual(store.activeScreen, .home)
        XCTAssertEqual(store.state.tutorialStep, .play)

        store.playWithToy(at: 0)
        XCTAssertEqual(store.currentPhotoModalID, DiaryCatalog.tutorialPhotoID)

        store.dismissCurrentPhotoModal()
        XCTAssertEqual(store.state.tutorialStep, .done)
        XCTAssertNotNil(store.state.home.wish)
    }

    func testTrilingualStringsCoverAllKeysAnd36Photos() {
        let zhKeys = Set(GameStrings.chinese.keys)
        let zhtKeys = Set(GameStrings.traditionalChinese.keys)
        let enKeys = Set(GameStrings.english.keys)
        XCTAssertEqual(zhKeys, zhtKeys, "Traditional Chinese keys must match Simplified Chinese")
        XCTAssertEqual(zhKeys, enKeys, "English keys must match Simplified Chinese")

        for photo in DiaryCatalog.photos {
            XCTAssertNotNil(GameStrings.chinese["photo.\(photo.id).title"], photo.id)
            XCTAssertNotNil(GameStrings.chinese["photo.\(photo.id).caption"], photo.id)
        }
    }

    func testAppReleaseIncludesBuild64AndPreservesHistoricalBuild63() {
        XCTAssertEqual(AppVersion.current.version, "1.0.0")
        XCTAssertEqual(AppVersion.current.buildNumber, 64)
        let builds = AppRelease.recent.map(\.build)
        XCTAssertTrue(builds.contains(64))
        XCTAssertTrue(builds.contains(63))
    }
}
