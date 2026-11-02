import Foundation
import XCTest
import CatGameCore
@testable import CatLife

final class RoomBowlPlannerTests: XCTestCase {
    @MainActor
    func testLegacyWallPositionRestoresToReachableFloorWithoutChangingRequest() async throws {
        let floor = makeFloor()
        let request = RoomBowlPlanner(floor: floor, requested: CGPoint(x: 195, y: 450),
                                      catPosition: CGPoint(x: 165, y: 90))
        let value = await Task.detached { request.resolve() }.value
        let result = try XCTUnwrap(value)
        let cat = try XCTUnwrap(result.catPosition)
        XCTAssertNotEqual(result.center, request.requested)
        XCTAssertEqual(request.requested, CGPoint(x: 195, y: 450), "Restoration is a visual projection, not a save edit.")
        XCTAssertTrue(floor.placementNavigator().isWalkable(floor.bowlGround(at: result.center)))
        XCTAssertTrue(result.navigation.isWalkable(cat))
        XCTAssertNotNil(floor.feedingPlan(from: cat, bowlAt: result.center, navigator: result.navigation))
#if DEBUG
        XCTAssertFalse(result.ranOnMainThread)
#endif
    }

    @MainActor
    func testValidRestoredPositionAndNavigationAreStableAcrossReload() async throws {
        let floor = makeFloor()
        let first = await Task.detached {
            RoomBowlPlanner(floor: floor, requested: CGPoint(x: 300, y: 110),
                            catPosition: CGPoint(x: 165, y: 90)).resolve()
        }.value
        let restored = try XCTUnwrap(first)
        let cat = try XCTUnwrap(restored.catPosition)
        let next = await Task.detached {
            RoomBowlPlanner(floor: floor, requested: restored.center, catPosition: cat).resolve()
        }.value
        let reloaded = try XCTUnwrap(next)
        XCTAssertEqual(reloaded.center, restored.center)
        XCTAssertEqual(reloaded.catPosition, restored.catPosition)
        XCTAssertEqual(reloaded.navigation.walkablePoints, restored.navigation.walkablePoints)
    }

    @MainActor
    func testCancelledWorkerCannotPublishAReplacementLayout() async {
        let request = RoomBowlPlanner(floor: makeFloor(), requested: CGPoint(x: 195, y: 450),
                                      catPosition: CGPoint(x: 165, y: 90))
        let worker = Task.detached {
            // A deterministic gate places cancellation before the planner,
            // without relying on a machine-specific duration or grid size.
            while !Task<Never, Never>.isCancelled { await Task.yield() }
            return request.resolve()
        }
        worker.cancel()
        let result = await worker.value
        XCTAssertNil(result)
    }

    @MainActor
    func testCompletelyBlockedLegacyLayoutDoesNotInventAWalkableRoute() async throws {
        let request = RoomBowlPlanner(
            floor: makeFloor(obstacles: [CGRect(x: -100, y: -100, width: 1_000, height: 1_000)]),
            requested: CGPoint(x: 300, y: 110), catPosition: CGPoint(x: 165, y: 90))
        let value = await Task.detached { request.resolve() }.value
        let result = try XCTUnwrap(value)
        XCTAssertEqual(result.center, request.requested)
        XCTAssertNil(result.catPosition)
        XCTAssertNil(result.navigation.route(from: request.catPosition, to: request.requested))
    }

    func testInterruptedClimbRetainsItsFirstPoseThenReturnsAllSupportToFloor() throws {
        let keys = CatFurnitureStepTimeline.retreating(startingFrame: 3, progress: 0.61,
                                                       elevation: 8, shadowElevation: 5)
        let first = try XCTUnwrap(keys.first)
        let last = try XCTUnwrap(keys.last)
        XCTAssertEqual(first.frame, 3)
        XCTAssertEqual(first.travel, 0)
        XCTAssertEqual(first.progress, 0.61)
        XCTAssertEqual(first.elevation, 8)
        XCTAssertEqual(first.shadowElevation, 5)
        XCTAssertEqual(last.travel, 1)
        XCTAssertEqual(last.progress, 0)
        XCTAssertEqual(last.elevation, 0)
        XCTAssertEqual(last.shadowElevation, 0)
        for (earlier, later) in zip(keys, keys.dropFirst()) {
            XCTAssertGreaterThanOrEqual(later.travel, earlier.travel)
            XCTAssertLessThanOrEqual(later.progress, earlier.progress)
            XCTAssertLessThanOrEqual(later.elevation, earlier.elevation)
        }
    }

    private func makeFloor(obstacles: [CGRect] = []) -> RoomFloor {
        RoomFloor(sceneSize: CGSize(width: 390, height: 480),
                  artworkSize: CGSize(width: 1024, height: 1536), catWidth: 54.6,
                  bowlSize: CGSize(width: 60.84, height: 50.4972), furnitureObstacles: obstacles)
    }
}
