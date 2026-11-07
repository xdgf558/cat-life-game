import SwiftUI
import CatGameCore

extension SupplyKind {
    var asset: String {
        switch self {
        case .food: "bowl-full"
        case .litter: "icon-clean"
        case .toy: "icon-play"
        case .premiumFood: "supply-premium-food"
        case .premiumLitter: "supply-premium-litter"
        }
    }
    var symbol: String { SupplyCatalog.definition(for: self).symbol }
    var nameKey: String { SupplyCatalog.definition(for: self).nameKey }
    var tint: Color {
        switch self {
        case .food, .premiumFood: RoomTheme.gold
        case .litter: RoomTheme.sky
        case .premiumLitter: RoomTheme.lilac
        case .toy: RoomTheme.coral
        }
    }
    var countID: String {
        switch self {
        case .food: "inventoryFoodCount"
        case .litter: "inventoryLitterCount"
        case .toy: "inventoryToyUses"
        case .premiumFood: "inventoryPremiumFoodCount"
        case .premiumLitter: "inventoryPremiumLitterCount"
        }
    }
    var countKey: String { nameKey }
    var actionKey: String {
        switch self { case .food, .premiumFood: "care.feed"; case .litter, .premiumLitter: "care.clean"; case .toy: "care.play" }
    }
    private var identifierName: String {
        switch self { case .food: "Food"; case .litter: "Litter"; case .toy: "Toy"; case .premiumFood: "PremiumFood"; case .premiumLitter: "PremiumLitter" }
    }
    var useID: String { "use\(identifierName)Button" }
    var restockID: String { "restock\(identifierName)Button" }
    var buyID: String { "buy\(identifierName)Button" }
}
