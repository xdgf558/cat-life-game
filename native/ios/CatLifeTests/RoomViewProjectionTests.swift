import Foundation
import XCTest
@testable import CatLife

final class RoomViewProjectionTests: XCTestCase {
    private let worlds = [CGSize(width: 375, height: 436), CGSize(width: 603, height: 1164),
                          CGSize(width: 804, height: 1552)]

    func testFrontProjectionIsExactlyTheExistingCoordinateSystem() {
        for world in worlds {
            let projection = RoomViewProjection(worldSize: world, angle: .front)
            for point in samples(world) {
                XCTAssertEqual(projection.project(point), point)
                XCTAssertEqual(projection.unproject(point), point)
                XCTAssertEqual(projection.vector(point), point)
                XCTAssertEqual(projection.projectedDepth(point), point.y)
            }
        }
    }

    func testAllAnglesRoundTripGroundAndWallPositions() {
        for world in worlds {
            for angle in RoomViewAngle.allCases {
                let projection = RoomViewProjection(worldSize: world, angle: angle)
                for point in samples(world) {
                    let restored = projection.unproject(projection.project(point))
                    XCTAssertEqual(restored.x, point.x, accuracy: 0.000001)
                    XCTAssertEqual(restored.y, point.y, accuracy: 0.000001)
                    let wall = projection.unprojectWallPoint(projection.wallPoint(point))
                    XCTAssertEqual(wall.x, point.x, accuracy: 0.000001)
                    XCTAssertEqual(wall.y, point.y, accuracy: 0.000001)
                }
                let center = CGPoint(x: world.width / 2, y: world.height / 2)
                XCTAssertEqual(projection.project(center), center)
            }
        }
    }

    func testVectorsAndDepthUseTheSameProjectionWithoutItsTranslation() {
        let origin = CGPoint(x: 127, y: 311), delta = CGPoint(x: -54, y: 72)
        for angle in RoomViewAngle.allCases {
            let projection = RoomViewProjection(worldSize: worlds[0], angle: angle)
            let start = projection.project(origin)
            let end = projection.project(CGPoint(x: origin.x + delta.x, y: origin.y + delta.y))
            let vector = projection.vector(delta)
            XCTAssertEqual(end.x - start.x, vector.x, accuracy: 0.000001)
            XCTAssertEqual(end.y - start.y, vector.y, accuracy: 0.000001)
            XCTAssertEqual(projection.projectedDepth(origin), start.y)
            let x = projection.vector(CGPoint(x: 1, y: 0)), y = projection.vector(CGPoint(x: 0, y: 1))
            XCTAssertEqual(x.x * y.y - x.y * y.x, 1, accuracy: 0.000001)
        }
    }

    func testSideViewsRotateTheUnprojectedFloorInsteadOfTheImagePlane() {
        let basis = CGPoint(x: sqrt(CGFloat(3)) / 2, y: 0.5)
        for angle in [RoomViewAngle.left, .right] {
            let projection = RoomViewProjection(worldSize: worlds[0], angle: angle)
            let vector = projection.vector(basis)
            let cosine = cos(angle.radians), sine = sin(angle.radians)
            XCTAssertEqual(vector.x, sqrt(CGFloat(3)) / 2 * (cosine - sine), accuracy: 0.000001)
            XCTAssertEqual(vector.y, (cosine + sine) / 2, accuracy: 0.000001)
        }
    }

    func testAngleSequenceContainsThreeDistinctFixedViews() {
        XCTAssertEqual(RoomViewAngle.allCases, [.left, .front, .right])
        XCTAssertEqual(RoomViewAngle.front.previous, .left)
        XCTAssertEqual(RoomViewAngle.front.next, .right)
        XCTAssertEqual(RoomViewAngle.left.previous, .right)
        XCTAssertEqual(RoomViewAngle.right.next, .left)
        XCTAssertEqual(RoomViewAngle.right.radians, .pi / 10)
    }

    private func samples(_ size: CGSize) -> [CGPoint] {
        [.zero, CGPoint(x: size.width, y: size.height), CGPoint(x: size.width / 2, y: size.height / 2),
         CGPoint(x: size.width * 0.76, y: size.height * 0.21), CGPoint(x: -23.125, y: size.height + 57.25)]
    }
}
