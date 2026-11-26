import Foundation

public struct FurnitureDef: Equatable, Sendable {
    public let id: FurnitureID
    public let room: RoomID
    /// `nil` for customer-gifted furniture not sold in the shop.
    public let price: Int?
    public let theme: FurnitureTheme
    public let defaultX: Double
    public let defaultBottom: Double
    public let layer: FurnitureLayer

    public init(
        id: FurnitureID,
        room: RoomID,
        price: Int?,
        theme: FurnitureTheme = .basic,
        defaultX: Double,
        defaultBottom: Double,
        layer: FurnitureLayer
    ) {
        self.id = id
        self.room = room
        self.price = price
        self.theme = theme
        self.defaultX = defaultX
        self.defaultBottom = defaultBottom
        self.layer = layer
    }
}

public struct CustomerDef: Equatable, Sendable {
    public let id: CustomerID
    public let gift: FurnitureID
}

public enum PhotoCategory: String, Codable, CaseIterable, Hashable, Sendable {
    case toy
    case furniture
    case food
    case daily
}

public enum DailyCondition: String, Codable, Hashable, Sendable {
    case any
    case morning
    case night
    case rain
    case happy
    case toyCollector
}

public enum PhotoTrigger: Equatable, Hashable, Sendable {
    case firstItem(MergeItem)
    case firstFurniture(FurnitureID)
    case playCount(Int)
    case toyWornOut
    case feedCount(Int)
    case fullBelly
    case firstHungry
    case daily(DailyCondition)
}

public struct PhotoDef: Equatable, Hashable, Identifiable, Sendable {
    public let id: String
    public let category: PhotoCategory
    public let trigger: PhotoTrigger
    public let cat: CatID

    public init(id: String, category: PhotoCategory, trigger: PhotoTrigger, cat: CatID = .xiaoju) {
        self.id = id
        self.category = category
        self.trigger = trigger
        self.cat = cat
    }

    public var isRare: Bool {
        if case .daily(let condition) = trigger { return condition != .any }
        return false
    }
}

public struct OfflineNoteDef: Equatable, Identifiable, Sendable {
    public let id: String
    public let weather: SceneLight?
    public let furniture: FurnitureID?
}

public enum CatBubbleMood: String, CaseIterable, Sendable {
    case normal
    case sleep
    case hungry
}

public enum DiaryCatalog {
    public static let customers: [CustomerDef] = [
        .init(id: .ajian, gift: .giftAjian),
        .init(id: .grandma, gift: .giftGrandma),
        .init(id: .petshop, gift: .giftPetshop),
    ]

    public static func customer(_ id: CustomerID) -> CustomerDef {
        customers.first { $0.id == id }!
    }

    public static let furniture: [FurnitureDef] = [
        // Basic purchasable (12)
        .init(id: .windowCushion, room: .livingroom, price: 120, defaultX: 0.16, defaultBottom: 0.63, layer: .floor),
        .init(id: .cardboardBox, room: .livingroom, price: 150, defaultX: 0.19, defaultBottom: 0.79, layer: .floor),
        .init(id: .plant, room: .livingroom, price: 180, defaultX: 0.07, defaultBottom: 0.72, layer: .floor),
        .init(id: .tunnel, room: .livingroom, price: 200, defaultX: 0.78, defaultBottom: 0.80, layer: .floor),
        .init(id: .sofaCover, room: .livingroom, price: 220, defaultX: 0.80, defaultBottom: 0.60, layer: .wall),
        .init(id: .foodBowl, room: .livingroom, price: 250, defaultX: 0.30, defaultBottom: 0.86, layer: .floor),
        .init(id: .catBed, room: .bedroom, price: 280, defaultX: 0.20, defaultBottom: 0.75, layer: .floor),
        .init(id: .rug, room: .bedroom, price: 320, defaultX: 0.48, defaultBottom: 0.87, layer: .flat),
        .init(id: .hammock, room: .bedroom, price: 380, defaultX: 0.80, defaultBottom: 0.40, layer: .wall),
        .init(id: .waterFountain, room: .livingroom, price: 450, defaultX: 0.68, defaultBottom: 0.86, layer: .floor),
        .init(id: .bookshelf, room: .bedroom, price: 520, defaultX: 0.80, defaultBottom: 0.87, layer: .floor),
        .init(id: .wallShelf, room: .livingroom, price: 600, defaultX: 0.72, defaultBottom: 0.33, layer: .wall),
        // Customer gifts (3)
        .init(id: .giftAjian, room: .livingroom, price: nil, defaultX: 0.68, defaultBottom: 0.67, layer: .floor),
        .init(id: .giftGrandma, room: .livingroom, price: nil, defaultX: 0.30, defaultBottom: 0.63, layer: .floor),
        .init(id: .giftPetshop, room: .bedroom, price: nil, defaultX: 0.77, defaultBottom: 0.74, layer: .floor),
    ]

    private static let furnitureMap: [FurnitureID: FurnitureDef] = Dictionary(
        uniqueKeysWithValues: furniture.map { ($0.id, $0) }
    )

    public static func furnitureDef(_ id: FurnitureID) -> FurnitureDef? {
        furnitureMap[id]
    }

    public static var shopFurniture: [FurnitureDef] {
        furniture.filter { $0.price != nil }
    }

    public static let tutorialToy = MergeItem(chain: .cloth, level: 3)
    public static let tutorialPhotoID = "photo_toy_01"

    /// Core 36 diary photos (1:1 with WeChat `PHOTOS`).
    public static let photos: [PhotoDef] = {
        var list: [PhotoDef] = [
            .init(id: "photo_toy_01", category: .toy, trigger: .firstItem(MergeItem(chain: .cloth, level: 3))),
            .init(id: "photo_toy_02", category: .toy, trigger: .firstItem(MergeItem(chain: .cloth, level: 4))),
            .init(id: "photo_toy_03", category: .toy, trigger: .firstItem(MergeItem(chain: .cloth, level: 5))),
            .init(id: "photo_toy_04", category: .toy, trigger: .firstItem(MergeItem(chain: .wood, level: 3))),
            .init(id: "photo_toy_05", category: .toy, trigger: .firstItem(MergeItem(chain: .wood, level: 4))),
            .init(id: "photo_toy_06", category: .toy, trigger: .firstItem(MergeItem(chain: .wood, level: 5))),
            .init(id: "photo_toy_07", category: .toy, trigger: .playCount(10)),
            .init(id: "photo_toy_08", category: .toy, trigger: .toyWornOut),
        ]
        for def in furniture where def.price != nil && def.theme == .basic {
            list.append(.init(id: "photo_furn_\(def.id.rawValue)", category: .furniture, trigger: .firstFurniture(def.id)))
        }
        list.append(contentsOf: [
            .init(id: "photo_food_01", category: .food, trigger: .firstItem(MergeItem(chain: .food, level: 3))),
            .init(id: "photo_food_02", category: .food, trigger: .firstItem(MergeItem(chain: .food, level: 4))),
            .init(id: "photo_food_03", category: .food, trigger: .firstItem(MergeItem(chain: .food, level: 5))),
            .init(id: "photo_food_04", category: .food, trigger: .feedCount(5)),
            .init(id: "photo_food_05", category: .food, trigger: .fullBelly),
            .init(id: "photo_food_06", category: .food, trigger: .firstHungry),
            .init(id: "photo_daily_01", category: .daily, trigger: .daily(.morning)),
            .init(id: "photo_daily_02", category: .daily, trigger: .daily(.rain)),
            .init(id: "photo_daily_03", category: .daily, trigger: .daily(.night)),
            .init(id: "photo_daily_04", category: .daily, trigger: .daily(.any)),
            .init(id: "photo_daily_05", category: .daily, trigger: .daily(.any)),
            .init(id: "photo_daily_06", category: .daily, trigger: .daily(.any)),
            .init(id: "photo_daily_07", category: .daily, trigger: .daily(.happy)),
            .init(id: "photo_daily_08", category: .daily, trigger: .daily(.any)),
            .init(id: "photo_daily_09", category: .daily, trigger: .daily(.any)),
            .init(id: "photo_daily_10", category: .daily, trigger: .daily(.toyCollector)),
        ])
        return list
    }()

    private static let photoMap: [String: PhotoDef] = Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0) })

    public static func photoDef(_ id: String) -> PhotoDef? {
        photoMap[id]
    }

    /// 30 offline notes keyed by localization ID (`note.01`...`note.30`).
    public static let offlineNotes: [OfflineNoteDef] = [
        .init(id: "note.01", weather: nil, furniture: nil),
        .init(id: "note.02", weather: nil, furniture: nil),
        .init(id: "note.03", weather: nil, furniture: nil),
        .init(id: "note.04", weather: nil, furniture: nil),
        .init(id: "note.05", weather: nil, furniture: nil),
        .init(id: "note.06", weather: nil, furniture: nil),
        .init(id: "note.07", weather: nil, furniture: nil),
        .init(id: "note.08", weather: nil, furniture: nil),
        .init(id: "note.09", weather: nil, furniture: nil),
        .init(id: "note.10", weather: nil, furniture: nil),
        .init(id: "note.11", weather: nil, furniture: nil),
        .init(id: "note.12", weather: nil, furniture: nil),
        .init(id: "note.13", weather: .rain, furniture: nil),
        .init(id: "note.14", weather: .rain, furniture: nil),
        .init(id: "note.15", weather: .rain, furniture: nil),
        .init(id: "note.16", weather: .rain, furniture: nil),
        .init(id: "note.17", weather: .rain, furniture: nil),
        .init(id: "note.18", weather: .rain, furniture: nil),
        .init(id: "note.19", weather: .night, furniture: nil),
        .init(id: "note.20", weather: .night, furniture: nil),
        .init(id: "note.21", weather: .night, furniture: nil),
        .init(id: "note.22", weather: .night, furniture: nil),
        .init(id: "note.23", weather: .night, furniture: nil),
        .init(id: "note.24", weather: .night, furniture: nil),
        .init(id: "note.25", weather: nil, furniture: .plant),
        .init(id: "note.26", weather: nil, furniture: .windowCushion),
        .init(id: "note.27", weather: nil, furniture: .bookshelf),
        .init(id: "note.28", weather: nil, furniture: .waterFountain),
        .init(id: "note.29", weather: nil, furniture: .sofaCover),
        .init(id: "note.30", weather: nil, furniture: .tunnel),
    ]

    public static func bubbleKeys(for mood: CatBubbleMood) -> [String] {
        switch mood {
        case .normal: (1...10).map { String(format: "bubble.normal.%02d", $0) }
        case .sleep: (1...4).map { String(format: "bubble.sleep.%02d", $0) }
        case .hungry: (1...3).map { String(format: "bubble.hungry.%02d", $0) }
        }
    }

    public static func pickBubbleKey(mood: CatBubbleMood, excluding last: String?, randomUnit: Double) -> String {
        let pool = bubbleKeys(for: mood)
        let choices = pool.count > 1 ? pool.filter { $0 != last } : pool
        let idx = min(choices.count - 1, max(0, Int(floor(randomUnit * Double(choices.count)))))
        return choices[idx]
    }
}
