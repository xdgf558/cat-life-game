import Foundation
import CoreGraphics

enum RoomViewAngle: Int, CaseIterable, Hashable, Sendable {
    case left = -1
    case front = 0
    case right = 1

    var previous: Self { Self(rawValue: rawValue - 1) ?? .right }
    var next: Self { Self(rawValue: rawValue + 1) ?? .left }
    var radians: CGFloat { CGFloat(rawValue) * .pi / 10 }
}

/// Changes presentation only: navigation, actors and saved positions keep their original coordinates.
struct RoomViewProjection: Sendable {
    let worldSize: CGSize
    let angle: RoomViewAngle
    let frontFloor: RoomFrontFloorProjection?

    var wallHeight: CGFloat {
        if angle == .front, let frontFloor { return frontFloor.destination.height * 0.34 / 0.66 }
        return min(worldSize.width * 0.43, worldSize.height * 0.27)
    }

    init(worldSize: CGSize, angle: RoomViewAngle, frontFloor: RoomFrontFloorProjection? = nil) {
        self.worldSize = worldSize
        self.angle = angle
        self.frontFloor = frontFloor
    }

    func project(_ point: CGPoint) -> CGPoint {
        if angle == .front { return frontFloor?.project(point) ?? point }
        let center = CGPoint(x: worldSize.width / 2, y: worldSize.height / 2)
        let offset = vector(CGPoint(x: point.x - center.x, y: point.y - center.y))
        return CGPoint(x: center.x + offset.x, y: center.y + offset.y)
    }

    func unproject(_ point: CGPoint) -> CGPoint {
        if angle == .front { return frontFloor?.unproject(point) ?? point }
        let center = CGPoint(x: worldSize.width / 2, y: worldSize.height / 2)
        let offset = transform(CGPoint(x: point.x - center.x, y: point.y - center.y), radians: -angle.radians)
        return CGPoint(x: center.x + offset.x, y: center.y + offset.y)
    }

    /// Rectification is piecewise affine, so a local displacement must retain its origin.
    func vector(_ delta: CGPoint, at origin: CGPoint = .zero) -> CGPoint {
        if angle == .front, frontFloor != nil {
            let a = project(origin), b = project(CGPoint(x: origin.x + delta.x, y: origin.y + delta.y))
            return CGPoint(x: b.x - a.x, y: b.y - a.y)
        }
        return transform(delta, radians: angle.radians)
    }

    /// Ground depth excludes a sprite's height, so tall furniture still sorts by its feet.
    func projectedDepth(_ point: CGPoint) -> CGFloat { project(point).y }

    /// Wall decorations retain their original wall coordinates; only their displayed height is remapped.
    func wallPoint(_ point: CGPoint) -> CGPoint {
        guard sourceWallHeight > 0, wallHeight > 0 else { return project(point) }
        if angle == .front, let frontFloor {
            let ground = wallGround(at: point.x)
            return CGPoint(x: frontFloor.project(ground).x,
                           y: frontFloor.destination.maxY + (point.y - ground.y) * wallHeight / sourceWallHeight)
        }
        let ground = wallGround(at: point.x)
        let projected = project(ground)
        return CGPoint(x: projected.x, y: projected.y + (point.y - ground.y) * wallHeight / sourceWallHeight)
    }

    func unprojectWallPoint(_ point: CGPoint) -> CGPoint {
        guard sourceWallHeight > 0, wallHeight > 0 else { return unproject(point) }
        if angle == .front, let frontFloor {
            // Legal decorations lie on one straight legacy right-wall edge, whose rectified x mapping is affine.
            let leftX = worldSize.width / 2, rightX = worldSize.width * 0.75
            let a = frontFloor.project(wallGround(at: leftX)), b = frontFloor.project(wallGround(at: rightX))
            guard abs(b.x - a.x) > 0.00001 else { return unproject(point) }
            let x = leftX + (point.x - a.x) * (rightX - leftX) / (b.x - a.x)
            let ground = wallGround(at: x)
            return CGPoint(x: x, y: ground.y + (point.y - frontFloor.destination.maxY) * sourceWallHeight / wallHeight)
        }
        let a = project(wallGround(at: 0)), b = project(wallGround(at: worldSize.width))
        guard abs(b.x - a.x) > 0.00001 else { return unproject(point) }
        let x = (point.x - a.x) / (b.x - a.x) * worldSize.width
        let ground = wallGround(at: x)
        return CGPoint(x: x, y: ground.y + (point.y - project(ground).y) * sourceWallHeight / wallHeight)
    }

    // Calibration uses room-empty.png's 1024×1536 top-left pixel coordinates and RoomArtworkTransform's aspect fill.
    // The retained 384px span remaps legacy decoration heights; it is separate from the projected wallHeight.
    // When replacing/reframing that artwork, recalibrate these values with RoomFloor.sourceFloor and RoomFurnitureWorld.wallPolygon.
    private var artworkScale: CGFloat { max(worldSize.width / 1024, worldSize.height / 1536) }
    private var sourceWallHeight: CGFloat { 384 * artworkScale }

    /// Legacy right-wall baseline shared by decoration heights and the upstairs window anchor.
    func wallGround(at x: CGFloat) -> CGPoint {
        // Right-wall/floor seam: source (442,530)→(1024,825); world y points upward.
        // 70=1024/2−442, 238=1536/2−530, and 295/582=(825−530)/(1024−442).
        let back = CGPoint(x: worldSize.width / 2 - 70 * artworkScale,
                           y: worldSize.height / 2 + 238 * artworkScale)
        return CGPoint(x: x, y: back.y - (x - back.x) * 295 / 582)
    }

    private func transform(_ point: CGPoint, radians: CGFloat) -> CGPoint {
        guard radians != 0 else { return point }
        // Undo the original 30° isometric basis, rotate its floor plane, then restore that basis.
        let cosine = cos(radians), sine = sin(radians), ratio = sqrt(CGFloat(3))
        return CGPoint(x: cosine * point.x - ratio * sine * point.y,
                       y: sine * point.x / ratio + cosine * point.y)
    }
}
