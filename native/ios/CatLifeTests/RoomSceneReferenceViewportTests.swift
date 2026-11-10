import XCTest
import SpriteKit
import CatGameCore
@testable import CatLife

@MainActor
final class RoomSceneReferenceViewportTests: XCTestCase {
#if DEBUG
    func testEditingViewportsAndTrayRectsKeepTheSamePhysicalRoomWithoutReplanning() async throws {
        for (reference, canvas) in [(CGSize(width: 355, height: 375), CGSize(width: 375, height: 539)),
                                    (CGSize(width: 382, height: 560), CGSize(width: 402, height: 712))] {
            for level in [1, 8] {
                var snapshot = GameSnapshot.fresh()
                snapshot.home = HomeState(roomLevel: level)
                let scene = RoomScene(size: reference)
                defer { scene.setPresentationActive(false) }
                scene.setReferenceViewportSize(reference)
                scene.apply(snapshot: snapshot, editing: false)
                try await waitForLayout(scene)
                scene.setRoomViewUsableRect(RoomStageLayout.usableRect(in: reference))
                let world = scene.furnitureWorld.transform.sceneSize
                let placements = scene.furnitureWorld.placements
                let nodes = scene.furnitureNodes.mapValues { ($0.position, $0.size) }
                let catPoint = scene.cat.position
                let catWidth = scene.furnitureWorld.catWidth
                let bowlPoint = scene.bowl.position, bowlSize = scene.bowl.size
                let front = try XCTUnwrap(scene.roomPresentation.projection.frontFloor).destination
                let completed = scene.diagnostics.bowlPlanCompletions
                let cancelled = scene.diagnostics.bowlPlanCancelled

                scene.apply(snapshot: snapshot, editing: true)
                scene.size = canvas
                for inset: CGFloat in [320, 170, 320] {
                    scene.setReferenceViewportSize(reference)
                    scene.setRoomViewUsableRect(RoomStageLayout.arrangementUsableRect(in: canvas, bottomInset: inset))
                    scene.apply(snapshot: snapshot, editing: true)
                    XCTAssertFalse(scene.diagnostics.bowlPlanning)
                    XCTAssertEqual(scene.diagnostics.bowlPlanCompletions, completed)
                    XCTAssertEqual(scene.diagnostics.bowlPlanCancelled, cancelled)
                    XCTAssertEqual(scene.furnitureWorld.transform.sceneSize, world)
                    XCTAssertEqual(scene.furnitureWorld.transform.viewportSize, reference)
                    XCTAssertEqual(scene.furnitureWorld.placements, placements)
                    XCTAssertEqual(scene.cat.position, catPoint)
                    XCTAssertEqual(scene.furnitureWorld.catWidth, catWidth)
                    XCTAssertEqual(scene.bowl.position, bowlPoint)
                    XCTAssertEqual(scene.bowl.size, bowlSize)
                    XCTAssertEqual(scene.roomPresentation.projection.frontFloor?.destination, front)
                    XCTAssertEqual(scene.roomPresentation.camera.viewportSize, canvas)
                    for (id, original) in nodes {
                        XCTAssertEqual(scene.furnitureNodes[id]?.position, original.0)
                        XCTAssertEqual(scene.furnitureNodes[id]?.size, original.1)
                    }
                }
                scene.apply(snapshot: snapshot, editing: false)
                scene.size = reference
                scene.setRoomViewUsableRect(RoomStageLayout.usableRect(in: reference))
                XCTAssertFalse(scene.diagnostics.bowlPlanning)
                XCTAssertEqual(scene.diagnostics.bowlPlanCompletions, completed)
                XCTAssertEqual(scene.diagnostics.bowlPlanCancelled, cancelled)
                XCTAssertEqual(scene.roomPresentation.projection.frontFloor?.destination, front)
                XCTAssertEqual(scene.furnitureWorld.transform.sceneSize, world)
                XCTAssertEqual(scene.furnitureWorld.placements, placements)
            }
        }
    }

    func testActualReferenceResizeRebuildsFromCommittedWorldWhileInvalidReferencesAreIgnored() async throws {
        let reference = CGSize(width: 355, height: 375), canvas = CGSize(width: 402, height: 712)
        let scene = RoomScene(size: reference)
        defer { scene.setPresentationActive(false) }
        scene.setReferenceViewportSize(reference)
        var snapshot = GameSnapshot.fresh()
        snapshot.home = HomeState(roomLevel: 3)
        scene.apply(snapshot: snapshot, editing: false)
        try await waitForLayout(scene)
        scene.size = canvas
        let oldWorld = scene.furnitureWorld.transform.sceneSize
        let oldCat = scene.cat.position
        let completed = scene.diagnostics.bowlPlanCompletions
        for invalid in [CGSize.zero, CGSize(width: CGFloat.nan, height: 500), CGSize(width: 400, height: CGFloat.infinity)] {
            scene.setReferenceViewportSize(invalid)
            XCTAssertFalse(scene.diagnostics.bowlPlanning)
            XCTAssertEqual(scene.furnitureWorld.transform.sceneSize, oldWorld)
        }
        let next = CGSize(width: 382, height: 560)
        scene.setReferenceViewportSize(next)
        XCTAssertTrue(scene.diagnostics.bowlPlanning)
        XCTAssertEqual(scene.furnitureWorld.transform.sceneSize, oldWorld)
        XCTAssertEqual(scene.cat.position, oldCat)
        XCTAssertFalse(scene.cat.isHidden)
        XCTAssertEqual(scene.diagnostics.bowlPlanCompletions, completed)
        try await waitForLayout(scene)
        XCTAssertEqual(scene.diagnostics.bowlPlanCompletions, completed + 1)
        XCTAssertEqual(scene.furnitureWorld.transform.viewportSize, next)
        XCTAssertEqual(scene.furnitureWorld.transform.sceneSize, CGSize(width: next.width * 1.5, height: next.height * 1.5))
        XCTAssertEqual(scene.roomPresentation.camera.viewportSize, canvas)
        XCTAssertEqual(scene.furnitureWorld.placements, snapshot.home.furniture)
        XCTAssertEqual(scene.furnitureWorld.catWidth, min(next.width * 0.14, next.height * 0.172), accuracy: 0.000001)
        let floor = scene.furnitureWorld.roomFloor
        let navigation = floor.navigator(bowlAt: scene.bowl.position)
        XCTAssertTrue(navigation.isWalkable(scene.cat.position))
        XCTAssertNotNil(floor.feedingPlan(from: scene.cat.position, bowlAt: scene.bowl.position, navigator: navigation))
    }

    func testActualReferenceResizeKeepsTheOccupiedRestWorldUntilItsSafeExit() async throws {
        let reference = CGSize(width: 375, height: 569)
        let scene = RoomScene(size: reference)
        defer { scene.setPresentationActive(false) }
        scene.setReferenceViewportSize(reference)
        var snapshot = GameSnapshot.fresh()
        snapshot.home = HomeState(roomLevel: 3)
        scene.apply(snapshot: snapshot, editing: false)
        try await waitForLayout(scene)
        scene.restInFurniture(kind: .floorCushion)
        let deadline = Date().addingTimeInterval(15)
        while scene.activeRest == nil, Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertNotNil(scene.activeRest)
        let world = scene.furnitureWorld.transform.sceneSize
        let placements = scene.furnitureWorld.placements
        let catPoint = scene.cat.position
        let completed = scene.diagnostics.bowlPlanCompletions
        scene.setReferenceViewportSize(CGSize(width: 402, height: 776))
        XCTAssertEqual(scene.deferredRoomLayoutFromSize, reference)
        XCTAssertEqual(scene.presentationPhase, "rest-exit")
        XCTAssertNotNil(scene.activeRest)
        XCTAssertEqual(scene.furnitureWorld.transform.sceneSize, world)
        XCTAssertEqual(scene.furnitureWorld.placements, placements)
        XCTAssertEqual(scene.cat.position, catPoint)
        XCTAssertEqual(scene.diagnostics.bowlPlanCompletions, completed)
        XCTAssertFalse(scene.diagnostics.bowlPlanning)
    }

    private func waitForLayout(_ scene: RoomScene) async throws {
        let deadline = Date().addingTimeInterval(15)
        while scene.diagnostics.bowlPlanning, Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(scene.diagnostics.bowlPlanning)
        XCTAssertEqual(scene.presentationPhase, "idle")
    }
#endif
}
