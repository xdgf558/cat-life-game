import SpriteKit
import CatGameCore

/// One animation source, with reusable upright artwork above the projected room.
@MainActor
final class RoomPresentationRenderer {
    let root = SKNode()
    let camera = RoomViewCamera()
    private let backdrop = SKSpriteNode(color: UIColor(red: 0.97, green: 0.93, blue: 0.84, alpha: 1), size: .zero)
    private let content = SKNode()
    private let shell = RoomShellArtwork()
    private var mirrors: [String: RoomNodeMirror] = [:]
    private var objectFrames: [String: CGRect] = [:]
    private var objectDepths: [String: CGFloat] = [:]
    private(set) var projection = RoomViewProjection(worldSize: CGSize(width: 390, height: 480), angle: .front)
    private var worldSize = CGSize.zero
    private var viewport = CGSize.zero
    private var polygon: [CGPoint] = []
    private var level = 0
    private var homeFloor: HomeFloor = .ground
    private var requestedUsableRect: CGRect?
    private var configuredUsableRect: CGRect?
    private var cameraUsableRect = CGRect.zero
    private var frontFramingBounds: CGRect?

    init() {
        root.name = "room-presentation"
        root.zPosition = 100_000
        backdrop.zPosition = -1_000
        // Opaque stage paper also hides the simulation-only nodes beneath this renderer.
        let paper = UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256)).image { context in
            let colors = [UIColor(red: 1, green: 0.98, blue: 0.92, alpha: 1).cgColor,
                          UIColor(red: 0.96, green: 0.91, blue: 0.80, alpha: 1).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                context.cgContext.drawRadialGradient(gradient, startCenter: CGPoint(x: 128, y: 128), startRadius: 0,
                    endCenter: CGPoint(x: 128, y: 128), endRadius: 190, options: [.drawsAfterEndLocation])
            }
        }
        backdrop.texture = SKTexture(image: paper)
        root.addChild(backdrop)
        root.addChild(content)
        content.addChild(shell)
    }

    func configure(world: CGSize, viewport: CGSize, floor: [CGPoint], angle: RoomViewAngle, level: Int,
                   homeFloor: HomeFloor = .ground) {
        guard viewport.width > 0, viewport.height > 0, !floor.isEmpty else { return }
        let changed = worldSize != world || self.viewport != viewport || polygon != floor
            || projection.angle != angle || self.level != level || self.homeFloor != homeFloor
            || configuredUsableRect != requestedUsableRect
        guard changed else { return }
        let reset = self.level != level || projection.angle != angle || self.homeFloor != homeFloor || worldSize == .zero
        let previousProjection = projection
        let wasWholeRoom = camera.isWholeRoom
        worldSize = world; self.viewport = viewport; polygon = floor; self.level = level; self.homeFloor = homeFloor
        backdrop.size = CGSize(width: viewport.width + 4, height: viewport.height + 4)
        let top = min(320, viewport.height * 0.43)
        let bottom = min(100, viewport.height * 0.15)
        let fallback = CGRect(x: 16, y: top, width: max(1, viewport.width - 32),
                              height: max(100, viewport.height - top - bottom))
        let usable = requestedUsableRect ?? fallback
        configuredUsableRect = requestedUsableRect
        cameraUsableRect = usable
        frontFramingBounds = nil
        let minX = floor.map(\.x).min()!, maxX = floor.map(\.x).max()!
        let minY = floor.map(\.y).min()!, maxY = floor.map(\.y).max()!
        let footprint = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        let frontBounds = CGRect(x: footprint.minX, y: footprint.minY, width: footprint.width,
                                 height: footprint.width * usable.height / usable.width * 0.66)
        let front = angle == .front ? RoomFrontFloorProjection(polygon: floor, destination: frontBounds) : nil
        let mappingChanged = previousProjection.frontFloor?.destination != front?.destination
        let previousCenter = !reset && !wasWholeRoom && mappingChanged
            ? previousProjection.unproject(camera.center) : nil
        projection = RoomViewProjection(worldSize: world, angle: angle, frontFloor: front)
        shell.configure(projection: projection, floorPolygon: floor, worldSize: world, floor: homeFloor)
        let cameraBounds = front == nil ? shell.contentBounds.insetBy(dx: -24, dy: -24) : shell.contentBounds
        camera.configure(bounds: cameraBounds, viewport: viewport,
                         usableRect: usable, worldScale: CGFloat(HomeCatalog.level(level)?.worldScale ?? 1), reset: reset)
        if !reset, mappingChanged {
            if wasWholeRoom { camera.fit() }
            else if let previousCenter { camera.recenter(on: projection.project(previousCenter)) }
        }
        updateCamera()
    }

    func setUsableRect(_ rect: CGRect) {
        guard [rect.minX, rect.minY, rect.width, rect.height].allSatisfy(\.isFinite),
              rect.width > 0, rect.height > 0, requestedUsableRect != rect else { return }
        requestedUsableRect = rect
        configure(world: worldSize, viewport: viewport, floor: polygon, angle: projection.angle, level: level, homeFloor: homeFloor)
    }

    func update(cat: CatActor, residents: RoomResidentCats, furniture: [String: SKSpriteNode],
                items: [FurnitureItem], bowl: SKSpriteNode, bowlFront: SKSpriteNode, restFront: SKSpriteNode,
                selection: SKShapeNode, toy: SKSpriteNode, feeding: Bool, rest: RoomFurnitureRest?,
                selectedID: String? = nil, particles: [SKNode] = [],
                companionRing: SKShapeNode? = nil, companionPlaque: SKShapeNode? = nil) {
        var active = Set<String>()
        func sync(_ key: String, _ source: SKNode, anchor: CGPoint? = nil, depth: CGFloat? = nil) {
            active.insert(key)
            let mirror: RoomNodeMirror
            if let existing = mirrors[key] { mirror = existing }
            else { mirror = RoomNodeMirror(source); mirrors[key] = mirror; content.addChild(mirror.node) }
            mirror.synchronize(source, root: true)
            mirror.node.name = key
            mirror.node.position = anchor ?? projection.project(source.position)
            mirror.node.zPosition = depth ?? 10_000 - projection.projectedDepth(source.position)
            objectFrames[key] = mirror.node.calculateAccumulatedFrame()
            objectDepths[key] = mirror.node.zPosition
        }
        for (id, node) in furniture {
            let wall = items.first { $0.id == id }.map { FurnitureCatalog.metadata(for: $0.kind).isWall } ?? false
            sync("furniture-" + id, node, anchor: wall ? projection.wallPoint(node.position) : nil,
                 depth: wall ? 100 : nil)
        }
        let bowlPoint = projection.project(bowl.position)
        let bowlDepth = 10_000 - projection.projectedDepth(bowl.position)
        sync("bowl", bowl, anchor: bowlPoint, depth: bowlDepth)
        sync("bowl-front", bowlFront,
             anchor: CGPoint(x: bowlPoint.x + bowlFront.position.x - bowl.position.x,
                             y: bowlPoint.y + bowlFront.position.y - bowl.position.y),
             depth: bowlDepth + min(1, max(-1, bowlFront.zPosition - bowl.zPosition)))
        var catAnchor = projection.project(cat.position)
        var catDepth = 10_000 - projection.projectedDepth(cat.position)
        // A calibrated mouth/paw contact is local artwork space, not a second
        // ground position. Blend into that space only near the active target.
        let target: SKNode? = rest.flatMap { furniture[$0.item.id] } ?? (feeding ? bowl : nil)
        if let target {
            let distance = hypot(cat.position.x - target.position.x, cat.position.y - target.position.y)
            let width = max(1, cat.visualFrame.width)
            let t = min(1, max(0, (3 * width - distance) / (1.5 * width)))
            let blend = t * t * (3 - 2 * t)
            let base = projection.project(target.position)
            let contact = CGPoint(x: base.x + cat.position.x - target.position.x,
                                  y: base.y + cat.position.y - target.position.y)
            catAnchor.x += (contact.x - catAnchor.x) * blend
            catAnchor.y += (contact.y - catAnchor.y) * blend
            if blend == 1 {
                catDepth = 10_000 - projection.projectedDepth(target.position)
                    + min(2, max(-2, cat.zPosition - target.zPosition))
            }
        }
        sync("cat", cat, anchor: catAnchor, depth: catDepth)
        if let companionRing {
            sync("companion-ring", companionRing, anchor: catAnchor, depth: catDepth - 0.5)
        }
        if let companionPlaque {
            let anchor = CGPoint(x: catAnchor.x + companionPlaque.position.x - cat.position.x,
                                 y: catAnchor.y + companionPlaque.position.y - cat.position.y)
            sync("companion-name", companionPlaque, anchor: anchor, depth: 20_001)
        }
        for (id, actor) in residents.actors { sync("resident-" + id, actor) }
        if let rest, let target = furniture[rest.item.id] {
            let base = projection.project(target.position)
            sync("rest-front", restFront,
                 anchor: CGPoint(x: base.x + restFront.position.x - target.position.x,
                                 y: base.y + restFront.position.y - target.position.y), depth: catDepth + 0.2)
        }
        let selectedWall = selectedID.flatMap { id in items.first { $0.id == id } }
            .map { FurnitureCatalog.metadata(for: $0.kind).isWall } ?? false
        sync("selection", selection, anchor: selectedWall ? projection.wallPoint(selection.position) : nil, depth: 25_000)
        sync("toy", toy)
        for particle in particles {
            sync("particle-\(ObjectIdentifier(particle))", particle,
                 anchor: CGPoint(x: catAnchor.x + particle.position.x - cat.position.x,
                                 y: catAnchor.y + particle.position.y - cat.position.y), depth: 30_000)
        }
        for key in Array(mirrors.keys) where !active.contains(key) {
            mirrors.removeValue(forKey: key)?.node.removeFromParent()
            objectFrames.removeValue(forKey: key); objectDepths.removeValue(forKey: key)
        }
        if projection.frontFloor != nil, frontFramingBounds == nil || selection.isHidden {
            let visible = Set(active.filter { key in
                guard key == "bowl" || key.hasPrefix("furniture-"), let node = mirrors[key]?.node else { return false }
                return !node.isHidden && node.alpha > 0.02
            })
            var bounds = shell.contentBounds
            for key in visible {
                if let frame = objectFrames[key] { bounds = bounds.union(frame) }
            }
            if bounds != frontFramingBounds {
                // Tall artwork can rise above the wall; keep it whole without changing its size or moving the camera during a drag.
                let wasWholeRoom = camera.isWholeRoom
                frontFramingBounds = bounds
                camera.configure(bounds: bounds.insetBy(dx: -2, dy: -2), viewport: viewport,
                                 usableRect: cameraUsableRect,
                                 worldScale: CGFloat(HomeCatalog.level(level)?.worldScale ?? 1), reset: wasWholeRoom)
            }
        }
        updateCamera()
    }

    func updateCamera() {
        guard viewport.width > 0, camera.scale > 0 else { return }
        content.setScale(1 / camera.scale)
        let origin = camera.viewPoint(projectedWorld: .zero)
        content.position = CGPoint(x: origin.x - viewport.width / 2, y: viewport.height / 2 - origin.y)
    }

    func worldPoint(screen: CGPoint, wall: Bool = false, displayOffset: CGPoint = .zero) -> CGPoint {
        let point = camera.worldPoint(viewPoint: CGPoint(x: screen.x + displayOffset.x, y: screen.y + displayOffset.y))
        return wall ? projection.unprojectWallPoint(point) : projection.unproject(point)
    }

    func frame(_ key: String) -> CGRect? {
        guard let source = objectFrames[key], let mirror = mirrors[key],
              !mirror.node.isHidden, mirror.node.alpha > 0.02 else { return nil }
        let a = camera.viewPoint(projectedWorld: CGPoint(x: source.minX, y: source.maxY))
        let b = camera.viewPoint(projectedWorld: CGPoint(x: source.maxX, y: source.minY))
        return CGRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y)
    }

    func displayedPoint(_ logicalPoint: CGPoint, source: SKNode, key: String) -> CGPoint? {
        guard let mirror = mirrors[key], !mirror.node.isHidden else { return nil }
        return camera.viewPoint(projectedWorld: CGPoint(x: mirror.node.position.x + logicalPoint.x - source.position.x,
                                                       y: mirror.node.position.y + logicalPoint.y - source.position.y))
    }

    func anchor(_ key: String) -> CGPoint? {
        mirrors[key].map { camera.viewPoint(projectedWorld: $0.node.position) }
    }

    func hit(screen: CGPoint, editing: Bool) -> String? {
        let candidates = mirrors.keys.compactMap { key -> (key: String, frame: CGRect, depth: CGFloat)? in
            guard key == "bowl" || key == "cat" || key.hasPrefix("resident-") || key.hasPrefix("furniture-"),
                  !editing || key == "bowl" || key.hasPrefix("furniture-"), let frame = frame(key) else { return nil }
            return (key, frame, objectDepths[key] ?? 0)
        }
        // Touch padding helps small objects, but never covers another object's visible image.
        if let visible = candidates.filter({ $0.frame.contains(screen) })
            .max(by: { $0.depth < $1.depth }) { return visible.key }
        let assisted = candidates.filter {
            $0.frame.insetBy(dx: -max(3, (44 - $0.frame.width) / 2),
                            dy: -max(3, (44 - $0.frame.height) / 2)).contains(screen)
        }
        func distance(to rect: CGRect) -> CGFloat {
            let dx = max(0, max(rect.minX - screen.x, screen.x - rect.maxX))
            let dy = max(0, max(rect.minY - screen.y, screen.y - rect.maxY))
            return dx * dx + dy * dy
        }
        return assisted.min {
            let a = distance(to: $0.frame), b = distance(to: $1.frame)
            return a == b ? $0.depth > $1.depth : a < b
        }?.key
    }
}

/// Mirrors visual properties only; actions and game callbacks never get copied.
@MainActor
private final class RoomNodeMirror {
    let node: SKNode
    private var children: [ObjectIdentifier: RoomNodeMirror] = [:]

    init(_ source: SKNode) {
        if source is SKSpriteNode { node = SKSpriteNode() }
        else if source is SKShapeNode { node = SKShapeNode() }
        else if source is SKLabelNode { node = SKLabelNode() }
        else { node = SKNode() }
    }

    func synchronize(_ source: SKNode, root: Bool = false) {
        if !root { node.position = source.position; node.zPosition = source.zPosition }
        node.xScale = source.xScale; node.yScale = source.yScale; node.zRotation = source.zRotation
        node.alpha = source.alpha; node.isHidden = source.isHidden
        if let a = source as? SKSpriteNode, let b = node as? SKSpriteNode {
            if b.texture !== a.texture { b.texture = a.texture }
            b.size = a.size; b.anchorPoint = a.anchorPoint
            b.color = a.color; b.colorBlendFactor = a.colorBlendFactor; b.blendMode = a.blendMode
            b.centerRect = a.centerRect; b.warpGeometry = a.warpGeometry
        } else if let a = source as? SKShapeNode, let b = node as? SKShapeNode {
            if b.path != a.path { b.path = a.path }
            b.fillColor = a.fillColor; b.strokeColor = a.strokeColor
            b.lineWidth = a.lineWidth; b.glowWidth = a.glowWidth
        } else if let a = source as? SKLabelNode, let b = node as? SKLabelNode {
            if b.text != a.text { b.text = a.text }
            if b.fontName != a.fontName { b.fontName = a.fontName }
            if b.fontSize != a.fontSize { b.fontSize = a.fontSize }
            if b.fontColor != a.fontColor { b.fontColor = a.fontColor }
            if b.horizontalAlignmentMode != a.horizontalAlignmentMode { b.horizontalAlignmentMode = a.horizontalAlignmentMode }
            if b.verticalAlignmentMode != a.verticalAlignmentMode { b.verticalAlignmentMode = a.verticalAlignmentMode }
        }
        let ids = Set(source.children.map(ObjectIdentifier.init))
        for id in Array(children.keys) where !ids.contains(id) { children.removeValue(forKey: id)?.node.removeFromParent() }
        for child in source.children {
            let id = ObjectIdentifier(child)
            let mirror: RoomNodeMirror
            if let old = children[id] { mirror = old }
            else { mirror = RoomNodeMirror(child); children[id] = mirror; node.addChild(mirror.node) }
            mirror.synchronize(child)
        }
    }
}
