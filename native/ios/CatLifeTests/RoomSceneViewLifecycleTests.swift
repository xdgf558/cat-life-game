import Foundation
import SpriteKit
import XCTest
import CatGameCore
@testable import CatLife

final class RoomSceneViewLifecycleTests: XCTestCase {
#if DEBUG
    @MainActor
    func testResizeImmediatelyUpdatesViewportWhileRestExitRetainsItsCanonicalWorld() async throws {
        let initialSize = CGSize(width: 375, height: 569)
        let scene = RoomScene(size: initialSize)
        defer { scene.setPresentationActive(false) }
        var snapshot = GameSnapshot.fresh()
        snapshot.home.roomLevel = 3
        scene.apply(snapshot: snapshot, editing: false)
        try await eventually("The level-three room must finish planning.") {
            scene.presentationPhase == "idle" && !scene.diagnostics.bowlPlanning
        }
        XCTAssertNil(scene.view)
        let cat = try XCTUnwrap(scene.childNode(withName: "cat") as? CatActor)
        let cushion = try XCTUnwrap(scene.furnitureWorld.item("floorCushion"))
        XCTAssertNotNil(scene.furnitureWorld.restVisit(to: cushion.id, from: cat.position),
                        "The initial fixture must have a genuinely reachable cushion.")
        scene.restInFurniture(kind: .floorCushion)
        try await eventually("Rest planning must publish an actual furniture visit.") { scene.activeRest != nil }
        XCTAssertEqual(scene.activeRest?.item.id, cushion.id)
        XCTAssertTrue(cat.isPerforming)
        let canonicalWorld = scene.roomPresentation.projection.worldSize
        let position = cat.position
        let placements = scene.furnitureWorld.placements
        let completedLayouts = scene.diagnostics.bowlPlanCompletions

        let resized = CGSize(width: 402, height: 776)
        scene.size = resized
        // Do not yield: the new viewport must be usable before any exit animation or layout worker finishes.
        XCTAssertEqual(scene.roomPresentation.camera.viewportSize, resized)
        XCTAssertEqual(scene.roomPresentation.projection.worldSize, canonicalWorld)
        XCTAssertEqual(scene.furnitureWorld.transform.sceneSize, canonicalWorld)
        XCTAssertEqual(scene.furnitureWorld.placements, placements)
        XCTAssertEqual(cat.position, position)
        XCTAssertEqual(scene.deferredRoomLayoutFromSize, initialSize)
        XCTAssertEqual(scene.diagnostics.bowlPlanCompletions, completedLayouts)
        XCTAssertNotNil(scene.activeRest)
        XCTAssertEqual(scene.presentationPhase, "rest-exit")
        let displayed = scene.roomPresentation.camera.viewPoint(
            projectedWorld: scene.roomPresentation.projection.project(position))
        let restored = scene.roomPresentation.worldPoint(screen: displayed)
        XCTAssertEqual(restored.x, position.x, accuracy: 0.0001)
        XCTAssertEqual(restored.y, position.y, accuracy: 0.0001)
    }

    @MainActor
    func testManualBrowsingDuringCareStaysPutUntilFollowingIsExplicitlyResumed() async throws {
        let scene = RoomScene(size: CGSize(width: 375, height: 436))
        defer { scene.setPresentationActive(false) }
        var snapshot = GameSnapshot.fresh()
        snapshot.home.roomLevel = 3
        scene.apply(snapshot: snapshot, editing: false)
        try await eventually("The level-three room must finish planning.") {
            scene.presentationPhase == "idle" && !scene.diagnostics.bowlPlanning
        }
        let cat = try XCTUnwrap(scene.childNode(withName: "cat") as? CatActor)
        scene.playFeedback(kind: .feed)
        try await eventually("A real care plan must start the actor's feeding action.") {
            cat.isPerforming && scene.presentationPhase == "feeding" && !scene.diagnostics.carePlanning
        }
        XCTAssertNil(scene.view, "Headless actions hold their position while camera behavior is checked.")
        let position = cat.position
        let completedPlans = scene.diagnostics.carePlanCompletions
        let cancelledPlans = scene.diagnostics.carePlanCancelled
        var callbacks = 0
        scene.onCatTapped = { callbacks += 1 }
        scene.onBowlTapped = { callbacks += 1 }
        scene.onBowlMoved = { _ in callbacks += 1 }
        scene.onFurnitureMoved = { _, _ in callbacks += 1 }
        scene.onFurniturePlacementFinished = { _, _ in callbacks += 1 }
        scene.onRestingFurnitureChanged = { _, _, _ in callbacks += 1 }
        scene.onSound = { _ in callbacks += 1 }

        scene.resetCamera()
        let camera = scene.roomPresentation.camera
        XCTAssertLessThan(camera.scale, camera.fitScale)
        let world = scene.roomPresentation.projection.worldSize
        let farPoint = scene.roomPresentation.projection.project(
            CGPoint(x: world.width * 0.95, y: world.height * 0.95))
        camera.focus(on: farPoint)
        scene.suspendRoomFollowing()
        let browsedCenter = camera.center
        let browsedScale = camera.scale
        for _ in 0..<5 { scene.updateRoomPresentation() }
        XCTAssertEqual(camera.center, browsedCenter)
        XCTAssertEqual(camera.scale, browsedScale)
        let target = scene.roomPresentation.projection.project(position)
        let before = hypot(browsedCenter.x - target.x, browsedCenter.y - target.y)

        scene.beginRoomFollowing()
        scene.updateRoomPresentation()
        let after = hypot(camera.center.x - target.x, camera.center.y - target.y)
        XCTAssertLessThan(after, before - 0.001, "Resuming follow must move a previously distant camera toward the cat.")
        XCTAssertEqual(camera.scale, browsedScale)
        XCTAssertEqual(cat.position, position)
        XCTAssertTrue(cat.isPerforming)
        XCTAssertEqual(scene.presentationPhase, "feeding")
        XCTAssertEqual(scene.diagnostics.carePlanCompletions, completedPlans)
        XCTAssertEqual(scene.diagnostics.carePlanCancelled, cancelledPlans)
        XCTAssertEqual(callbacks, 0)
    }

    @MainActor
    private func eventually(_ message: String, condition: @MainActor () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail(message)
        throw RoomViewLifecycleFailure.timedOut
    }
#endif
}

private enum RoomViewLifecycleFailure: Error { case timedOut }
