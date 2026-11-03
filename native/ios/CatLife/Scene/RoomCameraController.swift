import SpriteKit

/// Camera movement never changes room geometry or saved furniture positions.
@MainActor
final class RoomCameraController {
    let node = SKCameraNode()
    private(set) var geometry = RoomWorldGeometry(viewportSize: .zero, worldScale: 1)
    var scale: CGFloat { node.xScale }
    var isPinching: Bool { pinchWorldAnchor != nil }
    private var touchOrigin: CGPoint?
    private var touchCameraOrigin = CGPoint.zero
    private var canPan = false
    private var isPanning = false
    private var followsTarget = false
    private var lastUpdate: TimeInterval?
    private var pinchOriginScale: CGFloat = 1
    private var pinchWorldAnchor: CGPoint?

    func configure(_ geometry: RoomWorldGeometry) {
        self.geometry = geometry
        node.setScale(geometry.clampedCameraScale(scale))
        node.removeAllActions()
        node.position = geometry.clampedCameraPosition(node.position, cameraScale: scale)
        cancelGestures()
    }

    func beginTouch(at point: CGPoint, canPan: Bool) {
        touchOrigin = point
        touchCameraOrigin = node.position
        self.canPan = canPan && geometry.worldScale > 1
        isPanning = false
    }

    @discardableResult
    func moveTouch(to point: CGPoint) -> Bool {
        guard canPan, !isPinching, let origin = touchOrigin else { return false }
        let dx = point.x - origin.x, dy = point.y - origin.y
        guard isPanning || hypot(dx, dy) >= 8 else { return false }
        isPanning = true
        followsTarget = false
        node.removeAllActions()
        node.position = geometry.clampedCameraPosition(
            CGPoint(x: touchCameraOrigin.x - dx * scale, y: touchCameraOrigin.y + dy * scale), cameraScale: scale)
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

    func beginPinch(at point: CGPoint) {
        guard geometry.worldScale > 1, point.x.isFinite, point.y.isFinite else { return }
        _ = endTouch()
        node.removeAllActions()
        followsTarget = false
        pinchOriginScale = scale
        pinchWorldAnchor = geometry.worldPoint(point, camera: node.position, cameraScale: scale)
    }

    func changePinch(factor: CGFloat, at point: CGPoint) {
        guard let anchor = pinchWorldAnchor, factor.isFinite, factor > 0,
              point.x.isFinite, point.y.isFinite else { return }
        node.setScale(geometry.clampedCameraScale(pinchOriginScale / factor))
        node.position = geometry.cameraPosition(keeping: anchor, at: point, cameraScale: scale)
    }

    func endPinch() { pinchWorldAnchor = nil }

    func cancelGestures() {
        _ = endTouch()
        endPinch()
        lastUpdate = nil
    }

    func zoom(by factor: CGFloat) {
        guard geometry.worldScale > 1, factor.isFinite, factor > 0 else { return }
        let center = CGPoint(x: geometry.viewportSize.width / 2, y: geometry.viewportSize.height / 2)
        beginPinch(at: center)
        changePinch(factor: factor, at: center)
        endPinch()
    }

    func focus(on point: CGPoint, animated: Bool, resetScale: Bool = false) {
        cancelGestures()
        followsTarget = true
        node.removeAllActions()
        if resetScale { node.setScale(1) }
        let target = geometry.clampedCameraPosition(point, cameraScale: scale)
        if animated {
            let move = SKAction.move(to: target, duration: 0.45)
            move.timingMode = .easeInEaseOut
            node.run(move, withKey: "focus")
        } else { node.position = target }
    }

    func beginFollowing(_ point: CGPoint, animated: Bool) {
        guard !isPinching else { return }
        followsTarget = true
        let screen = geometry.screenPoint(point, camera: node.position, cameraScale: scale)
        let viewport = CGRect(origin: .zero, size: geometry.viewportSize).insetBy(dx: 35, dy: 45)
        if !viewport.contains(screen) { focus(on: point, animated: animated) }
    }

    /// Follow only outside a generous central band. Manual browsing suspends
    /// following until another explicit care/rest action or Find Cat request.
    @discardableResult
    func update(at time: TimeInterval, target: CGPoint?, draggingAt point: CGPoint?) -> Bool {
        let delta = CGFloat(min(1.0 / 15, max(0, time - (lastUpdate ?? time))))
        lastUpdate = time
        guard geometry.worldScale > 1, delta > 0, !isPanning, !isPinching else { return false }
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
                x: previous.x + min(1, max(-1, dx)) * 100 * delta * scale,
                y: previous.y + min(1, max(-1, dy)) * 100 * delta * scale), cameraScale: scale)
            return node.position != previous
        }
        guard followsTarget, let target, node.action(forKey: "focus") == nil else { return false }
        let halfX = geometry.viewportSize.width * 0.22 * scale
        let halfY = geometry.viewportSize.height * 0.20 * scale
        let desired = geometry.clampedCameraPosition(CGPoint(
            x: min(target.x + halfX, max(target.x - halfX, node.position.x)),
            y: min(target.y + halfY, max(target.y - halfY, node.position.y))), cameraScale: scale)
        let previous = node.position
        let fraction = min(1, delta * 4)
        node.position = CGPoint(x: previous.x + (desired.x - previous.x) * fraction,
                                y: previous.y + (desired.y - previous.y) * fraction)
        return node.position != previous
    }
}
