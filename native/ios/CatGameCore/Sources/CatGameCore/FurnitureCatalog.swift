import Foundation

public enum FurnitureKind: String, Codable, CaseIterable, Hashable, Sendable {
    case cabinet, catTree, catBed, wallFlower, wallCat, plant, floorCushion, flowerStool

    public var supportsMirroring: Bool { self != .wallFlower && self != .wallCat }
}

public enum FurnitureOrientation: String, Codable, CaseIterable, Hashable, Sendable {
    case normal, mirrored
}

/// Ownership is independent of placement: putting an item away never deletes it.
public struct FurnitureItem: Codable, Equatable, Hashable, Identifiable, Sendable {
    public var id: String
    public var kind: FurnitureKind
    public var orientation: FurnitureOrientation

    public init(id: String, kind: FurnitureKind, orientation: FurnitureOrientation = .normal) {
        self.id = id
        self.kind = kind
        self.orientation = orientation
    }

    private enum CodingKeys: String, CodingKey { case id, kind, orientation }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        kind = try values.decode(FurnitureKind.self, forKey: .kind)
        // Absent legacy orientation keeps the artwork; explicit malformed values are not reset.
        orientation = values.contains(.orientation)
            ? try values.decode(FurnitureOrientation.self, forKey: .orientation) : .normal
        guard orientation == .normal || kind.supportsMirroring else { throw SaveRepositoryError.invalidSnapshot }
    }
}

/// Positions use the original 1024×1536 room artwork, normalized from its top left.
/// Floor items use their ground-contact center; wall art uses its image center.
public struct FurniturePlacement: Codable, Equatable, Identifiable, Sendable {
    public var itemID: String
    public var position: NormalizedPoint
    public var id: String { itemID }

    public init(itemID: String, position: NormalizedPoint) {
        self.itemID = itemID
        self.position = position
    }
}

public struct FurnitureMetadata: Equatable, Sendable {
    public let kind: FurnitureKind
    public let isWall: Bool
    public let assetName: String
    public let nameKey: String
}

/// Stable IDs and display metadata only. Rendering sizes and collision shapes
/// belong to the scene, and the food bowl keeps its existing independent field.
public enum FurnitureCatalog {
    public static var all: [FurnitureMetadata] { FurnitureKind.allCases.map { metadata(for: $0) } }

    public static func metadata(for kind: FurnitureKind) -> FurnitureMetadata {
        let asset: String
        switch kind {
        case .cabinet: asset = "furniture-cabinet"
        case .catTree: asset = "furniture-cat-tree"
        case .catBed: asset = "furniture-cat-bed"
        case .wallFlower: asset = "furniture-wall-flower"
        case .wallCat: asset = "furniture-wall-cat"
        case .plant: asset = "furniture-plant"
        case .floorCushion: asset = "furniture-floor-cushion"
        case .flowerStool: asset = "furniture-flower-stool"
        }
        return FurnitureMetadata(kind: kind, isWall: kind == .wallFlower || kind == .wallCat,
                                 assetName: asset, nameKey: "furniture.\(kind.rawValue)")
    }

    public static let defaultItems: [FurnitureItem] = [
        .init(id: "cabinet", kind: .cabinet),
        .init(id: "catTree", kind: .catTree),
        .init(id: "catBed", kind: .catBed),
        .init(id: "wallFlower", kind: .wallFlower),
        .init(id: "wallCat", kind: .wallCat),
        .init(id: "plantLarge", kind: .plant),
        .init(id: "plantSmall", kind: .plant),
        .init(id: "floorCushion", kind: .floorCushion),
        .init(id: "flowerStool", kind: .flowerStool)
    ]

    public static let defaultPlacements: [FurniturePlacement] = [
        .init(itemID: "cabinet", position: .init(x: 0.5, y: 0.425)),
        .init(itemID: "catTree", position: .init(x: 0.84, y: 0.6)),
        .init(itemID: "catBed", position: .init(x: 0.27, y: 0.6)),
        .init(itemID: "wallFlower", position: .init(x: 0.625, y: 0.25)),
        .init(itemID: "wallCat", position: .init(x: 0.77, y: 0.31)),
        .init(itemID: "plantLarge", position: .init(x: 0.32, y: 0.445)),
        .init(itemID: "plantSmall", position: .init(x: 0.88, y: 0.68)),
        .init(itemID: "floorCushion", position: .init(x: 0.22, y: 0.7)),
        .init(itemID: "flowerStool", position: .init(x: 0.25, y: 0.78))
    ]
}
