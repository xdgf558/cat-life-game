import Foundation
import XCTest
import CatGameCore
@testable import CatLife

final class RoomCameraZoomTests: XCTestCase {
    @MainActor
    func testZoomProjectionRoundTripsAndKeepsCompleteRoomsInsideOverview() throws {
        for viewport in [CGSize(width: 375, height: 436), CGSize(width: 402, height: 776)] {
            for room in HomeCatalog.all {
                for floor in room.floors {
                    let expansion = CGFloat(try XCTUnwrap(room.worldScale(on: floor)))
                    let world = RoomWorldGeometry(viewportSize: viewport, worldScale: expansion).worldSize
                    let floorShape = RoomFloor(sceneSize: world, artworkSize: CGSize(width: 1024, height: 1536),
                                               catWidth: 50, bowlSize: CGSize(width: 58, height: 48))
                    for angle in RoomViewAngle.allCases {
                        let context = "level \(room.level), \(floor), \(angle), \(viewport)"
                        let projection = RoomViewProjection(worldSize: world, angle: angle)
                        let shell = RoomShellArtwork()
                        shell.configure(projection: projection, floorPolygon: floorShape.polygon, worldSize: world)
                        let bounds = shell.contentBounds
                        let usable = CGRect(x: 12, y: 40, width: viewport.width - 24, height: viewport.height - 80)
                        let camera = RoomViewCamera()
                        camera.configure(bounds: bounds, viewport: viewport, usableRect: usable, worldScale: expansion, reset: true)
                        for corner in [CGPoint(x: bounds.minX, y: bounds.minY), CGPoint(x: bounds.maxX, y: bounds.maxY)] {
                            XCTAssertTrue(usable.insetBy(dx: -0.001, dy: -0.001).contains(camera.viewPoint(projectedWorld: corner)), context)
                        }
                        let saved = CGPoint(x: world.width * 0.76, y: world.height * 0.21)
                        for focus in [CGPoint(x: -10_000, y: -10_000), CGPoint(x: 10_000, y: 10_000)] {
                            camera.focus(on: focus)
                            camera.zoom(by: 1.25)
                            let screen = camera.viewPoint(projectedWorld: projection.project(saved))
                            let restored = projection.unproject(camera.worldPoint(viewPoint: screen))
                            XCTAssertEqual(restored.x, saved.x, accuracy: 0.0001, context)
                            XCTAssertEqual(restored.y, saved.y, accuracy: 0.0001, context)
                            let visible = camera.visibleRect
                            if visible.width <= bounds.width {
                                XCTAssertGreaterThanOrEqual(visible.minX, bounds.minX - 0.001, context)
                                XCTAssertLessThanOrEqual(visible.maxX, bounds.maxX + 0.001, context)
                            } else { XCTAssertEqual(camera.center.x, bounds.midX, accuracy: 0.001, context) }
                            if visible.height <= bounds.height {
                                XCTAssertGreaterThanOrEqual(visible.minY, bounds.minY - 0.001, context)
                                XCTAssertLessThanOrEqual(visible.maxY, bounds.maxY + 0.001, context)
                            } else { XCTAssertEqual(camera.center.y, bounds.midY, accuracy: 0.001, context) }
                        }
                    }
                }
            }
        }
    }

#if DEBUG
    @MainActor
    func testPinchDoesNotRestartCareOrEmitGameCallbacksAndStopsWhenInactive() async throws {
        let scene = RoomScene(size: CGSize(width: 375, height: 436))
        defer { scene.setPresentationActive(false) }
        var snapshot = GameSnapshot.fresh()
        snapshot.home.roomLevel = 3
        scene.apply(snapshot: snapshot, editing: false)
        let deadline = Date().addingTimeInterval(10)
        while scene.presentationPhase != "idle", Date() < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(scene.canZoomCamera)
        XCTAssertEqual(scene.presentationPhase, "idle")
        var gameCallbacks = 0
        scene.onBowlTapped = { gameCallbacks += 1 }
        scene.onCatTapped = { gameCallbacks += 1 }
        scene.onBowlMoved = { _ in gameCallbacks += 1 }
        scene.onFurnitureMoved = { _, _ in gameCallbacks += 1 }
        scene.playFeedback(kind: .feed)
        let careDeadline = Date().addingTimeInterval(10)
        while scene.diagnostics.carePlanCompletions == 0, Date() < careDeadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        let cat = try XCTUnwrap(scene.childNode(withName: "cat") as? CatActor)
        XCTAssertTrue(cat.isPerforming)
        let camera = scene.roomPresentation.camera
        let fitScale = camera.fitScale
        let bowlCompletions = scene.diagnostics.bowlPlanCompletions
        let careCompletions = scene.diagnostics.carePlanCompletions
        let careCancellations = scene.diagnostics.carePlanCancelled
        let midpoint = CGPoint(x: 187.5, y: 218)
        scene.handlePinch(state: .began, scale: 1, location: midpoint)
        scene.handlePinch(state: .changed, scale: 1.25, location: midpoint)
        XCTAssertEqual(camera.scale, fitScale * 0.8, accuracy: 0.0001)
        XCTAssertTrue(cat.isPerforming)
        XCTAssertEqual(scene.presentationPhase, "feeding")
        XCTAssertEqual(scene.diagnostics.bowlPlanCompletions, bowlCompletions)
        XCTAssertEqual(scene.diagnostics.carePlanCompletions, careCompletions)
        XCTAssertEqual(scene.diagnostics.carePlanCancelled, careCancellations)
        scene.setPresentationActive(false)
        XCTAssertFalse(scene.canZoomCamera)
        scene.handlePinch(state: .changed, scale: 2, location: .zero)
        scene.handlePinch(state: .ended, scale: 2, location: .zero)
        XCTAssertEqual(camera.scale, fitScale * 0.8, accuracy: 0.0001)
        scene.setPresentationActive(true)
        scene.zoomIn()
        XCTAssertEqual(camera.scale, fitScale * 0.64, accuracy: 0.0001)
        scene.resetCamera()
        XCTAssertEqual(camera.scale, fitScale / 1.6, accuracy: 0.0001)
        XCTAssertEqual(gameCallbacks, 0)
    }
#endif

}
