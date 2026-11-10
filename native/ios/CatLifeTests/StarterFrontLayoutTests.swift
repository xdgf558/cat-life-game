import Foundation
import SpriteKit
import XCTest
import CatGameCore
@testable import CatLife

final class StarterFrontLayoutTests: XCTestCase {
    private let viewports = [CGSize(width: 355, height: 375), CGSize(width: 382, height: 560)]

    func testDefaultFurnitureKeepsSafeFootprintsAndReachableMealsAndBothRestPlacesOnEveryFloor() throws {
        for viewport in viewports {
            for room in HomeCatalog.all {
                for homeFloor in room.floors {
                    let world = makeWorld(viewport: viewport, room: room, floor: homeFloor)
                    let context = "level \(room.level), \(homeFloor), \(viewport)"
                    let start = CGPoint(x: world.transform.sceneSize.width * 0.43,
                                        y: world.transform.sceneSize.height * 0.18)
                    let resolution = try XCTUnwrap(RoomBowlPlanner(floor: world.roomFloor,
                        requested: world.bowlPosition, catPosition: start).resolve(), context)
                    let cat = try XCTUnwrap(resolution.catPosition, context)
                    XCTAssertEqual(cat.x, start.x, accuracy: 0.001, context)
                    XCTAssertEqual(cat.y, start.y, accuracy: 0.001, context)
                    XCTAssertEqual(resolution.center.x, world.bowlPosition.x, accuracy: 0.001, context)
                    XCTAssertEqual(resolution.center.y, world.bowlPosition.y, accuracy: 0.001, context)
                    XCTAssertNotNil(world.roomFloor.feedingPlan(from: cat, bowlAt: resolution.center,
                                                               navigator: resolution.navigation), context)
                    for item in world.items {
                        let center = try XCTUnwrap(world.center(item.id), context)
                        XCTAssertTrue(world.placementNavigator(for: item.id, catAt: cat).isWalkable(center),
                                      "Default \(item.id) must fit its real footprint and clear other items: \(context)")
                    }
                    for id in ["catBed", "floorCushion"] {
                        let visit = try XCTUnwrap(world.restVisit(to: id, from: cat), "\(id), \(context)")
                        XCTAssertEqual(visit.plan.approach.first, cat, context)
                        XCTAssertEqual(visit.plan.approach.last, visit.plan.stage, context)
                        XCTAssertTrue(visit.target.contains(visit.plan.restPoint), context)
                        for path in [visit.plan.entry, visit.plan.exit] {
                            for pair in zip(path, path.dropFirst()) {
                                XCTAssertTrue(visit.navigation.segmentIsWalkable(from: pair.0, to: pair.1), context)
                            }
                        }
                    }
                }
            }
        }
    }

    @MainActor
    func testDefaultFrontSpritesSeparateTheFurnitureThatPreviouslyCrossedEachOther() throws {
        for viewport in viewports {
            for room in HomeCatalog.all {
                for homeFloor in room.floors {
                    let world = makeWorld(viewport: viewport, room: room, floor: homeFloor)
                    let usable = RoomStageLayout.usableRect(in: viewport)
                    let floor = world.roomFloor.polygon
                    let minX = try XCTUnwrap(floor.map(\.x).min()), maxX = try XCTUnwrap(floor.map(\.x).max())
                    let minY = try XCTUnwrap(floor.map(\.y).min())
                    let destination = CGRect(x: minX, y: minY, width: maxX - minX,
                                             height: (maxX - minX) * usable.height / usable.width * 0.66)
                    let front = try XCTUnwrap(RoomFrontFloorProjection(polygon: floor, destination: destination))
                    let projection = RoomViewProjection(worldSize: world.transform.sceneSize, angle: .front, frontFloor: front)
                    var frames: [String: CGRect] = [:]
                    for item in world.items {
                        let spec = RoomFurnitureSpec.forItem(item)
                        let source = try XCTUnwrap(world.center(item.id))
                        let point = spec.isWall ? projection.wallPoint(source) : projection.project(source)
                        let texture = RoomFurnitureArt.texture(for: item.kind)
                        let width = spec.width * world.transform.visualScale
                        let height = width * texture.size().height / texture.size().width
                        frames[item.id] = CGRect(x: point.x - width / 2, y: point.y - height * spec.anchorY,
                                                 width: width, height: height)
                    }
                    let floorIDs = world.items.filter { !RoomFurnitureSpec.forItem($0).isWall }.map(\.id)
                    for index in floorIDs.indices {
                        for other in floorIDs.dropFirst(index + 1) {
                            let id = floorIDs[index]
                            XCTAssertFalse(try XCTUnwrap(frames[id]).intersects(try XCTUnwrap(frames[other])),
                                "Visible \(id) and \(other) must have separate silhouettes at level \(room.level), \(homeFloor), \(viewport)")
                        }
                    }
                    let picture = try XCTUnwrap(frames["wallFlower"])
                    let catPicture = try XCTUnwrap(frames["wallCat"])
                    XCTAssertFalse(picture.intersects(catPicture))
                    for picture in [picture, catPicture] {
                        XCTAssertFalse(picture.intersects(try XCTUnwrap(frames["catTree"])))
                        XCTAssertFalse(picture.intersects(try XCTUnwrap(frames["cabinet"])))
                    }
                    // The former pad/stool overlap is checked with the actual registered alpha-cropped textures above.
                    XCTAssertLessThan(try XCTUnwrap(frames["floorCushion"]).maxY,
                                      try XCTUnwrap(frames["flowerStool"]).minY)
                }
            }
        }
    }

    private func makeWorld(viewport: CGSize, room: HomeLevel, floor: HomeFloor) -> RoomFurnitureWorld {
        let scale = CGFloat(room.worldScale)
        let size = CGSize(width: viewport.width * scale, height: viewport.height * scale)
        let bowlWidth = min(viewport.width * 0.156, viewport.height * 0.185)
        let placements = FurnitureCatalog.defaultPlacements.map { placement in
            FurniturePlacement(itemID: placement.itemID, position: placement.position, floor: floor)
        }
        return RoomFurnitureWorld(transform: .init(sceneSize: size, artworkSize: .init(width: 1024, height: 1536),
                                                   viewportSize: viewport),
            catWidth: min(viewport.width * 0.14, viewport.height * 0.172),
            bowlSize: .init(width: bowlWidth, height: bowlWidth * 0.83),
            bowlPosition: .init(x: size.width * 0.76, y: size.height * 0.21),
            items: FurnitureCatalog.defaultItems, placements: placements)
    }
}
