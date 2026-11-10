import SpriteKit
import XCTest
import CatGameCore
@testable import CatLife

final class RoomStageLayoutTests: XCTestCase {
    private let stages = [CGSize(width: 300, height: 280), CGSize(width: 355, height: 410),
                          CGSize(width: 382, height: 560)]

    func testStageKeepsTheBottomCapsuleOutsideTheRoomViewport() {
        for size in stages {
            let stage = CGRect(origin: .zero, size: size)
            let controls = RoomStageLayout.controlsFrame(in: size)
            let usable = RoomStageLayout.usableRect(in: size)
            XCTAssertTrue(stage.contains(controls))
            XCTAssertTrue(stage.contains(usable))
            XCTAssertEqual(controls.midX, stage.midX, accuracy: 0.001)
            XCTAssertGreaterThanOrEqual(controls.height, 44)
            XCTAssertEqual(controls.maxY, size.height - 12, accuracy: 0.001)
            XCTAssertEqual(usable.minX, 20)
            XCTAssertEqual(usable.maxX, size.width - 20)
            XCTAssertLessThanOrEqual(usable.maxY, controls.minY - 8)
            XCTAssertFalse(usable.intersects(controls))
        }
    }

    @MainActor
    func testEveryRoomFloorAndAngleStillFitsInsideTheStageAboveTheCapsule() throws {
        for size in stages {
            let usable = RoomStageLayout.usableRect(in: size)
            let controls = RoomStageLayout.controlsFrame(in: size)
            for room in HomeCatalog.all {
                for homeFloor in room.floors {
                    let scale = CGFloat(try XCTUnwrap(room.worldScale(on: homeFloor)))
                    let world = RoomWorldGeometry(viewportSize: size, worldScale: scale).worldSize
                    let floor = RoomFloor(sceneSize: world, artworkSize: CGSize(width: 1024, height: 1536),
                                          catWidth: 50, bowlSize: CGSize(width: 58, height: 48))
                    for angle in RoomViewAngle.allCases {
                        let projection = RoomViewProjection(worldSize: world, angle: angle)
                        let shell = RoomShellArtwork()
                        shell.configure(projection: projection, floorPolygon: floor.polygon,
                                        worldSize: world, floor: homeFloor)
                        let bounds = shell.contentBounds.insetBy(dx: -24, dy: -24)
                        let camera = RoomViewCamera()
                        camera.configure(bounds: bounds, viewport: size, usableRect: usable,
                                         worldScale: scale, reset: true)
                        let context = "\(size), level \(room.level), \(homeFloor), \(angle)"
                        XCTAssertTrue(camera.isWholeRoom, context)
                        for point in [CGPoint(x: bounds.minX, y: bounds.minY), CGPoint(x: bounds.maxX, y: bounds.minY),
                                      CGPoint(x: bounds.minX, y: bounds.maxY), CGPoint(x: bounds.maxX, y: bounds.maxY)] {
                            let displayed = camera.viewPoint(projectedWorld: point)
                            XCTAssertTrue(usable.insetBy(dx: -0.001, dy: -0.001).contains(displayed), context)
                            XCTAssertLessThan(displayed.y, controls.minY, context)
                        }
                    }
                }
            }
        }
    }

    func testPreviewClampsOffscreenAndOversizedTargetsInsideTheStageAndAboveTheCapsule() {
        for size in stages {
            let region = RoomStageLayout.previewRegion(in: size)
            let controls = RoomStageLayout.controlsFrame(in: size)
            for target in [CGRect(x: -100, y: -80, width: 40, height: 50),
                           CGRect(x: size.width - 10, y: 8, width: 40, height: 50),
                           CGRect(x: 4, y: size.height - 10, width: 40, height: 50),
                           CGRect(x: size.width + 80, y: size.height + 100, width: 40, height: 50)] {
                for height: CGFloat in [160, 280, 1200] {
                    let frame = RoomStageLayout.previewFrame(near: target, preferredHeight: height, in: size)
                    XCTAssertTrue(region.insetBy(dx: -0.001, dy: -0.001).contains(frame))
                    XCTAssertGreaterThanOrEqual(frame.height, 44)
                    XCTAssertLessThanOrEqual(frame.maxY, controls.minY - 8)
                    XCTAssertFalse(frame.intersects(controls))
                }
            }
        }
    }

    func testPreviewUsesClearSpaceAboveTheCatAndFallsBelowATopEdgeCat() {
        let size = CGSize(width: 355, height: 500)
        let centerCat = CGRect(x: 180, y: 260, width: 40, height: 50)
        let above = RoomStageLayout.previewFrame(near: centerCat, preferredHeight: 140, in: size)
        XCTAssertEqual(above.maxY, centerCat.minY - 12)
        XCTAssertFalse(above.intersects(centerCat))
        let topCat = CGRect(x: 100, y: 20, width: 40, height: 50)
        let below = RoomStageLayout.previewFrame(near: topCat, preferredHeight: 140, in: size)
        XCTAssertEqual(below.minY, topCat.maxY + 12)
        XCTAssertFalse(below.intersects(topCat))
    }

    func testAccessibilityAndShortStagesUseAFullPreviewSheet() {
        XCTAssertTrue(RoomStageLayout.requiresPreviewSheet(in: CGSize(width: 300, height: 180), accessibility: false))
        XCTAssertTrue(RoomStageLayout.requiresPreviewSheet(in: .zero, accessibility: false))
        for size in stages {
            XCTAssertTrue(RoomStageLayout.requiresPreviewSheet(in: size, accessibility: true))
            XCTAssertFalse(RoomStageLayout.requiresPreviewSheet(in: size, accessibility: false))
        }
    }

    func testArrangementStillReservesTheFullScreenHeaderAndFurnitureTray() {
        for size in [CGSize(width: 375, height: 603), CGSize(width: 402, height: 776)] {
            for tray: CGFloat in [98, 180, 288] {
                let usable = RoomStageLayout.arrangementUsableRect(in: size, bottomInset: tray)
                XCTAssertEqual(usable.minY, 160)
                XCTAssertEqual(usable.maxY, size.height - tray - 12, accuracy: 0.001)
                XCTAssertTrue(CGRect(origin: .zero, size: size).contains(usable))
                XCTAssertGreaterThanOrEqual(usable.height, 80)
            }
        }
    }
}
