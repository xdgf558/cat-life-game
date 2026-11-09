import SpriteKit
import UIKit
import XCTest
import CatGameCore
@testable import CatLife

final class RoomRenderedRestTests: XCTestCase {
#if DEBUG
    @MainActor
    func testRenderedPawOffsetsSurviveAllViewsDuringRealBedAndCushionEntryAndExit() async throws {
        for kind in [FurnitureKind.catBed, .floorCushion] {
            let scene = RoomScene(size: CGSize(width: 375, height: 569))
            scene.scaleMode = .aspectFit
            var snapshot = GameSnapshot.fresh()
            snapshot.home.roomLevel = 3
            scene.apply(snapshot: snapshot, editing: false)
            let playback = try RenderedRestPlayback(scene: scene)
            defer { playback.close() }
            let deadline = Date().addingTimeInterval(20)
            while scene.presentationPhase != "idle", Date() < deadline {
                try await Task.sleep(for: .milliseconds(10))
            }
            XCTAssertEqual(scene.presentationPhase, "idle", "The real scene must finish its initial layout.")
            XCTAssertEqual(scene.size, CGSize(width: 375, height: 569))
            let cat = try XCTUnwrap(scene.childNode(withName: "cat") as? CatActor)
            cat.speed = 2
            let item = try XCTUnwrap(snapshot.inventory.furniture.first { $0.kind == kind })
            let target = try XCTUnwrap(scene.furnitureNodes[item.id])
            XCTAssertNotNil(scene.furnitureWorld.restVisit(to: item.id, from: cat.position),
                            "The fixture must permit the actual furniture visit.")
            let completedRests = cat.completedRests
            let completedExits = scene.diagnostics.restExits
            var begins = 0, ends = 0
            var sessionID: String?
            scene.onRestingFurnitureChanged = { furnitureID, currentSessionID, catID in
                XCTAssertEqual(catID, snapshot.activeCatID)
                if let furnitureID {
                    XCTAssertEqual(furnitureID, item.id)
                    begins += 1
                    sessionID = currentSessionID
                } else {
                    XCTAssertEqual(currentSessionID, sessionID)
                    ends += 1
                }
            }
            scene.restInFurniture(kind: kind)
            var entrySamples = 0, exitSamples = 0
            var entryViews = Set<RoomViewAngle>(), exitViews = Set<RoomViewAngle>()
            var requestedExit = false
            var finished = false
            while Date() < deadline {
                if scene.activeRest != nil, let paw = cat.frontPawContact {
                    let isEntry = cat.restPhase == .entering
                    let isExit = cat.restPhase == .leaving
                    if isEntry || isExit {
                        let catPosition = cat.position
                        let targetPosition = target.position
                        XCTAssertLessThanOrEqual(hypot(catPosition.x - targetPosition.x, catPosition.y - targetPosition.y),
                                                 cat.visualFrame.width * 1.5,
                                                 "Registered contact frames must be inside the renderer's full local-contact group.")
                        for angle in [RoomViewAngle.front, .left, .right] {
                            for _ in 0..<2 {
                                if scene.roomViewAngle == angle { break }
                                let previous = scene.roomViewAngle.rawValue
                                let direction = (angle.rawValue - previous).signum()
                                scene.turnRoomView(by: direction)
                                XCTAssertEqual(scene.roomViewAngle.rawValue, previous + direction,
                                               "The fixed-view action must remain available during contact.")
                            }
                            guard scene.roomViewAngle == angle else { throw RenderedRestFailure.viewUnavailable }
                            scene.updateRoomPresentation()
                            XCTAssertEqual(cat.position, catPosition, "Turning a view cannot rewrite the current path point.")
                            XCTAssertEqual(target.position, targetPosition)
                            let displayedPaw = try XCTUnwrap(scene.roomPresentation.displayedPoint(paw, source: cat, key: "cat"))
                            let displayedTarget = try XCTUnwrap(scene.roomPresentation.displayedPoint(
                                targetPosition, source: target, key: "furniture-" + item.id))
                            let scale = scene.roomPresentation.camera.scale
                            XCTAssertEqual((displayedPaw.x - displayedTarget.x) * scale,
                                           paw.x - targetPosition.x, accuracy: 0.01)
                            XCTAssertEqual((displayedTarget.y - displayedPaw.y) * scale,
                                           paw.y - targetPosition.y, accuracy: 0.01)
                            if isEntry { entryViews.insert(angle) }
                            if isExit { exitViews.insert(angle) }
                        }
                        if isEntry { entrySamples += 1 }
                        if isExit { exitSamples += 1 }
                    }
                }
                if cat.restPhase == .resting, !requestedExit {
                    XCTAssertEqual(cat.completedRests, completedRests + 1)
                    XCTAssertEqual(scene.activeRest?.item.id, item.id)
                    requestedExit = true
                    scene.restInFurniture(kind: kind)
                }
                if requestedExit, scene.activeRest == nil, !cat.isPerforming, scene.presentationPhase == "idle" {
                    finished = true
                    break
                }
                try await Task.sleep(for: .milliseconds(10))
            }
            XCTAssertTrue(finished, "\(kind.rawValue) must complete one real rest and exit within twenty seconds.")
            XCTAssertGreaterThan(entrySamples, 0, "Sample real entry step landmarks, not a settled pose.")
            XCTAssertGreaterThan(exitSamples, 0, "Sample real exit step landmarks, not only entry.")
            XCTAssertEqual(entryViews, Set(RoomViewAngle.allCases))
            XCTAssertEqual(exitViews, Set(RoomViewAngle.allCases))
            XCTAssertEqual(cat.completedRests, completedRests + 1)
            XCTAssertEqual(scene.diagnostics.restExits, completedExits + 1)
            XCTAssertEqual(begins, 1)
            XCTAssertEqual(ends, 1)
        }
    }
#endif
}

private enum RenderedRestFailure: Error { case viewUnavailable }

/// Supplies real SpriteKit action frames; aspectFit keeps the canonical test canvas unchanged.
@MainActor
private final class RenderedRestPlayback {
    private let scene: RoomScene
    private let window: UIWindow
    private let view: SKView

    init(scene: RoomScene) throws {
        self.scene = scene
        let windowScene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        window = UIWindow(windowScene: windowScene)
        window.frame = windowScene.coordinateSpace.bounds
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue + 1)
        view = SKView(frame: window.bounds)
        view.preferredFramesPerSecond = 60
        let controller = UIViewController()
        controller.view = view
        window.rootViewController = controller
        view.presentScene(scene)
        window.isHidden = false
    }

    func close() {
        scene.setPresentationActive(false)
        scene.removeAllActions()
        scene.children.forEach { $0.removeAllActions() }
        view.presentScene(nil)
        window.isHidden = true
        window.rootViewController = nil
    }
}
