import Foundation
import XCTest
import CatGameCore
@testable import CatLife

final class RoomCameraZoomTests: XCTestCase {
    func testZoomProjectionRoundTripsAndKeepsVisibleWorldInsideBounds() {
        for viewport in [CGSize(width: 375, height: 436), CGSize(width: 402, height: 567)] {
            for expansion: CGFloat in [1.25, 1.5] {
                let geometry = RoomWorldGeometry(viewportSize: viewport, worldScale: expansion)
                for scale: CGFloat in [0.625, 1, expansion] {
                    for proposed in [CGPoint(x: -1_000, y: -1_000), CGPoint(x: 10_000, y: 10_000)] {
                        let camera = geometry.clampedCameraPosition(proposed, cameraScale: scale)
                        let topLeft = geometry.worldPoint(.zero, camera: camera, cameraScale: scale)
                        let bottomRight = geometry.worldPoint(CGPoint(x: viewport.width, y: viewport.height),
                                                              camera: camera, cameraScale: scale)
                        XCTAssertGreaterThanOrEqual(topLeft.x, -0.0001)
                        XCTAssertLessThanOrEqual(topLeft.y, geometry.worldSize.height + 0.0001)
                        XCTAssertLessThanOrEqual(bottomRight.x, geometry.worldSize.width + 0.0001)
                        XCTAssertGreaterThanOrEqual(bottomRight.y, -0.0001)
                        let savedWorldPoint = CGPoint(x: geometry.worldSize.width * 0.76, y: geometry.worldSize.height * 0.21)
                        let projected = geometry.screenPoint(savedWorldPoint, camera: camera, cameraScale: scale)
                        let restored = geometry.worldPoint(projected, camera: camera, cameraScale: scale)
                        XCTAssertEqual(restored.x, savedWorldPoint.x, accuracy: 0.0001)
                        XCTAssertEqual(restored.y, savedWorldPoint.y, accuracy: 0.0001)
                        if scale == expansion {
                            XCTAssertEqual(topLeft.x, 0, accuracy: 0.0001)
                            XCTAssertEqual(topLeft.y, geometry.worldSize.height, accuracy: 0.0001)
                            XCTAssertEqual(bottomRight.x, geometry.worldSize.width, accuracy: 0.0001)
                            XCTAssertEqual(bottomRight.y, 0, accuracy: 0.0001)
                        }
                    }
                }
            }
        }
    }

    @MainActor
    func testPinchKeepsWorldAnchorUnderMovingMidpointAndRejectsInvalidInput() {
        let camera = makeCamera()
        let geometry = camera.geometry
        let origin = CGPoint(x: 150, y: 196)
        let moved = CGPoint(x: 162, y: 218)
        let anchor = geometry.worldPoint(origin, camera: camera.node.position, cameraScale: camera.scale)
        let before = camera.node.position
        camera.beginPinch(at: origin)
        XCTAssertEqual(camera.node.position, before, "Beginning a pinch cannot jump the camera.")
        camera.changePinch(factor: 1.6, at: moved)
        XCTAssertEqual(camera.scale, 0.625, accuracy: 0.0001)
        let projected = geometry.screenPoint(anchor, camera: camera.node.position, cameraScale: camera.scale)
        XCTAssertEqual(projected.x, moved.x, accuracy: 0.0001)
        XCTAssertEqual(projected.y, moved.y, accuracy: 0.0001)
        let zoomed = camera.node.position
        for invalid: CGFloat in [0, -1, .nan, .infinity] {
            camera.changePinch(factor: invalid, at: moved)
            XCTAssertEqual(camera.node.position, zoomed)
            XCTAssertEqual(camera.scale, 0.625, accuracy: 0.0001)
        }
        camera.endPinch()
        camera.changePinch(factor: 0.2, at: .zero)
        XCTAssertEqual(camera.node.position, zoomed)
        XCTAssertEqual(camera.scale, 0.625, accuracy: 0.0001)
    }

    @MainActor
    func testPanAndEdgeScrollingFollowScreenDistanceAtZoomedScale() {
        let camera = makeCamera()
        camera.zoom(by: 1.25)
        XCTAssertEqual(camera.scale, 0.8, accuracy: 0.0001)
        let original = camera.node.position
        camera.beginTouch(at: CGPoint(x: 160, y: 200), canPan: true)
        XCTAssertTrue(camera.moveTouch(to: CGPoint(x: 180, y: 215)))
        XCTAssertEqual(camera.node.position.x, original.x - 20 * camera.scale, accuracy: 0.0001)
        XCTAssertEqual(camera.node.position.y, original.y + 15 * camera.scale, accuracy: 0.0001)
        XCTAssertTrue(camera.endTouch())
        let beforeEdge = camera.node.position
        _ = camera.update(at: 1, target: nil, draggingAt: CGPoint(x: 375, y: 218))
        XCTAssertTrue(camera.update(at: 1.05, target: nil, draggingAt: CGPoint(x: 375, y: 218)))
        XCTAssertEqual(camera.node.position.x, beforeEdge.x + 100 * 0.05 * camera.scale, accuracy: 0.0001)
        XCTAssertEqual(camera.node.position.y, beforeEdge.y)
        camera.beginPinch(at: CGPoint(x: 180, y: 218))
        let pinching = camera.node.position
        XCTAssertFalse(camera.update(at: 1.1, target: .zero, draggingAt: .zero))
        XCTAssertEqual(camera.node.position, pinching)
    }

    @MainActor
    func testZoomLimitsAndGeometryChangesKeepCameraValidAndLevelOneLocked() {
        let camera = makeCamera()
        camera.zoom(by: 0.01)
        XCTAssertEqual(camera.scale, 1.5)
        XCTAssertEqual(camera.node.position, CGPoint(x: 375 * 1.5 / 2, y: 436 * 1.5 / 2))
        camera.beginPinch(at: CGPoint(x: 180, y: 218))
        camera.configure(RoomWorldGeometry(viewportSize: CGSize(width: 402, height: 567), worldScale: 1.25))
        XCTAssertFalse(camera.isPinching)
        XCTAssertEqual(camera.scale, 1.25)
        XCTAssertEqual(camera.node.position, CGPoint(x: 402 * 1.25 / 2, y: 567 * 1.25 / 2))
        camera.zoom(by: 100)
        XCTAssertEqual(camera.scale, 0.625)
        camera.focus(on: .zero, animated: false, resetScale: true)
        XCTAssertEqual(camera.scale, 1)
        XCTAssertEqual(camera.node.position, CGPoint(x: 201, y: 283.5))
        camera.configure(RoomWorldGeometry(viewportSize: CGSize(width: 375, height: 436), worldScale: 1))
        camera.beginPinch(at: CGPoint(x: 180, y: 218))
        camera.changePinch(factor: 1.6, at: .zero)
        camera.zoom(by: 0.2)
        XCTAssertFalse(camera.isPinching)
        XCTAssertEqual(camera.scale, 1)
        XCTAssertEqual(camera.node.position, CGPoint(x: 187.5, y: 218))
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
        let camera = try XCTUnwrap(scene.camera)
        let bowlCompletions = scene.diagnostics.bowlPlanCompletions
        let careCompletions = scene.diagnostics.carePlanCompletions
        let careCancellations = scene.diagnostics.carePlanCancelled
        let midpoint = CGPoint(x: 187.5, y: 218)
        scene.handlePinch(state: .began, scale: 1, location: midpoint)
        scene.handlePinch(state: .changed, scale: 1.25, location: midpoint)
        XCTAssertEqual(camera.xScale, 0.8, accuracy: 0.0001)
        XCTAssertTrue(cat.isPerforming)
        XCTAssertEqual(scene.presentationPhase, "feeding")
        XCTAssertEqual(scene.diagnostics.bowlPlanCompletions, bowlCompletions)
        XCTAssertEqual(scene.diagnostics.carePlanCompletions, careCompletions)
        XCTAssertEqual(scene.diagnostics.carePlanCancelled, careCancellations)
        scene.setPresentationActive(false)
        XCTAssertFalse(scene.canZoomCamera)
        scene.handlePinch(state: .changed, scale: 2, location: .zero)
        scene.handlePinch(state: .ended, scale: 2, location: .zero)
        XCTAssertEqual(camera.xScale, 0.8, accuracy: 0.0001)
        scene.setPresentationActive(true)
        scene.zoomIn()
        XCTAssertEqual(camera.xScale, 0.64, accuracy: 0.0001)
        scene.resetCamera()
        XCTAssertEqual(camera.xScale, 1)
        XCTAssertEqual(gameCallbacks, 0)
    }
#endif

    @MainActor
    private func makeCamera() -> RoomCameraController {
        let camera = RoomCameraController()
        camera.configure(RoomWorldGeometry(viewportSize: CGSize(width: 375, height: 436), worldScale: 1.5))
        camera.node.position = CGPoint(x: 375 * 1.5 / 2, y: 436 * 1.5 / 2)
        return camera
    }
}
