import Foundation
import Observation
import CatGameCore

@Observable
@MainActor
final class GameLocalization {
    static let shared = GameLocalization()
    var language: GameLanguage = .preferred(in: Locale.preferredLanguages)

    private init() {}
}

@MainActor
enum GameStrings {
    static func text(_ key: String) -> String {
        let dictionary: [String: String]
        switch GameLocalization.shared.language {
        case .simplifiedChinese: dictionary = chinese
        case .traditionalChinese: dictionary = traditionalChinese
        case .english: dictionary = english
        }
        return dictionary[key] ?? chinese[key] ?? key
    }

    static func format(_ key: String, _ values: CVarArg...) -> String {
        String(
            format: text(key),
            locale: Locale(identifier: GameLocalization.shared.language.rawValue),
            arguments: values
        )
    }

    static func itemName(_ item: MergeItem) -> String {
        text("item.\(item.rawID)")
    }

    static func chainName(_ chain: MergeChain) -> String {
        text("chain.\(chain.rawValue)")
    }

    static func generatorName(_ chain: MergeChain) -> String {
        text("gen.\(chain.rawValue)")
    }

    static func furnitureName(_ id: FurnitureID) -> String {
        text("furn.\(id.rawValue)")
    }

    static func customerName(_ id: CustomerID) -> String {
        text("customer.\(id.rawValue)")
    }

    static func roomName(_ id: RoomID) -> String {
        text("room.\(id.rawValue)")
    }

    static func photoTitle(_ id: String) -> String {
        text("photo.\(id).title")
    }

    static func photoCaption(_ id: String) -> String {
        text("photo.\(id).caption")
    }

    static func photoCategoryName(_ category: PhotoCategory) -> String {
        text("diary.cat.\(category.rawValue)")
    }

    static func wishLabel(_ goal: WishGoal) -> String {
        switch goal {
        case .pet: text("wish.goal.pet")
        case .play(let item): format("wish.goal.play", itemName(item))
        case .feed(let item): format("wish.goal.feed", itemName(item))
        }
    }

    static func wishHint(_ goal: WishGoal, bonusXP: Int) -> String {
        switch goal {
        case .pet: format("wish.hint.pet", bonusXP)
        case .play(let item): format("wish.hint.play", itemName(item), bonusXP)
        case .feed(let item): format("wish.hint.feed", itemName(item), bonusXP)
        }
    }

    static func unlockDescription(_ rule: UnlockRule) -> String {
        switch rule.kind {
        case .chain(let chain): format("unlock.chain", generatorName(chain))
        case .room(let room): format("unlock.room", roomName(room))
        case .customer(let customer): format("unlock.customer", customerName(customer))
        }
    }
}
