import Foundation

public enum DiaryGameEvent: Equatable, Sendable {
    case dayStarted(Int)
    case itemGenerated(chain: MergeChain, item: MergeItem, cell: Int)
    case itemsMerged(item: MergeItem, cell: Int)
    case itemSold(item: MergeItem, price: Int)
    case pendingClaimed(MergeItem)
    case orderDelivered(order: CustomerOrder, wage: Int, bonusOffer: WageOffer?)
    case giftReceived(customer: CustomerID, furniture: FurnitureID)
    case orderRerolled(oldID: String, order: CustomerOrder)
    case furnitureBought(furniture: FurnitureID, price: Int)
    case broughtHome(MergeItem)
    case catPlayed(cat: CatID, item: MergeItem, wornOut: Bool)
    case catFed(cat: CatID, item: MergeItem)
    case catPetted(cat: CatID)
    case furnitureFirstUse(cat: CatID, furniture: FurnitureID)
    case homeVisited(offlineNoteID: String?)
    case photoTaken(cat: CatID, photoID: String)
    case levelUp(cat: CatID, level: Int, unlocks: [UnlockRule])
    case wishCompleted(cat: CatID, goal: WishGoal, bonusXP: Int)
    case tutorialFinished
    case adOffered(AdOffer)
    case adRefused(AdSlot)
    case adStarted(slot: AdSlot, claimID: String)
    case adGranted(slot: AdSlot, claimID: String, reward: AdReward)
    case adCancelled(slot: AdSlot, claimID: String, reason: AdPlayResult)
}

public struct EngineCommandOutput<Value: Sendable>: Sendable {
    public let value: Value
    public let events: [DiaryGameEvent]
    public let didMutate: Bool
}

/// Pure, synchronous state machine mirroring `cat-work-diary/src/core/game.ts`.
public final class DiaryGameEngine {
    public private(set) var state: DiaryGameState
    public let balance: DiaryBalance
    public var adConfig: AdRemoteConfig
    public let calendar: Calendar
    private var rng: any RandomSource

    public init(
        state: DiaryGameState,
        balance: DiaryBalance = .default,
        adConfig: AdRemoteConfig = .default,
        rng: any RandomSource = SystemRandomSource(),
        calendar: Calendar = .current
    ) {
        self.state = state
        self.balance = balance
        self.adConfig = adConfig
        self.rng = rng
        self.calendar = calendar
    }

    public func sceneLight(now: Int64) -> SceneLight {
        DiaryHome.sceneLight(now: now, savedDayKey: state.dayKey, balance: balance, calendar: calendar)
    }

    public func petCooldownLeft(now: Int64, catID: CatID = .primary) -> Int64 {
        guard let cat = state.cats[catID] else { return 0 }
        return DiaryHome.petCooldownLeft(cat, now: now, balance: balance)
    }

    @discardableResult
    public func start(now: Int64) -> EngineCommandOutput<Void> {
        run(now: now) { _ in
            DiaryLedger.recoverPendingOnStartup(&state)
            DiaryOrders.ensureOrders(&state, rng: &rng, balance: balance)
        }
    }

    @discardableResult
    public func refreshDay(now: Int64) -> EngineCommandOutput<Bool> {
        let nextKey = DayClock.monotonicDayKey(now: now, lastDayKey: state.dayKey, calendar: calendar)
        guard nextKey != state.dayKey else {
            return EngineCommandOutput(value: false, events: [], didMutate: false)
        }
        return run(now: now) { _ in true }
    }

    // MARK: - Workshop

    public func tapGenerator(chain: MergeChain, now: Int64) -> EngineCommandOutput<GeneratorTapResult> {
        run(now: now) { events in
            let result = DiaryBoard.tapGenerator(&state, chain: chain, now: now, rng: &rng, balance: balance)
            if case .generated(let item, let cell) = result {
                events.append(.itemGenerated(chain: chain, item: item, cell: cell))
            }
            return result
        }
    }

    public func moveItem(from: Int, to: Int, now: Int64) -> EngineCommandOutput<MoveItemResult> {
        run(now: now) { events in
            let result = DiaryBoard.moveItem(&state, from: from, to: to)
            if case .merged(let item) = result {
                events.append(.itemsMerged(item: item, cell: to))
            }
            return result
        }
    }

    public func claimPending(now: Int64) -> EngineCommandOutput<MergeItem?> {
        run(now: now) { events in
            let item = DiaryBoard.claimPending(&state)
            if let item { events.append(.pendingClaimed(item)) }
            return item
        }
    }

    public func sellItem(at index: Int, now: Int64) -> EngineCommandOutput<Int> {
        run(now: now) { events in
            let item = state.board.cells.indices.contains(index) ? state.board.cells[index] : nil
            let price = DiaryBoard.sellItem(&state, at: index, balance: balance)
            if let item, price > 0 { events.append(.itemSold(item: item, price: price)) }
            return price
        }
    }

    public func setTarget(item: MergeItem, orderID: String? = nil, now: Int64) -> EngineCommandOutput<Void> {
        run(now: now) { _ in
            DiaryOrders.setTarget(&state, item: item, orderID: orderID)
        }
    }

    public func clearTarget(now: Int64) -> EngineCommandOutput<Void> {
        run(now: now) { _ in
            DiaryOrders.clearTarget(&state)
        }
    }

    // MARK: - Orders & Shop

    public func deliverOrder(orderID: String, now: Int64) -> EngineCommandOutput<(result: DeliverOrderResult, bonusOffer: WageOffer?)> {
        run(now: now) { events in
            let result = DiaryOrders.deliverOrder(&state, orderID: orderID, rng: &rng, balance: balance)
            guard case .delivered(let order, let wage, let gift, _) = result else {
                return (result, nil)
            }
            let bonus = DiaryAds.wageOffer(state, order: order, config: adConfig, now: now, balance: balance)
            events.append(.orderDelivered(order: order, wage: wage, bonusOffer: bonus))
            if let gift { events.append(.giftReceived(customer: order.customer, furniture: gift)) }
            return (result, bonus)
        }
    }

    public func rerollOrder(orderID: String, now: Int64) -> EngineCommandOutput<CustomerOrder?> {
        run(now: now) { events in
            let fresh = DiaryOrders.rerollOrder(&state, orderID: orderID, rng: &rng, balance: balance)
            if let fresh { events.append(.orderRerolled(oldID: orderID, order: fresh)) }
            return fresh
        }
    }

    public func buyFurniture(id: FurnitureID, now: Int64) -> EngineCommandOutput<BuyFurnitureResult> {
        run(now: now) { events in
            let result = DiaryOrders.buyFurniture(&state, id: id, balance: balance)
            if case .bought(let furniture, let price) = result {
                events.append(.furnitureBought(furniture: furniture, price: price))
            }
            return result
        }
    }

    public func setWishlist(_ id: FurnitureID?, now: Int64) -> EngineCommandOutput<Void> {
        run(now: now) { _ in
            state.home.wishlist = id
        }
    }

    // MARK: - Home

    public func bringHome(cellIndex: Int, now: Int64) -> EngineCommandOutput<BringHomeResult> {
        run(now: now) { events in
            let result = DiaryHome.bringHome(&state, cellIndex: cellIndex, balance: balance)
            if case .brought(let item) = result { events.append(.broughtHome(item)) }
            return result
        }
    }

    public func playWithToy(index: Int, now: Int64, catID: CatID = .primary) -> EngineCommandOutput<PlayToyResult> {
        run(now: now) { events in
            let result = DiaryHome.playWithToy(&state, toyIndex: index, now: now, catID: catID, balance: balance)
            if case .played(let reaction, let item, let wornOut) = result {
                events.append(.catPlayed(cat: catID, item: item, wornOut: wornOut))
                if reaction.wishBonus > 0 {
                    events.append(.wishCompleted(cat: catID, goal: .play(item), bonusXP: reaction.wishBonus))
                }
                emitReaction(cat: catID, photos: reaction.newPhotos, levelUps: reaction.levelUps, into: &events)
            }
            return result
        }
    }

    public func feed(index: Int, now: Int64, catID: CatID = .primary) -> EngineCommandOutput<FeedCatResult> {
        run(now: now) { events in
            let result = DiaryHome.feed(&state, foodIndex: index, now: now, catID: catID, balance: balance)
            if case .fed(let reaction, let item) = result {
                events.append(.catFed(cat: catID, item: item))
                if reaction.wishBonus > 0 {
                    events.append(.wishCompleted(cat: catID, goal: .feed(item), bonusXP: reaction.wishBonus))
                }
                emitReaction(cat: catID, photos: reaction.newPhotos, levelUps: reaction.levelUps, into: &events)
            }
            return result
        }
    }

    public func pet(now: Int64, catID: CatID = .primary) -> EngineCommandOutput<PetCatResult> {
        run(now: now) { events in
            let result = DiaryHome.pet(&state, now: now, catID: catID, balance: balance)
            if case .petted(let reaction) = result {
                events.append(.catPetted(cat: catID))
                if reaction.wishBonus > 0 {
                    events.append(.wishCompleted(cat: catID, goal: .pet, bonusXP: reaction.wishBonus))
                }
                emitReaction(cat: catID, photos: reaction.newPhotos, levelUps: reaction.levelUps, into: &events)
            }
            return result
        }
    }

    public func visitHome(now: Int64) -> EngineCommandOutput<HomeVisitResult> {
        run(now: now) { events in
            let visit = DiaryHome.visitHome(&state, now: now, rng: &rng, balance: balance, calendar: calendar)
            events.append(.homeVisited(offlineNoteID: visit.offlineNoteID))
            for f in visit.furnitureUsed { events.append(.furnitureFirstUse(cat: .primary, furniture: f)) }
            emitReaction(cat: .primary, photos: visit.newPhotos, levelUps: visit.levelUps, into: &events)
            return visit
        }
    }

    public func leaveHome(now: Int64) -> EngineCommandOutput<Void> {
        run(now: now) { _ in
            state.home.lastVisitAt = now
        }
    }

    public func settleNewFurniture(now: Int64) -> EngineCommandOutput<NewFurnitureReaction> {
        run(now: now) { events in
            let reaction = DiaryHome.settleNewFurniture(&state, now: now, balance: balance)
            for f in reaction.furnitureUsed { events.append(.furnitureFirstUse(cat: .primary, furniture: f)) }
            emitReaction(cat: .primary, photos: reaction.newPhotos, levelUps: reaction.levelUps, into: &events)
            return reaction
        }
    }

    public func finishTutorial(now: Int64) -> EngineCommandOutput<Void> {
        run(now: now) { events in
            guard state.tutorialActive else { return }
            state.tutorialActive = false
            DiaryWishEngine.ensureDailyWish(&state, balance: balance)
            events.append(.tutorialFinished)
        }
    }

    public func updateSettings(_ settings: GameSettings, now: Int64) -> EngineCommandOutput<Void> {
        run(now: now) { _ in
            state.settings = settings
        }
    }

    public func resetProgress(now: Int64) -> EngineCommandOutput<Void> {
        let keptSettings = state.settings
        state = DiaryGameState.fresh(now: now, balance: balance, calendar: calendar)
        state.settings = keptSettings
        DiaryOrders.ensureOrders(&state, rng: &rng, balance: balance)
        return EngineCommandOutput(value: (), events: [], didMutate: true)
    }

    // MARK: - Ads

    public func materialOfferFor(
        chain: MergeChain,
        now: Int64,
        canShow: (MaterialOffer) -> Bool = { _ in true }
    ) -> EngineCommandOutput<MaterialOffer?> {
        run(now: now) { _ in
            let current = state.target
            if let current, current.item.chain == chain,
               let offer = DiaryAds.materialOffer(state, config: adConfig, now: now, balance: balance),
               canShow(offer) {
                return offer
            }
            guard let auto = DiaryAds.autoMaterialTarget(state, chain: chain, config: adConfig, balance: balance) else {
                return nil
            }
            if let current, current.item == auto.item && current.orderID == auto.orderID {
                return nil
            }
            let prevTargetID = state.nextTargetID
            DiaryOrders.setTarget(&state, item: auto.item, orderID: auto.orderID)
            if let offer = DiaryAds.materialOffer(state, config: adConfig, now: now, balance: balance),
               canShow(offer) {
                return offer
            }
            state.target = current
            state.nextTargetID = prevTargetID
            return nil
        }
    }

    public func offerStillAllowed(_ offer: AdOffer, now: Int64) -> Bool {
        if DiaryAds.quotaBlock(state, slot: offer.slot, config: adConfig, now: now) != nil { return false }
        if DiaryLedger.isClaimed(state, key: offer.key) { return false }
        return true
    }

    public func offerShown(_ offer: AdOffer, now: Int64) -> EngineCommandOutput<Void> {
        run(now: now) { events in
            switch offer {
            case .material(let m): DiaryAds.markMaterialOfferShown(&state, offer: m, now: now)
            case .wage: DiaryAds.markOfferShown(&state, now: now)
            }
            events.append(.adOffered(offer))
        }
    }

    public func refuseAd(slot: AdSlot, now: Int64) -> EngineCommandOutput<Void> {
        run(now: now) { events in
            DiaryAds.recordRefusal(&state, slot: slot, config: adConfig)
            events.append(.adRefused(slot))
        }
    }

    public func startAd(offer: AdOffer, now: Int64) -> EngineCommandOutput<String?> {
        run(now: now) { events in
            guard DiaryLedger.pendingClaims(state).isEmpty else { return nil }
            guard !DiaryLedger.isClaimed(state, key: offer.key) else { return nil }
            if let block = DiaryAds.quotaBlock(state, slot: offer.slot, config: adConfig, now: now),
               block != .interval {
                return nil
            }
            DiaryAds.recordAccept(&state, slot: offer.slot)
            let claimID = DiaryLedger.createPending(&state, slot: offer.slot, reward: offer.reward, now: now, key: offer.key)
            events.append(.adStarted(slot: offer.slot, claimID: claimID))
            return claimID
        }
    }

    public func finishAd(claimID: String, result: AdPlayResult, now: Int64) -> EngineCommandOutput<Bool> {
        run(now: now) { events in
            guard let claim = DiaryLedger.findClaim(state, id: claimID) else { return false }
            if result == .ended {
                let granted = DiaryLedger.grantOnce(&state, id: claimID)
                if granted {
                    events.append(.adGranted(slot: claim.slot, claimID: claimID, reward: claim.reward))
                }
                return granted
            }
            if DiaryLedger.cancelClaim(&state, id: claimID) {
                events.append(.adCancelled(slot: claim.slot, claimID: claimID, reason: result))
            }
            return false
        }
    }

    // MARK: - Internal pipeline

    private func emitReaction(cat: CatID, photos: [String], levelUps: [Int], into events: inout [DiaryGameEvent]) {
        for photo in photos { events.append(.photoTaken(cat: cat, photoID: photo)) }
        for level in levelUps {
            let unlocks = cat == .primary ? DiaryProgression.unlocks(at: level, balance: balance) : []
            events.append(.levelUp(cat: cat, level: level, unlocks: unlocks))
        }
    }

    private func run<T: Sendable>(
        now: Int64,
        action: (inout [DiaryGameEvent]) -> T
    ) -> EngineCommandOutput<T> {
        var events: [DiaryGameEvent] = []
        if state.rollDay(now: now, calendar: calendar) {
            events.append(.dayStarted(state.dayKey))
        }
        DiaryWishEngine.ensureDailyWish(&state, balance: balance)
        DiaryEnergy.settle(&state, now: now, balance: balance)
        DiaryHome.settleCats(&state, now: now, balance: balance)
        let value = action(&events)
        state.updatedAt = max(state.updatedAt, now)
        return EngineCommandOutput(value: value, events: events, didMutate: true)
    }
}
