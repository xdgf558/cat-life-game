import SpriteKit
import UIKit
import XCTest
import CatGameCore
@testable import CatLife

#if DEBUG
@MainActor
final class RoomAmbientBehaviorTests: XCTestCase {
    func testSharedRoomStillStartsDurableAutomaticRestAndRecoversEnergy() async throws {
        let seed = try sharedRoom()
        let repository = AmbientSaveRepository(seed)
        let suite = "com.stationcat.catlife.ambient-tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = GameStore(repository: repository, reminderDefaults: defaults)
        await store.load()
        let scene = RoomScene(size: CGSize(width: 375, height: 436))
        let playback = try AmbientPlayback(scene: scene)
        defer { playback.close() }
        var arrivals = 0
        scene.onRestingFurnitureChanged = { furnitureID, sessionID, catID in
            if furnitureID != nil { arrivals += 1 }
            store.setRestingFurniture(id: furnitureID, sessionID: sessionID, catID: catID)
        }
        scene.apply(snapshot: try XCTUnwrap(store.sceneSnapshot), editing: false)
        try await ready(scene)
        XCTAssertEqual(scene.residents.actors.count, 1)
        XCTAssertFalse(scene.reducedMotion)

        // Exercise the real idle decision, with a deterministic successful roll.
        // Only the cat's animation clock is accelerated; game recovery uses saved time.
        scene.cat.speed = 8
        scene.takeQuietStroll(now: Date().addingTimeInterval(41), restRoll: 0)
        XCTAssertEqual(scene.presentationPhase, "rest-approach")
        XCTAssertFalse(scene.residents.isStrolling, "A housemate must not bypass the autonomous rest branch.")
        try await eventually { store.cat?.activeRest != nil && !store.isBusy }
        XCTAssertEqual(arrivals, 1)
        XCTAssertEqual(scene.presentationPhase, "resting")
        var saved = await repository.snapshot
        let rest = try XCTUnwrap(saved.activeCat?.activeRest)
        XCTAssertEqual(rest.furnitureID, "catBed")
        XCTAssertEqual(saved.activeCatID, seed.activeCatID)
        XCTAssertNil(saved.cats.first { $0.id == CatCatalog.cowCatID }?.activeRest)
        XCTAssertEqual(saved.inventory.food, seed.inventory.food)
        XCTAssertEqual(saved.player.gold, seed.player.gold)

        let energy = try XCTUnwrap(saved.activeCat?.energy)
        XCTAssertTrue(GameEngine.synchronize(&saved, now: rest.endsAt).succeeded)
        XCTAssertGreaterThan(try XCTUnwrap(saved.activeCat?.energy), energy,
                             "The automatic visit must persist an energy-bearing rest, not just a sleeping pose.")
        XCTAssertNil(saved.activeCat?.activeRest)
    }

    func testResidentPreparationBlocksTravelButStrollingKeepsTravelAndNeedsAvailable() async throws {
        var snapshot = try sharedRoom()
        snapshot.home.furniture = []
        let scene = RoomScene(size: CGSize(width: 375, height: 436))
        defer { stop(scene) }
        scene.apply(snapshot: snapshot, editing: false)
        try await ready(scene)
        var travelReady = false
        scene.onFloorTravelAvailabilityChanged = { travelReady = $0 }

        scene.residents.invalidate()
        scene.apply(snapshot: snapshot, editing: false)
        XCTAssertTrue(scene.residents.isPreparing)
        XCTAssertFalse(scene.residents.isStrolling)
        scene.update(0)
        XCTAssertFalse(travelReady)
        XCTAssertFalse(scene.canShowCatNeed)
        try await ready(scene)
        scene.update(1)
        XCTAssertTrue(travelReady)

        scene.takeQuietStroll(restRoll: 1)
        XCTAssertTrue(scene.residents.isStrolling)
        XCTAssertFalse(scene.residents.isPreparing)
        scene.update(2)
        XCTAssertTrue(travelReady)
        XCTAssertTrue(scene.canShowCatNeed)
        try await eventually {
            scene.cat.isPerforming || scene.residents.actors.values.contains { $0.isPerforming }
        }
        // Without an SKView the accepted walk is frozen, whoever was selected.
        scene.update(3)
        XCTAssertTrue(scene.residents.isStrolling)
        XCTAssertTrue(travelReady)
        XCTAssertTrue(scene.canShowCatNeed)

        scene.playFeedback(kind: .feed, catID: snapshot.activeCatID)
        XCTAssertEqual(scene.presentationPhase, "idle")
        XCTAssertFalse(scene.diagnostics.carePlanning, "Care must wait for the moving obstacle to settle.")
        scene.update(4)
        XCTAssertFalse(travelReady, "A committed pending meal, unlike a harmless stroll, must prevent floor travel.")

        XCTAssertTrue(GameEngine.selectCompanion(&snapshot, catID: CatCatalog.cowCatID).succeeded)
        scene.apply(snapshot: snapshot, editing: false)
        try await ready(scene)
        XCTAssertFalse(scene.residents.isStrolling)
        XCTAssertEqual(scene.presentationPhase, "idle")
        XCTAssertFalse(scene.cat.isPerforming)
        XCTAssertFalse(scene.diagnostics.carePlanning)
        XCTAssertEqual(scene.diagnostics.carePlanCompletions, 0,
                       "The previous companion's queued meal must not leak through the cancelled walk.")
    }

    func testPausingPlannedOrStartedStrollRevalidatesResidentsBeforeQueuedMeal() async throws {
        for (waitForStartedWalk, feedAfterPause) in [(false, false), (false, true), (true, false), (true, true)] {
            var snapshot = try sharedRoom()
            snapshot.home.furniture = []
            let scene = RoomScene(size: CGSize(width: 375, height: 436))
            defer { stop(scene) }
            scene.apply(snapshot: snapshot, editing: false)
            try await ready(scene)
            var residentCompletions = 0
            let finish = scene.residents.onFinished
            scene.residents.onFinished = { residentCompletions += 1; finish?() }

            scene.takeQuietStroll(restRoll: 1)
            XCTAssertTrue(scene.residents.isStrolling)
            if waitForStartedWalk {
                try await eventually {
                    scene.cat.isPerforming || scene.residents.actors.values.contains { $0.isPerforming }
                }
            }
            // Cover both worker timing and care committed before/after leaving the room.
            if !feedAfterPause { scene.playFeedback(kind: .feed, catID: snapshot.activeCatID) }
            scene.setPresentationActive(false)
            if feedAfterPause { scene.playFeedback(kind: .feed, catID: snapshot.activeCatID) }
            XCTAssertFalse(scene.residents.isBusy)
            XCTAssertFalse(scene.cat.isPerforming)
            XCTAssertFalse(scene.residents.actors.values.contains { $0.isPerforming })
            for _ in 0..<20 {
                try await Task.sleep(for: .milliseconds(10))
                XCTAssertFalse(scene.residents.isBusy)
                XCTAssertFalse(scene.cat.isPerforming)
                XCTAssertFalse(scene.residents.actors.values.contains { $0.isPerforming })
                XCTAssertFalse(scene.diagnostics.carePlanning)
                XCTAssertEqual(residentCompletions, 0, "Cancelled walks cannot finish behind another page.")
            }

            scene.setPresentationActive(true)
            XCTAssertTrue(scene.residents.isPreparing,
                          "The stopped position must be checked again before it is used as a care obstacle.")
            XCTAssertFalse(scene.diagnostics.carePlanning)
            XCTAssertEqual(scene.diagnostics.carePlanCompletions, 0)
            try await eventually { scene.diagnostics.carePlanCompletions == 1 }
            XCTAssertEqual(residentCompletions, 1)
            XCTAssertFalse(scene.residents.isBusy)
            XCTAssertEqual(scene.presentationPhase, "feeding")
            XCTAssertTrue(scene.cat.isPerforming)
            scene.setPresentationActive(true)
            await Task.yield()
            XCTAssertEqual(scene.diagnostics.carePlanCompletions, 1,
                           "Returning to the same page cannot replay the queued meal.")
        }
    }

    private func sharedRoom() throws -> GameSnapshot {
        var snapshot = GameSnapshot.fresh()
        snapshot.player.level = 8
        snapshot.player.gold = 10_000
        snapshot.home = HomeState(roomLevel: 6)
        XCTAssertTrue(GameEngine.adoptCat(&snapshot, catID: CatCatalog.cowCatID).succeeded)
        snapshot.cats[0].energy = 30
        snapshot.cats[0].satiety = 30
        // One usable rest destination removes furniture selection randomness.
        snapshot.home.furniture.removeAll { $0.itemID == "floorCushion" }
        snapshot.settings.audio = AudioSettings(musicEnabled: false, effectsEnabled: false)
        return snapshot
    }

    private func ready(_ scene: RoomScene) async throws {
        try await eventually {
            !scene.diagnostics.bowlPlanning && scene.diagnostics.bowlPlanCompletions > 0
                && !scene.residents.isBusy && scene.residents.actors.count == 1
        }
    }

    private func eventually(_ condition: @MainActor () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("The shared-room ambient behavior did not reach the expected state.")
        throw AmbientTestError.timedOut
    }

    private func stop(_ scene: RoomScene) {
        scene.setPresentationActive(false)
        scene.residents.invalidate(hide: true)
        scene.cat.cancelAndSettle(at: scene.cat.position)
        scene.removeAllActions()
    }
}

@MainActor
private final class AmbientPlayback {
    private let window: UIWindow
    private let view: SKView
    private let scene: RoomScene

    init(scene: RoomScene) throws {
        self.scene = scene
        let windowScene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        window = UIWindow(windowScene: windowScene)
        window.frame = windowScene.coordinateSpace.bounds
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue + 1)
        let controller = UIViewController()
        controller.view = UIView(frame: window.bounds)
        view = SKView(frame: CGRect(origin: .zero, size: scene.size))
        view.preferredFramesPerSecond = 60
        controller.view.addSubview(view)
        window.rootViewController = controller
        view.presentScene(scene)
        window.isHidden = false
    }

    func close() {
        scene.onRestingFurnitureChanged = nil
        scene.setPresentationActive(false)
        scene.residents.invalidate(hide: true)
        scene.cat.cancelAndSettle(at: scene.cat.position)
        scene.removeAllActions()
        view.presentScene(nil)
        window.isHidden = true
        window.rootViewController = nil
    }
}

private actor AmbientSaveRepository: GameSaveRepository {
    let lastLoadDisposition = SaveLoadDisposition.loaded
    private(set) var snapshot: GameSnapshot
    init(_ snapshot: GameSnapshot) { self.snapshot = snapshot }
    func loadOrCreate(now: Date) -> GameSnapshot { snapshot }
    func save(_ state: GameSnapshot) { snapshot = state }
    func checkWritable() {}
}

private enum AmbientTestError: Error { case timedOut }
#endif
