import Foundation
import CoreGraphics
import SpriteKit
import UIKit
import CatGameCore

/// Art coordinates keep furniture attached to the same room floor on every screen.
struct RoomArtworkTransform: Sendable {
    let sceneSize: CGSize
    let artworkSize: CGSize
    let viewportSize: CGSize

    init(sceneSize: CGSize, artworkSize: CGSize, viewportSize: CGSize? = nil) {
        self.sceneSize = sceneSize
        self.artworkSize = artworkSize
        self.viewportSize = viewportSize ?? sceneSize
    }

    var scale: CGFloat { max(sceneSize.width / artworkSize.width, sceneSize.height / artworkSize.height) }
    var visualScale: CGFloat { max(viewportSize.width / artworkSize.width, viewportSize.height / artworkSize.height) }
    func point(_ normalized: NormalizedPoint) -> CGPoint {
        CGPoint(x: sceneSize.width / 2 + (normalized.x - 0.5) * artworkSize.width * scale,
                y: sceneSize.height / 2 + (0.5 - normalized.y) * artworkSize.height * scale)
    }
    func normalized(_ point: CGPoint) -> NormalizedPoint {
        .init(x: min(1, max(0, 0.5 + (point.x - sceneSize.width / 2) / (artworkSize.width * scale))),
              y: min(1, max(0, 0.5 - (point.y - sceneSize.height / 2) / (artworkSize.height * scale))))
    }
}

struct RoomFurnitureSpec: Sendable {
    let width: CGFloat
    let footprint: CGSize
    let anchorY: CGFloat
    let isWall: Bool

    static func forItem(_ item: FurnitureItem) -> Self {
        switch item.kind {
        case .cabinet: return .init(width: 244, footprint: CGSize(width: 186, height: 78), anchorY: 0.12, isWall: false)
        case .catTree: return .init(width: 225, footprint: CGSize(width: 160, height: 82), anchorY: 0.07, isWall: false)
        case .catBed: return .init(width: 344, footprint: CGSize(width: 292, height: 144), anchorY: 0.23, isWall: false)
        case .wallFlower: return .init(width: 110, footprint: CGSize(width: 110, height: 170), anchorY: 0.5, isWall: true)
        case .wallCat: return .init(width: 108, footprint: CGSize(width: 108, height: 148), anchorY: 0.5, isWall: true)
        case .plant:
            let factor: CGFloat = item.id == "plantSmall" ? 0.78 : 1
            return .init(width: 138 * factor, footprint: CGSize(width: 70 * factor, height: 42 * factor), anchorY: 0.09, isWall: false)
        case .floorCushion: return .init(width: 184, footprint: CGSize(width: 154, height: 80), anchorY: 0.42, isWall: false)
        case .flowerStool: return .init(width: 190, footprint: CGSize(width: 126, height: 68), anchorY: 0.14, isWall: false)
        }
    }
}

/// This value contains no nodes or UIKit objects and can be sent to a worker.
struct RoomFurnitureWorld: Sendable {
    let transform: RoomArtworkTransform
    let catWidth: CGFloat
    let bowlSize: CGSize
    let bowlPosition: CGPoint
    let items: [FurnitureItem]
    let placements: [FurniturePlacement]

    var roomFloor: RoomFloor {
        RoomFloor(sceneSize: transform.sceneSize, artworkSize: transform.artworkSize,
                  catWidth: catWidth, bowlSize: bowlSize, furnitureObstacles: floorObstacles())
    }

    func item(_ id: String) -> FurnitureItem? { items.first { $0.id == id } }
    func center(_ id: String) -> CGPoint? { placements.first { $0.itemID == id }.map { transform.point($0.position) } }

    func footprint(_ item: FurnitureItem) -> CGSize {
        let spec = RoomFurnitureSpec.forItem(item)
        return CGSize(width: spec.footprint.width * transform.visualScale, height: spec.footprint.height * transform.visualScale)
    }

    func rectangle(_ item: FurnitureItem, at center: CGPoint) -> CGRect {
        let size = footprint(item)
        return CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2,
                      width: size.width, height: size.height)
    }

    func floorObstacles(excluding excludedID: String? = nil) -> [CGRect] {
        placements.compactMap { placement in
            guard placement.itemID != excludedID, let item = item(placement.itemID),
                  !RoomFurnitureSpec.forItem(item).isWall else { return nil }
            return rectangle(item, at: transform.point(placement.position))
        }
    }

    var wallPolygon: [CGPoint] {
        let points: [NormalizedPoint] = [
            .init(x: 0.47, y: 0.11), .init(x: 0.98, y: 0.278),
            .init(x: 0.98, y: 0.512), .init(x: 0.47, y: 0.343)
        ]
        return RoomFloor.clip(points.map(transform.point), to: CGRect(x: 8, y: 8,
                          width: max(1, transform.sceneSize.width - 16),
                          height: max(1, transform.sceneSize.height - 16)))
    }

    func placementNavigator(for id: String?, catAt cat: CGPoint) -> RoomNavigation {
        let floor = roomFloor
        guard let id, let item = item(id) else { return floor.placementNavigator(catAt: cat) }
        let spec = RoomFurnitureSpec.forItem(item)
        if spec.isWall {
            let obstacles = placements.compactMap { placement -> CGRect? in
                guard placement.itemID != id, let other = self.item(placement.itemID),
                      RoomFurnitureSpec.forItem(other).isWall else { return nil }
                return rectangle(other, at: transform.point(placement.position)).insetBy(dx: -3, dy: -3)
            }
            return RoomNavigation(floor: wallPolygon, obstacles: obstacles, footprint: footprint(item), cellSize: 7)
        }
        let catRect = CGRect(x: cat.x - floor.catFootprint.width / 2 - 3,
                             y: cat.y - floor.catFootprint.height / 2 - 3,
                             width: floor.catFootprint.width + 6, height: floor.catFootprint.height + 6)
        return RoomNavigation(floor: floor.polygon,
                              obstacles: floorObstacles(excluding: id).map { $0.insetBy(dx: -2, dy: -2) }
                                + [floor.bowlObstacle(at: bowlPosition).insetBy(dx: -2, dy: -2), catRect],
                              footprint: footprint(item), cellSize: 7)
    }

    func replacing(_ id: String, with center: CGPoint) -> Self {
        var updated = placements.filter { $0.itemID != id }
        updated.append(.init(itemID: id, position: transform.normalized(center)))
        return Self(transform: transform, catWidth: catWidth, bowlSize: bowlSize, bowlPosition: bowlPosition,
                    items: items, placements: updated)
    }

    func resolve(id: String?, near point: CGPoint, catAt cat: CGPoint,
                 placement: RoomNavigation) -> RoomFurnitureResolution? {
        let floor = roomFloor
        if id == nil {
            guard let result = floor.resolvePlacement(near: point, catAt: cat, placement: placement) else { return nil }
            return .init(id: nil, center: result.center, floor: floor, navigation: result.navigation)
        }
        guard let id, let item = item(id) else { return nil }
        let nearest = placement.nearestWalkable(to: point).map { [$0] } ?? []
        let candidates = nearest + placement.walkablePoints.sorted {
            hypot($0.x - point.x, $0.y - point.y) < hypot($1.x - point.x, $1.y - point.y)
        }
        for candidate in candidates {
            guard !Task<Never, Never>.isCancelled else { return nil }
            let proposedWorld = replacing(id, with: candidate)
            let proposedFloor = proposedWorld.roomFloor
            let navigator = proposedFloor.navigator(bowlAt: bowlPosition, precomputeGrid: false)
            guard navigator.isWalkable(cat) else { continue }
            if !RoomFurnitureSpec.forItem(item).isWall,
               proposedFloor.feedingPlan(from: cat, bowlAt: bowlPosition, navigator: navigator, firstReachable: true) == nil {
                continue
            }
            // Beds and cushions need enough room for both entering and waking
            // up. Validate this on the same worker as the feeding route.
            if [.catBed, .floorCushion].contains(item.kind),
               proposedWorld.restVisit(to: id, from: cat) == nil { continue }
            return .init(id: id, center: candidate, floor: proposedFloor,
                         navigation: proposedFloor.navigator(bowlAt: bowlPosition))
        }
        return nil
    }
}

struct RoomFurnitureResolution: Sendable {
    let id: String?
    let center: CGPoint
    let floor: RoomFloor
    let navigation: RoomNavigation
}

/// A visit owns permission to enter exactly one furniture footprint. The
/// ordinary navigation remains unchanged for every other activity.
struct RoomFurnitureRest: Sendable {
    let item: FurnitureItem
    let plan: FurnitureRestPlan
    let navigation: RoomNavigation
    let target: CGRect
    let elevation: CGFloat
    /// Measured visible front-mattress band, independent of the actor's pose.
    let entrySupportBand: CGRect?
}

extension RoomFurnitureWorld {
    func restVisit(to id: String, from start: CGPoint) -> RoomFurnitureRest? {
        guard let item = item(id), [.catBed, .floorCushion].contains(item.kind),
              let center = center(id) else { return nil }
        let floor = roomFloor
        let target = rectangle(item, at: center)
        let otherObstacles = floorObstacles(excluding: id) + [floor.bowlObstacle(at: bowlPosition)]
        var point = center
        var elevation = catWidth * 0.14
        var supportBand: CGRect?
        if item.kind == .catBed {
            let spec = RoomFurnitureSpec.forItem(item)
            let width = spec.width * transform.visualScale
            // The unchanged bed PNG's alpha>24 crop is (86,44)..(1477,961).
            // The low yellow opening is at y≈805 in source pixels, about .17
            // up the cropped texture. The green vertical side is not support.
            let height = width * 917 / 1391
            let edgeY = center.y + height * (0.17 - spec.anchorY)
            supportBand = CGRect(x: center.x - width * 0.22,
                                 y: center.y + height * (0.155 - spec.anchorY),
                                 width: width * 0.44, height: height * 0.05)
            let visualRestY = center.y + target.height * 0.16 + catWidth * 0.06
            let stageY = target.minY - floor.catFootprint.height / 2
                - max(1, floor.catFootprint.height * 0.15)
            // Front-paw support holds at .14 of the validated entry. Solve
            // ground projection + physical elevation against the visible rim;
            // using only the old .06C sleeping offset left both paws on floor.
            let contactProgress: CGFloat = 0.14
            elevation = (edgeY - stageY - contactProgress * (visualRestY - stageY))
                / (1 - contactProgress)
            // A narrow/tall crop can make the bed taller relative to the cat.
            // This is a step-up, not a jump: reject an unreachable ledge rather
            // than compressing the forelegs through themselves or faking contact.
            guard elevation.isFinite, elevation > 0, elevation <= catWidth * 0.55 else { return nil }
            point.y = visualRestY - elevation
        }
        guard let plan = FurnitureRestPlanner.plan(floor: floor.polygon, obstacles: otherObstacles,
                                                  target: target, footprint: floor.catFootprint,
                                                  start: start, restPoint: point) else { return nil }
        return .init(item: item, plan: plan,
                     navigation: RoomNavigation(floor: floor.polygon, obstacles: otherObstacles,
                                                footprint: floor.catFootprint, cellSize: 7, precomputeGrid: false),
                     target: target, elevation: elevation, entrySupportBand: supportBand)
    }
}

/// Register the generated transparent sprites once, retaining their original PNGs.
@MainActor
enum RoomFurnitureArt {
    private static var textures: [FurnitureKind: SKTexture] = [:]

    static func texture(for kind: FurnitureKind) -> SKTexture {
        if let texture = textures[kind] { return texture }
        let name = FurnitureCatalog.metadata(for: kind).assetName
        let full = SKTexture(imageNamed: name)
        guard let cg = UIImage(named: name)?.cgImage else { return full }
        let width = cg.width, height = cg.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let found: CGRect? = bytes.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
            var minX = width, minY = height, maxX = 0, maxY = 0
            let pixels = buffer.bindMemory(to: UInt8.self)
            for y in 0..<height {
                for x in 0..<width where pixels[(y * width + x) * 4 + 3] > 24 {
                    minX = min(minX, x); minY = min(minY, y)
                    maxX = max(maxX, x); maxY = max(maxY, y)
                }
            }
            guard minX <= maxX, minY <= maxY else { return nil }
            return CGRect(x: CGFloat(minX) / CGFloat(width), y: CGFloat(height - maxY - 1) / CGFloat(height),
                          width: CGFloat(maxX - minX + 1) / CGFloat(width), height: CGFloat(maxY - minY + 1) / CGFloat(height))
        }
        let texture = found.map { SKTexture(rect: $0, in: full) } ?? full
        textures[kind] = texture
        return texture
    }
}
