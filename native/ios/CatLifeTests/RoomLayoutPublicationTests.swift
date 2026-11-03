import Foundation
import SpriteKit
import XCTest
import CatGameCore
@testable import CatLife

final class RoomLayoutPublicationTests: XCTestCase {
#if DEBUG
    @MainActor
    func testUpgradesKeepCompleteSafeWorldVisibleUntilLatestLayoutCommits() async throws {
        for viewport in [CGSize(width: 375, height: 436), CGSize(width: 402, height: 567)] {
            var snapshot = GameSnapshot.fresh()
            let scene = RoomScene(size: viewport)
            defer { scene.setPresentationActive(false) }
            scene.apply(snapshot: snapshot, editing: false)
            try await eventually { !scene.diagnostics.bowlPlanning }
            let cat = try XCTUnwrap(scene.childNode(withName: "cat") as? CatActor)
            let bowl = try XCTUnwrap(scene.childNode(withName: "bowl") as? SKSpriteNode)
            let bed = try XCTUnwrap(scene.childNode(withName: "furniture-catBed") as? SKSpriteNode)
            let oldCat = cat.position
            let oldBowl = bowl.position
            let oldBed = bed.position
            let oldBowlSize = bowl.size
            let oldCatWidth = scene.furnitureWorld.catWidth
            let completions = scene.diagnostics.bowlPlanCompletions
            snapshot.home.roomLevel = 2
            scene.apply(snapshot: snapshot, editing: false)
            // No actor yield: a background result cannot publish before these assertions.
            XCTAssertTrue(scene.diagnostics.bowlPlanning)
            XCTAssertFalse(cat.isHidden)
            XCTAssertFalse(bowl.isHidden)
            XCTAssertEqual(cat.position, oldCat)
            XCTAssertEqual(bowl.position, oldBowl)
            XCTAssertEqual(bed.position, oldBed)
            XCTAssertEqual(scene.furnitureWorld.transform.sceneSize.width / scene.size.width, 1)
            XCTAssertEqual(scene.presentationPhase, "layout-planning")
            XCTAssertFalse(scene.canZoomCamera)
            XCTAssertFalse(cat.isPerforming)

            // Supersede an upgrade before its completion can enter the main actor.
            snapshot.home.roomLevel = 3
            scene.apply(snapshot: snapshot, editing: false)
            XCTAssertFalse(cat.isHidden)
            XCTAssertFalse(bowl.isHidden)
            XCTAssertEqual(bed.position, oldBed)
            try await eventually { !scene.diagnostics.bowlPlanning }
            XCTAssertEqual(scene.diagnostics.bowlPlanCompletions, completions + 1)
            XCTAssertEqual(scene.furnitureWorld.transform.sceneSize.width / scene.size.width, 1.5)
            XCTAssertEqual(bowl.size, oldBowlSize)
            XCTAssertEqual(scene.furnitureWorld.catWidth, oldCatWidth)
            XCTAssertNotEqual(bed.position, oldBed)
            XCTAssertEqual(scene.presentationPhase, "idle")
            XCTAssertTrue(scene.canZoomCamera)
            XCTAssertFalse(cat.isHidden)
            XCTAssertFalse(bowl.isHidden)
            let floor = scene.furnitureWorld.roomFloor
            let navigation = floor.navigator(bowlAt: bowl.position)
            XCTAssertTrue(navigation.isWalkable(cat.position))
            XCTAssertNotNil(floor.feedingPlan(from: cat.position, bowlAt: bowl.position, navigator: navigation))
            XCTAssertFalse(scene.diagnostics.lastBowlPlanOnMainThread)
        }
    }

    @MainActor
    func testBackgroundedUpgradeRetainsOldWorldAndResumesOnlyLatestRequest() async throws {
        var snapshot = GameSnapshot.fresh()
        let scene = RoomScene(size: CGSize(width: 375, height: 436))
        defer { scene.setPresentationActive(false) }
        scene.apply(snapshot: snapshot, editing: false)
        try await eventually { !scene.diagnostics.bowlPlanning }
        let cat = try XCTUnwrap(scene.childNode(withName: "cat"))
        let bowl = try XCTUnwrap(scene.childNode(withName: "bowl"))
        let oldCat = cat.position
        let oldBowl = bowl.position
        let completions = scene.diagnostics.bowlPlanCompletions
        snapshot.home.roomLevel = 2
        scene.apply(snapshot: snapshot, editing: false)
        scene.setPresentationActive(false)
        await Task.yield()
        XCTAssertTrue(scene.diagnostics.bowlPlanning)
        XCTAssertEqual(scene.diagnostics.bowlPlanCompletions, completions)
        XCTAssertEqual(cat.position, oldCat)
        XCTAssertEqual(bowl.position, oldBowl)
        XCTAssertFalse(cat.isHidden)
        XCTAssertFalse(bowl.isHidden)
        XCTAssertEqual(scene.furnitureWorld.transform.sceneSize.width / scene.size.width, 1)
        scene.setPresentationActive(true)
        try await eventually { !scene.diagnostics.bowlPlanning }
        XCTAssertEqual(scene.diagnostics.bowlPlanCompletions, completions + 1)
        XCTAssertEqual(scene.furnitureWorld.transform.sceneSize.width / scene.size.width, 1.25)
        XCTAssertFalse(cat.isHidden)
        XCTAssertFalse(bowl.isHidden)
    }

    @MainActor
    func testFurnitureRebuildKeepsOldObstaclePositionUntilCatHasSafeReplacement() async throws {
        var snapshot = GameSnapshot.fresh()
        let scene = RoomScene(size: CGSize(width: 375, height: 436))
        defer { scene.setPresentationActive(false) }
        scene.apply(snapshot: snapshot, editing: false)
        try await eventually { !scene.diagnostics.bowlPlanning }
        let cat = try XCTUnwrap(scene.childNode(withName: "cat"))
        let bowl = try XCTUnwrap(scene.childNode(withName: "bowl"))
        let plant = try XCTUnwrap(scene.childNode(withName: "furniture-plantSmall"))
        let oldPlant = plant.position
        let oldCat = cat.position
        let index = try XCTUnwrap(snapshot.home.furniture.firstIndex { $0.itemID == "plantSmall" })
        snapshot.home.furniture[index].position = scene.furnitureWorld.transform.normalized(oldCat)
        scene.apply(snapshot: snapshot, editing: false)
        XCTAssertEqual(plant.position, oldPlant)
        XCTAssertEqual(cat.position, oldCat)
        XCTAssertFalse(cat.isHidden)
        XCTAssertFalse(bowl.isHidden)
        XCTAssertTrue(scene.diagnostics.bowlPlanning)
        try await eventually { !scene.diagnostics.bowlPlanning }
        XCTAssertNotEqual(plant.position, oldPlant)
        XCTAssertNotEqual(cat.position, oldCat)
        XCTAssertTrue(scene.furnitureWorld.roomFloor.navigator(bowlAt: bowl.position).isWalkable(cat.position))
        XCTAssertFalse(cat.isHidden)
        XCTAssertFalse(bowl.isHidden)
    }

    @MainActor
    func testUpgradeWaitsForAnAlreadyCommittedMealInsteadOfCancellingIt() async throws {
        var snapshot = GameSnapshot.fresh()
        let scene = RoomScene(size: CGSize(width: 375, height: 436))
        defer { scene.setPresentationActive(false) }
        scene.apply(snapshot: snapshot, editing: false)
        try await eventually { !scene.diagnostics.bowlPlanning }
        let cat = try XCTUnwrap(scene.childNode(withName: "cat") as? CatActor)
        scene.playFeedback(kind: .feed)
        try await eventually { !scene.diagnostics.carePlanning }
        XCTAssertTrue(cat.isPerforming)
        XCTAssertEqual(scene.presentationPhase, "feeding")
        let completedLayouts = scene.diagnostics.bowlPlanCompletions
        snapshot.home.roomLevel = 2
        scene.apply(snapshot: snapshot, editing: false)
        XCTAssertEqual(scene.presentationPhase, "feeding")
        XCTAssertTrue(cat.isPerforming)
        XCTAssertFalse(scene.diagnostics.bowlPlanning)
        XCTAssertEqual(scene.diagnostics.bowlPlanCompletions, completedLayouts)
        XCTAssertEqual(scene.furnitureWorld.transform.sceneSize.width / scene.size.width, 1)
    }

    @MainActor
    func testConsecutiveResizesMapFromLastVisibleWorldRatherThanUnpublishedSize() async throws {
        let first = RoomScene(size: CGSize(width: 375, height: 436))
        let direct = RoomScene(size: CGSize(width: 375, height: 436))
        defer { first.setPresentationActive(false); direct.setPresentationActive(false) }
        first.apply(snapshot: .fresh(), editing: false)
        direct.apply(snapshot: .fresh(), editing: false)
        try await eventually { !first.diagnostics.bowlPlanning && !direct.diagnostics.bowlPlanning }
        let firstCat = try XCTUnwrap(first.childNode(withName: "cat"))
        let directCat = try XCTUnwrap(direct.childNode(withName: "cat"))
        let oldCat = firstCat.position
        first.size = CGSize(width: 390, height: 480)
        first.size = CGSize(width: 402, height: 567)
        direct.size = first.size
        XCTAssertEqual(firstCat.position, oldCat)
        XCTAssertFalse(firstCat.isHidden)
        try await eventually { !first.diagnostics.bowlPlanning && !direct.diagnostics.bowlPlanning }
        XCTAssertEqual(firstCat.position, directCat.position)
        XCTAssertEqual(first.childNode(withName: "bowl")?.position, direct.childNode(withName: "bowl")?.position)
    }

    @MainActor
    func testCompanionSwitchDuringUpgradeDropsOldQueuedCareAndKeepsNewOwnerVisible() async throws {
        var snapshot = GameSnapshot.fresh()
        snapshot.player.level = 2
        snapshot.player.gold = 1_000
        let scene = RoomScene(size: CGSize(width: 375, height: 436))
        defer { scene.setPresentationActive(false) }
        scene.apply(snapshot: snapshot, editing: false)
        try await eventually { !scene.diagnostics.bowlPlanning }
        let cat = try XCTUnwrap(scene.childNode(withName: "cat") as? CatActor)
        let oldPosition = cat.position
        snapshot.home.roomLevel = 2
        XCTAssertTrue(GameEngine.adoptCat(&snapshot, catID: CatCatalog.cowCatID).succeeded)
        scene.apply(snapshot: snapshot, editing: false)
        scene.playFeedback(kind: .feed, catID: CatCatalog.initialCatID)
        XCTAssertTrue(GameEngine.selectCompanion(&snapshot, catID: CatCatalog.cowCatID).succeeded)
        scene.apply(snapshot: snapshot, editing: false)
        XCTAssertEqual(scene.presentationPhase, "layout-planning")
        XCTAssertEqual(cat.position, oldPosition)
        XCTAssertFalse(cat.isHidden)
        scene.playFeedback(kind: .clean, catID: CatCatalog.cowCatID)
        try await eventually { !scene.diagnostics.bowlPlanning }
        XCTAssertEqual(scene.presentationPhase, "cleaning")
        XCTAssertTrue(cat.isPerforming)
        XCTAssertFalse(cat.isHidden)
        XCTAssertEqual(scene.diagnostics.carePlanCompletions, 0, "Old cat's queued feed must not start after switching.")
    }

    @MainActor
    private func eventually(_ condition: @MainActor () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("The scene did not publish its current layout proposal.")
        throw LayoutPublicationFailure.timedOut
    }
#endif
}

private enum LayoutPublicationFailure: Error { case timedOut }
