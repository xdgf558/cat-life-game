import Foundation

public enum CatAppearance: String, Codable, CaseIterable, Sendable {
    case orange, cow
}

public struct CatAdoptionOffer: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let appearance: CatAppearance
    public let price: Int
    public let requiredPlayerLevel: Int
    public let requiredRoomLevel: Int
}

public enum CatCatalog {
    public static let initialCatID = "cat_001"
    public static let cowCatID = "cat_002"
    public static let adoptionOffers: [CatAdoptionOffer] = [
        .init(id: cowCatID, name: "牛奶", appearance: .cow, price: 300,
              requiredPlayerLevel: 2, requiredRoomLevel: 2)
    ]

    public static func adoptionOffer(catID: String) -> CatAdoptionOffer? {
        adoptionOffers.first { $0.id == catID }
    }
}
