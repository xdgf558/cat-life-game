import Foundation

public struct NeighborRelationship: Codable, Equatable, Sendable {
    public var friendship: Int
    public var visitedToday: Bool
    public var giftsGivenToday: Int
    public var totalVisitCount: Int
    public var totalGiftCount: Int
    public var rewardedStageLevels: [Int]

    public init(friendship: Int = 0, visitedToday: Bool = false, giftsGivenToday: Int = 0,
                totalVisitCount: Int = 0, totalGiftCount: Int = 0, rewardedStageLevels: [Int] = []) {
        self.friendship = friendship
        self.visitedToday = visitedToday
        self.giftsGivenToday = giftsGivenToday
        self.totalVisitCount = totalVisitCount
        self.totalGiftCount = totalGiftCount
        self.rewardedStageLevels = rewardedStageLevels
    }

    public var stage: FriendshipStage { CommunityCatalog.stage(friendship: friendship) }
    public var nextStage: FriendshipStage? { CommunityCatalog.nextStage(friendship: friendship) }
    public var canEarnVisitFriendship: Bool { !visitedToday && friendship < 100 }
    public var remainingGiftsToday: Int { max(0, CommunityCatalog.dailyGiftLimit - giftsGivenToday) }

    var isValid: Bool {
        (0...100).contains(friendship)
            && (0...CommunityCatalog.dailyGiftLimit).contains(giftsGivenToday)
            && (0...GameSnapshot.maximumGold).contains(totalVisitCount)
            && (0...GameSnapshot.maximumGold).contains(totalGiftCount)
            && (!visitedToday || totalVisitCount > 0)
            && giftsGivenToday <= totalGiftCount
            && rewardedStageLevels.count <= 32
            && Set(rewardedStageLevels).count == rewardedStageLevels.count
            && rewardedStageLevels.allSatisfy { (2...1_000).contains($0) }
    }
}

public struct CommunityState: Codable, Equatable, Sendable {
    public var relationships: [String: NeighborRelationship]

    public init(relationships: [String: NeighborRelationship]? = nil) {
        self.relationships = relationships ?? Dictionary(uniqueKeysWithValues:
            CommunityCatalog.neighbors.map { ($0.id, NeighborRelationship()) })
    }

    public func relationship(for neighborID: String) -> NeighborRelationship {
        relationships[neighborID] ?? NeighborRelationship()
    }
    public var dailyVisitCount: Int { relationships.values.filter(\.visitedToday).count }
    public var dailyGiftCount: Int { relationships.values.reduce(0) { $0 + $1.giftsGivenToday } }
    public var totalVisitCount: Int { min(GameSnapshot.maximumGold, relationships.values.reduce(0) { $0 + $1.totalVisitCount }) }
    public var totalGiftCount: Int { min(GameSnapshot.maximumGold, relationships.values.reduce(0) { $0 + $1.totalGiftCount }) }
    public var highestFriendship: Int { relationships.values.map(\.friendship).max() ?? 0 }

    mutating func startNewDay() {
        for id in relationships.keys {
            relationships[id]?.visitedToday = false
            relationships[id]?.giftsGivenToday = 0
        }
    }

    var isValid: Bool {
        guard relationships.count <= 32,
              CommunityCatalog.neighbors.allSatisfy({ relationships[$0.id] != nil }),
              relationships.allSatisfy({ id, relationship in
                  !id.isEmpty && id.utf8.count <= 80 && relationship.isValid
              }) else { return false }
        return true
    }
}
