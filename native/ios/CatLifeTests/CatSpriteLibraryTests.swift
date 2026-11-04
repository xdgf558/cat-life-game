import XCTest
import CatGameCore
@testable import CatLife

final class CatSpriteLibraryTests: XCTestCase {
#if DEBUG
    @MainActor
    func testWarmRegistrationIsSharedAcrossCompanionSwitchesAndActors() async {
        await CatSpriteLibrary.resetCacheForTests()
        await CatSpriteLibrary.preload()
        let expectedCount = CatAppearance.allCases.count * CatClip.allCases.count
        XCTAssertEqual(CatSpriteLibrary.backgroundRegistrations, expectedCount)
        XCTAssertEqual(CatSpriteLibrary.synchronousRegistrations, 0)

        let library = CatSpriteLibrary()
        let orange = CatClip.allCases.map { library.sequence($0) }
        library.setAppearance(.cow)
        let cow = CatClip.allCases.map { library.sequence($0) }
        for sequences in [orange, cow] {
            for sequence in sequences {
                XCTAssertEqual(sequence.frames.count, 8)
                XCTAssertGreaterThan(sequence.referenceHeight, 0)
                XCTAssertTrue(sequence.frames.allSatisfy { $0.bounds.width > 0 && $0.bounds.height > 0 })
            }
        }
        // Preserve per-species paw calibration while sharing the immutable clip.
        let cowStep = library.sequence(.step)
        XCTAssertEqual(cowStep.frames[2].groundY, 420)
        XCTAssertEqual(cowStep.frames[2].frontPaw, CGPoint(x: 317.7, y: 387))
        XCTAssertEqual(cowStep.frames[2].rearPaw, CGPoint(x: 106.2, y: 420))

        for _ in 0..<5 {
            for appearance in CatAppearance.allCases {
                library.setAppearance(appearance)
                let secondOwner = CatSpriteLibrary(appearance: appearance)
                let expected = appearance == .orange ? orange : cow
                for (index, clip) in CatClip.allCases.enumerated() {
                    let current = library.sequence(clip)
                    let other = secondOwner.sequence(clip)
                    for frame in current.frames.indices {
                        XCTAssertTrue(current.frames[frame].texture === expected[index].frames[frame].texture)
                        XCTAssertTrue(other.frames[frame].texture === expected[index].frames[frame].texture)
                        XCTAssertEqual(current.frames[frame].bounds, expected[index].frames[frame].bounds)
                    }
                }
                let actor = CatActor()
                actor.setIdleEnabled(false)
                actor.setAppearance(appearance)
            }
        }
        await CatSpriteLibrary.preload()
        XCTAssertEqual(CatSpriteLibrary.backgroundRegistrations, expectedCount)
        XCTAssertEqual(CatSpriteLibrary.synchronousRegistrations, 0)
    }

    @MainActor
    func testConcurrentWelcomePreparationRegistersEachAtlasOnlyOnce() async {
        await RoomScene.resetWelcomeResourcesForTests()
        await CatSpriteLibrary.resetCacheForTests()
        XCTAssertFalse(RoomScene.welcomeResourcesReadyForTests)
        let first = Task {
            await RoomScene.preloadWelcomeResources()
            return RoomScene.welcomeResourcesReadyForTests
        }
        let second = Task {
            await RoomScene.preloadWelcomeResources()
            return RoomScene.welcomeResourcesReadyForTests
        }
        let firstReady = await first.value
        let secondReady = await second.value
        XCTAssertTrue(firstReady)
        XCTAssertTrue(secondReady)
        XCTAssertEqual(RoomScene.welcomePreloadPassCount, 1)
        XCTAssertEqual(CatSpriteLibrary.backgroundRegistrations,
                       CatAppearance.allCases.count * CatClip.allCases.count)
        XCTAssertEqual(CatSpriteLibrary.synchronousRegistrations, 0)
        await RoomScene.preloadWelcomeResources()
        XCTAssertEqual(RoomScene.welcomePreloadPassCount, 1)
    }
#endif
}
