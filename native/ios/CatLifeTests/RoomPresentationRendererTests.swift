import SpriteKit
import UIKit
import XCTest
import CatGameCore
@testable import CatLife

final class RoomPresentationRendererTests: XCTestCase {
    @MainActor
    func testTouchPaddingNeverStealsAnotherSmallFurnituresVisibleImage() throws {
        let source = PresentationSource()
        source.configure(.front)
        let scale = source.renderer.camera.scale
        source.cat.isHidden = true; source.bowl.isHidden = true; source.bowlFront.isHidden = true
        let front = SKSpriteNode(color: .brown, size: CGSize(width: 8 * scale, height: 8 * scale))
        front.position = CGPoint(x: source.world.width * 0.45, y: source.world.height * 0.28)
        let rear = SKSpriteNode(color: .green, size: front.size)
        rear.position = CGPoint(x: front.position.x + 20 * scale, y: front.position.y + 2 * scale)
        source.furniture = ["front": front, "rear": rear]
        source.scene.addChild(front); source.scene.addChild(rear)
        source.update()
        let rearFrame = try XCTUnwrap(source.renderer.frame("furniture-rear"))
        let center = CGPoint(x: rearFrame.midX, y: rearFrame.midY)
        XCTAssertEqual(source.renderer.hit(screen: center, editing: true), "furniture-rear")
        let frontFrame = try XCTUnwrap(source.renderer.frame("furniture-front"))
        let padded = CGPoint(x: frontFrame.midX - 15, y: frontFrame.midY)
        XCTAssertFalse(frontFrame.contains(padded))
        XCTAssertEqual(source.renderer.hit(screen: padded, editing: true), "furniture-front")
    }

    @MainActor
    func testEveryLevelAndViewPreservesSourcePositionsOrientationActionsAndCallbacks() {
        for viewport in [CGSize(width: 375, height: 436), CGSize(width: 402, height: 776)] {
            for home in HomeCatalog.all {
                let source = PresentationSource(viewport: viewport, level: home.level)
                let callbacks = source.callbacks
                source.cat.onSound = { _ in callbacks.count += 1 }
                for node in source.logicalNodes {
                    node.run(.sequence([.wait(forDuration: 60), .run { callbacks.count += 1 }]), withKey: "source-only")
                }
                let states = source.logicalNodes.map { NodeState($0) }
                let items = source.items
                for angle in RoomViewAngle.allCases {
                    source.configure(angle)
                    source.update()
                    source.update(feeding: true)
                    XCTAssertEqual(source.items, items)
                    for (node, state) in zip(source.logicalNodes, states) { state.assertUnchanged(node) }
                    XCTAssertEqual(callbacks.count, 0)
                    assertNoActions(source.renderer.root)
                }
                source.logicalNodes.forEach { $0.removeAllActions() }
            }
        }
    }

    @MainActor
    func testHitUsesDisplayedCatBowlAndFurnitureFramesAtEveryAngle() throws {
        let source = PresentationSource()
        for angle in RoomViewAngle.allCases {
            source.configure(angle)
            source.update()
            let cat = try XCTUnwrap(source.renderer.frame("cat"))
            let furniture = try XCTUnwrap(source.renderer.frame("furniture-chair"))
            let bowl = try XCTUnwrap(source.renderer.frame("bowl"))
            XCTAssertGreaterThan(cat.width, 0)
            XCTAssertGreaterThan(furniture.height, 0)
            let catPoint = CGPoint(x: cat.midX, y: cat.midY)
            let furniturePoint = CGPoint(x: furniture.midX, y: furniture.midY)
            let bowlPoint = CGPoint(x: bowl.midX, y: bowl.midY)
            XCTAssertFalse(furniture.insetBy(dx: -3, dy: -3).contains(catPoint))
            XCTAssertFalse(bowl.insetBy(dx: -3, dy: -3).contains(catPoint))
            XCTAssertEqual(source.renderer.hit(screen: catPoint, editing: false), "cat")
            XCTAssertNil(source.renderer.hit(screen: catPoint, editing: true))
            XCTAssertEqual(source.renderer.hit(screen: furniturePoint, editing: false), "furniture-chair")
            XCTAssertEqual(source.renderer.hit(screen: furniturePoint, editing: true), "furniture-chair")
            XCTAssertEqual(source.renderer.hit(screen: bowlPoint, editing: false), "bowl")
        }
    }

    @MainActor
    func testWallDecorationsUseWallHeightMappingAndDragBackToOriginalCoordinates() throws {
        let source = PresentationSource()
        let wall = try XCTUnwrap(source.furniture["wall"])
        let chair = try XCTUnwrap(source.furniture["chair"])
        for angle in RoomViewAngle.allCases {
            source.configure(angle)
            source.update()
            let wallFrame = try XCTUnwrap(source.renderer.frame("furniture-wall"))
            let chairFrame = try XCTUnwrap(source.renderer.frame("furniture-chair"))
            let wallCenter = CGPoint(x: wallFrame.midX, y: wallFrame.midY)
            let chairCenter = CGPoint(x: chairFrame.midX, y: chairFrame.midY)
            let expectedWall = source.renderer.camera.viewPoint(projectedWorld: source.renderer.projection.wallPoint(wall.position))
            let expectedChair = source.renderer.camera.viewPoint(projectedWorld: source.renderer.projection.project(chair.position))
            assertPoint(wallCenter, equals: expectedWall)
            assertPoint(chairCenter, equals: expectedChair)
            let wrongWall = source.renderer.camera.viewPoint(projectedWorld: source.renderer.projection.project(wall.position))
            XCTAssertGreaterThan(hypot(wallCenter.x - wrongWall.x, wallCenter.y - wrongWall.y), 1)
            assertPoint(source.renderer.worldPoint(screen: wallCenter, wall: true), equals: wall.position)
            assertPoint(source.renderer.worldPoint(screen: chairCenter), equals: chair.position)
        }
    }

    @MainActor
    func testRepeatedUpdatesReuseProxiesAndRemoveHiddenOrRemovedHitTargets() throws {
        let source = PresentationSource()
        source.configure(.right)
        source.update()
        let initialCount = descendantCount(source.renderer.root)
        let oldCatFrame = try XCTUnwrap(source.renderer.frame("cat"))
        for _ in 0..<10 { source.update() }
        XCTAssertEqual(descendantCount(source.renderer.root), initialCount)
        source.cat.isHidden = true
        source.furniture.removeValue(forKey: "chair")
        source.update()
        XCTAssertNil(source.renderer.frame("cat"))
        XCTAssertNil(source.renderer.frame("furniture-chair"))
        XCTAssertNil(source.renderer.hit(screen: CGPoint(x: oldCatFrame.midX, y: oldCatFrame.midY), editing: false))
        XCTAssertLessThan(descendantCount(source.renderer.root), initialCount)
        source.cat.isHidden = false
        source.update()
        XCTAssertNotNil(source.renderer.frame("cat"))
        XCTAssertNil(source.renderer.frame("furniture-chair"))
    }

#if DEBUG
    @MainActor
    func testRealMealFramesKeepCalibratedMouthContactInBothSideViewsWithoutDuplicatingCallbacks() async throws {
        for facing: CGFloat in [-1, 1] {
            let source = PresentationSource()
            source.bowl.texture = SKTexture(imageNamed: "bowl-full")
            let dock = FeedingDock(catWidth: source.catWidth, bowlSize: source.bowl.size,
                                   bowlCenter: source.bowl.position, facing: facing)
            source.cat.cancelAndSettle(at: dock.eatingPoint)
            source.cat.speed = 3
            let playback = try PresentationPlayback(scene: source.scene)
            defer { playback.close() }
            var meals = 0, completions = 0
            source.cat.feed(at: dock.eatingPoint, facing: facing, approach: [dock.eatingPoint],
                            dockingPath: [dock.eatingPoint], returnPath: [dock.eatingPoint],
                            onMealFinished: { meals += 1 }, completion: { completions += 1 })
            let foodPixelX: CGFloat = facing > 0 ? 610 : 764
            let target = CGPoint(x: source.bowl.position.x + (foodPixelX / 1374 - 0.5) * source.bowl.size.width,
                                 y: source.bowl.position.y + (0.5 - 315.0 / 1145) * source.bowl.size.height)
            var sampledContacts = Set<Int>()
            let deadline = Date().addingTimeInterval(8)
            while Date() < deadline, completions == 0 {
                if let contact = source.cat.currentMealContact {
                    XCTAssertTrue(source.cat.isDockingForMeal)
                    XCTAssertTrue(dock.containsFoodContact(contact))
                    XCTAssertLessThan(hypot(source.cat.position.x - source.bowl.position.x,
                                            source.cat.position.y - source.bowl.position.y), source.cat.visualFrame.width * 1.5)
                    sampledContacts.insert(Int((contact.x * 1_000).rounded()))
                    let originalPosition = source.cat.position
                    var frontDifference: CGPoint?
                    for angle in [RoomViewAngle.front, .left, .right] {
                        source.configure(angle)
                        source.update(feeding: true)
                        let mouth = try XCTUnwrap(source.renderer.displayedPoint(contact, source: source.cat, key: "cat"))
                        let food = try XCTUnwrap(source.renderer.displayedPoint(target, source: source.bowl, key: "bowl"))
                        let scale = source.renderer.camera.scale
                        let difference = CGPoint(x: (mouth.x - food.x) * scale, y: (food.y - mouth.y) * scale)
                        assertPoint(difference, equals: CGPoint(x: contact.x - target.x, y: contact.y - target.y))
                        if let frontDifference { assertPoint(difference, equals: frontDifference) }
                        else { frontDifference = difference }
                        XCTAssertEqual(source.cat.position, originalPosition)
                        assertNoActions(source.renderer.root)
                    }
                }
                try await Task.sleep(for: .milliseconds(10))
            }
            XCTAssertGreaterThanOrEqual(sampledContacts.count, 2, "Sample both registered mouth-contact frames, not only a static anchor.")
            XCTAssertEqual(meals, 1)
            XCTAssertEqual(completions, 1)
        }
    }
#endif

    @MainActor
    private func assertNoActions(_ node: SKNode, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(node.hasActions(), "Rendering must not copy callbacks or animation clocks.", file: file, line: line)
        for child in node.children { assertNoActions(child, file: file, line: line) }
    }

    @MainActor
    private func descendantCount(_ node: SKNode) -> Int { node.children.reduce(0) { $0 + 1 + descendantCount($1) } }

    private func assertPoint(_ point: CGPoint, equals expected: CGPoint, file: StaticString = #filePath, line: UInt = #line) {
        // SpriteKit node transforms store float precision; stay well below one display pixel.
        XCTAssertEqual(point.x, expected.x, accuracy: 0.002, file: file, line: line)
        XCTAssertEqual(point.y, expected.y, accuracy: 0.002, file: file, line: line)
    }
}

@MainActor
private final class PresentationSource {
    let viewport: CGSize
    let world: CGSize
    let level: Int
    let scene: SKScene
    let catWidth: CGFloat = 50
    let cat = CatActor()
    let residents = RoomResidentCats()
    let renderer = RoomPresentationRenderer()
    let bowl = SKSpriteNode(color: .green, size: CGSize(width: 58, height: 58 * 1145 / 1374))
    let bowlFront = SKSpriteNode(color: .green, size: CGSize(width: 58, height: 20))
    let restFront = SKSpriteNode()
    let selection = SKShapeNode()
    let toy = SKSpriteNode()
    let callbacks = PresentationCallbacks()
    let items = [FurnitureItem(id: "chair", kind: .rattanChair, orientation: .mirrored),
                 FurnitureItem(id: "wall", kind: .wallFlower)]
    var furniture: [String: SKSpriteNode]
    let floor: RoomFloor

    var logicalNodes: [SKNode] { [cat, bowl, bowlFront, restFront, selection, toy] + furniture.keys.sorted().compactMap { furniture[$0] } }

    init(viewport: CGSize = CGSize(width: 375, height: 436), level: Int = 3) {
        self.viewport = viewport
        self.level = level
        let scale = CGFloat(HomeCatalog.level(level)?.worldScale ?? 1)
        world = CGSize(width: viewport.width * scale, height: viewport.height * scale)
        scene = SKScene(size: viewport)
        floor = RoomFloor(sceneSize: world, artworkSize: CGSize(width: 1024, height: 1536),
                          catWidth: 50, bowlSize: bowl.size)
        let chair = SKSpriteNode(color: .brown, size: CGSize(width: 40, height: 48))
        chair.position = CGPoint(x: world.width * 0.78, y: world.height * 0.25)
        chair.xScale = -1
        let wall = SKSpriteNode(color: .yellow, size: CGSize(width: 24, height: 28))
        wall.position = RoomArtworkTransform(sceneSize: world, artworkSize: CGSize(width: 1024, height: 1536))
            .point(.init(x: 0.72, y: 0.25))
        furniture = ["chair": chair, "wall": wall]
        cat.setIdleEnabled(false)
        cat.setVisualWidth(catWidth)
        cat.cancelAndSettle(at: CGPoint(x: world.width * 0.22, y: world.height * 0.18))
        bowl.position = CGPoint(x: world.width * 0.73, y: world.height * 0.47)
        bowlFront.position = CGPoint(x: bowl.position.x, y: bowl.position.y - 8)
        restFront.isHidden = true
        selection.isHidden = true
        toy.isHidden = true
        logicalNodes.forEach { scene.addChild($0) }
    }

    func configure(_ angle: RoomViewAngle) {
        renderer.configure(world: world, viewport: viewport, floor: floor.polygon, angle: angle, level: level)
    }

    func update(feeding: Bool = false) {
        renderer.update(cat: cat, residents: residents, furniture: furniture, items: items,
                        bowl: bowl, bowlFront: bowlFront, restFront: restFront, selection: selection,
                        toy: toy, feeding: feeding, rest: nil)
    }
}

@MainActor
private final class PresentationCallbacks { var count = 0 }

@MainActor
private struct NodeState {
    let position: CGPoint
    let xScale: CGFloat
    let yScale: CGFloat
    let rotation: CGFloat
    let parent: SKNode?
    let action: SKAction?

    init(_ node: SKNode) {
        position = node.position
        xScale = node.xScale
        yScale = node.yScale
        rotation = node.zRotation
        parent = node.parent
        action = node.action(forKey: "source-only")
    }

    func assertUnchanged(_ node: SKNode, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(node.position, position, file: file, line: line)
        XCTAssertEqual(node.xScale, xScale, file: file, line: line)
        XCTAssertEqual(node.yScale, yScale, file: file, line: line)
        XCTAssertEqual(node.zRotation, rotation, file: file, line: line)
        XCTAssertTrue(node.parent === parent, file: file, line: line)
        XCTAssertTrue(node.action(forKey: "source-only") === action, file: file, line: line)
    }
}

/// A separate SKView supplies real action frames without changing the app's window.
@MainActor
private final class PresentationPlayback {
    private let window: UIWindow
    private let view: SKView

    init(scene: SKScene) throws {
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
        view.scene?.removeAllActions()
        view.scene?.children.forEach { $0.removeAllActions() }
        view.presentScene(nil)
        window.isHidden = true
        window.rootViewController = nil
    }
}
