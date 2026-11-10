import Foundation
import SpriteKit
import XCTest
import CatGameCore
@testable import CatLife

@MainActor
final class RoomResidentCatsTests: XCTestCase {
    func testCompanionMarkerFollowsWithoutChangingTheCatsNavigationFootprintAndHonorsReducedMotion() {
        let scene = SKScene(size: CGSize(width: 390, height: 500))
        let artwork = RoomSceneArtwork(); artwork.install(in: scene)
        let cat = CatActor(); scene.addChild(cat); cat.setVisualWidth(80)
        cat.cancelAndSettle(at: CGPoint(x: 160, y: 120))
        let frame = cat.visualFrame
        artwork.updateCompanionMarker(cat: cat, name: "小橘", hidden: false, reducedMotion: false)
        XCTAssertEqual(cat.visualFrame, frame, "Decorations must not become part of hit testing or navigation geometry.")
        let ring = scene.childNode(withName: "companion-ring")
        XCTAssertEqual(ring?.position, cat.position); XCTAssertNotNil(ring?.action(forKey: "breathe"))
        cat.position = CGPoint(x: 200, y: 180)
        artwork.updateCompanionMarker(cat: cat, name: "小橘", hidden: false, reducedMotion: true)
        XCTAssertEqual(ring?.position, cat.position); XCTAssertNil(ring?.action(forKey: "breathe"))
        artwork.updateCompanionMarker(cat: cat, name: "小橘", hidden: true, reducedMotion: true)
        XCTAssertEqual(ring?.isHidden, true); XCTAssertEqual(scene.childNode(withName: "companion-name")?.isHidden, true)
    }
    func testHouseLevelFourUnlocksEveryOwnedCatWithoutDuplicatingTheCompanion() async throws {
        var snapshot = try fiveCats()
        let residents = RoomResidentCats()
        defer { residents.invalidate(hide: true) }
        let downstairs = try fixture(roomLevel: 3)
        let scene = SKScene(size: downstairs.world.transform.sceneSize)

        prepare(residents, snapshot: snapshot, scene: scene, fixture: downstairs)
        XCTAssertFalse(residents.isBusy)
        XCTAssertTrue(residents.actors.isEmpty)
        XCTAssertTrue(scene.children.isEmpty)

        snapshot.home.roomLevel = 4
        let expanded = try fixture(roomLevel: 4)
        scene.size = expanded.world.transform.sceneSize
        prepare(residents, snapshot: snapshot, scene: scene, fixture: expanded)
        try await waitUntilReady(residents)
        assertResidents(residents, snapshot: snapshot, scene: scene)
        XCTAssertEqual(residents.actors.count, 4)
        XCTAssertEqual(Set(residents.actors.keys).union([snapshot.activeCatID]), Set(snapshot.cats.map(\.id)))
    }

    func testRepeatedPreparationKeepsPositionsAndDoesNotAddNodes() async throws {
        var snapshot = try fiveCats()
        snapshot.home.roomLevel = 4
        let value = try fixture(roomLevel: 4)
        let scene = SKScene(size: value.world.transform.sceneSize)
        let residents = RoomResidentCats()
        defer { residents.invalidate(hide: true) }
        prepare(residents, snapshot: snapshot, scene: scene, fixture: value)
        try await waitUntilReady(residents)
        let positions = residents.actors.mapValues(\.position)
        let identities = residents.actors.mapValues { ObjectIdentifier($0) }

        // Ordinary care and currency refreshes retain the same cats in the room.
        for _ in 0..<3 {
            snapshot.player.gold += 1
            prepare(residents, snapshot: snapshot, scene: scene, fixture: value)
            try await waitUntilReady(residents)
            assertPositions(residents.actors.mapValues(\.position), positions)
            XCTAssertEqual(residents.actors.mapValues { ObjectIdentifier($0) }, identities)
            assertResidents(residents, snapshot: snapshot, scene: scene)
        }
    }

    func testCompanionRoleExchangesKeepUniqueCatsAtTheirExistingPositions() async throws {
        var snapshot = try fiveCats()
        snapshot.home.roomLevel = 4
        let value = try fixture(roomLevel: 4)
        let scene = SKScene(size: value.world.transform.sceneSize)
        let residents = RoomResidentCats()
        defer { residents.invalidate(hide: true) }
        var active = value.active
        prepare(residents, snapshot: snapshot, scene: scene, fixture: value, active: active)
        try await waitUntilReady(residents)
        var originalPositions = residents.actors.mapValues(\.position)
        originalPositions[snapshot.activeCatID] = active
        let originalNodes = Set(residents.actors.values.map { ObjectIdentifier($0) })

        for catID in [CatCatalog.cowCatID, CatCatalog.silverCatID, CatCatalog.initialCatID] {
            let old = try XCTUnwrap(snapshot.activeCat)
            let new = try XCTUnwrap(snapshot.cats.first { $0.id == catID })
            let destination = try XCTUnwrap(residents.exchangeActive(from: old, to: new, at: active))
            assertPosition(destination, try XCTUnwrap(originalPositions[catID]))
            assertPosition(try XCTUnwrap(residents.actors[old.id]?.position), active)
            let now = snapshot.meta.lastSyncAt
            XCTAssertTrue(GameEngine.selectCompanion(&snapshot, catID: catID, now: now).succeeded)
            active = destination
            assertResidents(residents, snapshot: snapshot, scene: scene)

            prepare(residents, snapshot: snapshot, scene: scene, fixture: value, active: active)
            try await waitUntilReady(residents)
            assertResidents(residents, snapshot: snapshot, scene: scene)
            var positions = residents.actors.mapValues(\.position)
            positions[snapshot.activeCatID] = active
            assertPositions(positions, originalPositions)
            XCTAssertEqual(Set(residents.actors.values.map { ObjectIdentifier($0) }), originalNodes)
        }
    }

    func testInvalidatedBackgroundPreparationCannotAddCatsOrFinishLater() async throws {
        var snapshot = try fiveCats()
        snapshot.home.roomLevel = 4
        let value = try fixture(roomLevel: 4)
        let scene = SKScene(size: value.world.transform.sceneSize)
        let residents = RoomResidentCats()
        defer { residents.invalidate(hide: true) }
        var finished = 0
        residents.onFinished = { finished += 1 }

        prepare(residents, snapshot: snapshot, scene: scene, fixture: value)
        XCTAssertTrue(residents.isBusy)
        // No MainActor yield: even a fast completed planner cannot publish before
        // this invalidation, as when the floor or scene is replaced immediately.
        residents.invalidate(hide: true)
        XCTAssertFalse(residents.isBusy)
        let deadline = Date().addingTimeInterval(1)
        repeat {
            try await Task.sleep(for: .milliseconds(10))
            if !residents.actors.isEmpty || !scene.children.isEmpty || finished != 0 {
                XCTFail("An invalidated planning result was published into the scene.")
                throw ResidentCatsTestFailure.stalePublication
            }
        } while Date() < deadline
    }

#if DEBUG
    func testQueuedFeedingStartsImmediatelyWhenReturningAfterResidentsFinishInBackground() async throws {
        var snapshot = try fiveCats()
        snapshot.home.roomLevel = 4
        let scene = RoomScene(size: CGSize(width: 402, height: 567))
        defer {
            scene.setPresentationActive(false)
            scene.residents.invalidate(hide: true)
        }
        scene.reducedMotion = true
        scene.apply(snapshot: snapshot, editing: false)
        let deadline = Date().addingTimeInterval(4)
        while Date() < deadline {
            if !scene.diagnostics.bowlPlanning, scene.diagnostics.bowlPlanCompletions > 0,
               !scene.residents.isBusy, scene.residents.actors.count == 4 { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        guard !scene.diagnostics.bowlPlanning, scene.diagnostics.bowlPlanCompletions > 0,
              !scene.residents.isBusy, scene.residents.actors.count == 4 else {
            XCTFail("The five-cat scene did not finish its initial planning within four seconds.")
            throw ResidentCatsTestFailure.timedOut
        }
        XCTAssertEqual(scene.presentationPhase, "idle")

        // Re-enter real resident planning without yielding to its result. This
        // reliably places feeding in the pending queue, not in care planning.
        scene.residents.invalidate()
        scene.apply(snapshot: snapshot, editing: false)
        XCTAssertTrue(scene.residents.isBusy)
        scene.playFeedback(kind: .feed, catID: snapshot.activeCatID)
        XCTAssertEqual(scene.presentationPhase, "idle")
        XCTAssertFalse(scene.diagnostics.carePlanning)
        scene.setPresentationActive(false)
        try await waitUntilReady(scene.residents)
        XCTAssertEqual(scene.presentationPhase, "idle")
        XCTAssertFalse(scene.diagnostics.carePlanning)

        // With no SKView or idle animation frames, only the foreground resume
        // path can drain this queue; it must not wait for a random stroll.
        scene.setPresentationActive(true)
        XCTAssertEqual(scene.presentationPhase, "feeding")
        XCTAssertTrue(scene.diagnostics.carePlanning)
    }
#endif

    func testNoSafeSpaceShowsOneHintAndNeverOverlapsOrLosesOwnedCats() async throws {
        var snapshot = try fiveCats()
        snapshot.home.roomLevel = 4
        let value = try fixture(roomLevel: 4)
        let original = snapshot
        let scene = SKScene(size: value.world.transform.sceneSize)
        let residents = RoomResidentCats()
        defer { residents.invalidate(hide: true) }
        var hints = 0
        residents.onLimitedSpace = { hints += 1 }
        let planner = RoomResidentPlanner(
            floor: value.world.roomFloor.addingObstacles([CGRect(origin: .zero, size: scene.size)]),
            bowl: value.world.bowlPosition, world: value.world, active: value.active, catWidth: value.world.catWidth)
        for _ in 0..<2 {
            residents.prepare(snapshot: snapshot, active: value.active, scene: scene, planner: planner,
                              width: value.world.catWidth, reducedMotion: true)
            try await waitUntilReady(residents)
        }
        XCTAssertEqual(hints, 1, "Ordinary refreshes must not repeatedly report the same crowded layout.")
        XCTAssertTrue(residents.actors.isEmpty)
        XCTAssertTrue(scene.children.isEmpty)
        XCTAssertEqual(snapshot, original)
    }

    private func fiveCats() throws -> GameSnapshot {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        var snapshot = GameSnapshot.fresh(now: now)
        snapshot.player.level = 8
        snapshot.player.gold = 10_000
        snapshot.home.roomLevel = 3
        for offer in CatCatalog.adoptionOffers {
            XCTAssertTrue(GameEngine.adoptCat(&snapshot, catID: offer.id, now: now).succeeded)
        }
        XCTAssertEqual(snapshot.cats.count, 5)
        return snapshot
    }

    private struct Fixture {
        let world: RoomFurnitureWorld
        let active: CGPoint
    }

    private func fixture(roomLevel: Int) throws -> Fixture {
        let viewport = CGSize(width: 402, height: 567)
        let scale = CGFloat(try XCTUnwrap(HomeCatalog.level(roomLevel)).worldScale)
        let size = CGSize(width: viewport.width * scale, height: viewport.height * scale)
        let width = min(viewport.width * 0.14, viewport.height * 0.172)
        let bowlWidth = min(viewport.width * 0.156, viewport.height * 0.185)
        let transform = RoomArtworkTransform(sceneSize: size, artworkSize: .init(width: 1024, height: 1536),
                                              viewportSize: viewport)
        let world = RoomFurnitureWorld(transform: transform, catWidth: width,
            bowlSize: .init(width: bowlWidth, height: bowlWidth * 0.83),
            bowlPosition: .init(x: size.width * 0.76, y: size.height * 0.21), items: [], placements: [])
        let resolved = try XCTUnwrap(RoomBowlPlanner(floor: world.roomFloor, requested: world.bowlPosition,
            catPosition: .init(x: size.width * 0.43, y: size.height * 0.18)).resolve())
        return .init(world: .init(transform: transform, catWidth: width, bowlSize: world.bowlSize,
                                 bowlPosition: resolved.center, items: [], placements: []),
                     active: try XCTUnwrap(resolved.catPosition))
    }

    private func prepare(_ residents: RoomResidentCats, snapshot: GameSnapshot, scene: SKScene,
                         fixture: Fixture, active: CGPoint? = nil) {
        let point = active ?? fixture.active
        residents.prepare(snapshot: snapshot, active: point, scene: scene,
            planner: .init(floor: fixture.world.roomFloor, bowl: fixture.world.bowlPosition,
                           world: fixture.world, active: point, catWidth: fixture.world.catWidth),
            width: fixture.world.catWidth, reducedMotion: true)
    }

    private func assertPosition(_ actual: CGPoint, _ expected: CGPoint,
                                file: StaticString = #filePath, line: UInt = #line) {
        // SpriteKit stores positions with float32 precision. Subpixel rounding
        // is expected; changing the selected cat must not visibly move anyone.
        XCTAssertEqual(actual.x, expected.x, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actual.y, expected.y, accuracy: 0.001, file: file, line: line)
    }

    private func assertPositions(_ actual: [String: CGPoint], _ expected: [String: CGPoint],
                                 file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(Set(actual.keys), Set(expected.keys), file: file, line: line)
        for (id, position) in expected {
            guard let current = actual[id] else { continue }
            assertPosition(current, position, file: file, line: line)
        }
    }

    private func assertResidents(_ residents: RoomResidentCats, snapshot: GameSnapshot, scene: SKScene,
                                 file: StaticString = #filePath, line: UInt = #line) {
        let expected = Set(snapshot.cats.filter { $0.id != snapshot.activeCatID }.map(\.id))
        XCTAssertEqual(Set(residents.actors.keys), expected, file: file, line: line)
        XCTAssertEqual(scene.children.compactMap { $0 as? CatActor }.count, expected.count, file: file, line: line)
        XCTAssertEqual(Set(scene.children.compactMap(\.name)), Set(expected.map { "resident-\($0)" }),
                       file: file, line: line)
        for actor in residents.actors.values {
            XCTAssertTrue(actor.parent === scene, file: file, line: line)
            XCTAssertFalse(actor.isHidden, file: file, line: line)
        }
    }

    private func waitUntilReady(_ residents: RoomResidentCats) async throws {
        let deadline = Date().addingTimeInterval(4)
        while residents.isBusy && Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        if residents.isBusy {
            XCTFail("Resident planning did not settle within four seconds.")
            throw ResidentCatsTestFailure.timedOut
        }
    }
}

private enum ResidentCatsTestFailure: Error { case timedOut, stalePublication }
