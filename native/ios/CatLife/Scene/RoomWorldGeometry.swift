import Foundation
import CoreGraphics

/// Physical sprites and saved positions belong to the world. Camera scaling
/// changes only their projection into the viewport.
struct RoomWorldGeometry: Sendable {
    let viewportSize: CGSize
    let worldScale: CGFloat

    var worldSize: CGSize {
        CGSize(width: viewportSize.width * worldScale, height: viewportSize.height * worldScale)
    }

    func clampedCameraScale(_ scale: CGFloat) -> CGFloat {
        guard worldScale > 1, scale.isFinite else { return 1 }
        return min(worldScale, max(0.625, scale))
    }

    func clampedCameraPosition(_ point: CGPoint, cameraScale: CGFloat = 1) -> CGPoint {
        let scale = clampedCameraScale(cameraScale)
        let halfWidth = viewportSize.width * scale / 2
        let halfHeight = viewportSize.height * scale / 2
        return CGPoint(x: min(worldSize.width - halfWidth, max(halfWidth, point.x)),
                       y: min(worldSize.height - halfHeight, max(halfHeight, point.y)))
    }

    func screenPoint(_ worldPoint: CGPoint, camera: CGPoint, cameraScale: CGFloat = 1) -> CGPoint {
        let scale = clampedCameraScale(cameraScale)
        return CGPoint(x: (worldPoint.x - camera.x) / scale + viewportSize.width / 2,
                       y: viewportSize.height / 2 - (worldPoint.y - camera.y) / scale)
    }

    func worldPoint(_ screenPoint: CGPoint, camera: CGPoint, cameraScale: CGFloat = 1) -> CGPoint {
        let scale = clampedCameraScale(cameraScale)
        return CGPoint(x: camera.x + (screenPoint.x - viewportSize.width / 2) * scale,
                       y: camera.y + (viewportSize.height / 2 - screenPoint.y) * scale)
    }

    func cameraPosition(keeping worldPoint: CGPoint, at screenPoint: CGPoint, cameraScale: CGFloat) -> CGPoint {
        let scale = clampedCameraScale(cameraScale)
        return clampedCameraPosition(CGPoint(
            x: worldPoint.x - (screenPoint.x - viewportSize.width / 2) * scale,
            y: worldPoint.y - (viewportSize.height / 2 - screenPoint.y) * scale), cameraScale: scale)
    }
}
