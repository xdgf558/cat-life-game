import CoreGraphics
import Foundation
import CatGameCore
import XCTest
@testable import CatLife

final class RoomFrontFloorProjectionTests: XCTestCase {
    private let viewports = [CGSize(width: 300, height: 180), CGSize(width: 300, height: 280),
                             CGSize(width: 355, height: 410), CGSize(width: 382, height: 560),
                             CGSize(width: 440, height: 680)]

    func testEveryLevelAndFloorHasAnUnfoldedFanAndRoundTripsDenseInteriorAndBoundaryPoints() throws {
        for viewport in viewports {
            for room in HomeCatalog.all {
                for homeFloor in room.floors {
                    let world = RoomWorldGeometry(viewportSize: viewport,
                        worldScale: CGFloat(try XCTUnwrap(room.worldScale(on: homeFloor)))).worldSize
                    let floor = RoomFloor(sceneSize: world, artworkSize: CGSize(width: 1024, height: 1536),
                                          catWidth: 50, bowlSize: CGSize(width: 58, height: 48))
                    let destination = CGRect(x: 12, y: 27, width: world.width,
                                             height: world.width * viewport.height / viewport.width * 0.66)
                    let map = try XCTUnwrap(RoomFrontFloorProjection(polygon: floor.polygon, destination: destination))
                    let context = "level \(room.level), \(homeFloor), \(viewport)"
                    let sourceCenter = map.sourceCenter
                    let targetCenter = CGPoint(x: destination.midX, y: destination.midY)
                    assertPoint(map.project(sourceCenter), equals: targetCenter, context)
                    let source = map.sourcePolygon
                    for index in source.indices {
                        let a = source[index], b = source[(index + 1) % source.count]
                        let targetA = map.project(a), targetB = map.project(b)
                        XCTAssertLessThan(cross(subtract(a, sourceCenter), subtract(b, sourceCenter)), 0, context)
                        XCTAssertLessThan(cross(subtract(targetA, targetCenter), subtract(targetB, targetCenter)), 0, context)
                        for step in 0...12 {
                            let point = interpolate(a, b, CGFloat(step) / 12)
                            let target = map.project(point)
                            XCTAssertTrue(destination.insetBy(dx: -0.000001, dy: -0.000001).contains(target), context)
                            XCTAssertLessThan([abs(target.x - destination.minX), abs(target.x - destination.maxX),
                                                    abs(target.y - destination.minY), abs(target.y - destination.maxY)].min()!, 0.000001, context)
                            assertPoint(map.unproject(target), equals: point, context)
                        }
                        for u in 0...8 {
                            for v in 0...(8 - u) {
                                let point = CGPoint(x: sourceCenter.x + CGFloat(u) / 8 * (a.x - sourceCenter.x)
                                                        + CGFloat(v) / 8 * (b.x - sourceCenter.x),
                                                    y: sourceCenter.y + CGFloat(u) / 8 * (a.y - sourceCenter.y)
                                                        + CGFloat(v) / 8 * (b.y - sourceCenter.y))
                                let target = map.project(point)
                                XCTAssertTrue(destination.insetBy(dx: -0.000001, dy: -0.000001).contains(target), context)
                                assertPoint(map.unproject(target), equals: point, context)
                            }
                        }
                    }
                    let path = CGMutablePath()
                    path.addLines(between: source); path.closeSubpath()
                    for x in 1..<8 {
                        for y in 1..<8 {
                            let target = CGPoint(x: destination.minX + destination.width * CGFloat(x) / 8,
                                                 y: destination.minY + destination.height * CGFloat(y) / 8)
                            let point = map.unproject(target)
                            XCTAssertTrue(path.contains(point), context)
                            assertPoint(map.project(point), equals: target, context)
                        }
                    }
                }
            }
        }
    }

    func testLegalRightWallLocationsHaveOneHorizontalBaselineAndRoundTripAtEveryLevelAndViewport() throws {
        for viewport in viewports {
            for room in HomeCatalog.all {
                let world = RoomWorldGeometry(viewportSize: viewport, worldScale: CGFloat(room.worldScale)).worldSize
                let floor = RoomFloor(sceneSize: world, artworkSize: CGSize(width: 1024, height: 1536),
                                      catWidth: 50, bowlSize: CGSize(width: 58, height: 48))
                let destination = CGRect(x: 0, y: 0, width: world.width,
                                         height: world.width * viewport.height / viewport.width * 0.66)
                let map = try XCTUnwrap(RoomFrontFloorProjection(polygon: floor.polygon, destination: destination))
                let projection = RoomViewProjection(worldSize: world, angle: .front, frontFloor: map)
                let sourceWallHeight = 384 * max(world.width / 1024, world.height / 1536)
                XCTAssertEqual(projection.wallHeight, destination.height * 0.34 / 0.66, accuracy: 0.000001)
                for fraction: CGFloat in [0.5, 0.625, 0.77, 0.95] {
                    let x = world.width * fraction
                    let ground = projection.wallGround(at: x)
                    XCTAssertEqual(projection.wallPoint(ground).y, destination.maxY, accuracy: 0.000001)
                    for height: CGFloat in [0.08, 0.25, 0.75, 0.95] {
                        let point = CGPoint(x: x, y: ground.y + sourceWallHeight * height)
                        let target = projection.wallPoint(point)
                        XCTAssertGreaterThan(target.y, destination.maxY)
                        assertPoint(projection.unprojectWallPoint(target), equals: point)
                    }
                }
            }
        }
    }

    func testExtrapolatedContactPointsAndLocalVectorsRemainReversible() throws {
        let world = CGSize(width: 603, height: 1164)
        let floor = RoomFloor(sceneSize: world, artworkSize: CGSize(width: 1024, height: 1536),
                              catWidth: 50, bowlSize: CGSize(width: 58, height: 48))
        let map = try XCTUnwrap(RoomFrontFloorProjection(polygon: floor.polygon,
            destination: CGRect(x: 10, y: 20, width: 500, height: 600)))
        let projection = RoomViewProjection(worldSize: world, angle: .front, frontFloor: map)
        for point in [CGPoint(x: -10_000, y: -10_000), CGPoint(x: 10_000, y: 10_000),
                      CGPoint(x: -100, y: 1200), CGPoint(x: 800, y: -50)] {
            assertPoint(projection.unproject(projection.project(point)), equals: point)
        }
        let delta = CGPoint(x: 13, y: -9)
        for origin in [map.sourceCenter] + map.sourcePolygon {
            let a = projection.project(origin)
            let b = projection.project(CGPoint(x: origin.x + delta.x, y: origin.y + delta.y))
            assertPoint(projection.vector(delta, at: origin), equals: subtract(b, a))
        }
    }

    func testReversingTheSourceWindingDoesNotReflectTheRoomAndSideViewsKeepTheirLegacyMapping() throws {
        let world = CGSize(width: 603, height: 1164)
        let floor = RoomFloor(sceneSize: world, artworkSize: CGSize(width: 1024, height: 1536),
                              catWidth: 50, bowlSize: CGSize(width: 58, height: 48))
        let destination = CGRect(x: 0, y: 0, width: 500, height: 600)
        let a = try XCTUnwrap(RoomFrontFloorProjection(polygon: floor.polygon, destination: destination))
        let b = try XCTUnwrap(RoomFrontFloorProjection(polygon: Array(floor.polygon.reversed()), destination: destination))
        for point in a.sourcePolygon + [a.sourceCenter, .zero] {
            assertPoint(a.project(point), equals: b.project(point))
            for angle in [RoomViewAngle.left, .right] {
                let legacy = RoomViewProjection(worldSize: world, angle: angle)
                let configured = RoomViewProjection(worldSize: world, angle: angle, frontFloor: a)
                assertPoint(configured.project(point), equals: legacy.project(point))
                assertPoint(configured.unproject(point), equals: legacy.unproject(point))
                assertPoint(configured.wallPoint(point), equals: legacy.wallPoint(point))
                assertPoint(configured.unprojectWallPoint(point), equals: legacy.unprojectWallPoint(point))
                XCTAssertEqual(configured.wallHeight, legacy.wallHeight)
            }
        }
    }

    func testInvalidOrCollapsedGeometryIsRejected() {
        let rectangle = [CGPoint(x: 0, y: 10), CGPoint(x: 10, y: 10), CGPoint(x: 10, y: 0), .zero]
        let destination = CGRect(x: 0, y: 0, width: 100, height: 200)
        XCTAssertNotNil(RoomFrontFloorProjection(polygon: rectangle, destination: destination))
        XCTAssertNil(RoomFrontFloorProjection(polygon: [], destination: destination))
        XCTAssertNil(RoomFrontFloorProjection(polygon: [CGPoint](repeating: .zero, count: 4), destination: destination))
        XCTAssertNil(RoomFrontFloorProjection(polygon: [.zero, CGPoint(x: 1, y: 1), CGPoint(x: 2, y: 2), CGPoint(x: 3, y: 3)], destination: destination))
        XCTAssertNil(RoomFrontFloorProjection(polygon: rectangle + [CGPoint(x: CGFloat.nan, y: 0)], destination: destination))
        XCTAssertNil(RoomFrontFloorProjection(polygon: rectangle, destination: .zero))
        XCTAssertNil(RoomFrontFloorProjection(polygon: rectangle, destination: CGRect(x: 0, y: 0, width: CGFloat.infinity, height: 100)))
    }

    private func assertPoint(_ actual: CGPoint, equals expected: CGPoint, _ context: String = "",
                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.x, expected.x, accuracy: 0.000001, context, file: file, line: line)
        XCTAssertEqual(actual.y, expected.y, accuracy: 0.000001, context, file: file, line: line)
    }
    private func subtract(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: a.x - b.x, y: a.y - b.y) }
    private func cross(_ a: CGPoint, _ b: CGPoint) -> CGFloat { a.x * b.y - a.y * b.x }
    private func interpolate(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }
}
