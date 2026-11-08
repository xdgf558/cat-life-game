import Foundation
import XCTest
import UIKit
import CatGameCore
@testable import CatLife

final class NewFurnitureGeometryTests: XCTestCase {
    func testNewFloorFurnitureCanBePlacedWithoutBlockingCareAndMirroringKeepsTheSameFootprint() throws {
        for viewport in [CGSize(width: 375, height: 436), CGSize(width: 402, height: 776)] {
            for room in HomeCatalog.all {
                for floor in room.floors {
                    let floorContext = "room level \(room.level), \(floor.rawValue), \(viewport)"
                    let scale = CGFloat(try XCTUnwrap(room.worldScale(on: floor), floorContext))
                    let sceneSize = CGSize(width: viewport.width * scale, height: viewport.height * scale)
                    let transform = RoomArtworkTransform(sceneSize: sceneSize, artworkSize: .init(width: 1024, height: 1536),
                                                         viewportSize: viewport)
                    let cat = CGPoint(x: sceneSize.width * 0.43, y: sceneSize.height * 0.18)
                    // The measured feeding dock requires the same bowl sizing as RoomLayoutPlanning.
                    let bowlWidth = min(viewport.width * 0.156, viewport.height * 0.185)
                    for kind in [FurnitureKind.bookcase, .rattanChair, .sideTable] {
                        let context = "\(kind.rawValue), \(floorContext)"
                        let item = FurnitureItem(id: "new", kind: kind)
                        let world = RoomFurnitureWorld(transform: transform, catWidth: viewport.width * 0.14,
                            bowlSize: .init(width: bowlWidth, height: bowlWidth * 0.83),
                            bowlPosition: .init(x: sceneSize.width * 0.76, y: sceneSize.height * 0.21),
                            items: [item], placements: [])
                        XCTAssertNotNil(world.roomFloor.feedingPlan(from: cat, bowlAt: world.bowlPosition,
                            navigator: world.roomFloor.navigator(bowlAt: world.bowlPosition)),
                            "The empty-room fixture must already support feeding: \(context)")
                        let navigation = world.placementNavigator(for: item.id, catAt: cat)
                        let result = try XCTUnwrap(world.resolve(id: item.id,
                            near: transform.point(.init(x: 0.50, y: 0.65)), catAt: cat, placement: navigation), context)
                        let placed = world.replacing(item.id, with: result.center)
                        XCTAssertEqual(placed.floorObstacles().count, 1, context)
                        XCTAssertFalse(placed.roomFloor.navigator(bowlAt: placed.bowlPosition).isWalkable(result.center), context)
                        XCTAssertNotNil(placed.roomFloor.feedingPlan(from: cat, bowlAt: placed.bowlPosition,
                            navigator: placed.roomFloor.navigator(bowlAt: placed.bowlPosition)), context)
                        XCTAssertNil(placed.restVisit(to: item.id, from: cat), context)
                        var mirrored = item
                        mirrored.orientation = .mirrored
                        XCTAssertEqual(placed.footprint(item), placed.footprint(mirrored), context)
                    }
                }
            }
        }
    }

    func testNewWallArtOnlyBlocksOtherWallArt() {
        let item = FurnitureItem(id: "sunrise", kind: .wallSunrise)
        let spec = RoomFurnitureSpec.forItem(item)
        XCTAssertTrue(spec.isWall)
        let world = RoomFurnitureWorld(transform: .init(sceneSize: .init(width: 402, height: 776),
            artworkSize: .init(width: 1024, height: 1536)), catWidth: 56, bowlSize: .init(width: 48, height: 32),
            bowlPosition: .init(x: 300, y: 150), items: [item],
            placements: [.init(itemID: item.id, position: .init(x: 0.7, y: 0.3))])
        XCTAssertTrue(world.floorObstacles().isEmpty)
        XCTAssertEqual(world.placementNavigator(for: item.id, catAt: .init(x: 150, y: 120)).floor, world.wallPolygon)
    }

    @MainActor func testNewFurnitureSpritesHaveRealTransparencyAndTrilingualNames() throws {
        for kind in [FurnitureKind.bookcase, .rattanChair, .sideTable, .wallSunrise] {
            let metadata = FurnitureCatalog.metadata(for: kind)
            let cg = try XCTUnwrap(UIImage(named: metadata.assetName)?.cgImage)
            XCTAssertGreaterThan(cg.width, 100)
            XCTAssertNotEqual(cg.alphaInfo, .none)
            XCTAssertNotEqual(cg.alphaInfo, .noneSkipFirst)
            XCTAssertNotEqual(cg.alphaInfo, .noneSkipLast)
            for dictionary in [GameStrings.chinese, GameStrings.traditionalChinese, GameStrings.english] {
                XCTAssertNotNil(dictionary[metadata.nameKey])
            }
        }
    }
}
