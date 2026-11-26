import Foundation

// MARK: - Progression

public enum DiaryProgression {
    public static func unlockLevel(for kind: UnlockKind, balance: DiaryBalance = .default) -> Int {
        balance.unlocks.first { $0.kind == kind }?.level ?? Int.max
    }

    public static func chainUnlocked(_ state: DiaryGameState, chain: MergeChain, balance: DiaryBalance = .default) -> Bool {
        state.progressLevel >= unlockLevel(for: .chain(chain), balance: balance)
    }

    public static func roomUnlocked(_ state: DiaryGameState, room: RoomID, balance: DiaryBalance = .default) -> Bool {
        state.progressLevel >= unlockLevel(for: .room(room), balance: balance)
    }

    public static func unlockedCustomers(_ state: DiaryGameState, balance: DiaryBalance = .default) -> [CustomerID] {
        DiaryCatalog.customers
            .filter { state.progressLevel >= unlockLevel(for: .customer($0.id), balance: balance) }
            .map(\.id)
    }

    public static func unlocks(at level: Int, balance: DiaryBalance = .default) -> [UnlockRule] {
        balance.unlocks.filter { $0.level == level }
    }

    public static func level(forXP xp: Int, balance: DiaryBalance = .default) -> Int {
        var resolved = 1
        for (idx, threshold) in balance.cat.levelXP.enumerated() where xp >= threshold {
            resolved = idx + 1
        }
        return min(resolved, balance.cat.maxLevel)
    }

    public static func xpProgress(for cat: DiaryCatState, balance: DiaryBalance = .default) -> (current: Int, target: Int, isMax: Bool) {
        let levels = balance.cat.levelXP
        if cat.level >= balance.cat.maxLevel || cat.level >= levels.count {
            return (1, 1, true)
        }
        let floorXP = levels[max(0, cat.level - 1)]
        let nextXP = levels[cat.level]
        return (max(0, cat.xp - floorXP), max(1, nextXP - floorXP), false)
    }

    @discardableResult
    public static func addXP(_ cat: inout DiaryCatState, amount: Int, balance: DiaryBalance = .default) -> [Int] {
        guard amount > 0 else { return [] }
        let before = cat.level
        cat.xp += amount
        cat.level = max(before, level(forXP: cat.xp, balance: balance))
        guard cat.level > before else { return [] }
        return Array((before + 1)...cat.level)
    }
}

// MARK: - Daily Wish

public enum DiaryWishEngine {
    public static func pool(for state: DiaryGameState, balance: DiaryBalance = .default) -> [WishGoal] {
        var goals: [WishGoal] = [
            .pet,
            .play(MergeItem(chain: .cloth, level: 3)),
            .play(MergeItem(chain: .cloth, level: 4)),
        ]
        if DiaryProgression.chainUnlocked(state, chain: .food, balance: balance) {
            goals.append(.feed(MergeItem(chain: .food, level: 3)))
            goals.append(.feed(MergeItem(chain: .food, level: 4)))
        }
        if DiaryProgression.chainUnlocked(state, chain: .wood, balance: balance) {
            goals.append(.play(MergeItem(chain: .wood, level: 3)))
            goals.append(.play(MergeItem(chain: .wood, level: 4)))
        }
        return goals
    }

    @discardableResult
    public static func ensureDailyWish(_ state: inout DiaryGameState, balance: DiaryBalance = .default) -> DailyWish? {
        if state.tutorialActive { return nil }
        if let existing = state.home.wish, existing.dayKey == state.dayKey { return existing }
        let all = pool(for: state, balance: balance)
        let fresh = state.home.wish.map { prev in all.filter { $0 != prev.goal } } ?? all
        let choices = fresh.isEmpty ? all : fresh
        var rng = SeededRNG(seed: state.dayKey &* 31 &+ 7)
        let chosen = rng.pick(from: choices) ?? .pet
        let wish = DailyWish(dayKey: state.dayKey, goal: chosen, completed: false)
        state.home.wish = wish
        return wish
    }

    public static func completeWish(
        _ state: inout DiaryGameState,
        catID: CatID,
        done: WishGoal,
        balance: DiaryBalance = .default
    ) -> (bonusXP: Int, levelUps: [Int])? {
        guard !state.tutorialActive,
              var wish = state.home.wish,
              !wish.completed,
              wish.dayKey == state.dayKey,
              wish.goal == done,
              var cat = state.cats[catID] else {
            return nil
        }
        wish.completed = true
        state.home.wish = wish
        let bonus = balance.cat.wishBonusXP
        let ups = DiaryProgression.addXP(&cat, amount: bonus, balance: balance)
        state.cats[catID] = cat
        return (bonus, ups)
    }
}

// MARK: - Home & Diary

public struct CatReaction: Equatable, Sendable {
    public let cat: CatID
    public let newPhotos: [String]
    public let xpGained: Int
    public let levelUps: [Int]
    public let wishBonus: Int
}

public enum BringHomeResult: Equatable, Sendable {
    case brought(MergeItem)
    case empty
    case levelTooLow
}

public enum CatInteractFailure: String, Equatable, Sendable {
    case noToy
    case noFood
    case hungry
    case cooldown
}

public enum PlayToyResult: Equatable, Sendable {
    case played(reaction: CatReaction, item: MergeItem, wornOut: Bool)
    case failed(CatInteractFailure)
}

public enum FeedCatResult: Equatable, Sendable {
    case fed(reaction: CatReaction, item: MergeItem)
    case failed(CatInteractFailure)
}

public enum PetCatResult: Equatable, Sendable {
    case petted(reaction: CatReaction)
    case failed(CatInteractFailure)
}

public struct HomeVisitResult: Equatable, Sendable {
    public let offlineNoteID: String?
    public let furnitureUsed: [FurnitureID]
    public let dailyMoment: String?
    public let newPhotos: [String]
    public let xpGained: Int
    public let levelUps: [Int]
    public let hungry: Bool
}

public struct NewFurnitureReaction: Equatable, Sendable {
    public let furnitureUsed: [FurnitureID]
    public let newPhotos: [String]
    public let xpGained: Int
    public let levelUps: [Int]
}

public enum DiaryHome {
    public static func settleCat(_ cat: inout DiaryCatState, now: Int64, balance: DiaryBalance = .default) {
        let dt = Double(max(0, now - cat.updatedAt))
        let cfg = balance.cat
        cat.satiety = max(0, cat.satiety - dt * cfg.satietyDecayPerMs)
        let drift = dt * cfg.moodDriftPerMs
        if cat.mood > cfg.moodBaseline {
            cat.mood = max(cfg.moodBaseline, cat.mood - drift)
        } else {
            cat.mood = min(cfg.moodBaseline, cat.mood + drift)
        }
        cat.updatedAt = max(cat.updatedAt, now)
    }

    public static func settleCats(_ state: inout DiaryGameState, now: Int64, balance: DiaryBalance = .default) {
        for id in state.cats.keys {
            if var cat = state.cats[id] {
                settleCat(&cat, now: now, balance: balance)
                state.cats[id] = cat
            }
        }
    }

    public static func isHungry(_ cat: DiaryCatState, balance: DiaryBalance = .default) -> Bool {
        cat.satiety < balance.cat.hungryBelow
    }

    public static func petCooldownLeft(_ cat: DiaryCatState, now: Int64, balance: DiaryBalance = .default) -> Int64 {
        guard let last = cat.lastPetAt, now >= last else { return 0 }
        return max(0, balance.cat.petCooldownMs - (now - last))
    }

    public static func isRainyDay(dayKey: Int, balance: DiaryBalance = .default) -> Bool {
        var rng = SeededRNG(seed: UInt32(truncatingIfNeeded: dayKey) &* 2_654_435_761)
        return rng.nextUnit() < balance.home.rainyDayChance
    }

    public static func isNightHour(_ hour: Int) -> Bool {
        hour >= 22 || hour < 4
    }

    public static func sceneLight(now: Int64, savedDayKey: Int, balance: DiaryBalance = .default, calendar: Calendar = .current) -> SceneLight {
        if isNightHour(DayClock.hour(for: now, calendar: calendar)) { return .night }
        let key = DayClock.monotonicDayKey(now: now, lastDayKey: savedDayKey, calendar: calendar)
        return isRainyDay(dayKey: key, balance: balance) ? .rain : .day
    }

    public static func photoProgress(_ state: DiaryGameState) -> (got: Int, total: Int) {
        let owned = Set(state.diary.photos)
        let got = DiaryCatalog.photos.filter { owned.contains($0.id) }.count
        return (got, DiaryCatalog.photos.count)
    }

    private static func triggerMet(_ cat: DiaryCatState, photo: PhotoDef) -> Bool {
        switch photo.trigger {
        case .firstItem(let item): cat.itemsTried.contains(item)
        case .firstFurniture(let furniture): cat.furnitureUsed.contains(furniture)
        case .playCount(let count): cat.playCount >= count
        case .toyWornOut: cat.flags.toyWornOut
        case .feedCount(let count): cat.feedCount >= count
        case .fullBelly: cat.flags.fullBelly
        case .firstHungry: cat.flags.hungry
        case .daily: false
        }
    }

    public static func collectPhotos(_ state: inout DiaryGameState, catID: CatID, now: Int64) -> [String] {
        guard let cat = state.cats[catID] else { return [] }
        var fresh: [String] = []
        for photo in DiaryCatalog.photos where photo.cat == catID && !state.diary.photos.contains(photo.id) {
            if triggerMet(cat, photo: photo) {
                state.addPhoto(photo.id, now: now)
                fresh.append(photo.id)
            }
        }
        return fresh
    }

    public static func bringHome(_ state: inout DiaryGameState, cellIndex: Int, balance: DiaryBalance = .default) -> BringHomeResult {
        guard state.board.cells.indices.contains(cellIndex), let item = state.board.cells[cellIndex] else {
            return .empty
        }
        guard item.level >= balance.cat.minUsableLevel else { return .levelTooLow }
        state.board.cells[cellIndex] = nil
        if item.isFood {
            state.home.food.append(item)
        } else {
            state.home.toys.append(OwnedToy(item: item, usesLeft: balance.cat.toyUses))
        }
        return .brought(item)
    }

    public static func playWithToy(
        _ state: inout DiaryGameState,
        toyIndex: Int,
        now: Int64,
        catID: CatID = .primary,
        balance: DiaryBalance = .default
    ) -> PlayToyResult {
        guard var cat = state.cats[catID] else { return .failed(.noToy) }
        settleCat(&cat, now: now, balance: balance)
        guard state.home.toys.indices.contains(toyIndex) else { return .failed(.noToy) }
        if isHungry(cat, balance: balance) && !state.tutorialActive {
            state.cats[catID] = cat
            return .failed(.hungry)
        }

        let item = state.home.toys[toyIndex].item
        state.home.toys[toyIndex].usesLeft -= 1
        let wornOut = state.home.toys[toyIndex].usesLeft <= 0
        if wornOut {
            state.home.toys.remove(at: toyIndex)
            cat.flags.toyWornOut = true
        }
        if !cat.itemsTried.contains(item) { cat.itemsTried.append(item) }
        cat.playCount += 1
        cat.mood = min(100, cat.mood + balance.cat.playMood)
        state.cats[catID] = cat

        let reaction = finishInteraction(&state, catID: catID, wishDone: .play(item), now: now, balance: balance)
        return .played(reaction: reaction, item: item, wornOut: wornOut)
    }

    public static func feed(
        _ state: inout DiaryGameState,
        foodIndex: Int,
        now: Int64,
        catID: CatID = .primary,
        balance: DiaryBalance = .default
    ) -> FeedCatResult {
        guard var cat = state.cats[catID] else { return .failed(.noFood) }
        settleCat(&cat, now: now, balance: balance)
        guard state.home.food.indices.contains(foodIndex) else { return .failed(.noFood) }

        let item = state.home.food.remove(at: foodIndex)
        let cfg = balance.cat
        let satGain = item.level < cfg.feedSatiety.count ? cfg.feedSatiety[item.level] : 0
        let moodGain = item.level < cfg.feedMood.count ? cfg.feedMood[item.level] : 0
        cat.satiety = min(100, cat.satiety + satGain)
        cat.mood = min(100, cat.mood + moodGain)
        if cat.satiety >= 100 { cat.flags.fullBelly = true }
        if !cat.itemsTried.contains(item) { cat.itemsTried.append(item) }
        cat.feedCount += 1
        state.cats[catID] = cat

        let reaction = finishInteraction(&state, catID: catID, wishDone: .feed(item), now: now, balance: balance)
        return .fed(reaction: reaction, item: item)
    }

    public static func pet(
        _ state: inout DiaryGameState,
        now: Int64,
        catID: CatID = .primary,
        balance: DiaryBalance = .default
    ) -> PetCatResult {
        guard var cat = state.cats[catID] else { return .failed(.cooldown) }
        settleCat(&cat, now: now, balance: balance)
        if petCooldownLeft(cat, now: now, balance: balance) > 0 {
            state.cats[catID] = cat
            return .failed(.cooldown)
        }
        cat.lastPetAt = now
        cat.petCount += 1
        cat.mood = min(100, cat.mood + balance.cat.petMood)
        state.cats[catID] = cat

        let reaction = finishInteraction(&state, catID: catID, wishDone: .pet, now: now, balance: balance)
        return .petted(reaction: reaction)
    }

    private static func finishInteraction(
        _ state: inout DiaryGameState,
        catID: CatID,
        wishDone: WishGoal,
        now: Int64,
        balance: DiaryBalance
    ) -> CatReaction {
        let newPhotos = collectPhotos(&state, catID: catID, now: now)
        var xp = balance.cat.xpPerInteraction + newPhotos.count * balance.cat.xpFirstReaction
        var cat = state.cats[catID]!
        var levelUps = DiaryProgression.addXP(&cat, amount: xp, balance: balance)
        state.cats[catID] = cat

        var wishBonus = 0
        if let w = DiaryWishEngine.completeWish(&state, catID: catID, done: wishDone, balance: balance) {
            wishBonus = w.bonusXP
            xp += w.bonusXP
            levelUps.append(contentsOf: w.levelUps)
        }
        return CatReaction(cat: catID, newPhotos: newPhotos, xpGained: xp, levelUps: levelUps, wishBonus: wishBonus)
    }

    public static func settleNewFurniture(
        _ state: inout DiaryGameState,
        now: Int64,
        balance: DiaryBalance = .default
    ) -> NewFurnitureReaction {
        var cat = state.primaryCat
        settleCat(&cat, now: now, balance: balance)
        let placedIDs = Set(state.home.layout.map(\.id))
        let fresh = state.home.furnitureOwned.filter { !cat.furnitureUsed.contains($0) && placedIDs.contains($0) }
        guard !fresh.isEmpty else {
            state.primaryCat = cat
            return NewFurnitureReaction(furnitureUsed: [], newPhotos: [], xpGained: 0, levelUps: [])
        }
        for id in fresh {
            cat.furnitureUsed.append(id)
            cat.mood = min(100, cat.mood + balance.cat.furnitureMood)
        }
        state.primaryCat = cat
        let newPhotos = collectPhotos(&state, catID: .primary, now: now)
        let xp = newPhotos.count * balance.cat.xpFirstReaction
        var updatedCat = state.primaryCat
        let ups = DiaryProgression.addXP(&updatedCat, amount: xp, balance: balance)
        state.primaryCat = updatedCat
        return NewFurnitureReaction(furnitureUsed: fresh, newPhotos: newPhotos, xpGained: xp, levelUps: ups)
    }

    public static func pickOfflineNoteID<R: RandomSource>(
        _ state: DiaryGameState,
        now: Int64,
        rng: inout R,
        balance: DiaryBalance = .default,
        calendar: Calendar = .current
    ) -> String {
        let light = sceneLight(now: now, savedDayKey: state.dayKey, balance: balance, calendar: calendar)
        let specialWeather: SceneLight? = (light == .rain || light == .night) ? light : nil
        let special = specialWeather.map { w in DiaryCatalog.offlineNotes.filter { $0.weather == w } } ?? []
        let placed = Set(state.home.layout.map(\.id))
        let usual = DiaryCatalog.offlineNotes.filter { note in
            note.weather == nil && (note.furniture == nil || placed.contains(note.furniture!))
        }
        let u = rng.nextUnit()
        let specialWeight = 0.7
        if !special.isEmpty, u < specialWeight {
            let idx = min(special.count - 1, Int(floor((u / specialWeight) * Double(special.count))))
            return special[idx].id
        }
        let v = special.isEmpty ? u : (u - specialWeight) / (1.0 - specialWeight)
        let idx = min(usual.count - 1, max(0, Int(floor(v * Double(usual.count)))))
        return usual[idx].id
    }

    private static func dailyConditionMet(
        _ state: DiaryGameState,
        cat: DiaryCatState,
        condition: DailyCondition,
        now: Int64,
        balance: DiaryBalance,
        calendar: Calendar
    ) -> Bool {
        let hour = DayClock.hour(for: now, calendar: calendar)
        switch condition {
        case .any: return true
        case .morning: return hour >= 5 && hour < 9
        case .night: return isNightHour(hour)
        case .rain: return isRainyDay(dayKey: state.dayKey, balance: balance)
        case .happy: return cat.mood >= balance.cat.rareMomentMoodAbove
        case .toyCollector:
            let toyCount = DiaryCatalog.photos.filter { $0.category == .toy && state.diary.photos.contains($0.id) }.count
            return toyCount >= 5
        }
    }

    public static func visitHome<R: RandomSource>(
        _ state: inout DiaryGameState,
        now: Int64,
        rng: inout R,
        balance: DiaryBalance = .default,
        calendar: Calendar = .current
    ) -> HomeVisitResult {
        let last = state.home.lastVisitAt
        let noteID: String? = if let last, now - last >= balance.home.offlineNoteAfterMs {
            pickOfflineNoteID(state, now: now, rng: &rng, balance: balance, calendar: calendar)
        } else {
            nil
        }
        state.home.lastVisitAt = now
        DiaryWishEngine.ensureDailyWish(&state, balance: balance)

        var cat = state.primaryCat
        settleCat(&cat, now: now, balance: balance)
        let placedIDs = Set(state.home.layout.map(\.id))
        let furnitureUsed = state.home.furnitureOwned.filter { !cat.furnitureUsed.contains($0) && placedIDs.contains($0) }
        for f in furnitureUsed {
            cat.furnitureUsed.append(f)
            cat.mood = min(100, cat.mood + balance.cat.furnitureMood)
        }
        let hungry = isHungry(cat, balance: balance) && !state.tutorialActive
        if hungry { cat.flags.hungry = true }
        state.primaryCat = cat

        var newPhotos = collectPhotos(&state, catID: .primary, now: now)
        var dailyMoment: String? = nil
        if !state.tutorialActive {
            let chance = cat.mood >= balance.cat.rareMomentMoodAbove
                ? balance.home.dailyMomentChanceHappy
                : balance.home.dailyMomentChance
            if rng.nextUnit() < chance {
                let candidates = DiaryCatalog.photos.filter { photo in
                    guard case .daily(let cond) = photo.trigger, !state.diary.photos.contains(photo.id) else {
                        return false
                    }
                    return dailyConditionMet(state, cat: cat, condition: cond, now: now, balance: balance, calendar: calendar)
                }
                if let picked = rng.pick(from: candidates) {
                    state.addPhoto(picked.id, now: now)
                    dailyMoment = picked.id
                    newPhotos.append(picked.id)
                }
            }
        }
        let xp = newPhotos.count * balance.cat.xpFirstReaction
        var updatedCat = state.primaryCat
        let ups = DiaryProgression.addXP(&updatedCat, amount: xp, balance: balance)
        state.primaryCat = updatedCat
        return HomeVisitResult(
            offlineNoteID: noteID,
            furnitureUsed: furnitureUsed,
            dailyMoment: dailyMoment,
            newPhotos: newPhotos,
            xpGained: xp,
            levelUps: ups,
            hungry: hungry
        )
    }
}
