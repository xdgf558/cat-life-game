import Foundation
import SpriteKit
import UIKit
import XCTest
import CatGameCore
@testable import CatLife

@MainActor
final class RoomCompanionProjectionTests: XCTestCase {
    func testCompanionMarkersFollowTheRenderedCatsOwnHeadAndContactAnchorAtEveryAngleAndZoom() throws {
        let source = CompanionProjectionSource()
        let position = source.cat.position
        for angle in RoomViewAngle.allCases {
            source.configure(angle)
            for zoom: CGFloat in [1, 1.4] {
                source.renderer.camera.zoom(by: zoom)
                source.update(feeding: true)
                let catAnchor = try XCTUnwrap(source.renderer.anchor("cat"))
                let ringAnchor = try XCTUnwrap(source.renderer.anchor("companion-ring"))
                assertPoint(ringAnchor, equals: catAnchor)
                let head = CGPoint(x: source.cat.visualFrame.midX, y: source.cat.visualFrame.maxY + 17)
                let expectedName = try XCTUnwrap(source.renderer.displayedPoint(head, source: source.cat, key: "cat"))
                assertPoint(try XCTUnwrap(source.renderer.anchor("companion-name")), equals: expectedName)
                let plaque = try XCTUnwrap(renderedNode("companion-name", in: source.renderer) as? SKShapeNode)
                let label = try XCTUnwrap(plaque.children.first as? SKLabelNode)
                XCTAssertEqual(label.text, "♥ 小橘")
                XCTAssertEqual(label.fontName, "AvenirNext-Heavy")
                XCTAssertEqual(label.fontSize, 12)
                XCTAssertEqual(label.verticalAlignmentMode, .center)
                XCTAssertEqual(source.cat.position, position)
                assertNoActions(source.renderer.root)
            }
        }
    }

    func testLabelAndMarkerProxiesAreReusedAndReflectNameVisibilityAndReducedMotion() throws {
        let source = CompanionProjectionSource()
        source.configure(.left)
        source.update()
        let ring = try XCTUnwrap(renderedNode("companion-ring", in: source.renderer) as? SKShapeNode)
        let plaque = try XCTUnwrap(renderedNode("companion-name", in: source.renderer) as? SKShapeNode)
        let label = try XCTUnwrap(plaque.children.first as? SKLabelNode)
        let ringPath = try XCTUnwrap(ring.path)
        source.artwork.companionRing.alpha = 0.6
        for _ in 0..<10 { source.update() }
        XCTAssertTrue(renderedNode("companion-ring", in: source.renderer) === ring)
        XCTAssertTrue(renderedNode("companion-name", in: source.renderer) === plaque)
        XCTAssertTrue(plaque.children.first === label)
        XCTAssertTrue(ring.path === ringPath)
        XCTAssertEqual(ring.path, source.artwork.companionRing.path)
        XCTAssertEqual(ring.alpha, 0.6, accuracy: 0.001)
        source.cat.setVisualWidth(100)
        source.update()
        let resizedPath = try XCTUnwrap(ring.path)
        XCTAssertGreaterThan(resizedPath.boundingBoxOfPath.width, ringPath.boundingBoxOfPath.width)
        XCTAssertEqual(resizedPath, source.artwork.companionRing.path)
        source.update()
        XCTAssertTrue(ring.path === resizedPath)
        source.name = "霜糖小伙伴"
        source.update()
        XCTAssertTrue(plaque.children.first === label)
        XCTAssertEqual(label.text, "♥ 霜糖小伙伴")
        source.hidden = true
        source.reducedMotion = true
        source.update()
        XCTAssertNil(source.renderer.frame("companion-ring"))
        XCTAssertNil(source.renderer.frame("companion-name"))
        XCTAssertNil(source.artwork.companionRing.action(forKey: "breathe"))
        XCTAssertEqual(ring.alpha, 1)
        assertNoActions(source.renderer.root)
    }

    func testChangingUsableRectKeepsTheConfiguredUpperFloor() throws {
        let source = CompanionProjectionSource()
        source.configure(.right, homeFloor: .upper)
        let upperTexture = try XCTUnwrap(floorTexture(in: source.renderer))
        XCTAssertEqual(upperTexture.colorBlendFactor, 0.12, accuracy: 0.001)
        source.renderer.setUsableRect(CGRect(x: 24, y: 240, width: 300, height: 270))
        let afterLayout = try XCTUnwrap(floorTexture(in: source.renderer))
        XCTAssertEqual(afterLayout.colorBlendFactor, 0.12, accuracy: 0.001)
        source.configure(.right, homeFloor: .ground)
        let groundTexture = try XCTUnwrap(floorTexture(in: source.renderer))
        XCTAssertEqual(groundTexture.colorBlendFactor, 0, accuracy: 0.001)
    }

#if DEBUG
    func testRealSpriteKitFramesMatchRendererFramesAcrossCanvasSizesViewsAndZooms() async throws {
        for size in [CGSize(width: 375, height: 569), CGSize(width: 402, height: 776)] {
            let scene = RoomScene(size: size)
            let playback = try CompanionProjectionPlayback(scene: scene, canvasSize: size)
            defer { playback.close() }
            var snapshot = GameSnapshot.fresh()
            snapshot.home.roomLevel = 6
            scene.apply(snapshot: snapshot, editing: false)
            try await eventually { scene.presentationPhase == "idle" && !scene.diagnostics.bowlPlanning }
            scene.cat.setIdleEnabled(false)
            scene.cat.cancelAndSettle(at: scene.cat.position)
            let position = scene.cat.position
            let clockAdvanced = expectation(description: "SpriteKit must advance the displayed scene's real frame clock")
            scene.run(.sequence([.wait(forDuration: 0.05), .run { clockAdvanced.fulfill() }]), withKey: "coordinate-clock")
            let clockResult = await XCTWaiter.fulfillment(of: [clockAdvanced], timeout: 3)
            XCTAssertEqual(clockResult, .completed)
            XCTAssertEqual(scene.size, size)
            XCTAssertEqual(playback.view.bounds.size, size)
            XCTAssertTrue(scene.roomPresentation.root.parent === scene.camera)
            scene.setRoomViewUsableRect(CGRect(x: 16, y: 220, width: size.width - 112, height: size.height - 250))

            for angle in RoomViewAngle.allCases {
                for _ in 0..<2 {
                    if scene.roomViewAngle == angle { break }
                    scene.turnRoomView(by: (angle.rawValue - scene.roomViewAngle.rawValue).signum())
                }
                XCTAssertEqual(scene.roomViewAngle, angle)
                for zoom: CGFloat in [1, 1.4] {
                    scene.roomPresentation.camera.zoom(by: zoom)
                    scene.updateRoomPresentation()
                    // Check a frame that the visible SpriteKit scene has actually presented.
                    try await Task.sleep(for: .milliseconds(100))
                    for key in ["cat", "bowl", "companion-ring", "companion-name"] {
                        let mirror = try XCTUnwrap(renderedNode(key, in: scene.roomPresentation))
                        let parent = try XCTUnwrap(mirror.parent)
                        XCTAssertTrue(parent.parent === scene.roomPresentation.root)
                        XCTAssertFalse(mirror === scene.cat)
                        let frame = mirror.calculateAccumulatedFrame()
                        let topLeft = scene.convertPoint(toView: parent.convert(CGPoint(x: frame.minX, y: frame.maxY), to: scene))
                        let bottomRight = scene.convertPoint(toView: parent.convert(CGPoint(x: frame.maxX, y: frame.minY), to: scene))
                        let actual = CGRect(x: topLeft.x, y: topLeft.y,
                                            width: bottomRight.x - topLeft.x, height: bottomRight.y - topLeft.y)
                        let reported = try XCTUnwrap(scene.roomPresentation.frame(key))
                        XCTAssertEqual(actual.minX, reported.minX, accuracy: 0.001, "\(size) \(angle) \(key)")
                        XCTAssertEqual(actual.minY, reported.minY, accuracy: 0.001, "\(size) \(angle) \(key)")
                        XCTAssertEqual(actual.width, reported.width, accuracy: 0.001, "\(size) \(angle) \(key)")
                        XCTAssertEqual(actual.height, reported.height, accuracy: 0.001, "\(size) \(angle) \(key)")
                        let actualAnchor = scene.convertPoint(toView: parent.convert(mirror.position, to: scene))
                        assertPoint(actualAnchor, equals: try XCTUnwrap(scene.roomPresentation.anchor(key)))
                    }
                    XCTAssertEqual(scene.cat.position, position)
                }
            }
        }
    }

    func testResidentPreviewFramesAndNamePlaqueFollowTheSelectedCatAfterRoleExchange() async throws {
        let size = CGSize(width: 402, height: 567)
        let scene = RoomScene(size: size)
        scene.scaleMode = .aspectFit
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        view.presentScene(scene)
        defer { scene.setPresentationActive(false); view.presentScene(nil) }
        var snapshot = GameSnapshot.fresh()
        snapshot.home.roomLevel = 4
        snapshot.player.level = 20
        snapshot.player.gold = 30_000
        let now = snapshot.meta.lastSyncAt
        XCTAssertTrue(GameEngine.adoptCat(&snapshot, catID: CatCatalog.cowCatID, now: now).succeeded)
        scene.apply(snapshot: snapshot, editing: false)

        for activeID in [CatCatalog.initialCatID, CatCatalog.cowCatID] {
            if snapshot.activeCatID != activeID {
                XCTAssertTrue(GameEngine.selectCompanion(&snapshot, catID: activeID, now: now).succeeded)
                scene.apply(snapshot: snapshot, editing: false)
            }
            let otherID = activeID == CatCatalog.initialCatID ? CatCatalog.cowCatID : CatCatalog.initialCatID
            try await eventually {
                scene.presentationPhase == "idle" && !scene.residents.isBusy && scene.residents.actors[otherID] != nil
            }
            let other = try XCTUnwrap(scene.residents.actors[otherID])
            let catPosition = scene.cat.position, otherPosition = other.position
            for angle in RoomViewAngle.allCases {
                for _ in 0..<2 {
                    if scene.roomViewAngle == angle { break }
                    scene.turnRoomView(by: (angle.rawValue - scene.roomViewAngle.rawValue).signum())
                }
                XCTAssertEqual(scene.roomViewAngle, angle)
                scene.updateRoomPresentation()
                XCTAssertEqual(scene.residentFrame(id: activeID), scene.roomPresentation.frame("cat"))
                XCTAssertEqual(scene.residentFrame(id: otherID), scene.roomPresentation.frame("resident-" + otherID))
                XCTAssertNotNil(scene.residentFrame(id: activeID))
                XCTAssertNotNil(scene.residentFrame(id: otherID))
                XCTAssertNotEqual(scene.residentFrame(id: activeID), scene.residentFrame(id: otherID))
                let head = CGPoint(x: scene.cat.visualFrame.midX, y: scene.cat.visualFrame.maxY + 17)
                let expected = try XCTUnwrap(scene.roomPresentation.displayedPoint(head, source: scene.cat, key: "cat"))
                assertPoint(try XCTUnwrap(scene.roomPresentation.anchor("companion-name")), equals: expected)
                let plaque = try XCTUnwrap(renderedNode("companion-name", in: scene.roomPresentation))
                let label = try XCTUnwrap(plaque.children.first as? SKLabelNode)
                XCTAssertEqual(label.text, "♥ " + GameStrings.catName(try XCTUnwrap(snapshot.activeCat)))
                XCTAssertEqual(scene.cat.position, catPosition)
                XCTAssertEqual(other.position, otherPosition)
            }
        }
    }

    private func eventually(_ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("The real scene must finish preparing both cats before projection is checked.")
        throw CompanionProjectionFailure.timedOut
    }
#endif

    private func renderedNode(_ key: String, in renderer: RoomPresentationRenderer) -> SKNode? {
        // A leading // searches the entire scene and can find the hidden simulation node.
        let node = renderer.root.childNode(withName: "*/" + key)
        if let node { XCTAssertTrue(node.parent?.parent === renderer.root) }
        return node
    }

    private func floorTexture(in renderer: RoomPresentationRenderer) -> SKSpriteNode? {
        let texture = renderer.root.childNode(withName: "*/room-shell/*/room-shell-floor-texture") as? SKSpriteNode
        if let texture { XCTAssertTrue(texture.parent?.parent?.parent?.parent === renderer.root) }
        return texture
    }

    private func assertPoint(_ point: CGPoint, equals expected: CGPoint, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(point.x, expected.x, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(point.y, expected.y, accuracy: 0.0001, file: file, line: line)
    }

    private func assertNoActions(_ node: SKNode, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(node.hasActions(), file: file, line: line)
        for child in node.children { assertNoActions(child, file: file, line: line) }
    }
}

@MainActor
private final class CompanionProjectionSource {
    let scene = SKScene(size: CGSize(width: 375, height: 569))
    let artwork = RoomSceneArtwork()
    let cat = CatActor()
    let residents = RoomResidentCats()
    let renderer = RoomPresentationRenderer()
    let world = CGSize(width: 600, height: 900)
    let floor = [CGPoint(x: 10, y: 20), CGPoint(x: 590, y: 20), CGPoint(x: 590, y: 600),
                 CGPoint(x: 300, y: 780), CGPoint(x: 10, y: 600)]
    var name = "小橘"
    var hidden = false
    var reducedMotion = false

    init() {
        artwork.install(in: scene)
        scene.addChild(cat)
        cat.setIdleEnabled(false)
        cat.setVisualWidth(80)
        cat.cancelAndSettle(at: CGPoint(x: 300, y: 230))
        artwork.bowl.position = CGPoint(x: 330, y: 240)
        artwork.bowl.size = CGSize(width: 58, height: 48)
    }

    func configure(_ angle: RoomViewAngle, homeFloor: HomeFloor = .ground) {
        renderer.configure(world: world, viewport: scene.size, floor: floor, angle: angle, level: 6, homeFloor: homeFloor)
    }

    func update(feeding: Bool = false) {
        artwork.updateCompanionMarker(cat: cat, name: name, hidden: hidden, reducedMotion: reducedMotion)
        renderer.update(cat: cat, residents: residents, furniture: [:], items: [], bowl: artwork.bowl,
            bowlFront: artwork.bowlFront, restFront: artwork.restFront, selection: artwork.selection, toy: artwork.toy,
            feeding: feeding, rest: nil, companionRing: artwork.companionRing, companionPlaque: artwork.companionPlaque)
    }
}

/// An independently sized visible canvas exercises SpriteKit's actual camera/view conversion.
@MainActor
private final class CompanionProjectionPlayback {
    let view: SKView
    private let scene: RoomScene
    private let window: UIWindow

    init(scene: RoomScene, canvasSize: CGSize) throws {
        self.scene = scene
        let windowScene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        window = UIWindow(windowScene: windowScene)
        window.frame = windowScene.coordinateSpace.bounds
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue + 1)
        let controller = UIViewController()
        controller.view = UIView(frame: window.bounds)
        view = SKView(frame: CGRect(origin: .zero, size: canvasSize))
        view.preferredFramesPerSecond = 60
        controller.view.addSubview(view)
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

private enum CompanionProjectionFailure: Error { case timedOut }
