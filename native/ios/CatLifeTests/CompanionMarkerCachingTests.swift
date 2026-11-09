import SpriteKit
import XCTest
@testable import CatLife

@MainActor
final class CompanionMarkerCachingTests: XCTestCase {
    func testMovementReusesPathsAndBreathingWhileFollowingTheCanonicalCat() throws {
        let scene = SKScene(size: CGSize(width: 390, height: 569))
        let artwork = RoomSceneArtwork()
        artwork.install(in: scene)
        let cat = CatActor()
        cat.setIdleEnabled(false)
        cat.setVisualWidth(80)
        scene.addChild(cat)
        cat.cancelAndSettle(at: CGPoint(x: 160, y: 120))
        artwork.updateCompanionMarker(cat: cat, name: "小橘", hidden: false, reducedMotion: false)
        let ring = try XCTUnwrap(scene.childNode(withName: "companion-ring") as? SKShapeNode)
        let plaque = try XCTUnwrap(scene.childNode(withName: "companion-name") as? SKShapeNode)
        let ringPath = try XCTUnwrap(ring.path)
        let plaquePath = try XCTUnwrap(plaque.path)
        let breathing = try XCTUnwrap(ring.action(forKey: "breathe"))

        for step in 0..<30 {
            cat.position = CGPoint(x: 160 + CGFloat(step) * 2.3, y: 120 + CGFloat(step) * 1.7)
            cat.zPosition = 1_000 - cat.position.y
            let position = cat.position, frame = cat.visualFrame
            artwork.updateCompanionMarker(cat: cat, name: "小橘", hidden: false, reducedMotion: false)
            XCTAssertTrue(ring.path === ringPath)
            XCTAssertTrue(plaque.path === plaquePath)
            XCTAssertTrue(ring.action(forKey: "breathe") === breathing)
            XCTAssertEqual(ring.position, position)
            XCTAssertEqual(ring.zPosition, cat.zPosition - 0.5)
            XCTAssertEqual(plaque.position, CGPoint(x: frame.midX, y: frame.maxY + 17))
            XCTAssertEqual(cat.position, position)
            XCTAssertEqual(cat.visualFrame, frame, "Markers cannot change the cat's geometry.")
        }
    }

    func testOnlyChangedGeometryOrTextRebuildsTheCorrespondingMarkerLayout() throws {
        let scene = SKScene(size: CGSize(width: 390, height: 569))
        let artwork = RoomSceneArtwork()
        artwork.install(in: scene)
        let cat = CatActor()
        cat.setIdleEnabled(false)
        cat.setVisualWidth(80)
        scene.addChild(cat)
        cat.cancelAndSettle(at: CGPoint(x: 160, y: 120))
        artwork.updateCompanionMarker(cat: cat, name: "小橘", hidden: false, reducedMotion: false)
        let ring = try XCTUnwrap(scene.childNode(withName: "companion-ring") as? SKShapeNode)
        let plaque = try XCTUnwrap(scene.childNode(withName: "companion-name") as? SKShapeNode)
        let label = try XCTUnwrap(plaque.children.first as? SKLabelNode)
        let initialRing = try XCTUnwrap(ring.path)
        let initialPlaque = try XCTUnwrap(plaque.path)

        cat.setVisualWidth(100)
        artwork.updateCompanionMarker(cat: cat, name: "小橘", hidden: false, reducedMotion: false)
        XCTAssertFalse(ring.path === initialRing)
        XCTAssertTrue(plaque.path === initialPlaque)
        let resizedRing = try XCTUnwrap(ring.path)
        let expectedRingWidth = cat.visualFrame.width * 0.88
        XCTAssertEqual(resizedRing.boundingBoxOfPath.width, expectedRingWidth, accuracy: 0.001)

        artwork.updateCompanionMarker(cat: cat, name: "霜糖小伙伴", hidden: false, reducedMotion: false)
        XCTAssertTrue(ring.path === resizedRing)
        XCTAssertFalse(plaque.path === initialPlaque)
        XCTAssertEqual(label.text, "♥ 霜糖小伙伴")
        let renamedPlaque = try XCTUnwrap(plaque.path)
        label.fontSize += 2
        artwork.updateCompanionMarker(cat: cat, name: "霜糖小伙伴", hidden: true, reducedMotion: true)
        XCTAssertFalse(plaque.path === renamedPlaque, "Changed label metrics must resize the plaque even if the name is unchanged.")
        XCTAssertTrue(ring.path === resizedRing)
        XCTAssertTrue(ring.isHidden)
        XCTAssertTrue(plaque.isHidden)
        XCTAssertNil(ring.action(forKey: "breathe"))
        XCTAssertEqual(ring.alpha, 1)
    }
}
