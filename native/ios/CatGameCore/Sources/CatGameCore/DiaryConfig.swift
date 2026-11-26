import Foundation

public enum UnlockKind: Codable, Equatable, Hashable, Sendable {
    case chain(MergeChain)
    case room(RoomID)
    case customer(CustomerID)
}

public struct UnlockRule: Codable, Equatable, Hashable, Sendable {
    public let level: Int
    public let kind: UnlockKind

    public init(level: Int, kind: UnlockKind) {
        self.level = level
        self.kind = kind
    }
}

/// Core balance numbers mirrored from cat-work-diary `src/core/config.ts`.
public struct DiaryBalance: Equatable, Sendable {
    public struct Board: Equatable, Sendable {
        public let cols: Int
        public let rows: Int
        public var cellCount: Int { cols * rows }
    }

    public struct Energy: Equatable, Sendable {
        public let max: Int
        public let regenIntervalMs: Int64
    }

    public struct Generator: Equatable, Sendable {
        public let cost: Int
        public let level2Chance: Double
    }

    public struct Orders: Equatable, Sendable {
        public let activeCount: Int
        public let minItems: Int
        public let maxItems: Int
        public let minLevel: Int
        public let maxLevel: Int
        public let fullLevelFromCatLevel: Int
        public let wagePerEnergy: Double
        public let wageRoundTo: Int
        public let freeRerollsPerDay: Int
        public let giftEveryOrders: Int
    }

    public struct Cat: Equatable, Sendable {
        public let satietyDecayPerMs: Double
        public let hungryBelow: Double
        public let moodBaseline: Double
        public let moodDriftPerMs: Double
        public let rareMomentMoodAbove: Double
        public let petCooldownMs: Int64
        public let toyUses: Int
        public let minUsableLevel: Int
        public let feedSatiety: [Double]
        public let feedMood: [Double]
        public let playMood: Double
        public let petMood: Double
        public let furnitureMood: Double
        public let xpPerInteraction: Int
        public let xpFirstReaction: Int
        public let wishBonusXP: Int
        public let levelXP: [Int]
        public let maxLevel: Int
    }

    public struct Home: Equatable, Sendable {
        public let dailyMomentChance: Double
        public let dailyMomentChanceHappy: Double
        public let offlineNoteAfterMs: Int64
        public let rainyDayChance: Double
    }

    public let board: Board
    public let energy: Energy
    public let generator: Generator
    public let unlocks: [UnlockRule]
    public let orders: Orders
    public let sellRatio: Double
    public let cat: Cat
    public let home: Home

    public static let `default` = DiaryBalance(
        board: .init(cols: 6, rows: 7),
        energy: .init(max: 30, regenIntervalMs: 2 * DayClock.minuteMs),
        generator: .init(cost: 1, level2Chance: 0.1),
        unlocks: [
            .init(level: 1, kind: .chain(.cloth)),
            .init(level: 1, kind: .room(.livingroom)),
            .init(level: 1, kind: .customer(.ajian)),
            .init(level: 1, kind: .customer(.grandma)),
            .init(level: 2, kind: .chain(.food)),
            .init(level: 3, kind: .room(.bedroom)),
            .init(level: 3, kind: .customer(.petshop)),
            .init(level: 4, kind: .chain(.wood)),
            .init(level: 6, kind: .room(.entrance)),
            .init(level: 8, kind: .room(.balcony)),
        ],
        orders: .init(
            activeCount: 3,
            minItems: 1,
            maxItems: 2,
            minLevel: 3,
            maxLevel: 5,
            fullLevelFromCatLevel: 3,
            wagePerEnergy: 2.5,
            wageRoundTo: 5,
            freeRerollsPerDay: 1,
            giftEveryOrders: 20
        ),
        sellRatio: 0.5,
        cat: .init(
            satietyDecayPerMs: 100.0 / Double(12 * DayClock.hourMs),
            hungryBelow: 20,
            moodBaseline: 50,
            moodDriftPerMs: 1.0 / Double(10 * DayClock.minuteMs),
            rareMomentMoodAbove: 80,
            petCooldownMs: 5 * DayClock.minuteMs,
            toyUses: 3,
            minUsableLevel: 3,
            feedSatiety: [0, 0, 0, 20, 50, 100],
            feedMood: [0, 0, 0, 0, 10, 25],
            playMood: 10,
            petMood: 5,
            furnitureMood: 15,
            xpPerInteraction: 1,
            xpFirstReaction: 5,
            wishBonusXP: 3,
            levelXP: [0, 13, 66, 109, 172, 245, 328, 421, 524, 637],
            maxLevel: 10
        ),
        home: .init(
            dailyMomentChance: 0.25,
            dailyMomentChanceHappy: 0.40,
            offlineNoteAfterMs: 30 * DayClock.minuteMs,
            rainyDayChance: 0.25
        )
    )
}

public struct AdRemoteConfig: Codable, Equatable, Sendable {
    public var adEnabled: Bool
    public var perSlotDailyLimit: [AdSlot: Int]
    public var totalDailyLimit: Int
    public var minOfferIntervalMs: Int64
    public var newbieOrdersRequired: Int
    public var refusalLimit: Int
    public var materialMaxCount: Int
    public var wageMinAmount: Int

    public init(
        adEnabled: Bool = true,
        perSlotDailyLimit: [AdSlot: Int] = [.material: 2, .wage: 2],
        totalDailyLimit: Int = 4,
        minOfferIntervalMs: Int64 = 90_000,
        newbieOrdersRequired: Int = 2,
        refusalLimit: Int = 3,
        materialMaxCount: Int = 8,
        wageMinAmount: Int = 20
    ) {
        self.adEnabled = adEnabled
        self.perSlotDailyLimit = perSlotDailyLimit
        self.totalDailyLimit = totalDailyLimit
        self.minOfferIntervalMs = minOfferIntervalMs
        self.newbieOrdersRequired = newbieOrdersRequired
        self.refusalLimit = refusalLimit
        self.materialMaxCount = materialMaxCount
        self.wageMinAmount = wageMinAmount
    }

    public static let `default` = AdRemoteConfig()

    public func dailyLimit(for slot: AdSlot) -> Int {
        perSlotDailyLimit[slot] ?? 0
    }
}

public protocol RandomSource: Sendable {
    /// Returns a value in [0, 1).
    mutating func nextUnit() -> Double
}

public extension RandomSource {
    mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        let span = range.upperBound - range.lowerBound + 1
        let offset = min(span - 1, max(0, Int(floor(nextUnit() * Double(span)))))
        return range.lowerBound + offset
    }

    mutating func pick<T>(from list: [T]) -> T? {
        guard !list.isEmpty else { return nil }
        return list[nextInt(in: 0...(list.count - 1))]
    }
}

/// Mulberry32 matching WeChat core `seededRng` for deterministic tests & day weather.
public struct SeededRNG: RandomSource, Sendable {
    private var state: UInt32

    public init(seed: UInt32) {
        self.state = seed
    }

    public init(seed: Int) {
        self.state = UInt32(truncatingIfNeeded: seed)
    }

    public mutating func nextUnit() -> Double {
        state &+= 0x6D2B79F5
        var t = state
        t = (t ^ (t >> 15)) &* (t | 1)
        t ^= t &+ ((t ^ (t >> 7)) &* (t | 61))
        let value = t ^ (t >> 14)
        return Double(value) / 4_294_967_296.0
    }
}

public struct SequenceRNG: RandomSource, Sendable {
    private let values: [Double]
    private var index = 0

    public init(_ values: [Double]) {
        self.values = values.isEmpty ? [0.0] : values
    }

    public mutating func nextUnit() -> Double {
        let value = values[index % values.count]
        index += 1
        return value
    }
}

public struct SystemRandomSource: RandomSource, Sendable {
    public init() {}
    public mutating func nextUnit() -> Double {
        Double.random(in: 0..<1)
    }
}
