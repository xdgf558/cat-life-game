import Foundation

/// Captured at the visible, player-initiated arrival, never at an animation's completion.
public struct CatRestObservation: Codable, Equatable, Sendable {
    public let floor: HomeFloor
    public let position: NormalizedPoint
    public init(floor: HomeFloor, position: NormalizedPoint) { self.floor = floor; self.position = position }
    var isValid: Bool { GameSnapshot.isUnitPosition(position) }
}

public struct CatRestObservationReceipt: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let furnitureID: String
    public let kind: CatRestPreference
    public let location: CatRestObservation
    public let completedAt: Date
    public let matched: Bool
    var isValid: Bool {
        CatHabitState.validID(id) && CatHabitState.validID(furnitureID) && location.isValid
            && completedAt.timeIntervalSince1970.isFinite
    }
}

public struct CatPlayObservation: Codable, Equatable, Sendable {
    public let sessionID: String
    public let rhythm: CatPlayRhythm
    public let observedAt: Date
    public let matched: Bool
    var isValid: Bool { CatHabitState.validID(sessionID) && observedAt.timeIntervalSince1970.isFinite }
}

public struct CatHabitState: Codable, Equatable, Sendable {
    public var restClueSessionIDs: [String] = []
    public var playClueSessionIDs: [String] = []
    public var lastRestObservation: CatRestObservationReceipt?
    public var lastPlayObservation: CatPlayObservation?
    public var cornerFurnitureID: String?
    public var dismissedRestOfferID: String?
    public var memories: [CatMemory] = []
    public init() {}
    public var restConfirmed: Bool { restClueSessionIDs.count >= CatHabitCatalog.cluesToConfirm }
    public var playConfirmed: Bool { playClueSessionIDs.count >= CatHabitCatalog.cluesToConfirm }

    mutating func remember(_ kind: CatMemoryKind, at date: Date) {
        guard !memories.contains(where: { $0.kind == kind }) else { return }
        memories.append(CatMemory(kind: kind, createdAt: date))
    }
    static func validID(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.utf8.count <= 128
    }
    var isValid: Bool {
        [restClueSessionIDs, playClueSessionIDs].allSatisfy {
            $0.count <= CatHabitCatalog.cluesToConfirm && Set($0).count == $0.count && $0.allSatisfy(Self.validID)
        } && (lastRestObservation?.isValid ?? true) && (lastPlayObservation?.isValid ?? true)
            && (cornerFurnitureID.map(Self.validID) ?? true)
            && (dismissedRestOfferID.map(Self.validID) ?? true)
            && memories.count <= CatMemoryKind.allCases.count && Set(memories.map(\.kind)).count == memories.count
            && memories.allSatisfy { $0.createdAt.timeIntervalSince1970.isFinite }
            && (!memories.contains { $0.kind == .favoriteRest } || restConfirmed)
            && (!memories.contains { $0.kind == .favoritePlay } || playConfirmed)
    }
}
