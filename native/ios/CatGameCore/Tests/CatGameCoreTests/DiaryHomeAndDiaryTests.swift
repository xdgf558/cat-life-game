import XCTest
@testable import CatGameCore

final class DiaryHomeAndDiaryTests: XCTestCase {
    private let t0: Int64 = 1_760_000_000_000

    func testTutorialFlowEndToEnd() {
        let engine = DiaryGameEngine(
            state: DiaryGameState.fresh(now: t0),
            rng: SequenceRNG([0.5])
        )
        XCTAssertEqual(engine.state.tutorialStep, .meet)

        // Step 0: Pet Xiaoju
        _ = engine.pet(now: t0)
        XCTAssertEqual(engine.state.tutorialStep, .gather)

        // Step 1: Tap toybox 4 times -> 4 cloth_1 -> ready to merge
        for _ in 0..<4 { _ = engine.tapGenerator(chain: .cloth, now: t0) }
        XCTAssertEqual(engine.state.tutorialStep, .merge)

        // Step 2: Merge into cloth_3
        _ = engine.moveItem(from: 0, to: 1, now: t0)
        _ = engine.moveItem(from: 2, to: 3, now: t0)
        _ = engine.moveItem(from: 1, to: 3, now: t0)
        XCTAssertEqual(engine.state.tutorialStep, .bringHome)

        // Step 3: Bring cloth_3 home
        _ = engine.bringHome(cellIndex: 3, now: t0)
        XCTAssertEqual(engine.state.tutorialStep, .play)

        // Step 4: Play with cloth_3 -> captures photo_toy_01
        let playOut = engine.playWithToy(index: 0, now: t0)
        XCTAssertTrue(playOut.events.contains(.photoTaken(cat: .xiaoju, photoID: DiaryCatalog.tutorialPhotoID)))
        XCTAssertEqual(engine.state.tutorialStep, .finish)

        // Step 5: Finish tutorial -> generates daily wish
        _ = engine.finishTutorial(now: t0)
        XCTAssertEqual(engine.state.tutorialStep, .done)
        XCTAssertNotNil(engine.state.home.wish)
    }

    func testHungryCatRefusesPlayOutsideTutorialAndFeedsRestoresSatiety() {
        var state = DiaryGameState.fresh(now: t0)
        state.tutorialActive = false
        state.primaryCat.satiety = 10
        state.home.toys = [OwnedToy(item: MergeItem(chain: .cloth, level: 3), usesLeft: 3)]
        state.home.food = [MergeItem(chain: .food, level: 4)]

        XCTAssertEqual(DiaryHome.playWithToy(&state, toyIndex: 0, now: t0), .failed(.hungry))

        let feedResult = DiaryHome.feed(&state, foodIndex: 0, now: t0)
        guard case .fed(let reaction, _) = feedResult else {
            return XCTFail("Expected successful feed")
        }
        XCTAssertEqual(state.primaryCat.satiety, 60, accuracy: 0.01)
        XCTAssertTrue(reaction.newPhotos.contains("photo_food_02"))
    }

    func testToyWearsOutAfterThreeUsesAndUnlocksPhoto() {
        var state = DiaryGameState.fresh(now: t0)
        state.tutorialActive = false
        state.home.toys = [OwnedToy(item: MergeItem(chain: .cloth, level: 3), usesLeft: 3)]
        for i in 0..<3 {
            let res = DiaryHome.playWithToy(&state, toyIndex: 0, now: t0 + Int64(i) * 1000)
            guard case .played(let reaction, _, let wornOut) = res else { return XCTFail("Expected play") }
            if i < 2 {
                XCTAssertFalse(wornOut)
            } else {
                XCTAssertTrue(wornOut)
                XCTAssertTrue(reaction.newPhotos.contains("photo_toy_08"))
            }
        }
        XCTAssertTrue(state.home.toys.isEmpty)
    }

    func testDailyWishGrantsBonusXPOnce() {
        var state = DiaryGameState.fresh(now: t0)
        state.tutorialActive = false
        state.home.wish = DailyWish(dayKey: state.dayKey, goal: .pet, completed: false)

        let res = DiaryHome.pet(&state, now: t0)
        guard case .petted(let reaction) = res else { return XCTFail("Expected pet") }
        XCTAssertEqual(reaction.wishBonus, DiaryBalance.default.cat.wishBonusXP)
        XCTAssertEqual(state.home.wish?.completed, true)
    }

    func testCatalogHasExactly36CorePhotosAnd30OfflineNotes() {
        XCTAssertEqual(DiaryCatalog.photos.count, 36)
        XCTAssertEqual(Set(DiaryCatalog.photos.map(\.id)).count, 36)
        XCTAssertEqual(DiaryCatalog.offlineNotes.count, 30)
    }
}
