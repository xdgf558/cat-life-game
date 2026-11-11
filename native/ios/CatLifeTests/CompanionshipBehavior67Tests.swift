import XCTest
import SpriteKit
import UIKit
import CatGameCore
@testable import CatLife

#if DEBUG
final class CompanionshipBehavior67Tests: XCTestCase {
    func testRestKindWeightIsNotDilutedByManyCushionsAndOtherFloorsAreExcluded() throws {
        let items = [FurnitureItem(id: "bed", kind: .catBed)]
            + (0..<20).map { FurnitureItem(id: "c\($0)", kind: .floorCushion) }
            + [FurnitureItem(id: "upstairs", kind: .catBed), FurnitureItem(id: "plant", kind: .plant)]
        let placements = items.map { FurniturePlacement(itemID: $0.id, position: .init(x: 0.5, y: 0.7),
            floor: $0.id == "upstairs" ? .upper : .ground) }
        var beds = 0, cushions = 0
        for sample in 0..<400 {
            let result = try XCTUnwrap(RoomHabitBehavior.restingFurniture(placements: placements, items: items,
                floor: .ground, preference: .bed, cornerID: nil,
                kindRoll: (Double(sample) + 0.5) / 400, instanceRoll: 0.6))
            XCTAssertNotEqual(result.itemID, "upstairs"); XCTAssertNotEqual(result.itemID, "plant")
            if result.itemID == "bed" { beds += 1 } else { cushions += 1 }
        }
        XCTAssertEqual(beds, 300); XCTAssertEqual(cushions, 100)
        XCTAssertNil(RoomHabitBehavior.restingFurniture(placements: [], items: items, floor: .ground,
            preference: .bed, cornerID: nil, kindRoll: 0.2, instanceRoll: 0.2))
        XCTAssertNotNil(RoomHabitBehavior.restingFurniture(placements: placements, items: items, floor: .ground,
            preference: nil, cornerID: nil, kindRoll: 0.2, instanceRoll: 0.2),
            "A retired habit definition must not disable existing autonomous rest.")
    }

    func testNonpreferredCornerMakesKindsEqualAndHasThreeToOneInstanceWeight() throws {
        let items = [FurnitureItem(id: "bed", kind: .catBed), FurnitureItem(id: "a-corner", kind: .floorCushion),
                     FurnitureItem(id: "b-cushion", kind: .floorCushion)]
        let placements = items.map { FurniturePlacement(itemID: $0.id, position: .init(x: 0.5, y: 0.7)) }
        var beds = 0, corner = 0
        for sample in 0..<400 {
            let roll = (Double(sample) + 0.5) / 400
            let kind = try XCTUnwrap(RoomHabitBehavior.restingFurniture(placements: placements, items: items,
                floor: .ground, preference: .bed, cornerID: "a-corner", kindRoll: roll, instanceRoll: 0))
            if kind.itemID == "bed" { beds += 1 }
            let instance = try XCTUnwrap(RoomHabitBehavior.restingFurniture(placements: placements, items: items,
                floor: .ground, preference: .bed, cornerID: "a-corner", kindRoll: 0.9, instanceRoll: roll))
            if instance.itemID == "a-corner" { corner += 1 }
        }
        XCTAssertEqual(beds, 200); XCTAssertEqual(corner, 300)
    }

    @MainActor
    func testOpeningRequiresDiscoveredHabitAndNoUrgentNeedAndDoesNotCreateRecovery() throws {
        var cat = GameSnapshot.fresh().cats[0]
        func request(_ value: CatState, roll: Double = 0) -> RoomHabitOpening? {
            RoomHabitBehavior.openingRequest(cat: value, floor: .ground, roll: roll, kindRoll: 0, instanceRoll: 0)
        }
        XCTAssertNil(request(cat))
        cat.habits.restClueSessionIDs = ["one", "two"]
        cat.satiety = 80
        cat.healthState = CatHealthState(now: Date())
        XCTAssertNotNil(request(cat)); XCTAssertNil(request(cat, roll: 0.5))
        XCTAssertNil(request(cat, roll: .nan)); XCTAssertNil(request(cat, roll: -0.01))
        let changes: [(inout CatState) -> Void] = [
            { $0.satiety = 49 }, { $0.cleanliness = 39 }, { $0.mood = 44 }, { $0.energy = 39 },
            { $0.healthState?.illness = .cold },
            { $0.activeRest = CatRest(furnitureID: "catBed", startedAt: Date(), endsAt: Date().addingTimeInterval(12), energyReward: 18) },
            { $0.id = "retired-habit-cat" }
        ]
        for change in changes {
            var urgent = cat; change(&urgent); XCTAssertNil(request(urgent))
        }
        cat.satiety = 50; cat.cleanliness = 40; cat.mood = 45; cat.energy = 40
        XCTAssertNotNil(request(cat), "Existing need thresholds retain their exact boundaries.")
        let before = cat
        for reduced in [false, true] {
            let scene = RoomScene(size: .init(width: 355, height: 375))
            scene.reducedMotion = reduced
            XCTAssertNotNil(request(cat))
            XCTAssertNil(cat.activeRest); XCTAssertEqual(cat, before)
            scene.setPresentationActive(false)
        }
    }

    @MainActor
    func testFirstSnapshotAddsOpeningWhileTheDefaultPlaceholderIsStillPending() async throws {
        try await assertFirstRealOpening(afterPlaceholderPublication: false, reducedMotion: false)
    }

    @MainActor
    func testFirstSnapshotAddsOpeningAfterTheDefaultPlaceholderHasAlreadyPublished() async throws {
        try await assertFirstRealOpening(afterPlaceholderPublication: true, reducedMotion: true)
    }

    @MainActor
    private func assertFirstRealOpening(afterPlaceholderPublication: Bool, reducedMotion: Bool) async throws {
        var snapshot = GameSnapshot.fresh()
        snapshot.cats[0].satiety = 80
        snapshot.cats[0].habits.restClueSessionIDs = ["first", "second"]
        let scene = RoomScene(size: .init(width: 355, height: 375))
        defer { scene.setPresentationActive(false) }
        scene.openingRollForTesting = 0
        scene.reducedMotion = reducedMotion
        scene.setReferenceViewportSize(scene.size)
        if afterPlaceholderPublication { try await settled(scene) }
        else { XCTAssertEqual(scene.diagnostics.bowlPlanCompletions, 0) }
        let placeholderCompletions = scene.diagnostics.bowlPlanCompletions
        scene.apply(snapshot: snapshot, editing: false)
        let cancellationCount = scene.diagnostics.bowlPlanCancelled
        scene.apply(snapshot: snapshot, editing: false)
        XCTAssertEqual(scene.diagnostics.bowlPlanCancelled, cancellationCount,
                       "Repeating the first snapshot must reuse its matching pending proposal.")
        try await settled(scene)
        XCTAssertEqual(scene.diagnostics.bowlPlanCompletions, placeholderCompletions + 1)
        let world = scene.furnitureWorld
        let origin = CGPoint(x: world.transform.sceneSize.width * 0.43, y: world.transform.sceneSize.height * 0.18)
        let original = try XCTUnwrap(RoomBowlPlanner(floor: world.roomFloor, requested: world.bowlPosition,
                                                    catPosition: origin).resolve())
        let request = try XCTUnwrap(RoomHabitBehavior.openingRequest(cat: snapshot.cats[0], floor: .ground,
            roll: 0, kindRoll: 0, instanceRoll: 0))
        let expected = try XCTUnwrap(RoomHabitBehavior.openingPoint(request, world: world,
            origin: try XCTUnwrap(original.catPosition), navigation: original.navigation))
        // SKNode quantizes coordinates to Float; 0.0001 world points remains far below one pixel.
        XCTAssertEqual(scene.cat.position.x, expected.x, accuracy: 0.0001)
        XCTAssertEqual(scene.cat.position.y, expected.y, accuracy: 0.0001)
        XCTAssertGreaterThan(hypot(scene.cat.position.x - origin.x, scene.cat.position.y - origin.y), 1,
                             "A healthy confirmed level-one cat must actually use the entry position.")
        XCTAssertNil(scene.activeRest)
        XCTAssertEqual(scene.reducedMotion, reducedMotion)
        let position = scene.cat.position
        scene.apply(snapshot: snapshot, editing: false)
        try await Task.sleep(for: .milliseconds(40))
        XCTAssertFalse(scene.diagnostics.bowlPlanning)
        XCTAssertEqual(scene.diagnostics.bowlPlanCompletions, placeholderCompletions + 1)
        XCTAssertEqual(scene.cat.position, position, "Initial positioning is consumed only once per real scene entry.")
    }

    @MainActor
    private func settled(_ scene: RoomScene) async throws {
        let deadline = Date().addingTimeInterval(10)
        while scene.diagnostics.bowlPlanning, Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(scene.diagnostics.bowlPlanning)
        XCTAssertEqual(scene.presentationPhase, "idle")
    }

    func testOpeningPointIsLegalAndConnectedAcrossEveryLevelFloorAndBothScreenSizes() throws {
        var cat = GameSnapshot.fresh().cats[0]
        cat.habits.restClueSessionIDs = ["one", "two"]
        cat.satiety = 80
        cat.healthState = CatHealthState(now: Date())
        for viewport in [CGSize(width: 355, height: 375), CGSize(width: 382, height: 560)] {
            for room in HomeCatalog.all {
                for floor in room.floors {
                    let opening = try XCTUnwrap(RoomHabitBehavior.openingRequest(cat: cat, floor: floor,
                        roll: 0, kindRoll: 0, instanceRoll: 0))
                    let placements = FurnitureCatalog.defaultPlacements.map {
                        FurniturePlacement(itemID: $0.itemID, position: $0.position, floor: floor)
                    }
                    let proposal = RoomLayoutProposal(viewport: viewport, roomLevel: room.level,
                        artworkSize: .init(width: 1024, height: 1536), bowlAspect: 0.83,
                        items: FurnitureCatalog.defaultItems, placements: placements, bowl: .init(x: 0.76, y: 0.79),
                        previousCat: nil, previousWorld: viewport, opening: opening)
                    let result = try XCTUnwrap(proposal.resolve())
                    let point = try XCTUnwrap(result.openingPosition, "level \(room.level), \(floor), \(viewport)")
                    XCTAssertTrue(result.navigation.isWalkable(point))
                    XCTAssertNotNil(proposal.planner.floor.feedingPlan(from: point, bowlAt: result.center,
                        navigator: result.navigation, firstReachable: true))
                    let world = RoomFurnitureWorld(transform: .init(sceneSize: proposal.geometry.worldSize,
                        artworkSize: proposal.artworkSize, viewportSize: viewport), catWidth: proposal.catWidth,
                        bowlSize: proposal.bowlSize, bowlPosition: result.center, items: proposal.items, placements: proposal.placements)
                    for id in ["catBed", "floorCushion"] { XCTAssertNotNil(world.restVisit(to: id, from: point)) }
                    if room.level == 8 {
                        let planner = RoomResidentPlanner(floor: world.roomFloor, bowl: result.center, world: world,
                            active: point, catWidth: proposal.catWidth)
                        let otherCats = planner.positions(count: 4)
                        XCTAssertEqual(otherCats.count, 4)
                        XCTAssertTrue(otherCats.allSatisfy { hypot($0.x - point.x, $0.y - point.y) >= proposal.catWidth * 0.95 })
                    }
                    let empty = RoomFurnitureWorld(transform: world.transform, catWidth: world.catWidth,
                        bowlSize: world.bowlSize, bowlPosition: world.bowlPosition, items: [], placements: [])
                    XCTAssertNil(RoomHabitBehavior.openingPoint(opening, world: empty, origin: point, navigation: result.navigation))
                }
            }
        }
    }

    @MainActor
    func testFirstVisitStylesStayOnTheSameRouteAndAddLessThanHalfASecond() throws {
        func actor(style: CatBehaviorStyle?) -> CatActor {
            let actor = CatActor(); actor.setIdleEnabled(false); actor.position = .zero
            actor.rest(approach: [.zero, .init(x: 80, y: 0)], entry: [.init(x: 80, y: 0), .init(x: 80, y: 12)],
                facing: 1, duration: 9, elevation: 8, introductionStyle: style, onSettled: {}, completion: {})
            return actor
        }
        let baseline = actor(style: nil)
        let duration = try XCTUnwrap(baseline.action(forKey: "activity")).duration
        for style in CatBehaviorStyle.allCases {
            let first = actor(style: style)
            XCTAssertEqual(first.position, .zero)
            XCTAssertEqual(first.lastRestIntroductionStyle, style)
            XCTAssertEqual(first.restPhase, .approaching)
            XCTAssertLessThanOrEqual(abs(try XCTUnwrap(first.action(forKey: "activity")).duration - duration), 0.5)
            first.cancelAndSettle(at: first.position)
        }
        baseline.cancelAndSettle(at: baseline.position)
    }

    @MainActor
    func testTwoConfirmedResponseEndingsUseRealSpriteFramesAndRemainAvailableWithReducedMotion() async throws {
        for appearance: CatAppearance in [.orange, .cow] {
            for reduced in [false, true] {
                let scene = CatPlayTogetherScene(appearance: appearance)
                let playback = try CompanionPlayback67(scene: scene)
                defer { playback.close() }
                scene.reducedMotion = reduced; scene.actor.speed = 4
                var satisfied = 0
                scene.onMotion = { if $0 == "satisfied" { satisfied += 1 } }
                for index in [0, 1] {
                    let previous = satisfied
                    scene.completeResponse(finishIndex: index)
                    XCTAssertTrue(scene.isResponding)
                    XCTAssertEqual(scene.actor.lastResponseFinishIndex, index)
                    let deadline = Date().addingTimeInterval(8)
                    while satisfied == previous, Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
                    XCTAssertEqual(satisfied, previous + 1)
                    XCTAssertFalse(scene.isResponding)
                    XCTAssertEqual(scene.responseFinishIndex, index)
                    XCTAssertTrue(CGRect(origin: .zero, size: scene.size).insetBy(dx: -2, dy: -2).contains(scene.actor.visualFrame))
                }
                XCTAssertEqual(scene.pounces, 2)
                if !reduced { XCTAssertEqual(scene.actor.completedPounces, 2) }
            }
        }
    }
}

@MainActor
private final class CompanionPlayback67 {
    private let window: UIWindow
    private let view: SKView
    private let scene: CatPlayTogetherScene
    init(scene: CatPlayTogetherScene) throws {
        self.scene = scene
        let windowScene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        window = UIWindow(windowScene: windowScene); window.frame = windowScene.coordinateSpace.bounds
        window.windowLevel = .alert + 1
        let controller = UIViewController(); controller.view = UIView(frame: window.bounds)
        view = SKView(frame: CGRect(x: 0, y: 0, width: 350, height: 280)); controller.view.addSubview(view)
        window.rootViewController = controller; view.presentScene(scene); window.isHidden = false
    }
    func close() {
        scene.stop(); view.presentScene(nil); window.isHidden = true; window.rootViewController = nil
    }
}

#endif
