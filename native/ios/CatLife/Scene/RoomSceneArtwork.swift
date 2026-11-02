import SpriteKit
import UIKit
import CatGameCore

/// Owns room nodes, layering and decoration visuals. It never plans routes or
/// mutates saved furniture; RoomScene remains the interaction coordinator.
@MainActor
final class RoomSceneArtwork {
    private weak var scene: SKScene?
    let room = SKSpriteNode(imageNamed: "room-empty")
    let bowl = SKSpriteNode(imageNamed: "bowl-empty")
    private let bowlFront = SKSpriteNode()
    let toy = SKSpriteNode(imageNamed: "icon-play")
    let restFront = SKSpriteNode()
    let selection = SKShapeNode(ellipseOf: CGSize(width: 105, height: 52))
    let thought = SKNode()
    private(set) var furnitureNodes: [String: SKSpriteNode] = [:]

    func install(in scene: SKScene) {
        self.scene = scene
        room.zPosition = 0
        scene.addChild(room)
        bowl.name = "bowl"
        bowl.zPosition = 25
        scene.addChild(bowl)
        scene.addChild(bowlFront)
        restFront.isHidden = true
        scene.addChild(restFront)
        setBowlTexture("bowl-empty")
        toy.zPosition = 26
        toy.isHidden = true
        scene.addChild(toy)
        selection.fillColor = UIColor(red: 0.3, green: 0.75, blue: 0.60, alpha: 0.15)
        selection.strokeColor = UIColor(red: 0.15, green: 0.61, blue: 0.46, alpha: 0.9)
        selection.lineWidth = 2
        selection.zPosition = 1_500
        selection.isHidden = true
        scene.addChild(selection)
        let bubble = SKShapeNode(rectOf: CGSize(width: 58, height: 46), cornerRadius: 20)
        bubble.fillColor = UIColor(red: 1, green: 0.99, blue: 0.96, alpha: 0.98)
        bubble.strokeColor = UIColor(red: 0.81, green: 0.71, blue: 0.56, alpha: 0.4)
        bubble.lineWidth = 1
        let food = SKSpriteNode(imageNamed: "bowl-full")
        food.size = CGSize(width: 43, height: 36)
        food.zPosition = 1
        bubble.addChild(food)
        thought.addChild(bubble)
        for (x, y, radius) in [(CGFloat(-17), CGFloat(-27), CGFloat(4)), (-22, -36, 2.5)] {
            let dot = SKShapeNode(circleOfRadius: radius)
            dot.fillColor = bubble.fillColor
            dot.strokeColor = .clear
            dot.position = CGPoint(x: x, y: y)
            thought.addChild(dot)
        }
        thought.zPosition = 30
        scene.addChild(thought)
    }

    func synchronizeFurniture(items ownedFurniture: [FurnitureItem], placements renderedFurniture: [FurniturePlacement],
                              keeping newPlacementID: String?, transform artworkTransform: RoomArtworkTransform) {
        let visible = Set(renderedFurniture.map(\.itemID))
        for id in Array(furnitureNodes.keys) where !visible.contains(id) && id != newPlacementID {
            furnitureNodes.removeValue(forKey: id)?.removeFromParent()
        }
        for placement in renderedFurniture {
            guard let item = ownedFurniture.first(where: { $0.id == placement.itemID }) else { continue }
            let node = furnitureNode(for: item, transform: artworkTransform)
            node.position = artworkTransform.point(placement.position)
            node.alpha = 1
        }
    }

    func furnitureNode(for item: FurnitureItem, transform artworkTransform: RoomArtworkTransform) -> SKSpriteNode {
        let texture = RoomFurnitureArt.texture(for: item.kind)
        let node: SKSpriteNode
        if let existing = furnitureNodes[item.id] { node = existing }
        else {
            node = SKSpriteNode(texture: texture)
            node.name = "furniture-" + item.id
            furnitureNodes[item.id] = node
            scene?.addChild(node)
        }
        let spec = RoomFurnitureSpec.forItem(item)
        let width = spec.width * artworkTransform.scale
        let ratio = texture.size().height / max(1, texture.size().width)
        node.size = CGSize(width: width, height: width * ratio)
        node.anchorPoint = CGPoint(x: 0.5, y: spec.anchorY)
        return node
    }

    func updateFurnitureLayers(items ownedFurniture: [FurnitureItem], cat: CatActor, activeRest: RoomFurnitureRest?) {
        for item in ownedFurniture {
            guard let node = furnitureNodes[item.id] else { continue }
            node.zPosition = RoomFurnitureSpec.forItem(item).isWall ? 10 : 1_000 - node.position.y
        }
        restFront.isHidden = true
        if cat.isEnteringFurniture, let visit = activeRest, let node = furnitureNodes[visit.item.id] {
            // Before front-paw contact, preserve ordinary ground depth. Once
            // supported, the cat and its paw-height animation sit above the
            // cushion surface; never draw the entire cushion across its body.
            if cat.stepPhase != .reaching { node.zPosition = cat.zPosition - 0.2 }
            // The near rim can cover paws only after the whole cat has crossed
            // onto the mattress. During entry/exit it otherwise cuts through
            // the chest while the rear paws are still on the floor.
            if visit.item.kind == .catBed, cat.stepPhase == .supported {
                let fraction: CGFloat = 0.22
                restFront.isHidden = false
                restFront.size = CGSize(width: node.size.width, height: node.size.height * fraction)
                restFront.position = CGPoint(x: node.position.x,
                                             y: node.position.y + node.size.height * (fraction / 2 - node.anchorPoint.y))
                restFront.zPosition = cat.zPosition + 0.2
            }
        }
    }

    func setBowlTexture(_ name: String) {
        let texture = SKTexture(imageNamed: name)
        bowl.texture = texture
        // SpriteKit UV y=0 is the image bottom. Keep the lower bowl wall in
        // front while a feeding muzzle reaches over the rear rim and food.
        // The cut starts below the measured mouth (source y=315) and above
        // the paws, so paws never appear painted onto the food surface.
        bowlFront.texture = SKTexture(rect: CGRect(x: 0, y: 0, width: 1, height: 0.68), in: texture)
    }

    func updateBowlLayers(cat: CatActor, floor: RoomFloor?) {
        bowlFront.size = CGSize(width: bowl.size.width, height: bowl.size.height * 0.68)
        bowlFront.position = CGPoint(x: bowl.position.x, y: bowl.position.y - bowl.size.height * 0.16)
        let groundDepth = 1_000 - (floor?.bowlGround(at: bowl.position).y ?? bowl.position.y)
        let muzzleOverFood = cat.isMuzzleOverFood
        bowl.zPosition = muzzleOverFood ? cat.zPosition - 0.2 : groundDepth
        bowlFront.zPosition = muzzleOverFood ? cat.zPosition + 0.2 : groundDepth + 0.01
    }

    func updateSelection(editing: Bool, selectedFurnitureID: String?, ownedFurniture: [FurnitureItem],
                         furnitureWorld: RoomFurnitureWorld, floor: RoomFloor?) {
        selection.isHidden = !editing
        if let id = selectedFurnitureID, let item = ownedFurniture.first(where: { $0.id == id }),
           let node = furnitureNodes[id] {
            let size = furnitureWorld.footprint(item)
            let rect = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
            selection.path = RoomFurnitureSpec.forItem(item).isWall
                ? CGPath(roundedRect: rect, cornerWidth: 5, cornerHeight: 5, transform: nil)
                : CGPath(ellipseIn: rect, transform: nil)
            selection.position = node.position
            selection.setScale(1)
        } else {
            let rect = CGRect(x: -bowl.size.width * 0.55, y: -bowl.size.width * 0.24,
                              width: bowl.size.width * 1.10, height: bowl.size.width * 0.48)
            selection.path = CGPath(ellipseIn: rect, transform: nil)
            selection.position = floor?.bowlGround(at: bowl.position) ?? bowl.position
            selection.setScale(1)
        }
    }
    func showCareParticles(cat: CatActor, reducedMotion: Bool) {
        guard !reducedMotion, let image = UIImage(systemName: "sparkles")?.withTintColor(.white, renderingMode: .alwaysOriginal) else { return }
        for index in 0..<3 {
            let particle = SKSpriteNode(texture: SKTexture(image: image))
            particle.name = "care-particle"
            particle.size = CGSize(width: 14, height: 14)
            particle.position = CGPoint(x: cat.position.x - 18 + CGFloat(index) * 19, y: cat.visualFrame.midY)
            particle.zPosition = 2_010
            particle.alpha = 0
            scene?.addChild(particle)
            particle.run(.sequence([.wait(forDuration: 0.4 + Double(index) * 0.12), .fadeIn(withDuration: 0.1),
                                    .group([.moveBy(x: CGFloat(index - 1) * 6, y: 22, duration: 0.8), .fadeOut(withDuration: 0.8)]), .removeFromParent()]))
        }
    }
}
