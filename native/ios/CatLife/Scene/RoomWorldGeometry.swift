import Foundation
import CoreGraphics

/// The viewport fixes sprite sizes. The world grows independently, and a 1×
/// camera exposes it without changing saved world-relative positions.
struct RoomWorldGeometry: Sendable {
    let viewportSize: CGSize
    let worldScale: CGFloat

    var worldSize: CGSize {
        CGSize(width: viewportSize.width * worldScale, height: viewportSize.height * worldScale)
    }

    func clampedCameraPosition(_ point: CGPoint) -> CGPoint {
        CGPoint(x: min(worldSize.width - viewportSize.width / 2, max(viewportSize.width / 2, point.x)),
                y: min(worldSize.height - viewportSize.height / 2, max(viewportSize.height / 2, point.y)))
    }

    func screenPoint(_ worldPoint: CGPoint, camera: CGPoint) -> CGPoint {
        CGPoint(x: worldPoint.x - camera.x + viewportSize.width / 2,
                y: viewportSize.height / 2 - (worldPoint.y - camera.y))
    }

    func worldPoint(_ screenPoint: CGPoint, camera: CGPoint) -> CGPoint {
        CGPoint(x: screenPoint.x + camera.x - viewportSize.width / 2,
                y: camera.y + viewportSize.height / 2 - screenPoint.y)
    }
}
