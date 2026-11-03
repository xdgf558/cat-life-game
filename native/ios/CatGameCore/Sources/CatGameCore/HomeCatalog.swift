import Foundation

public struct HomeLevel: Identifiable, Equatable, Sendable {
    public let level: Int
    public let capacity: Int
    public let worldScale: Double
    /// Gold required to enter this level; the initial room costs nothing.
    public let upgradeCost: Int
    public let requiredPlayerLevel: Int
    public var id: Int { level }
}

public enum HomeCatalog {
    public static let all: [HomeLevel] = [
        .init(level: 1, capacity: 9, worldScale: 1, upgradeCost: 0, requiredPlayerLevel: 1),
        .init(level: 2, capacity: 12, worldScale: 1.25, upgradeCost: 450, requiredPlayerLevel: 2),
        .init(level: 3, capacity: 16, worldScale: 1.5, upgradeCost: 900, requiredPlayerLevel: 4)
    ]

    public static func level(_ level: Int) -> HomeLevel? { all.first { $0.level == level } }

    public static func nextLevel(after current: Int) -> HomeLevel? {
        guard let index = all.firstIndex(where: { $0.level == current }), index + 1 < all.count else { return nil }
        return all[index + 1]
    }

    /// Preserve pre-upgrade saves that already contain more items than today's
    /// limit. They can still be moved or put away; only new placements are gated.
    static func allowsLayout(_ proposed: [FurniturePlacement], replacing previous: [FurniturePlacement],
                             roomLevel: Int) -> Bool {
        guard let room = level(roomLevel) else { return false }
        if proposed.count <= room.capacity { return true }
        let previousIDs = Set(previous.map(\.itemID))
        return proposed.allSatisfy { previousIDs.contains($0.itemID) }
    }
}
