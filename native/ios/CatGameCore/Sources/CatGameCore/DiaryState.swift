import Foundation

public struct CustomerOrder: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let customer: CustomerID
    public let items: [MergeItem]
    public let wage: Int

    public init(id: String, customer: CustomerID, items: [MergeItem], wage: Int) {
        self.id = id
        self.customer = customer
        self.items = items
        self.wage = wage
    }
}

public struct CraftTarget: Codable, Equatable, Sendable {
    public let id: Int
    public let item: MergeItem
    public let orderID: String?

    public init(id: Int, item: MergeItem, orderID: String? = nil) {
        self.id = id
        self.item = item
        self.orderID = orderID
    }
}

public enum AdReward: Codable, Equatable, Sendable {
    case materials(item: MergeItem, count: Int, orderID: String?)
    case coins(amount: Int)
}

public enum ClaimStatus: String, Codable, Equatable, Sendable {
    case pending
    case granted
    case cancelled
}

public struct AdClaim: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let key: String
    public let slot: AdSlot
    public let reward: AdReward
    public var status: ClaimStatus
    public let createdAt: Int64
    public let dayKey: Int
}

public struct OwnedToy: Codable, Equatable, Identifiable, Sendable {
    public var id: String { "\(item.rawID)-\(usesLeft)" }
    public let item: MergeItem
    public var usesLeft: Int

    public init(item: MergeItem, usesLeft: Int) {
        self.item = item
        self.usesLeft = usesLeft
    }
}

public struct CatFlags: Codable, Equatable, Sendable {
    public var toyWornOut: Bool
    public var hungry: Bool
    public var fullBelly: Bool

    public init(toyWornOut: Bool = false, hungry: Bool = false, fullBelly: Bool = false) {
        self.toyWornOut = toyWornOut
        self.hungry = hungry
        self.fullBelly = fullBelly
    }
}

public struct DiaryCatState: Codable, Equatable, Sendable {
    public let id: CatID
    public var satiety: Double
    public var mood: Double
    public var xp: Int
    public var level: Int
    public var updatedAt: Int64
    public var lastPetAt: Int64?
    public var playCount: Int
    public var feedCount: Int
    public var petCount: Int
    public var itemsTried: [MergeItem]
    public var furnitureUsed: [FurnitureID]
    public var flags: CatFlags

    public init(id: CatID, now: Int64, balance: DiaryBalance = .default) {
        self.id = id
        self.satiety = 80
        self.mood = balance.cat.moodBaseline
        self.xp = 0
        self.level = 1
        self.updatedAt = now
        self.lastPetAt = nil
        self.playCount = 0
        self.feedCount = 0
        self.petCount = 0
        self.itemsTried = []
        self.furnitureUsed = []
        self.flags = CatFlags()
    }
}

public enum WishGoal: Codable, Equatable, Hashable, Sendable {
    case play(MergeItem)
    case feed(MergeItem)
    case pet
}

public struct DailyWish: Codable, Equatable, Sendable {
    public let dayKey: Int
    public let goal: WishGoal
    public var completed: Bool
}

public struct PlacedFurniture: Codable, Equatable, Identifiable, Sendable {
    public let id: FurnitureID
    public var room: RoomID
    public var x: Double
    public var bottom: Double
    public var flip: Bool

    public init(id: FurnitureID, room: RoomID, x: Double, bottom: Double, flip: Bool = false) {
        self.id = id
        self.room = room
        self.x = x
        self.bottom = bottom
        self.flip = flip
    }
}

public struct EnergyState: Codable, Equatable, Sendable {
    public var current: Int
    public var updatedAt: Int64
}

public struct BoardState: Codable, Equatable, Sendable {
    public var cells: [MergeItem?]
    public var pending: [MergeItem]
}

public struct OrdersState: Codable, Equatable, Sendable {
    public var active: [CustomerOrder]
    public var nextID: Int
    public var rerollsUsedToday: Int
    public var completedTotal: Int
    public var customerProgress: [CustomerID: Int]
    public var materialAdOrderIDs: [String]
}

public struct HomeState: Codable, Equatable, Sendable {
    public var toys: [OwnedToy]
    public var food: [MergeItem]
    public var furnitureOwned: [FurnitureID]
    public var layout: [PlacedFurniture]
    public var lastVisitAt: Int64?
    public var wishlist: FurnitureID?
    public var wish: DailyWish?
}

public struct DiaryAlbumState: Codable, Equatable, Sendable {
    public var photos: [String]
    public var photoDates: [String: Int64]
}

public struct AdsState: Codable, Equatable, Sendable {
    public var used: [AdSlot: Int]
    public var refusals: [AdSlot: Int]
    public var disabledToday: [AdSlot]
    public var lastOfferAt: Int64?
    public var offeredTargetIDs: [Int]
    public var offeredMaterialKeys: [String]
    public var ledger: [AdClaim]
    public var nextClaimSeq: Int
    public var claimedKeys: [String]

    public static func empty() -> AdsState {
        AdsState(
            used: [.material: 0, .wage: 0],
            refusals: [.material: 0, .wage: 0],
            disabledToday: [],
            lastOfferAt: nil,
            offeredTargetIDs: [],
            offeredMaterialKeys: [],
            ledger: [],
            nextClaimSeq: 1,
            claimedKeys: []
        )
    }
}

public enum TutorialStep: String, Equatable, Sendable {
    case meet
    case gather
    case merge
    case bringHome
    case play
    case finish
    case done
}

public struct DiaryGameState: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var createdAt: Int64
    public var updatedAt: Int64
    public var dayKey: Int
    public var coins: Int
    public var tutorialActive: Bool
    public var energy: EnergyState
    public var board: BoardState
    public var target: CraftTarget?
    public var nextTargetID: Int
    public var orders: OrdersState
    public var cats: [CatID: DiaryCatState]
    public var home: HomeState
    public var diary: DiaryAlbumState
    public var ads: AdsState
    public var settings: GameSettings

    public static func fresh(
        now: Int64,
        balance: DiaryBalance = .default,
        calendar: Calendar = .current
    ) -> DiaryGameState {
        DiaryGameState(
            schemaVersion: currentSchemaVersion,
            createdAt: now,
            updatedAt: now,
            dayKey: DayClock.dayKey(for: now, calendar: calendar),
            coins: 0,
            tutorialActive: true,
            energy: EnergyState(current: balance.energy.max, updatedAt: now),
            board: BoardState(cells: Array(repeating: nil, count: balance.board.cellCount), pending: []),
            target: nil,
            nextTargetID: 1,
            orders: OrdersState(
                active: [],
                nextID: 1,
                rerollsUsedToday: 0,
                completedTotal: 0,
                customerProgress: [.ajian: 0, .grandma: 0, .petshop: 0],
                materialAdOrderIDs: []
            ),
            cats: [.xiaoju: DiaryCatState(id: .xiaoju, now: now, balance: balance)],
            home: HomeState(
                toys: [],
                food: [],
                furnitureOwned: [],
                layout: [],
                lastVisitAt: nil,
                wishlist: nil,
                wish: nil
            ),
            diary: DiaryAlbumState(photos: [], photoDates: [:]),
            ads: .empty(),
            settings: GameSettings()
        )
    }

    public var primaryCat: DiaryCatState {
        get { cats[.xiaoju] ?? DiaryCatState(id: .xiaoju, now: updatedAt) }
        set { cats[.xiaoju] = newValue }
    }

    public var progressLevel: Int { primaryCat.level }

    public var isValid: Bool {
        guard schemaVersion == Self.currentSchemaVersion else { return false }
        guard coins >= 0, dayKey >= 19700101 else { return false }
        guard board.cells.count == DiaryBalance.default.board.cellCount else { return false }
        guard energy.current >= 0, energy.current <= DiaryBalance.default.energy.max else { return false }
        guard let xiaoju = cats[.xiaoju], xiaoju.level >= 1, xiaoju.satiety.isFinite, xiaoju.mood.isFinite else {
            return false
        }
        return true
    }

    @discardableResult
    public mutating func rollDay(now: Int64, calendar: Calendar = .current) -> Bool {
        let key = DayClock.monotonicDayKey(now: now, lastDayKey: dayKey, calendar: calendar)
        guard key != dayKey else { return false }
        dayKey = key
        orders.rerollsUsedToday = 0
        ads.used = [.material: 0, .wage: 0]
        ads.refusals = [.material: 0, .wage: 0]
        ads.disabledToday = []
        ads.offeredTargetIDs = []
        ads.offeredMaterialKeys = []
        return true
    }

    public mutating func addPhoto(_ id: String, now: Int64) {
        if !diary.photos.contains(id) {
            diary.photos.append(id)
        }
        if diary.photoDates[id] == nil {
            diary.photoDates[id] = now
        }
    }

    /// Derived tutorial step (matches `src/core/tutorial.ts`, never gets stuck).
    public var tutorialStep: TutorialStep {
        guard tutorialActive else { return .done }
        if diary.photos.contains(DiaryCatalog.tutorialPhotoID) { return .finish }
        if home.toys.contains(where: { $0.item == DiaryCatalog.tutorialToy }) { return .play }

        var clothValue = 0
        var started = !board.pending.isEmpty
        for item in board.cells.compactMap({ $0 }) {
            if item == DiaryCatalog.tutorialToy { return .bringHome }
            started = true
            if item.chain == .cloth && item.level < DiaryCatalog.tutorialToy.level {
                clothValue += item.energyValue
            }
        }
        if clothValue >= DiaryCatalog.tutorialToy.energyValue { return .merge }
        let cat = primaryCat
        let metCat = cat.lastPetAt != nil || cat.playCount > 0 || cat.feedCount > 0
            || !home.toys.isEmpty || !home.food.isEmpty
        return (started || metCat) ? .gather : .meet
    }
}
