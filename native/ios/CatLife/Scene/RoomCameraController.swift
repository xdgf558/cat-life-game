import SpriteKit

/// Camera movement never changes room geometry or saved furniture positions.
@MainActor
final class RoomCameraController {
    let node = SKCameraNode()
    private(set) var geometry = RoomWorldGeometry(viewportSize: .zero, worldScale: 1)
    private var touchOrigin: CGPoint?
    private var touchCameraOrigin = CGPoint.zero
    private var canPan = false
    private var isPanning = false
    private var followsTarget = false
    private var lastUpdate: TimeInterval?

    func configure(_ geometry: RoomWorldGeometry) {
        self.geometry = geometry
        node.setScale(1)
        node.removeAllActions()
        node.position = geometry.clampedCameraPosition(node.position)
        _ = endTouch()
    }

    func beginTouch(at point: CGPoint, canPan: Bool) {
        touchOrigin = point
        touchCameraOrigin = node.position
        self.canPan = canPan && geometry.worldScale > 1
        isPanning = false
    }

    @discardableResult
    func moveTouch(to point: CGPoint) -> Bool {
        guard canPan, let origin = touchOrigin else { return false }
        let dx = point.x - origin.x, dy = point.y - origin.y
        guard isPanning || hypot(dx, dy) >= 8 else { return false }
        isPanning = true
        followsTarget = false
        node.removeAllActions()
        node.position = geometry.clampedCameraPosition(
            CGPoint(x: touchCameraOrigin.x - dx, y: touchCameraOrigin.y + dy))
        return true
    }

    @discardableResult
    func endTouch() -> Bool {
        let wasPanning = isPanning
        touchOrigin = nil
        canPan = false
        isPanning = false
        return wasPanning
    }

    func focus(on point: CGPoint, animated: Bool) {
        followsTarget = true
        node.removeAllActions()
        let target = geometry.clampedCameraPosition(point)
        if animated {
            let move = SKAction.move(to: target, duration: 0.45)
            move.timingMode = .easeInEaseOut
            node.run(move, withKey: "focus")
        } else { node.position = target }
    }

    func beginFollowing(_ point: CGPoint, animated: Bool) {
        followsTarget = true
        let screen = geometry.screenPoint(point, camera: node.position)
        let viewport = CGRect(origin: .zero, size: geometry.viewportSize).insetBy(dx: 35, dy: 45)
        if !viewport.contains(screen) { focus(on: point, animated: animated) }
    }

    /// Follow only outside a generous central band. Manual browsing suspends
    /// following until another explicit care/rest action or Find Cat request.
    @discardableResult
    func update(at time: TimeInterval, target: CGPoint?, draggingAt point: CGPoint?) -> Bool {
        let delta = CGFloat(min(1.0 / 15, max(0, time - (lastUpdate ?? time))))
        lastUpdate = time
        guard geometry.worldScale > 1, delta > 0, !isPanning else { return false }
        if let point {
            let edge: CGFloat = 30
            let size = geometry.viewportSize
            let dx = point.x < edge ? -(edge - point.x) / edge
                : point.x > size.width - edge ? (point.x - size.width + edge) / edge : 0
            let dy = point.y < edge ? (edge - point.y) / edge
                : point.y > size.height - edge ? -(point.y - size.height + edge) / edge : 0
            guard dx != 0 || dy != 0 else { return false }
            followsTarget = false
            node.removeAllActions()
            let previous = node.position
            node.position = geometry.clampedCameraPosition(CGPoint(
                x: previous.x + min(1, max(-1, dx)) * 100 * delta,
                y: previous.y + min(1, max(-1, dy)) * 100 * delta))
            return node.position != previous
        }
        guard followsTarget, let target, node.action(forKey: "focus") == nil else { return false }
        let halfX = geometry.viewportSize.width * 0.22
        let halfY = geometry.viewportSize.height * 0.20
        let desired = geometry.clampedCameraPosition(CGPoint(
            x: min(target.x + halfX, max(target.x - halfX, node.position.x)),
            y: min(target.y + halfY, max(target.y - halfY, node.position.y))))
        let previous = node.position
        let fraction = min(1, delta * 4)
        node.position = CGPoint(x: previous.x + (desired.x - previous.x) * fraction,
                                y: previous.y + (desired.y - previous.y) * fraction)
        return node.position != previous
    }
}
