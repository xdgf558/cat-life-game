import Foundation
import XCTest
import CatGameCore
@testable import CatLife

final class RoomResidentPlannerTests: XCTestCase {
    func testFiveCatsFitEveryUnlockedHomeAndEveryCatCanReachTheBowl() throws {
        for viewport in [CGSize(width: 375, height: 436), CGSize(width: 402, height: 567)] {
            for room in HomeCatalog.all where room.level >= 4 {
                for levelFloor in room.floors {
                    let fixture = try fixture(viewport: viewport, roomLevel: room.level,
                                              furnished: levelFloor == .ground)
                    let context = "\(viewport), home \(room.level), \(levelFloor)"
                    let positions = fixture.planner.positions(count: 4)
                    XCTAssertEqual(positions.count, 4, context)
                    assertCareAvailable(fixture, positions: [fixture.active] + positions, context: context)
                    let obstacles = positions.map { RoomResidentPlanner.obstacle(at: $0, width: fixture.world.catWidth) }
                    for placement in fixture.world.placements {
                        guard fixture.world.restVisit(to: placement.itemID, from: fixture.active) != nil else { continue }
                        XCTAssertNotNil(fixture.world.restVisit(to: placement.itemID, from: fixture.active,
                                                               additionalObstacles: obstacles), context)
                    }
                    XCTAssertEqual(fixture.planner.positions(count: 4, existing: positions), positions,
                                   "A harmless refresh must keep valid resident positions: \(context)")
                }
            }
        }
    }

    func testResidentAndActiveWalksAvoidAllOtherCatsAndKeepCareReachable() throws {
        let value = try fixture(viewport: .init(width: 375, height: 436), roomLevel: 4, furnished: false)
        let residents = value.planner.positions(count: 4)
        XCTAssertEqual(residents.count, 4)
        let resident = try XCTUnwrap(residents.first)
        for (origin, others) in [(resident, Array(residents.dropFirst())), (value.active, residents)] {
            let activeWalking = origin == value.active
            let stationary = others + (activeWalking ? [] : [value.active])
            let route = try XCTUnwrap(value.planner.stroll(from: origin, others: others, active: value.active))
            XCTAssertEqual(route.first, origin)
            let navigation = value.world.roomFloor.addingObstacles(stationary.map {
                RoomResidentPlanner.obstacle(at: $0, width: value.world.catWidth)
            }).navigator(bowlAt: value.world.bowlPosition, precomputeGrid: false)
            XCTAssertTrue(zip(route, route.dropFirst()).allSatisfy {
                navigation.segmentIsWalkable(from: $0.0, to: $0.1)
            }, "A safe destination alone does not prove the path avoids another cat.")
            assertCareAvailable(value, positions: stationary + [try XCTUnwrap(route.last)], context: "after stroll")
        }
    }

    func testExtraObstaclesReachMealDockingAndFurnitureEntryValidation() throws {
        let value = try fixture(viewport: .init(width: 402, height: 567), roomLevel: 4, furnished: true)
        let floor = value.world.roomFloor
        let meal = try XCTUnwrap(floor.feedingPlan(from: value.active, bowlAt: value.world.bowlPosition,
                                                  navigator: floor.navigator(bowlAt: value.world.bowlPosition)))
        let occupiedBowl = CGRect(x: value.world.bowlPosition.x - value.world.catWidth * 2,
                                 y: value.world.bowlPosition.y - value.world.catWidth,
                                 width: value.world.catWidth * 4, height: value.world.catWidth * 2)
        let blocked = floor.addingObstacles([occupiedBowl])
        XCTAssertEqual(blocked.polygon, floor.polygon)
        XCTAssertEqual(blocked.catFootprint, floor.catFootprint)
        XCTAssertFalse(blocked.navigator(bowlAt: value.world.bowlPosition).isWalkable(meal.path.last!))
        XCTAssertNil(blocked.feedingPlan(from: value.active, bowlAt: value.world.bowlPosition,
                                         navigator: blocked.navigator(bowlAt: value.world.bowlPosition)))
        let rest = try XCTUnwrap(value.world.placements.compactMap {
            value.world.restVisit(to: $0.itemID, from: value.active)
        }.first)
        XCTAssertNil(value.world.restVisit(to: rest.item.id, from: value.active,
            additionalObstacles: [RoomResidentPlanner.obstacle(at: rest.plan.restPoint, width: value.world.catWidth)]),
            "Other cats cannot be ignored after the approach reaches the furniture.")
    }

    func testUnavailableSpaceDoesNotForceAnUnsafePosition() throws {
        let value = try fixture(viewport: .init(width: 375, height: 436), roomLevel: 4, furnished: false)
        let blockedFloor = value.world.roomFloor.addingObstacles([
            CGRect(origin: .zero, size: value.world.transform.sceneSize)
        ])
        let planner = RoomResidentPlanner(floor: blockedFloor, bowl: value.world.bowlPosition,
            world: value.world, active: value.active, catWidth: value.world.catWidth)
        XCTAssertTrue(planner.positions(count: 4).isEmpty)
        XCTAssertNil(planner.stroll(from: value.active, others: [], active: value.active))
    }

    private struct Fixture {
        let world: RoomFurnitureWorld
        let active: CGPoint
        var planner: RoomResidentPlanner {
            .init(floor: world.roomFloor, bowl: world.bowlPosition, world: world,
                  active: active, catWidth: world.catWidth)
        }
    }

    private func fixture(viewport: CGSize, roomLevel: Int, furnished: Bool) throws -> Fixture {
        let scale = CGFloat(try XCTUnwrap(HomeCatalog.level(roomLevel)).worldScale)
        let size = CGSize(width: viewport.width * scale, height: viewport.height * scale)
        let width = min(viewport.width * 0.14, viewport.height * 0.172)
        let bowlWidth = min(viewport.width * 0.156, viewport.height * 0.185)
        let transform = RoomArtworkTransform(sceneSize: size, artworkSize: .init(width: 1024, height: 1536),
                                              viewportSize: viewport)
        let world = RoomFurnitureWorld(transform: transform, catWidth: width,
            bowlSize: .init(width: bowlWidth, height: bowlWidth * 0.83),
            bowlPosition: .init(x: size.width * 0.76, y: size.height * 0.21),
            items: furnished ? FurnitureCatalog.defaultItems : [],
            placements: furnished ? FurnitureCatalog.defaultPlacements : [])
        let resolved = try XCTUnwrap(RoomBowlPlanner(floor: world.roomFloor, requested: world.bowlPosition,
            catPosition: .init(x: size.width * 0.43, y: size.height * 0.18)).resolve())
        return .init(world: .init(transform: transform, catWidth: width, bowlSize: world.bowlSize,
                                 bowlPosition: resolved.center, items: world.items, placements: world.placements),
                     active: try XCTUnwrap(resolved.catPosition))
    }

    private func assertCareAvailable(_ fixture: Fixture, positions: [CGPoint], context: String,
                                     file: StaticString = #filePath, line: UInt = #line) {
        for (index, point) in positions.enumerated() {
            let obstacles = positions.enumerated().filter { $0.offset != index }.map {
                RoomResidentPlanner.obstacle(at: $0.element, width: fixture.world.catWidth)
            }
            let floor = fixture.world.roomFloor.addingObstacles(obstacles)
            let navigation = floor.navigator(bowlAt: fixture.world.bowlPosition, precomputeGrid: false)
            XCTAssertTrue(navigation.isWalkable(point), context, file: file, line: line)
            XCTAssertNotNil(floor.feedingPlan(from: point, bowlAt: fixture.world.bowlPosition,
                navigator: navigation, firstReachable: true), context, file: file, line: line)
        }
    }
}
