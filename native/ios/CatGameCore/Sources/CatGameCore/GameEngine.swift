import Foundation

/// Deterministic rules. Call `synchronize` on launch, foreground, and active ticks.
/// Every public action first synchronizes elapsed time. Even when the requested
/// action fails or is a no-op, its inout state retains that independent progress.
/// Callers must persist a changed state regardless of ActionOutcome.succeeded;
/// the outcome describes the requested action, not every elapsed-time effect.
/// Animations are effects of these committed results and never determine rewards.
public enum GameEngine {
    public static let foodPrice = 20
    public static let litterPrice = 18
    public static let toyPrice = 35
    public static let toyUsesPerPurchase = 6

    public static func adoptCat(_ state: inout GameSnapshot, catID: String,
                                now: Date = Date()) -> ActionOutcome {
        let synchronized = synchronize(&state, now: now)
        guard synchronized.succeeded else { return synchronized }
        guard let offer = CatCatalog.adoptionOffer(catID: catID) else { return failure(.catAdoptionMissing) }
        guard !state.cats.contains(where: { $0.id == catID }) else { return failure(.catAlreadyOwned) }
        guard state.player.level >= offer.requiredPlayerLevel
        else { return failure(.catPlayerLevelRequired, amount: offer.requiredPlayerLevel) }
        guard state.home.roomLevel >= offer.requiredRoomLevel
        else { return failure(.catRoomLevelRequired, amount: offer.requiredRoomLevel) }
        guard state.player.gold >= offer.price else { return failure(.shopGoldRequired, amount: offer.price) }
        var candidate = state
        candidate.player.gold -= offer.price
        candidate.cats.append(CatState(id: offer.id, name: offer.name,
            satiety: 70, cleanliness: 85, mood: 80, intimacy: 10, energy: 85, health: 100,
            now: effectiveTime(state, now: now), appearance: offer.appearance))
        guard candidate.isValid else { return failure(.gameInvalidState) }
        state = candidate
        return ActionOutcome(success: .catAdopted, amount: offer.price)
    }

    public static func selectCompanion(_ state: inout GameSnapshot, catID: String,
                                       now: Date = Date()) -> ActionOutcome {
        let synchronized = synchronize(&state, now: now)
        guard synchronized.succeeded else { return synchronized }
        guard state.cats.contains(where: { $0.id == catID }) else { return failure(.careCatMissing) }
        guard state.activeCatID != catID else { return ActionOutcome() }
        if let index = state.cats.firstIndex(where: { $0.id == state.activeCatID }) {
            finishCatRest(&state, index: index, now: effectiveTime(state, now: now))
        }
        state.activeCatID = catID
        return ActionOutcome(success: .companionSelected)
    }

    public static func selectAvatar(_ state: inout GameSnapshot, avatarID: String,
                                    now: Date = Date()) -> ActionOutcome {
        let synchronized = synchronize(&state, now: now)
        guard synchronized.succeeded else { return synchronized }
        guard PlayerCatalog.avatar(id: avatarID) != nil else { return failure(.playerAvatarMissing) }
        state.player.profile.avatarID = avatarID
        return ActionOutcome(success: .avatarSaved)
    }

    public static func equipItem(_ state: inout GameSnapshot, itemID: String,
                                 now: Date = Date()) -> ActionOutcome {
        let synchronized = synchronize(&state, now: now)
        guard synchronized.succeeded else { return synchronized }
        guard let item = PlayerCatalog.item(id: itemID) else { return failure(.equipmentItemMissing) }
        guard state.player.profile.ownedEquipmentIDs.contains(itemID) else { return failure(.equipmentNotOwned) }
        state.player.profile.equipped[item.slot] = item.id
        return ActionOutcome(success: .equipped)
    }

    public static func unequipSlot(_ state: inout GameSnapshot, slot: EquipmentSlot,
                                   now: Date = Date()) -> ActionOutcome {
        let synchronized = synchronize(&state, now: now)
        guard synchronized.succeeded else { return synchronized }
        state.player.profile.equipped.removeValue(forKey: slot)
        return ActionOutcome(success: .unequipped)
    }

    public static func equipStarterSet(_ state: inout GameSnapshot,
                                       now: Date = Date()) -> ActionOutcome {
        let synchronized = synchronize(&state, now: now)
        guard synchronized.succeeded else { return synchronized }
        guard PlayerCatalog.starterEquipmentIDs.allSatisfy({ state.player.profile.ownedEquipmentIDs.contains($0) })
        else { return failure(.equipmentNotOwned) }
        let items = PlayerCatalog.starterEquipmentIDs.compactMap { PlayerCatalog.item(id: $0) }
        guard items.count == PlayerCatalog.starterEquipmentIDs.count else { return failure(.equipmentItemMissing) }
        for item in items {
            state.player.profile.equipped[item.slot] = item.id
        }
        return ActionOutcome(success: .starterEquipped)
    }

    /// The same deterministic preview is captured by startWork. Locked careers
    /// can still be previewed, but only startWork authorizes starting a shift.
    public static func workQuote(for player: PlayerState,
                                 jobID: String = "job_flyer") -> WorkQuote? {
        guard player.profile.isValid, let job = WorkCatalog.job(id: jobID) else { return nil }
        return WorkQuote(job: job, profile: player.profile)
    }

    public static func catRestDuration(for kind: FurnitureKind) -> TimeInterval? {
        switch kind {
        case .catBed: 12
        case .floorCushion: 9
        default: nil
        }
    }

    public static func startSleep(_ state: inout GameSnapshot, now: Date = Date()) -> ActionOutcome {
        let synchronized = synchronize(&state, now: now)
        guard synchronized.succeeded else { return synchronized }
        guard state.player.activeSleep == nil else { return ActionOutcome() }
        var candidate = state
        guard candidate.player.activeWork == nil else { return failure(.sleepWorkActive) }
        candidate.player.activeSleep = PlayerSleep(startedAt: effectiveTime(candidate, now: now))
        state = candidate
        return ActionOutcome(success: .sleepStarted)
    }

    public static func wakeUp(_ state: inout GameSnapshot, now: Date = Date()) -> ActionOutcome {
        let synchronized = synchronize(&state, now: now)
        guard synchronized.succeeded else { return synchronized }
        guard let sleep = state.player.activeSleep else { return ActionOutcome() }
        let timestamp = effectiveTime(state, now: now)
        // Preserve awake-time remainder without counting any sleeping interval twice.
        let awakeRemainder = min(3600, max(0, sleep.startedAt.timeIntervalSince(state.player.staminaUpdatedAt)))
        state.player.staminaUpdatedAt = state.player.stamina == 100
            ? timestamp : timestamp.addingTimeInterval(-awakeRemainder)
        state.player.activeSleep = nil
        return ActionOutcome(success: .sleepEnded)
    }

    public static func startCatRest(_ state: inout GameSnapshot, catID: String, furnitureID: String,
                                    sessionID: String = UUID().uuidString,
                                    now: Date = Date()) -> ActionOutcome {
        let synchronized = synchronize(&state, now: now)
        guard synchronized.succeeded else { return synchronized }
        guard let index = state.cats.firstIndex(where: { $0.id == catID }) else {
            return failure(.careCatMissing)
        }
        // A delayed arrival from the previous room companion cannot start a new rest.
        guard state.activeCatID == catID else { return ActionOutcome() }
        guard state.cats[index].activeRest == nil,
              state.cats[index].lastRestSessionID != sessionID else { return ActionOutcome() }
        guard !sessionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return failure(.restInvalidSession)
        }
        guard state.home.furniture.contains(where: { $0.itemID == furnitureID }),
              let item = state.inventory.furniture.first(where: { $0.id == furnitureID }),
              let duration = catRestDuration(for: item.kind) else { return failure(.restInvalidFurniture) }
        var candidate = state
        let timestamp = effectiveTime(candidate, now: now)
        candidate.cats[index].activeRest = CatRest(id: sessionID, furnitureID: furnitureID,
            startedAt: timestamp, endsAt: timestamp.addingTimeInterval(duration),
            energyReward: 20 + candidate.home.comfortScore / 20)
        candidate.cats[index].lastRestSessionID = sessionID
        guard candidate.isValid else { return failure(.gameInvalidState) }
        state = candidate
        return ActionOutcome(success: .catRestStarted)
    }

    public static func endCatRest(_ state: inout GameSnapshot, catID: String,
                                  sessionID: String? = nil, now: Date = Date()) -> ActionOutcome {
        let synchronized = synchronize(&state, now: now)
        guard synchronized.succeeded else { return synchronized }
        guard let index = state.cats.firstIndex(where: { $0.id == catID }) else {
            return failure(.careCatMissing)
        }
        guard let rest = state.cats[index].activeRest,
              sessionID == nil || sessionID == rest.id else { return ActionOutcome() }
        finishCatRest(&state, index: index, now: effectiveTime(state, now: now))
        return ActionOutcome(success: .catRestEnded)
    }

    public static func feed(_ state: inout GameSnapshot, catID: String,
                            now: Date = Date()) -> ActionOutcome {
        let synchronized = synchronize(&state, now: now)
        guard synchronized.succeeded else { return synchronized }
        guard let index = state.cats.firstIndex(where: { $0.id == catID }) else {
            return failure(.careCatMissing)
        }
        let units = state.cats[index].isPregnant ? 2 : 1
        guard state.inventory.food >= units else {
            return failure(.careFoodRequired, amount: units)
        }
        let timestamp = effectiveTime(state, now: now)
        finishCatRest(&state, index: index, now: timestamp)
        state.inventory.food -= units
        state.cats[index].satiety = cap(state.cats[index].satiety + 25)
        state.cats[index].mood = cap(state.cats[index].mood + 4)
        state.cats[index].decayTracker.satiety = max(state.cats[index].decayTracker.satiety, timestamp)
        state.cats[index].decayTracker.mood = max(state.cats[index].decayTracker.mood, timestamp)
        return ActionOutcome(success: .fed, amount: units)
    }

    public static func clean(_ state: inout GameSnapshot, catID: String,
                             now: Date = Date()) -> ActionOutcome {
        let synchronized = synchronize(&state, now: now)
        guard synchronized.succeeded else { return synchronized }
        guard let index = state.cats.firstIndex(where: { $0.id == catID }) else {
            return failure(.careCatMissing)
        }
        guard state.inventory.litter > 0 else { return failure(.careLitterRequired) }
        let timestamp = effectiveTime(state, now: now)
        finishCatRest(&state, index: index, now: timestamp)
        state.inventory.litter -= 1
        state.cats[index].cleanliness = cap(state.cats[index].cleanliness + 30)
        state.cats[index].health = cap(state.cats[index].health + 4)
        state.cats[index].decayTracker.cleanliness = max(
            state.cats[index].decayTracker.cleanliness, timestamp)
        return ActionOutcome(success: .cleaned, amount: 1)
    }

    public static func play(_ state: inout GameSnapshot, catID: String,
                            now: Date = Date()) -> ActionOutcome {
        let synchronized = synchronize(&state, now: now)
        guard synchronized.succeeded else { return synchronized }
        guard let index = state.cats.firstIndex(where: { $0.id == catID }) else {
            return failure(.careCatMissing)
        }
        guard state.inventory.toys > 0 else { return failure(.careToyRequired) }
        let timestamp = effectiveTime(state, now: now)
        finishCatRest(&state, index: index, now: timestamp)
        state.inventory.toys -= 1
        let comfortBonus = state.home.comfortScore / 20
        state.cats[index].mood = cap(state.cats[index].mood + 18 + comfortBonus)
        // The web rule awards +8 intimacy and a further +4 toy bonus.
        state.cats[index].intimacy = cap(state.cats[index].intimacy + 12)
        state.cats[index].energy = cap(state.cats[index].energy - 10)
        state.player.mood = cap(state.player.mood + 4)
        state.cats[index].decayTracker.mood = max(state.cats[index].decayTracker.mood, timestamp)
        state.cats[index].decayTracker.energy = max(state.cats[index].decayTracker.energy, timestamp)
        return ActionOutcome(success: .played, amount: 1)
    }

    public static func buyFood(_ state: inout GameSnapshot, quantity: Int = 1,
                               now: Date = Date()) -> ActionOutcome {
        buy(&state, quantity: quantity, unitPrice: foodPrice, unitsPerItem: 1,
            stock: \.food, success: .foodPurchased, now: now)
    }

    public static func buyLitter(_ state: inout GameSnapshot, quantity: Int = 1,
                                 now: Date = Date()) -> ActionOutcome {
        buy(&state, quantity: quantity, unitPrice: litterPrice, unitsPerItem: 1,
            stock: \.litter, success: .litterPurchased, now: now)
    }

    public static func buyToy(_ state: inout GameSnapshot, quantity: Int = 1,
                              now: Date = Date()) -> ActionOutcome {
        buy(&state, quantity: quantity, unitPrice: toyPrice, unitsPerItem: toyUsesPerPurchase,
            stock: \.toys, success: .toyPurchased, now: now)
    }

    public static func purchaseEquipment(_ state: inout GameSnapshot, itemID: String,
                                         now: Date = Date()) -> ActionOutcome {
        let synchronized = synchronize(&state, now: now)
        guard synchronized.succeeded else { return synchronized }
        guard let offer = ShopCatalog.equipmentOffer(itemID: itemID), PlayerCatalog.item(id: itemID) != nil
        else { return failure(.shopItemMissing) }
        guard !state.player.profile.ownedEquipmentIDs.contains(itemID) else { return failure(.shopAlreadyOwned) }
        guard state.player.level >= offer.unlockLevel else { return failure(.shopLevelRequired, amount: offer.unlockLevel) }
        guard state.player.gold >= offer.price else { return failure(.shopGoldRequired, amount: offer.price) }
        state.player.gold -= offer.price
        state.player.profile.ownedEquipmentIDs.append(itemID)
        return ActionOutcome(success: .equipmentPurchased, amount: offer.price)
    }

    public static func purchaseFurniture(_ state: inout GameSnapshot, offerID: String,
                                         now: Date = Date()) -> ActionOutcome {
        let synchronized = synchronize(&state, now: now)
        guard synchronized.succeeded else { return synchronized }
        guard let offer = ShopCatalog.furnitureOffer(id: offerID) else { return failure(.shopItemMissing) }
        guard state.player.level >= offer.unlockLevel else { return failure(.shopLevelRequired, amount: offer.unlockLevel) }
        let ownedIDs = Set(state.inventory.furniture.map(\.id))
        guard ShopCatalog.ownedFurnitureCount(offerID: offerID, in: state.inventory.furniture) < offer.maxOwned,
              let instanceID = (1...offer.maxOwned).map(offer.instanceID).first(where: { !ownedIDs.contains($0) })
        else { return failure(.shopFurnitureLimit, amount: offer.maxOwned) }
        guard state.player.gold >= offer.price else { return failure(.shopGoldRequired, amount: offer.price) }
        state.player.gold -= offer.price
        state.inventory.furniture.append(FurnitureItem(id: instanceID, kind: offer.kind))
        return ActionOutcome(success: .furniturePurchased, amount: offer.price)
    }

    public static func upgradeHome(_ state: inout GameSnapshot, toLevel: Int,
                                   now: Date = Date()) -> ActionOutcome {
        let synchronized = synchronize(&state, now: now)
        guard synchronized.succeeded else { return synchronized }
        guard let next = HomeCatalog.nextLevel(after: state.home.roomLevel), next.level == toLevel
        else { return failure(.homeUpgradeUnavailable) }
        guard state.player.level >= next.requiredPlayerLevel
        else { return failure(.homeLevelRequired, amount: next.requiredPlayerLevel) }
        guard state.player.gold >= next.upgradeCost else { return failure(.shopGoldRequired, amount: next.upgradeCost) }
        // Geometry changes settle cat recovery while preserving the furniture
        // layout and any captured player work contract.
        finishAllCatRests(&state, now: effectiveTime(state, now: now))
        state.player.gold -= next.upgradeCost
        state.home.roomLevel = next.level
        return ActionOutcome(success: .homeUpgraded, amount: next.upgradeCost)
    }

    /// Base career values mirror the web catalog. Rewards are captured at
    /// start so a later catalog update cannot rewrite an in-progress shift.
    public static func startWork(_ state: inout GameSnapshot,
                                 jobID: String = "job_flyer",
                                 now: Date = Date()) -> ActionOutcome {
        let synchronized = synchronize(&state, now: now)
        guard synchronized.succeeded else { return synchronized }
        guard let job = WorkCatalog.job(id: jobID) else { return failure(.workJobMissing) }
        guard state.player.level >= job.unlockLevel else { return failure(.workLevelRequired) }
        guard state.player.activeSleep == nil else { return failure(.workSleeping) }
        guard state.player.activeWork == nil else { return failure(.workAlreadyActive) }
        guard let quote = workQuote(for: state.player, jobID: jobID) else { return failure(.gameInvalidState) }
        guard state.player.stamina >= quote.staminaCost else { return failure(.workStaminaRequired) }
        let timestamp = effectiveTime(state, now: now)
        var candidate = state
        if candidate.player.stamina == 100 {
            candidate.player.staminaUpdatedAt = max(candidate.player.staminaUpdatedAt, timestamp)
        }
        candidate.player.stamina -= quote.staminaCost
        candidate.player.mood = cap(candidate.player.mood - quote.moodCost)
        candidate.player.activeWork = ActiveWork(jobID: job.id, startedAt: timestamp,
                                            endsAt: timestamp.addingTimeInterval(Double(quote.durationSeconds)),
                                            goldReward: job.goldReward, expReward: job.expReward, quote: quote)
        guard candidate.isValid else { return failure(.gameInvalidState) }
        state = candidate
        return ActionOutcome(success: .workStarted)
    }

    /// Applies whole elapsed intervals, preserving the fractional remainder.
    /// Repeating a sync at the same timestamp has no effect and pays no reward.
    public static func synchronize(_ state: inout GameSnapshot,
                                   now: Date = Date()) -> ActionOutcome {
        guard valid(state, now: now) else { return failure(.gameInvalidState) }
        let timestamp = effectiveTime(state, now: now)
        var workProgress: (level: Int, exp: Int)?
        if let work = state.player.activeWork, timestamp >= work.endsAt {
            guard let progress = WorkCatalog.progress(level: state.player.level,
                                                      exp: state.player.exp, adding: work.expReward) else {
                return failure(.workProgressLimit)
            }
            workProgress = progress
        }
        for index in state.cats.indices {
            var cat = state.cats[index]
            decay(&cat.satiety, tracker: &cat.decayTracker.satiety,
                  interval: 12 * 60, now: timestamp)
            decay(&cat.cleanliness, tracker: &cat.decayTracker.cleanliness,
                  interval: 8 * 60, now: timestamp)
            decay(&cat.mood, tracker: &cat.decayTracker.mood,
                  interval: 6 * 60, now: timestamp)
            settleCatEnergy(&cat, now: timestamp)
            state.cats[index] = cat
        }

        if state.player.activeSleep != nil {
            settleSleep(&state.player, now: timestamp)
        } else if state.player.stamina >= 100 {
            state.player.stamina = 100
            state.player.staminaUpdatedAt = max(state.player.staminaUpdatedAt, timestamp)
        } else {
            let steps = elapsedSteps(from: state.player.staminaUpdatedAt, to: timestamp, interval: 3600)
            if steps > 0 {
                let gain = min(100 - state.player.stamina, steps * 5)
                state.player.stamina += gain
                state.player.staminaUpdatedAt = state.player.stamina == 100
                    ? timestamp : state.player.staminaUpdatedAt.addingTimeInterval(Double(steps) * 3600)
            }
        }

        state.meta.lastSyncAt = timestamp
        if let work = state.player.activeWork, let progress = workProgress {
            let levelBefore = state.player.level
            // The wallet has a storage cap; a completed shift still advances time,
            // awards all experience, and records only the gold actually received.
            let goldAwarded = min(work.goldReward, GameSnapshot.maximumGold - state.player.gold)
            state.player.gold += goldAwarded
            state.player.level = progress.level
            state.player.exp = progress.exp
            state.player.completedWorkCount = min(GameSnapshot.maximumGold, state.player.completedWorkCount + 1)
            state.player.lastWorkResult = WorkResult(
                id: work.id, jobID: work.jobID, completedAt: work.endsAt,
                goldReward: goldAwarded, expReward: work.expReward,
                levelBefore: levelBefore, levelAfter: progress.level, expAfter: progress.exp)
            state.player.activeWork = nil
            return ActionOutcome(success: .workFinished, amount: goldAwarded)
        }
        return ActionOutcome()
    }

    public static func setBowlPosition(_ state: inout GameSnapshot,
                                       _ position: NormalizedPoint,
                                       now: Date = Date()) -> ActionOutcome {
        let synchronized = synchronize(&state, now: now)
        guard synchronized.succeeded else { return synchronized }
        guard position.x.isFinite, position.y.isFinite else { return failure(.roomInvalidPosition) }
        let position = NormalizedPoint(x: min(1, max(0, position.x)), y: min(1, max(0, position.y)))
        if position != state.home.bowlPosition { finishAllCatRests(&state, now: effectiveTime(state, now: now)) }
        state.home.bowlPosition = position
        return ActionOutcome(success: .layoutSaved)
    }

    /// Commit the complete draft only after every coordinate and owned-item
    /// reference has been validated. Storing/replacing furniture changes no
    /// ownership, currency, care supply, or comfort values.
    public static func setRoomLayout(_ state: inout GameSnapshot,
                                     bowlPosition: NormalizedPoint,
                                     furniture: [FurniturePlacement],
                                     now: Date = Date()) -> ActionOutcome {
        let synchronized = synchronize(&state, now: now)
        guard synchronized.succeeded else { return synchronized }
        guard GameSnapshot.isUnitPosition(bowlPosition) else { return failure(.roomInvalidPosition) }
        guard GameSnapshot.validFurniture(owned: state.inventory.furniture, placements: furniture) else {
            return failure(.roomInvalidFurnitureLayout)
        }
        guard HomeCatalog.allowsLayout(furniture, replacing: state.home.furniture, roomLevel: state.home.roomLevel)
        else { return failure(.roomCapacityReached, amount: HomeCatalog.level(state.home.roomLevel)?.capacity ?? 0) }
        if bowlPosition != state.home.bowlPosition || furniture != state.home.furniture {
            // Geometry changes can affect an exit route as well as the occupied item.
            finishAllCatRests(&state, now: effectiveTime(state, now: now))
        }
        state.home.bowlPosition = bowlPosition
        state.home.furniture = furniture
        return ActionOutcome(success: .layoutSaved)
    }

    private static func buy(_ state: inout GameSnapshot, quantity: Int, unitPrice: Int,
                            unitsPerItem: Int, stock: WritableKeyPath<InventoryState, Int>,
                            success: ActionSuccess, now: Date) -> ActionOutcome {
        let synchronized = synchronize(&state, now: now)
        guard synchronized.succeeded else { return synchronized }
        guard (1...999).contains(quantity) else { return failure(.shopInvalidQuantity) }
        let cost = unitPrice * quantity
        let count = quantity * unitsPerItem
        guard state.player.gold >= cost else { return failure(.shopGoldRequired, amount: cost) }
        guard state.inventory[keyPath: stock] <= GameSnapshot.maximumStock - count else {
            return failure(.shopInventoryFull)
        }
        state.player.gold -= cost
        state.inventory[keyPath: stock] += count
        return ActionOutcome(success: success, amount: count)
    }

    private static func cap(_ value: Int) -> Int { min(100, max(0, value)) }

    private static func settleSleep(_ player: inout PlayerState, now: Date) {
        guard var sleep = player.activeSleep else { return }
        recoverDuringSleep(&player.stamina, tracker: &sleep.staminaUpdatedAt,
                           remainder: &player.sleepStaminaRemainder, now: now)
        recoverDuringSleep(&player.mood, tracker: &sleep.moodUpdatedAt,
                           remainder: &player.sleepMoodRemainder, now: now)
        player.activeSleep = sleep
    }

    private static func recoverDuringSleep(_ value: inout Int, tracker: inout Date,
                                           remainder: inout TimeInterval, now: Date) {
        let timestamp = max(now, tracker)
        let elapsed = min(180_000_000_000, timestamp.timeIntervalSince(tracker) + remainder)
        let points = Int(floor(elapsed / 180))
        value = cap(value + points)
        remainder = value == 100 ? 0 : elapsed - Double(points) * 180
        tracker = timestamp
    }

    private static func settleCatEnergy(_ cat: inout CatState, now: Date) {
        if var rest = cat.activeRest {
            let through = min(rest.endsAt, max(rest.startedAt, now))
            let duration = rest.endsAt.timeIntervalSince(rest.startedAt)
            let earned = through >= rest.endsAt ? rest.energyReward
                : Int(floor(Double(rest.energyReward) * through.timeIntervalSince(rest.startedAt) / duration))
            cat.energy = cap(cat.energy + max(0, earned - rest.energyGranted))
            rest.energyGranted = max(rest.energyGranted, earned)
            let paused = max(0, through.timeIntervalSince(rest.energyPausedUntil))
            cat.decayTracker.energy = cat.decayTracker.energy.addingTimeInterval(paused)
            rest.energyPausedUntil = max(rest.energyPausedUntil, through)
            cat.activeRest = now >= rest.endsAt ? nil : rest
        }
        if cat.activeRest == nil {
            decay(&cat.energy, tracker: &cat.decayTracker.energy, interval: 300, now: now)
        }
    }

    private static func finishCatRest(_ state: inout GameSnapshot, index: Int, now: Date) {
        guard state.cats[index].activeRest != nil else { return }
        var cat = state.cats[index]
        settleCatEnergy(&cat, now: now)
        cat.activeRest = nil
        decay(&cat.energy, tracker: &cat.decayTracker.energy, interval: 300, now: now)
        state.cats[index] = cat
        state.meta.lastSyncAt = max(state.meta.lastSyncAt, now)
    }

    private static func finishAllCatRests(_ state: inout GameSnapshot, now: Date) {
        for index in state.cats.indices { finishCatRest(&state, index: index, now: now) }
    }

    private static func effectiveTime(_ state: GameSnapshot, now: Date) -> Date {
        max(now, state.meta.lastSyncAt)
    }

    private static func valid(_ state: GameSnapshot, now: Date) -> Bool {
        now.timeIntervalSince1970.isFinite && state.isValid
    }

    private static func failure(_ reason: ActionFailure, amount: Int = 0) -> ActionOutcome {
        ActionOutcome(failure: reason, amount: amount)
    }

    private static func elapsedSteps(from: Date, to: Date, interval: TimeInterval) -> Int {
        let elapsed = to.timeIntervalSince(from)
        guard elapsed > 0 else { return 0 }
        // Finite input timestamps plus this bound protect Double-to-Int conversion.
        return Int(min(1_000_000_000, floor(elapsed / interval)))
    }

    private static func decay(_ value: inout Int, tracker: inout Date,
                              interval: TimeInterval, now: Date) {
        let steps = elapsedSteps(from: tracker, to: now, interval: interval)
        guard steps > 0 else { return }
        value = max(0, value - min(steps, 100))
        tracker = tracker.addingTimeInterval(Double(steps) * interval)
    }
}

extension GameSnapshot {
    static let maximumGold = 1_000_000_000
    static let maximumStock = 1_000_000

    var isValid: Bool {
        guard schemaVersion == Self.currentSchemaVersion,
              (0...Self.maximumGold).contains(player.gold),
              (0...100).contains(player.stamina), (0...100).contains(player.mood),
              [player.sleepStaminaRemainder, player.sleepMoodRemainder].allSatisfy({
                  $0.isFinite && (0..<180).contains($0)
              }),
              (0...Self.maximumGold).contains(player.completedWorkCount),
              WorkCatalog.validProgress(level: player.level, exp: player.exp),
              player.profile.isValid,
              [inventory.food, inventory.litter, inventory.toys].allSatisfy({ (0...Self.maximumStock).contains($0) }),
              (0...100).contains(home.comfortScore),
              HomeCatalog.level(home.roomLevel) != nil,
              home.name.map({ HomeNameRules.normalized($0) == $0 }) ?? true,
              Self.isUnitPosition(home.bowlPosition),
              Self.validFurniture(owned: inventory.furniture, placements: home.furniture),
              !cats.isEmpty, cats.count <= 1000,
              cats.contains(where: { $0.id == activeCatID }),
              Set(cats.map(\.id)).count == cats.count,
              [meta.createdAt, meta.lastSyncAt, player.staminaUpdatedAt].allSatisfy({ $0.timeIntervalSince1970.isFinite })
        else { return false }
        if let sleep = player.activeSleep {
            guard player.activeWork == nil,
                  [sleep.startedAt, sleep.staminaUpdatedAt, sleep.moodUpdatedAt].allSatisfy({ $0.timeIntervalSince1970.isFinite }),
                  sleep.staminaUpdatedAt >= sleep.startedAt,
                  sleep.moodUpdatedAt >= sleep.startedAt else { return false }
        }
        for cat in cats {
            guard !cat.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !cat.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  cat.customName.map({ CatNameRules.normalized($0) == $0 }) ?? true,
                  [cat.satiety, cat.cleanliness, cat.mood, cat.intimacy, cat.energy, cat.health].allSatisfy({ (0...100).contains($0) }),
                  [cat.decayTracker.satiety, cat.decayTracker.cleanliness, cat.decayTracker.mood,
                   cat.decayTracker.energy].allSatisfy({ $0.timeIntervalSince1970.isFinite })
            else { return false }
            if let session = cat.lastRestSessionID,
               session.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
            if let rest = cat.activeRest {
                guard !rest.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      cat.lastRestSessionID == rest.id,
                      home.furniture.contains(where: { $0.itemID == rest.furnitureID }),
                      let item = inventory.furniture.first(where: { $0.id == rest.furnitureID }),
                      let duration = GameEngine.catRestDuration(for: item.kind),
                      [rest.startedAt, rest.endsAt, rest.energyPausedUntil].allSatisfy({ $0.timeIntervalSince1970.isFinite }),
                      rest.endsAt.timeIntervalSince(rest.startedAt) == duration,
                      rest.energyPausedUntil >= rest.startedAt, rest.energyPausedUntil <= rest.endsAt,
                      (20...25).contains(rest.energyReward),
                      (0...rest.energyReward).contains(rest.energyGranted) else { return false }
            }
        }
        if let work = player.activeWork {
            guard !work.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !work.jobID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  work.id != player.lastWorkResult?.id,
                  (0...1_000_000).contains(work.goldReward),
                  (0...1_000_000).contains(work.expReward),
                  work.startedAt.timeIntervalSince1970.isFinite,
                  work.endsAt.timeIntervalSince1970.isFinite,
                  work.endsAt >= work.startedAt else { return false }
            if let quote = work.quote {
                guard quote.isValid, quote.jobID == work.jobID,
                      work.endsAt.timeIntervalSince(work.startedAt) == Double(quote.durationSeconds)
                else { return false }
            }
        }
        if let result = player.lastWorkResult {
            guard !result.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !result.jobID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  result.completedAt.timeIntervalSince1970.isFinite,
                  (0...1_000_000).contains(result.goldReward),
                  (0...1_000_000).contains(result.expReward),
                  WorkCatalog.requiredExperience(forLevel: result.levelBefore) > 0,
                  result.levelBefore <= result.levelAfter, result.levelAfter <= player.level,
                  WorkCatalog.validProgress(level: result.levelAfter, exp: result.expAfter)
            else { return false }
        }
        return true
    }

    static func isUnitPosition(_ point: NormalizedPoint) -> Bool {
        point.x.isFinite && point.y.isFinite && (0...1).contains(point.x) && (0...1).contains(point.y)
    }

    static func validFurniture(owned: [FurnitureItem], placements: [FurniturePlacement]) -> Bool {
        let ownedIDs = Set(owned.map(\.id))
        guard ownedIDs.count == owned.count,
              owned.allSatisfy({ !$0.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              Set(placements.map(\.itemID)).count == placements.count else { return false }
        return placements.allSatisfy { ownedIDs.contains($0.itemID) && isUnitPosition($0.position) }
    }
}
