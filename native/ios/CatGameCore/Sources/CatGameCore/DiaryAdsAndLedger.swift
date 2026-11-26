import Foundation

// MARK: - Reward Ledger (idempotent grant + crash recovery)

public enum DiaryLedger {
    private static let ledgerKeep = 50
    private static let claimedKeysKeep = 200

    public static func createPending(
        _ state: inout DiaryGameState,
        slot: AdSlot,
        reward: AdReward,
        now: Int64,
        key: String
    ) -> String {
        let id = "c\(state.dayKey)-\(state.ads.nextClaimSeq)"
        state.ads.nextClaimSeq += 1
        state.ads.ledger.append(
            AdClaim(id: id, key: key, slot: slot, reward: reward, status: .pending, createdAt: now, dayKey: state.dayKey)
        )
        prune(&state)
        return id
    }

    public static func findClaim(_ state: DiaryGameState, id: String) -> AdClaim? {
        state.ads.ledger.first { $0.id == id }
    }

    public static func isClaimed(_ state: DiaryGameState, key: String) -> Bool {
        state.ads.claimedKeys.contains(key)
    }

    public static func pendingClaims(_ state: DiaryGameState) -> [AdClaim] {
        state.ads.ledger.filter { $0.status == .pending }
    }

    public static func grantOnce(_ state: inout DiaryGameState, id: String) -> Bool {
        guard let idx = state.ads.ledger.firstIndex(where: { $0.id == id }),
              state.ads.ledger[idx].status == .pending else {
            return false
        }
        let claim = state.ads.ledger[idx]
        if isClaimed(state, key: claim.key) {
            state.ads.ledger[idx].status = .cancelled
            return false
        }
        state.ads.ledger[idx].status = .granted
        applyReward(&state, reward: claim.reward)
        state.ads.used[claim.slot, default: 0] += 1
        state.ads.claimedKeys.append(claim.key)
        if state.ads.claimedKeys.count > claimedKeysKeep {
            state.ads.claimedKeys.removeFirst(state.ads.claimedKeys.count - claimedKeysKeep)
        }
        if case .materials(_, _, let orderID) = claim.reward, let orderID {
            if !state.orders.materialAdOrderIDs.contains(orderID) {
                state.orders.materialAdOrderIDs.append(orderID)
            }
        }
        return true
    }

    public static func cancelClaim(_ state: inout DiaryGameState, id: String) -> Bool {
        guard let idx = state.ads.ledger.firstIndex(where: { $0.id == id }),
              state.ads.ledger[idx].status == .pending else {
            return false
        }
        state.ads.ledger[idx].status = .cancelled
        return true
    }

    /// Cancels unfinished pending claims on launch without granting unverified rewards.
    @discardableResult
    public static func recoverPendingOnStartup(_ state: inout DiaryGameState) -> Int {
        var count = 0
        for idx in state.ads.ledger.indices where state.ads.ledger[idx].status == .pending {
            state.ads.ledger[idx].status = .cancelled
            count += 1
        }
        return count
    }

    private static func applyReward(_ state: inout DiaryGameState, reward: AdReward) {
        switch reward {
        case .coins(let amount):
            state.coins += amount
        case .materials(let item, let count, _):
            for _ in 0..<count { DiaryBoard.placeItem(&state, item: item) }
        }
    }

    private static func prune(_ state: inout DiaryGameState) {
        guard state.ads.ledger.count > ledgerKeep else { return }
        let excess = state.ads.ledger.count - ledgerKeep
        var removed = 0
        state.ads.ledger = state.ads.ledger.filter { claim in
            if removed < excess && claim.status != .pending {
                removed += 1
                return false
            }
            return true
        }
    }
}

// MARK: - Ad Offers & Frequency Caps

public enum AdQuotaBlock: String, Equatable, Sendable {
    case disabled
    case newbie
    case limit
    case refused
    case interval
}

public struct MaterialOffer: Equatable, Sendable {
    public let targetID: Int
    public let target: MergeItem
    public let orderID: String?
    public let item: MergeItem
    public let count: Int
    public let completedUnits: Int
    public let totalUnits: Int
    public let catIsHungry: Bool

    public var key: String { "material:target:\(targetID)" }
}

public struct WageOffer: Equatable, Sendable {
    public let orderID: String
    public let amount: Int
    public let wishlistShortAfter: Int?
    public let furniture: FurnitureID?
    public let furniturePrice: Int?

    public var key: String { "wage:order:\(orderID)" }
}

public enum AdOffer: Equatable, Sendable {
    case material(MaterialOffer)
    case wage(WageOffer)

    public var slot: AdSlot {
        switch self {
        case .material: .material
        case .wage: .wage
        }
    }

    public var key: String {
        switch self {
        case .material(let offer): offer.key
        case .wage(let offer): offer.key
        }
    }

    public var reward: AdReward {
        switch self {
        case .material(let offer):
            .materials(item: offer.item, count: offer.count, orderID: offer.orderID)
        case .wage(let offer):
            .coins(amount: offer.amount)
        }
    }
}

public enum DiaryAds {
    public static func remainingForSlot(_ state: DiaryGameState, slot: AdSlot, config: AdRemoteConfig) -> Int {
        let pending = DiaryLedger.pendingClaims(state)
        func used(_ s: AdSlot) -> Int {
            (state.ads.used[s] ?? 0) + pending.filter { $0.slot == s }.count
        }
        let totalUsed = AdSlot.allCases.reduce(0) { $0 + used($1) }
        return max(0, min(config.dailyLimit(for: slot) - used(slot), config.totalDailyLimit - totalUsed))
    }

    public static func quotaBlock(
        _ state: DiaryGameState,
        slot: AdSlot,
        config: AdRemoteConfig,
        now: Int64
    ) -> AdQuotaBlock? {
        if !config.adEnabled { return .disabled }
        if state.orders.completedTotal < config.newbieOrdersRequired { return .newbie }
        if remainingForSlot(state, slot: slot, config: config) <= 0 { return .limit }
        if state.ads.disabledToday.contains(slot) { return .refused }
        if let last = state.ads.lastOfferAt, now >= last, now - last < config.minOfferIntervalMs {
            return .interval
        }
        return nil
    }

    public static func markOfferShown(_ state: inout DiaryGameState, now: Int64) {
        state.ads.lastOfferAt = now
    }

    public static func recordRefusal(_ state: inout DiaryGameState, slot: AdSlot, config: AdRemoteConfig) {
        let next = (state.ads.refusals[slot] ?? 0) + 1
        state.ads.refusals[slot] = next
        if next >= config.refusalLimit && !state.ads.disabledToday.contains(slot) {
            state.ads.disabledToday.append(slot)
        }
    }

    public static func recordAccept(_ state: inout DiaryGameState, slot: AdSlot) {
        state.ads.refusals[slot] = 0
    }

    public static func materialGap(_ state: DiaryGameState, target: MergeItem) -> Int {
        var units = 0
        for item in state.board.cells.compactMap({ $0 }) + state.board.pending {
            if item == target { return 0 }
            if item.chain == target.chain && item.level < target.level {
                units += item.energyValue
            }
        }
        return max(0, target.energyValue - units)
    }

    private static func materialOrderKey(orderID: String, chain: MergeChain) -> String {
        "\(orderID):\(chain.rawValue)"
    }

    public static func materialOffer(
        _ state: DiaryGameState,
        config: AdRemoteConfig,
        now: Int64,
        balance: DiaryBalance = .default
    ) -> MaterialOffer? {
        guard let target = state.target else { return nil }
        let chain = target.item.chain
        guard DiaryProgression.chainUnlocked(state, chain: chain, balance: balance) else { return nil }
        if state.ads.offeredTargetIDs.contains(target.id) { return nil }
        if let orderID = target.orderID,
           state.ads.offeredMaterialKeys.contains(materialOrderKey(orderID: orderID, chain: chain)) {
            return nil
        }
        if DiaryLedger.isClaimed(state, key: "material:target:\(target.id)") { return nil }
        let gap = materialGap(state, target: target.item)
        guard gap > 0 && gap <= config.materialMaxCount else { return nil }
        var energyCopy = state
        let energy = DiaryEnergy.settle(&energyCopy, now: now, balance: balance)
        guard !state.tutorialActive && energy < gap else { return nil }
        if quotaBlock(state, slot: .material, config: config, now: now) != nil { return nil }

        let totalUnits = target.item.energyValue
        return MaterialOffer(
            targetID: target.id,
            target: target.item,
            orderID: target.orderID,
            item: MergeItem(chain: chain, level: 1),
            count: gap,
            completedUnits: max(0, totalUnits - gap),
            totalUnits: totalUnits,
            catIsHungry: chain == .food && DiaryHome.isHungry(state.primaryCat, balance: balance)
        )
    }

    public static func autoMaterialTarget(
        _ state: DiaryGameState,
        chain: MergeChain,
        config: AdRemoteConfig,
        balance: DiaryBalance = .default
    ) -> (item: MergeItem, orderID: String)? {
        guard DiaryProgression.chainUnlocked(state, chain: chain, balance: balance) else { return nil }
        var best: (item: MergeItem, orderID: String, gap: Int)? = nil
        for order in state.orders.active {
            if state.ads.offeredMaterialKeys.contains(materialOrderKey(orderID: order.id, chain: chain)) { continue }
            for item in order.items where item.chain == chain {
                let gap = materialGap(state, target: item)
                guard gap >= 1 && gap <= config.materialMaxCount else { continue }
                if best == nil || gap < best!.gap {
                    best = (item, order.id, gap)
                }
            }
        }
        return best.map { ($0.item, $0.orderID) }
    }

    public static func markMaterialOfferShown(_ state: inout DiaryGameState, offer: MaterialOffer, now: Int64) {
        if !state.ads.offeredTargetIDs.contains(offer.targetID) {
            state.ads.offeredTargetIDs.append(offer.targetID)
        }
        if let orderID = offer.orderID {
            let key = materialOrderKey(orderID: orderID, chain: offer.target.chain)
            if !state.ads.offeredMaterialKeys.contains(key) {
                state.ads.offeredMaterialKeys.append(key)
            }
        }
        markOfferShown(&state, now: now)
    }

    public static func nearestFurniture(_ state: DiaryGameState, balance: DiaryBalance = .default) -> FurnitureDef? {
        DiaryCatalog.shopFurniture
            .filter { def in
                !state.home.furnitureOwned.contains(def.id)
                    && DiaryProgression.roomUnlocked(state, room: def.room, balance: balance)
            }
            .sorted { lhs, rhs in
                let lGap = max(0, (lhs.price ?? 0) - state.coins)
                let rGap = max(0, (rhs.price ?? 0) - state.coins)
                if lGap != rGap { return lGap < rGap }
                return (lhs.price ?? 0) < (rhs.price ?? 0)
            }
            .first
    }

    public static func wageOffer(
        _ state: DiaryGameState,
        order: CustomerOrder,
        config: AdRemoteConfig,
        now: Int64,
        balance: DiaryBalance = .default
    ) -> WageOffer? {
        if state.orders.materialAdOrderIDs.contains(order.id) { return nil }
        if DiaryLedger.isClaimed(state, key: "wage:order:\(order.id)") { return nil }
        if quotaBlock(state, slot: .wage, config: config, now: now) != nil { return nil }

        let short = DiaryOrders.wishlistShortfall(state, balance: balance)
        let after = short.map { max(0, $0 - order.wage) }
        // Skip small orders unless doubling completes the player's wishlisted furniture.
        if order.wage < config.wageMinAmount && !(short != nil && short! > 0 && after == 0) {
            return nil
        }
        let anchoredDef: FurnitureDef? = if short != nil, let wish = state.home.wishlist {
            DiaryCatalog.furnitureDef(wish)
        } else {
            nearestFurniture(state, balance: balance)
        }
        return WageOffer(
            orderID: order.id,
            amount: order.wage,
            wishlistShortAfter: after,
            furniture: anchoredDef?.id,
            furniturePrice: anchoredDef?.price
        )
    }
}
