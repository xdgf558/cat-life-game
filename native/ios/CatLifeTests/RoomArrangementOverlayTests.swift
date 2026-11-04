import XCTest
import SpriteKit
import CatGameCore
@testable import CatLife

final class RoomArrangementOverlayTests: XCTestCase {
    func testQuickActionsStayInsideScreenAndAboveExpandedTray() {
        for canvas in [CGSize(width: 320, height: 568), CGSize(width: 402, height: 820)] {
            for x: CGFloat in [-80, canvas.width / 2, canvas.width + 80] {
                for y: CGFloat in [0, 240, canvas.height + 50] {
                    let center = RoomArrangementOverlayLayout.center(
                        for: CGRect(x: x, y: y, width: 100, height: 130), canvas: canvas,
                        bottomInset: 250, width: 232)
                    XCTAssertGreaterThanOrEqual(center.x - 116, 12)
                    XCTAssertLessThanOrEqual(center.x + 116, canvas.width - 12)
                    XCTAssertGreaterThanOrEqual(center.y, 180)
                    XCTAssertLessThanOrEqual(center.y + 27, canvas.height - 250)
                }
            }
        }
    }

    func testQuickActionsTrackSelectedFurnitureWhenNoClampingIsNeeded() {
        let center = RoomArrangementOverlayLayout.center(
            for: CGRect(x: 150, y: 300, width: 100, height: 140),
            canvas: CGSize(width: 402, height: 820), bottomInset: 250, width: 232)
        XCTAssertEqual(center, CGPoint(x: 200, y: 268))
    }

    @MainActor
    func testOrientationAnimationReusesNodeAndReducedMotionSnapsToSavedDirection() throws {
        let scene = SKScene(size: CGSize(width: 390, height: 650))
        let artwork = RoomSceneArtwork()
        artwork.install(in: scene)
        let transform = RoomArtworkTransform(sceneSize: scene.size, artworkSize: CGSize(width: 1024, height: 1536))
        var item = try XCTUnwrap(FurnitureCatalog.defaultItems.first { $0.kind == .catBed })
        let node = artwork.furnitureNode(for: item, transform: transform)
        XCTAssertEqual(node.xScale, 1)
        let size = node.size
        item.orientation = .mirrored
        XCTAssertTrue(artwork.furnitureNode(for: item, transform: transform, animateOrientation: true) === node)
        let action = try XCTUnwrap(node.action(forKey: "orientation"))
        XCTAssertEqual(action.duration, 0.28, accuracy: 0.0001)
        _ = artwork.furnitureNode(for: item, transform: transform, animateOrientation: true)
        XCTAssertTrue(node.action(forKey: "orientation") === action, "A scene refresh must not restart the flip.")
        artwork.finishOrientationAnimations()
        XCTAssertNil(node.action(forKey: "orientation"))
        XCTAssertEqual(node.xScale, -1)
        XCTAssertEqual(node.size, size)
        item.orientation = .normal
        _ = artwork.furnitureNode(for: item, transform: transform, animateOrientation: false)
        XCTAssertNil(node.action(forKey: "orientation"))
        XCTAssertEqual(node.xScale, 1)
    }
}
