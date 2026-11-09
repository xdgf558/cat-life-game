import XCTest
import SpriteKit
import CatGameCore
@testable import CatLife

final class RoomShellFloorAppearanceTests: XCTestCase {
    @MainActor
    func testUpperFloorChangesAppearanceAndWindowWallWithoutChangingTheFloor() throws {
        for world in [CGSize(width: 375, height: 436), CGSize(width: 603, height: 1164),
                      CGSize(width: 1024, height: 768)] {
            let floor = RoomFloor(sceneSize: world, artworkSize: CGSize(width: 1024, height: 1536),
                                  catWidth: 50, bowlSize: CGSize(width: 58, height: 48))
            let physicalFloor = floor.polygon
            var upperAnchor: CGPoint?
            for angle in RoomViewAngle.allCases {
                let projection = RoomViewProjection(worldSize: world, angle: angle)
                let shell = RoomShellArtwork()
                shell.configure(projection: projection, floorPolygon: physicalFloor, worldSize: world)
                let groundOutline = try outline(shell)
                let groundAnchor = try XCTUnwrap(shell.windowGroundAnchor)
                XCTAssertEqual(shell.renderedFloor, .ground)
                XCTAssertLessThan(groundAnchor.x, world.width * 0.48)
                XCTAssertTrue(shell.children.filter { $0.name == "room-shell-upper-wall-stripe" }.isEmpty)
                let groundTexture = try XCTUnwrap(shell.childNode(withName: "//room-shell-floor-texture") as? SKSpriteNode)
                XCTAssertEqual(groundTexture.colorBlendFactor, 0)
                let groundBounds = shell.contentBounds

                shell.configure(projection: projection, floorPolygon: physicalFloor, worldSize: world, floor: .upper)
                XCTAssertEqual(shell.renderedFloor, .upper)
                XCTAssertEqual(try outline(shell), groundOutline)
                XCTAssertEqual(floor.polygon, physicalFloor)
                XCTAssertEqual(shell.contentBounds, groundBounds)
                XCTAssertFalse(shell.children.filter { $0.name == "room-shell-upper-wall-stripe" }.isEmpty)
                let upperTexture = try XCTUnwrap(shell.childNode(withName: "//room-shell-floor-texture") as? SKSpriteNode)
                XCTAssertEqual(upperTexture.colorBlendFactor, 0.12, accuracy: 0.000001)
                let anchor = try XCTUnwrap(shell.windowGroundAnchor)
                XCTAssertGreaterThan(anchor.x, world.width * 0.48)
                XCTAssertEqual(anchor.y, projection.wallGround(at: anchor.x).y, accuracy: 0.000001,
                               "The upstairs window must sit on the existing right-wall/floor seam.")
                if let upperAnchor { XCTAssertEqual(anchor, upperAnchor) }
                upperAnchor = anchor

                shell.configure(projection: projection, floorPolygon: physicalFloor, worldSize: world, floor: .ground)
                XCTAssertTrue(shell.children.filter { $0.name == "room-shell-upper-wall-stripe" }.isEmpty)
                XCTAssertEqual(shell.windowGroundAnchor, groundAnchor)
                XCTAssertEqual(try XCTUnwrap(shell.childNode(withName: "//room-shell-floor-texture") as? SKSpriteNode).colorBlendFactor, 0)
                shell.configure(projection: projection, floorPolygon: [], worldSize: world, floor: .upper)
                XCTAssertNil(shell.windowGroundAnchor)
                XCTAssertTrue(shell.children.isEmpty)
            }
        }
    }

    func testLegacyWallPixelCalibrationPreservesTheSeamAndDecorationHeight() {
        for world in [CGSize(width: 375, height: 436), CGSize(width: 603, height: 1164),
                      CGSize(width: 1024, height: 1536)] {
            let transform = RoomArtworkTransform(sceneSize: world, artworkSize: CGSize(width: 1024, height: 1536))
            for angle in RoomViewAngle.allCases {
                let projection = RoomViewProjection(worldSize: world, angle: angle)
                for pixel in [CGPoint(x: 442, y: 530), CGPoint(x: 733, y: 677.5), CGPoint(x: 1024, y: 825)] {
                    let foot = transform.point(.init(x: pixel.x / 1024, y: pixel.y / 1536))
                    let raised = transform.point(.init(x: pixel.x / 1024, y: (pixel.y - 384) / 1536))
                    let base = projection.project(foot)
                    let wallFoot = projection.wallPoint(foot)
                    let wallTop = projection.wallPoint(raised)
                    XCTAssertEqual(wallFoot.x, base.x, accuracy: 0.000001)
                    XCTAssertEqual(wallFoot.y, base.y, accuracy: 0.000001)
                    XCTAssertEqual(wallTop.x, base.x, accuracy: 0.000001)
                    XCTAssertEqual(wallTop.y - base.y, projection.wallHeight, accuracy: 0.000001)
                    let restored = projection.unprojectWallPoint(wallTop)
                    XCTAssertEqual(restored.x, raised.x, accuracy: 0.000001)
                    XCTAssertEqual(restored.y, raised.y, accuracy: 0.000001)
                }
            }
        }
    }

    @MainActor
    private func outline(_ shell: RoomShellArtwork) throws -> [CGPoint] {
        let floor = try XCTUnwrap(shell.childNode(withName: "room-shell-floor") as? SKShapeNode)
        let path = try XCTUnwrap(floor.path)
        var points: [CGPoint] = []
        path.applyWithBlock { element in
            if element.pointee.type == .moveToPoint || element.pointee.type == .addLineToPoint {
                points.append(element.pointee.points[0])
            }
        }
        return points
    }
}
