import Foundation
import Observation
import CatGameCore

/// Work, action and recovery messages from the same moment stay visible together.
@MainActor
@Observable
final class GameNoticeCenter {
    private(set) var toast: String?
    private(set) var startupNotice: String?
    @ObservationIgnored private var task: Task<Void, Never>?

    func show(_ message: String, ready: Bool) {
        guard !message.isEmpty else { return }
        let previous = ready ? toast : startupNotice
        let combined = ((previous.map { [$0] } ?? []) + [message])
            .flatMap { $0.components(separatedBy: "\n") }
            .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
            .joined(separator: "\n")
        guard ready else { startupNotice = combined; return }
        task?.cancel()
        toast = combined
        task = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            self?.toast = nil
        }
    }

    func enterHome() {
        guard let notice = startupNotice else { return }
        startupNotice = nil
        show(notice, ready: true)
    }
}

@MainActor
enum GameActionNotice {
    static func message(for outcome: ActionOutcome, snapshot: GameSnapshot?) -> String {
        if outcome.succeeded {
            switch outcome.kind {
            case .feed: return GameStrings.text("action.feed")
            case .clean: return GameStrings.text("action.clean")
            case .play: return GameStrings.text("action.play")
            case .purchase:
                switch outcome.messageKey {
                case "shop.equipmentPurchased", "shop.furniturePurchased", "home.upgraded":
                    return GameStrings.text(outcome.messageKey)
                default: return GameStrings.text("action.purchase")
                }
            case .workStarted:
                if let active = snapshot?.player.activeWork, let job = WorkCatalog.job(id: active.jobID) {
                    if let quote = active.quote, quote.durationSeconds != quote.baseDurationSeconds {
                        return GameStrings.text("work.benefitsApplied") + " · "
                            + GameStrings.format("work.durationSeconds", quote.durationSeconds / 60, quote.durationSeconds % 60)
                    }
                    return GameStrings.format("career.started", GameStrings.text("jobs.\(job.id).name"), job.durationMinutes)
                }
                return GameStrings.text("action.workStarted")
            case .workFinished: return GameStrings.format("action.workFinished", outcome.amount)
            case .sleepStarted, .sleepEnded, .catRestStarted, .catRestEnded:
                return GameStrings.text(outcome.messageKey)
            case .layout: return GameStrings.text("layout.saved")
            case .none: return GameStrings.text(outcome.messageKey)
            }
        }
        switch outcome.failure {
        case .playerAvatarMissing, .equipmentItemMissing, .equipmentNotOwned,
             .sleepWorkActive, .workSleeping, .restInvalidFurniture,
             .workJobMissing, .workLevelRequired, .workProgressLimit,
             .shopItemMissing, .shopAlreadyOwned, .homeUpgradeUnavailable:
            return GameStrings.text(outcome.messageKey)
        case .shopLevelRequired, .shopFurnitureLimit, .homeLevelRequired:
            return GameStrings.format(outcome.messageKey, outcome.amount)
        case .roomCapacityReached:
            let canUpgrade = HomeCatalog.nextLevel(after: snapshot?.home.roomLevel ?? 1) != nil
            return GameStrings.format(canUpgrade ? outcome.messageKey : "room.capacityReachedMax", outcome.amount)
        case .roomInvalidPosition, .roomInvalidFurnitureLayout: return GameStrings.text("layout.invalid")
        case .shopGoldRequired: return GameStrings.text("action.insufficientGold")
        case .workStaminaRequired: return GameStrings.text("action.insufficientStamina")
        case .careFoodRequired: return GameStrings.text("care.needFood")
        case .careLitterRequired: return GameStrings.text("care.needLitter")
        case .careToyRequired: return GameStrings.text("care.needToy")
        case .shopInventoryFull: return GameStrings.text("action.inventoryFull")
        case .careCatMissing, .gameInvalidState, .restInvalidSession, .shopInvalidQuantity, .workAlreadyActive, nil:
            return GameStrings.text("action.failed")
        }
    }
}
