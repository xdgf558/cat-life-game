import SpriteKit
import XCTest
import CatGameCore
@testable import CatLife

@MainActor
final class RoomFrontPresentationTests: XCTestCase {
    func testFrontArchitectureCoversTheStageAtEveryLevelFloorAndCameraLimit() throws {
        for viewport in [CGSize(width: 355, height: 280), CGSize(width: 355, height: 410), CGSize(width: 382, height: 560)] {
            for home in HomeCatalog.all {
                for homeFloor in home.floors {
                    let world = RoomWorldGeometry(viewportSize: viewport,
                        worldScale: CGFloat(try XCTUnwrap(home.worldScale(on: homeFloor)))).worldSize
                    let floor = RoomFloor(sceneSize: world, artworkSize: CGSize(width: 1024, height: 1536),
                                          catWidth: 50, bowlSize: CGSize(width: 58, height: 48))
                    let renderer = RoomPresentationRenderer()
                    renderer.setUsableRect(RoomStageLayout.usableRect(in: viewport))
                    renderer.configure(world: world, viewport: viewport, floor: floor.polygon,
                                       angle: .front, level: home.level, homeFloor: homeFloor)
                    let map = try XCTUnwrap(renderer.projection.frontFloor)
                    XCTAssertTrue(renderer.camera.isWholeRoom)
                    let architecture = try XCTUnwrap(renderer.root.childNode(withName: "//room-front-artwork"))
                    XCTAssertNil(architecture.childNode(withName: "//room-shell-wood-edge"))
                    XCTAssertNil(architecture.childNode(withName: "//room-shell-ground-shadow"))
                    let wall = try XCTUnwrap(architecture.childNode(withName: "room-shell-far-wall"))
                    let tiles = architecture.children.filter { $0.name == "room-shell-floor-texture" || $0.name == "room-front-floor-tile" }
                    XCTAssertFalse(tiles.isEmpty)
                    func assertCoverage() {
                        for point in [CGPoint.zero, CGPoint(x: viewport.width, y: 0),
                                      CGPoint(x: 0, y: viewport.height), CGPoint(x: viewport.width, y: viewport.height),
                                      CGPoint(x: viewport.width / 2, y: viewport.height / 2)] {
                            let projected = renderer.camera.worldPoint(viewPoint: point)
                            let covered = projected.y >= map.destination.maxY
                                ? wall.frame.insetBy(dx: -0.001, dy: -0.001).contains(projected)
                                : tiles.contains { $0.frame.insetBy(dx: -0.001, dy: -0.001).contains(projected) }
                            XCTAssertTrue(covered, "Front room must fill \(viewport), level \(home.level), \(homeFloor), at \(point).")
                        }
                    }
                    assertCoverage()
                    renderer.camera.zoom(by: 100)
                    for limit in [CGPoint(x: 100_000, y: 100_000), CGPoint(x: -100_000, y: -100_000)] {
                        renderer.camera.beginPan(at: .zero)
                        _ = renderer.camera.changePan(to: limit)
                        _ = renderer.camera.endPan()
                        assertCoverage()
                    }
                }
            }
        }
    }

    func testTallFurnitureAtTheBackKeepsItsWholeImageInTheFrontOverview() throws {
        for viewport in [CGSize(width: 355, height: 280), CGSize(width: 382, height: 560)] {
            for level in [1, 8] {
                let scale = CGFloat(try XCTUnwrap(HomeCatalog.level(level)?.worldScale))
                let world = RoomWorldGeometry(viewportSize: viewport, worldScale: scale).worldSize
                let transform = RoomArtworkTransform(sceneSize: world, artworkSize: CGSize(width: 1024, height: 1536),
                                                     viewportSize: viewport)
                let tree = FurnitureItem(id: "tree", kind: .catTree)
                let artwork = RoomSceneArtwork()
                let node = artwork.furnitureNode(for: tree, transform: transform)
                let floor = RoomFloor(sceneSize: world, artworkSize: CGSize(width: 1024, height: 1536),
                                      catWidth: 50, bowlSize: CGSize(width: 58, height: 48))
                let spec = RoomFurnitureSpec.forItem(tree)
                let navigation = RoomNavigation(floor: floor.polygon, obstacles: [],
                    footprint: CGSize(width: spec.footprint.width * transform.visualScale,
                                      height: spec.footprint.height * transform.visualScale), cellSize: 7)
                node.position = try XCTUnwrap(navigation.walkablePoints.max { $0.y < $1.y })
                XCTAssertTrue(navigation.isWalkable(node.position), "The tall furniture must use a legal floor footprint.")
                let originalPosition = node.position, originalSize = node.size
                let renderer = RoomPresentationRenderer()
                let usable = RoomStageLayout.usableRect(in: viewport)
                renderer.setUsableRect(usable)
                renderer.configure(world: world, viewport: viewport, floor: floor.polygon, angle: .front, level: level)
                let cat = CatActor(); cat.isHidden = true
                let bowl = SKSpriteNode(); bowl.isHidden = true
                let selection = SKShapeNode(); selection.isHidden = true
                renderer.update(cat: cat, residents: RoomResidentCats(), furniture: [tree.id: node], items: [tree],
                                bowl: bowl, bowlFront: SKSpriteNode(), restFront: SKSpriteNode(),
                                selection: selection, toy: SKSpriteNode(), feeding: false, rest: nil)
                let frame = try XCTUnwrap(renderer.frame("furniture-tree"))
                XCTAssertTrue(usable.insetBy(dx: -0.001, dy: -0.001).contains(frame),
                              "A legal tall tree must not be cropped in the front overview: \(frame), \(viewport), level \(level).")
                XCTAssertEqual(node.position, originalPosition)
                XCTAssertEqual(node.size, originalSize)
                XCTAssertTrue(renderer.camera.isWholeRoom)
            }
        }
    }

    func testMovingOrStashingFurnitureRefitsOnlyAfterTheDragEnds() throws {
        let viewport = CGSize(width: 355, height: 280)
        let world = viewport
        let floor = RoomFloor(sceneSize: world, artworkSize: CGSize(width: 1024, height: 1536),
                              catWidth: 50, bowlSize: CGSize(width: 58, height: 48))
        let artwork = RoomSceneArtwork(), item = FurnitureItem(id: "tree", kind: .catTree)
        let transform = RoomArtworkTransform(sceneSize: world, artworkSize: CGSize(width: 1024, height: 1536))
        let node = artwork.furnitureNode(for: item, transform: transform)
        let spec = RoomFurnitureSpec.forItem(item)
        let navigation = RoomNavigation(floor: floor.polygon, obstacles: [],
            footprint: CGSize(width: spec.footprint.width * transform.visualScale,
                              height: spec.footprint.height * transform.visualScale), cellSize: 7)
        node.position = try XCTUnwrap(navigation.walkablePoints.max { $0.y < $1.y })
        let cat = CatActor(); cat.isHidden = true
        let bowl = SKSpriteNode(); bowl.isHidden = true
        let selection = SKShapeNode(); selection.isHidden = true
        func renderer() -> RoomPresentationRenderer {
            let result = RoomPresentationRenderer()
            result.setUsableRect(RoomStageLayout.usableRect(in: viewport))
            result.configure(world: world, viewport: viewport, floor: floor.polygon, angle: .front, level: 1)
            return result
        }
        func update(_ renderer: RoomPresentationRenderer, furniture: [String: SKSpriteNode]) {
            renderer.update(cat: cat, residents: RoomResidentCats(), furniture: furniture, items: [item],
                            bowl: bowl, bowlFront: SKSpriteNode(), restFront: SKSpriteNode(),
                            selection: selection, toy: SKSpriteNode(), feeding: false, rest: nil)
        }
        let empty = renderer(), occupied = renderer()
        update(empty, furniture: [:])
        update(occupied, furniture: [item.id: node])
        XCTAssertGreaterThan(occupied.camera.scale, empty.camera.scale)
        let backPosition = node.position, backScale = occupied.camera.scale
        let nearestY = try XCTUnwrap(navigation.walkablePoints.map(\.y).min())
        node.position = try XCTUnwrap(navigation.walkablePoints.filter { abs($0.y - nearestY) < 0.001 }
            .min { abs($0.x - world.width / 2) < abs($1.x - world.width / 2) })
        selection.isHidden = false
        update(occupied, furniture: [item.id: node])
        XCTAssertEqual(occupied.camera.scale, backScale, "Dragging must not move the camera under the finger.")
        selection.isHidden = true
        update(occupied, furniture: [item.id: node])
        XCTAssertEqual(occupied.camera.scale, empty.camera.scale, accuracy: 0.000001)
        node.position = backPosition
        update(occupied, furniture: [item.id: node])
        XCTAssertGreaterThan(occupied.camera.scale, empty.camera.scale)
        node.isHidden = true
        update(occupied, furniture: [item.id: node])
        XCTAssertEqual(occupied.camera.scale, empty.camera.scale, accuracy: 0.000001)
        XCTAssertEqual(occupied.camera.center, empty.camera.center)
        node.isHidden = false; node.alpha = 0
        update(occupied, furniture: [item.id: node])
        XCTAssertEqual(occupied.camera.scale, empty.camera.scale, accuracy: 0.000001)
    }

    func testChangingTheSafeAreaKeepsTheSameLogicalFocusAndRelativeZoom() throws {
        let viewport = CGSize(width: 382, height: 560)
        let world = CGSize(width: 573, height: 840)
        let floor = RoomFloor(sceneSize: world, artworkSize: CGSize(width: 1024, height: 1536),
                              catWidth: 50, bowlSize: CGSize(width: 58, height: 48))
        let renderer = RoomPresentationRenderer()
        renderer.setUsableRect(CGRect(x: 20, y: 16, width: 342, height: 430))
        renderer.configure(world: world, viewport: viewport, floor: floor.polygon, angle: .front, level: 4)
        let map = try XCTUnwrap(renderer.projection.frontFloor)
        renderer.camera.focus(on: renderer.projection.project(map.sourceCenter))
        renderer.camera.zoom(by: 1.1)
        let logicalFocus = renderer.projection.unproject(renderer.camera.center)
        let relativeZoom = renderer.camera.scale / renderer.camera.fitScale
        renderer.setUsableRect(CGRect(x: 20, y: 16, width: 342, height: 390))
        let restored = renderer.projection.unproject(renderer.camera.center)
        XCTAssertEqual(restored.x, logicalFocus.x, accuracy: 0.000001)
        XCTAssertEqual(restored.y, logicalFocus.y, accuracy: 0.000001)
        XCTAssertEqual(renderer.camera.scale / renderer.camera.fitScale, relativeZoom, accuracy: 0.000001)
        renderer.camera.fit()
        renderer.setUsableRect(CGRect(x: 20, y: 16, width: 342, height: 450))
        XCTAssertTrue(renderer.camera.isWholeRoom)
    }
}
