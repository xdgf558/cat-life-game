import Foundation

public enum ActionKind: String, Codable, Sendable {
    case feed, clean, play, purchase, workStarted, workFinished, layout, none
    case sleepStarted, sleepEnded, catRestStarted, catRestEnded
}

public enum ActionFailure: String, Equatable, Sendable {
    case careCatMissing = "care.catMissing"
    case careFoodRequired = "care.foodRequired"
    case careLitterRequired = "care.litterRequired"
    case careToyRequired = "care.toyRequired"
    case equipmentItemMissing = "equipment.itemMissing"
    case equipmentNotOwned = "equipment.notOwned"
    case gameInvalidState = "game.invalidState"
    case playerAvatarMissing = "player.avatarMissing"
    case restInvalidFurniture = "rest.invalidFurniture"
    case restInvalidSession = "rest.invalidSession"
    case roomInvalidFurnitureLayout = "room.invalidFurnitureLayout"
    case roomInvalidPosition = "room.invalidPosition"
    case shopGoldRequired = "shop.goldRequired"
    case shopInvalidQuantity = "shop.invalidQuantity"
    case shopInventoryFull = "shop.inventoryFull"
    case sleepWorkActive = "sleep.workActive"
    case workAlreadyActive = "work.alreadyActive"
    case workJobMissing = "work.jobMissing"
    case workLevelRequired = "work.levelRequired"
    case workProgressLimit = "work.progressLimit"
    case workSleeping = "work.sleeping"
    case workStaminaRequired = "work.staminaRequired"
}

public struct ActionOutcome: Equatable, Sendable {
    public var kind: ActionKind
    public var succeeded: Bool
    public var messageKey: String
    /// Resource units consumed/granted, or gold paid out for completed work.
    public var amount: Int
    public let failure: ActionFailure?

    public init(kind: ActionKind = .none, succeeded: Bool = true,
                messageKey: String = "", amount: Int = 0, failure: ActionFailure? = nil) {
        self.kind = kind
        self.succeeded = failure == nil && succeeded
        self.messageKey = failure?.rawValue ?? messageKey
        self.amount = amount
        self.failure = failure
    }
}
