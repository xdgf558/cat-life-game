import Foundation
import XCTest
import CatGameCore
@testable import CatLife

final class CatCompanionSceneTests: XCTestCase {
#if DEBUG
    @MainActor
    func testColdCowCompanionKeepsInitialLayoutAndRejectsPreviousCatsFeedback() async throws {
        // Level 1 exercises identity initialization without an expansion rebuild
        // hiding the phase regression; level 2 is the normal adoption flow.
        for roomLevel in [1, 2] {
            var snapshot = GameSnapshot.fresh()
            snapshot.player.level = 2
            snapshot.player.gold = 1_000
            snapshot.home.roomLevel = 2
            XCTAssertTrue(GameEngine.adoptCat(&snapshot, catID: CatCatalog.cowCatID).succeeded)
            XCTAssertTrue(GameEngine.selectCompanion(&snapshot, catID: CatCatalog.cowCatID).succeeded)
            snapshot.home.roomLevel = roomLevel

            let scene = RoomScene(size: CGSize(width: 375, height: 436))
            defer { scene.setPresentationActive(false) }
            XCTAssertEqual(scene.presentationPhase, "layout-planning")
            // No MainActor yield: the constructor's worker cannot publish yet.
            scene.apply(snapshot: snapshot, editing: false)
            XCTAssertEqual(scene.presentationPhase, "layout-planning", "room level \(roomLevel)")
            XCTAssertTrue(scene.diagnostics.bowlPlanning)
            XCTAssertEqual(scene.diagnostics.bowlPlanCompletions, 0)
            try await eventually {
                scene.diagnostics.bowlPlanCompletions > 0 && !scene.diagnostics.bowlPlanning
            }
            XCTAssertEqual(scene.presentationPhase, "idle")
            let cat = try XCTUnwrap(scene.childNode(withName: "cat") as? CatActor)
            XCTAssertFalse(cat.isPerforming)

            scene.playFeedback(kind: .feed, catID: CatCatalog.initialCatID)
            XCTAssertEqual(scene.presentationPhase, "idle")
            XCTAssertFalse(scene.diagnostics.carePlanning)
            XCTAssertEqual(scene.diagnostics.carePlanCompletions, 0)
            scene.playFeedback(kind: .feed, catID: CatCatalog.cowCatID)
            XCTAssertEqual(scene.presentationPhase, "feeding")
            XCTAssertTrue(scene.diagnostics.carePlanning)
            try await eventually { scene.diagnostics.carePlanCompletions == 1 }
            // There is no SKView, so a frame cannot finish feeding before the
            // companion switch tests cancellation of the live actor action.
            XCTAssertTrue(cat.isPerforming)
            XCTAssertEqual(scene.presentationPhase, "feeding")
            let bowlCompletions = scene.diagnostics.bowlPlanCompletions

            XCTAssertTrue(GameEngine.selectCompanion(&snapshot, catID: CatCatalog.initialCatID).succeeded)
            scene.apply(snapshot: snapshot, editing: false)
            XCTAssertEqual(scene.presentationPhase, "idle")
            XCTAssertFalse(cat.isPerforming)
            XCTAssertFalse(scene.diagnostics.carePlanning)
            XCTAssertEqual(scene.diagnostics.bowlPlanCompletions, bowlCompletions)
            scene.playFeedback(kind: .feed, catID: CatCatalog.cowCatID)
            scene.playFeedback(kind: .play, catID: CatCatalog.cowCatID)
            await Task.yield()
            XCTAssertEqual(scene.presentationPhase, "idle")
            XCTAssertFalse(cat.isPerforming)
            XCTAssertFalse(scene.diagnostics.carePlanning)
            XCTAssertEqual(scene.diagnostics.carePlanCompletions, 1)

            scene.playFeedback(kind: .clean, catID: CatCatalog.initialCatID)
            XCTAssertEqual(scene.presentationPhase, "cleaning")
            XCTAssertTrue(cat.isPerforming)
        }
    }

    @MainActor
    private func eventually(_ condition: @MainActor () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("The companion scene's background planner did not settle.")
        throw CompanionSceneTestFailure.timedOut
    }
#endif
}

private enum CompanionSceneTestFailure: Error { case timedOut }
