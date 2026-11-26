import Foundation

public enum MergeChain: String, Codable, CaseIterable, Hashable, Sendable {
    case cloth
    case food
    case wood

    public var generatorAssetName: String {
        switch self {
        case .cloth: "gen_toybox"
        case .food: "gen_foodbasket"
        case .wood: "gen_toolbox"
        }
    }
}

public struct MergeItem: Codable, Equatable, Hashable, Comparable, Sendable {
    public static let minLevel = 1
    public static let maxLevel = 5

    public let chain: MergeChain
    public let level: Int

    public init(chain: MergeChain, level: Int) {
        self.chain = chain
        self.level = min(Self.maxLevel, max(Self.minLevel, level))
    }

    public init?(rawID: String) {
        let parts = rawID.split(separator: "_")
        guard parts.count == 2,
              let chain = MergeChain(rawValue: String(parts[0])),
              let level = Int(parts[1]),
              (Self.minLevel...Self.maxLevel).contains(level) else {
            return nil
        }
        self.chain = chain
        self.level = level
    }

    public var rawID: String { "\(chain.rawValue)_\(level)" }
    public var assetName: String { "item_\(rawID)" }

    /// Level N costs 2^(N-1) energy units / tier-1 materials.
    public var energyValue: Int { 1 << (level - 1) }

    public var nextLevel: MergeItem? {
        level >= Self.maxLevel ? nil : MergeItem(chain: chain, level: level + 1)
    }

    public var isFood: Bool { chain == .food }
    public var isUsableAtHome: Bool { level >= DiaryBalance.default.cat.minUsableLevel }

    public static func < (lhs: MergeItem, rhs: MergeItem) -> Bool {
        lhs.rawID < rhs.rawID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let parsed = MergeItem(rawID: raw) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid MergeItem: \(raw)")
        }
        self = parsed
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawID)
    }

    public static let allItems: [MergeItem] = MergeChain.allCases.flatMap { chain in
        (minLevel...maxLevel).map { MergeItem(chain: chain, level: $0) }
    }
}

public enum RoomID: String, Codable, CaseIterable, Hashable, Sendable {
    case livingroom
    case bedroom
    case entrance
    case balcony

    public var backgroundBaseKey: String { "bg_home_\(rawValue)" }
}

public enum CustomerID: String, Codable, CaseIterable, Hashable, Sendable {
    case ajian
    case grandma
    case petshop

    public var avatarAssetName: String { "npc_\(rawValue)" }
}

public enum CatID: String, Codable, CaseIterable, Hashable, Sendable {
    case xiaoju
    case xueqiu

    public static let primary: CatID = .xiaoju
    public static let second: CatID = .xueqiu
}

public enum CatGrowthStage: String, Codable, CaseIterable, Sendable {
    case kitten
    case junior
    case adult

    public static func stage(forLevel level: Int) -> CatGrowthStage {
        if level >= 8 { return .adult }
        if level >= 4 { return .junior }
        return .kitten
    }

    public var displayScale: Double {
        switch self {
        case .kitten: 1.0
        case .junior: 1.08
        case .adult: 1.15
        }
    }
}

public enum FurnitureTheme: String, Codable, CaseIterable, Sendable {
    case basic
    case winter
    case spring
}

public enum FurnitureLayer: String, Codable, Hashable, Sendable {
    case flat
    case wall
    case floor
}

public enum FurnitureID: String, Codable, CaseIterable, Hashable, Sendable {
    // Purchasable basic furniture (12)
    case windowCushion = "window_cushion"
    case cardboardBox = "cardboard_box"
    case plant
    case tunnel
    case sofaCover = "sofa_cover"
    case foodBowl = "food_bowl"
    case catBed = "cat_bed"
    case rug
    case hammock
    case waterFountain = "water_fountain"
    case bookshelf
    case wallShelf = "wall_shelf"
    // Customer exclusive gifts (3)
    case giftAjian = "gift_ajian"
    case giftGrandma = "gift_grandma"
    case giftPetshop = "gift_petshop"
    // Theme furniture reserved for M2 schema stability (16)
    case winterKotatsu = "winter_kotatsu"
    case winterHeater = "winter_heater"
    case winterTeaTray = "winter_tea_tray"
    case winterKnitBed = "winter_knit_bed"
    case winterLamp = "winter_lamp"
    case winterBlanketRack = "winter_blanket_rack"
    case winterFireplaceMat = "winter_fireplace_mat"
    case winterFairyLights = "winter_fairy_lights"
    case springSakuraPot = "spring_sakura_pot"
    case springRattanChair = "spring_rattan_chair"
    case springFlowerRack = "spring_flower_rack"
    case springWindchime = "spring_windchime"
    case springPicnicMat = "spring_picnic_mat"
    case springTeaTable = "spring_tea_table"
    case springCloudPillow = "spring_cloud_pillow"
    case springCurtain = "spring_curtain"

    public var assetName: String { "furn_\(rawValue)" }
}

public enum AdSlot: String, Codable, CaseIterable, Hashable, Sendable {
    case material
    case wage
}

public enum AdPlayResult: String, Codable, Equatable, Sendable {
    case ended
    case closed
    case failed
}

public enum SceneLight: String, Codable, Equatable, Sendable {
    case day
    case night
    case rain

    public func backgroundAssetName(base: String) -> String {
        switch self {
        case .day: base
        case .night: "\(base)_night"
        case .rain: "\(base)_rain"
        }
    }
}

public enum DayClock {
    public static let minuteMs: Int64 = 60_000
    public static let hourMs: Int64 = 60 * minuteMs
    public static let dayMs: Int64 = 24 * hourMs

    public static func epochMs(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1000.0).rounded())
    }

    public static func date(fromEpochMs ms: Int64) -> Date {
        Date(timeIntervalSince1970: Double(ms) / 1000.0)
    }

    /// YYYYMMDD in the given calendar (defaults to device local time).
    public static func dayKey(for ms: Int64, calendar: Calendar = .current) -> Int {
        let comps = calendar.dateComponents([.year, .month, .day], from: date(fromEpochMs: ms))
        return (comps.year ?? 1970) * 10_000 + (comps.month ?? 1) * 100 + (comps.day ?? 1)
    }

    public static func hour(for ms: Int64, calendar: Calendar = .current) -> Int {
        calendar.component(.hour, from: date(fromEpochMs: ms))
    }

    /// Monotonic natural day prevents clock rollback from refreshing daily limits.
    public static func monotonicDayKey(now ms: Int64, lastDayKey: Int, calendar: Calendar = .current) -> Int {
        max(dayKey(for: ms, calendar: calendar), lastDayKey)
    }

    public static func daysTogether(createdAt ms: Int64, now: Int64, calendar: Calendar = .current) -> Int {
        let startKey = dayKey(for: ms, calendar: calendar)
        let nowKey = dayKey(for: now, calendar: calendar)
        let diff = (utcDayNumber(nowKey) - utcDayNumber(startKey))
        return max(1, diff + 1)
    }

    private static func utcDayNumber(_ key: Int) -> Int {
        var comps = DateComponents()
        comps.calendar = Calendar(identifier: .gregorian)
        comps.timeZone = TimeZone(secondsFromGMT: 0)
        comps.year = key / 10_000
        comps.month = (key / 100) % 100
        comps.day = key % 100
        guard let date = comps.date else { return 0 }
        return Int((date.timeIntervalSince1970 / 86_400.0).rounded())
    }
}
