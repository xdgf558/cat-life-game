import XCTest
import SpriteKit
@testable import CatLife

final class RoomShellArtworkTests: XCTestCase {
    @MainActor
    func testAllAnglesCloseTheExistingFloorAndIncludeWallsAndEdgesInOverviewBounds() throws {
        for viewport in [CGSize(width: 375, height: 436), CGSize(width: 402, height: 776)] {
            for scale: CGFloat in [1, 1.5, 2] {
                let world = CGSize(width: viewport.width * scale, height: viewport.height * scale)
                let floor = RoomFloor(sceneSize: world, artworkSize: CGSize(width: 1024, height: 1536),
                                      catWidth: 50, bowlSize: CGSize(width: 58, height: 48))
                let source = floor.polygon
                for angle in RoomViewAngle.allCases {
                    let projection = RoomViewProjection(worldSize: world, angle: angle)
                    let shell = RoomShellArtwork()
                    shell.configure(projection: projection, floorPolygon: source, worldSize: world)
                    let node = try XCTUnwrap(shell.childNode(withName: "room-shell-floor") as? SKShapeNode)
                    let path = try XCTUnwrap(node.path)
                    var outline: [CGPoint] = []
                    var closed = false
                    path.applyWithBlock { element in
                        switch element.pointee.type {
                        case .moveToPoint, .addLineToPoint: outline.append(element.pointee.points[0])
                        case .closeSubpath: closed = true
                        default: XCTFail("The floor boundary must retain the existing polygon.")
                        }
                    }
                    XCTAssertEqual(outline, source.map(projection.project))
                    XCTAssertEqual(floor.polygon, source)
                    XCTAssertTrue(closed)
                    XCTAssertFalse(shell.contentBounds.isEmpty)
                    XCTAssertTrue([shell.contentBounds.minX, shell.contentBounds.minY,
                                   shell.contentBounds.maxX, shell.contentBounds.maxY].allSatisfy(\.isFinite))
                    for point in outline { XCTAssertTrue(shell.contentBounds.contains(point)) }
                    let farWalls = shell.children.filter { $0.name == "room-shell-far-wall" }
                    XCTAssertFalse(farWalls.isEmpty)
                    XCTAssertEqual(shell.children.filter { $0.name == "room-shell-wood-edge" }.count, source.count)
                    for wall in farWalls { XCTAssertTrue(shell.contentBounds.contains(wall.frame)) }
                    XCTAssertGreaterThan(shell.contentBounds.maxY, path.boundingBoxOfPath.maxY)
                    XCTAssertLessThan(shell.contentBounds.minY, path.boundingBoxOfPath.minY)
                }
            }
        }
    }

    @MainActor
    func testReconfigureReplacesTheShellAndInvalidGeometryClearsIt() {
        let world = CGSize(width: 375, height: 436)
        let projection = RoomViewProjection(worldSize: world, angle: .front)
        let polygon = [CGPoint(x: 20, y: 30), CGPoint(x: 350, y: 30),
                       CGPoint(x: 350, y: 280), CGPoint(x: 190, y: 355), CGPoint(x: 20, y: 280)]
        let shell = RoomShellArtwork()
        shell.configure(projection: projection, floorPolygon: polygon, worldSize: world)
        let count = shell.children.count, bounds = shell.contentBounds
        shell.configure(projection: projection, floorPolygon: polygon, worldSize: world)
        XCTAssertEqual(shell.children.count, count)
        XCTAssertEqual(shell.contentBounds, bounds)
        shell.configure(projection: projection, floorPolygon: [], worldSize: world)
        XCTAssertTrue(shell.children.isEmpty)
        XCTAssertEqual(shell.contentBounds, .zero)
        shell.configure(projection: projection, floorPolygon: [.zero, CGPoint(x: CGFloat.infinity, y: 0), CGPoint(x: 0, y: 20)],
                        worldSize: world)
        XCTAssertTrue(shell.children.isEmpty)
    }
}
