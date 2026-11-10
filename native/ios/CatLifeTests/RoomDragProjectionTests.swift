import CoreGraphics
import XCTest
import CatGameCore
@testable import CatLife

@MainActor
final class RoomDragProjectionTests: XCTestCase {
    func testGroundGripStaysAtTheFingerAcrossFrontSectorsViewsAndZoom() throws {
        for viewport in [CGSize(width: 355, height: 375), CGSize(width: 382, height: 560)] {
            let transform = RoomArtworkTransform(sceneSize: viewport, artworkSize: CGSize(width: 1024, height: 1536))
            let start = transform.point(.init(x: 0.58, y: 0.52))
            let targets = [NormalizedPoint(x: 0.40, y: 0.65), .init(x: 0.64, y: 0.70),
                           .init(x: 0.72, y: 0.62), .init(x: 0.35, y: 0.72)].map(transform.point)
            for angle in RoomViewAngle.allCases {
                let renderer = renderer(viewport: viewport, angle: angle)
                for zoom: CGFloat in [1, 1.6] {
                    renderer.camera.fit()
                    renderer.camera.zoom(by: zoom)
                    let startAnchor = renderer.camera.viewPoint(projectedWorld: renderer.projection.project(start))
                    for grip in [CGPoint(x: 0, y: -35), CGPoint(x: 15, y: 24)] {
                        let firstTouch = CGPoint(x: startAnchor.x + grip.x, y: startAnchor.y + grip.y)
                        let displayOffset = CGPoint(x: startAnchor.x - firstTouch.x, y: startAnchor.y - firstTouch.y)
                        for target in targets {
                            let desired = renderer.camera.viewPoint(projectedWorld: renderer.projection.project(target))
                            let touch = CGPoint(x: desired.x + grip.x, y: desired.y + grip.y)
                            let resolved = renderer.worldPoint(screen: touch, displayOffset: displayOffset)
                            assertPoint(resolved, equals: target)
                            let anchor = renderer.camera.viewPoint(projectedWorld: renderer.projection.project(resolved))
                            assertPoint(CGPoint(x: anchor.x - touch.x, y: anchor.y - touch.y), equals: displayOffset)
                        }
                        if angle == .front, zoom == 1, viewport.width == 355, grip.y < 0 {
                            let target = targets[1]
                            let desired = renderer.camera.viewPoint(projectedWorld: renderer.projection.project(target))
                            let touch = CGPoint(x: desired.x + grip.x, y: desired.y + grip.y)
                            let oldStart = renderer.worldPoint(screen: firstTouch)
                            let oldEnd = renderer.worldPoint(screen: touch)
                            let wrong = CGPoint(x: oldEnd.x + start.x - oldStart.x, y: oldEnd.y + start.y - oldStart.y)
                            let wrongAnchor = renderer.camera.viewPoint(projectedWorld: renderer.projection.project(wrong))
                            XCTAssertGreaterThan(hypot(wrongAnchor.x - desired.x, wrongAnchor.y - desired.y), 1,
                                                 "This fixture must cross a projection sector and catch the old source-space grip bug.")
                        }
                    }
                }
            }
        }
    }

    func testWallGripAndEdgeScrollingUseTheSameDisplayOffset() {
        let viewport = CGSize(width: 355, height: 375)
        let transform = RoomArtworkTransform(sceneSize: viewport, artworkSize: CGSize(width: 1024, height: 1536))
        let target = transform.point(.init(x: 0.72, y: 0.26))
        for angle in RoomViewAngle.allCases {
            let renderer = renderer(viewport: viewport, angle: angle)
            renderer.camera.zoom(by: 1.6)
            let displayOffset = CGPoint(x: -14, y: 22)
            let desired = renderer.camera.viewPoint(projectedWorld: renderer.projection.wallPoint(target))
            let touch = CGPoint(x: desired.x - displayOffset.x, y: desired.y - displayOffset.y)
            assertPoint(renderer.worldPoint(screen: touch, wall: true, displayOffset: displayOffset), equals: target)
            let edgeTouch = CGPoint(x: 22, y: 120)
            _ = renderer.camera.scrollNearEdge(at: edgeTouch, delta: 1.0 / 60)
            let moved = renderer.worldPoint(screen: edgeTouch, displayOffset: displayOffset)
            let anchor = renderer.camera.viewPoint(projectedWorld: renderer.projection.project(moved))
            assertPoint(anchor, equals: CGPoint(x: edgeTouch.x + displayOffset.x, y: edgeTouch.y + displayOffset.y))
        }
    }

    private func renderer(viewport: CGSize, angle: RoomViewAngle) -> RoomPresentationRenderer {
        let renderer = RoomPresentationRenderer()
        let floor = RoomFloor(sceneSize: viewport, artworkSize: CGSize(width: 1024, height: 1536),
                              catWidth: 50, bowlSize: CGSize(width: 58, height: 48))
        renderer.setUsableRect(RoomStageLayout.usableRect(in: viewport))
        renderer.configure(world: viewport, viewport: viewport, floor: floor.polygon, angle: angle, level: 1)
        return renderer
    }

    private func assertPoint(_ actual: CGPoint, equals expected: CGPoint,
                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.x, expected.x, accuracy: 0.000001, file: file, line: line)
        XCTAssertEqual(actual.y, expected.y, accuracy: 0.000001, file: file, line: line)
    }
}
