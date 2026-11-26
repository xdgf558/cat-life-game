import Foundation

// MARK: - Energy

public enum DiaryEnergy {
    @discardableResult
    public static func settle(_ state: inout DiaryGameState, now: Int64, balance: DiaryBalance = .default) -> Int {
        let maxEnergy = balance.energy.max
        let interval = balance.energy.regenIntervalMs
        if now < state.energy.updatedAt {
            state.energy.updatedAt = now
            return state.energy.current
        }
        if state.energy.current >= maxEnergy {
            state.energy.updatedAt = now
            return state.energy.current
        }
        let ticks = Int((now - state.energy.updatedAt) / interval)
        if ticks > 0 {
            state.energy.current = min(maxEnergy, state.energy.current + ticks)
            state.energy.updatedAt = state.energy.current >= maxEnergy
                ? now
                : state.energy.updatedAt + Int64(ticks) * interval
        }
        return state.energy.current
    }

    public static func msToNext(_ state: inout DiaryGameState, now: Int64, balance: DiaryBalance = .default) -> Int64 {
        settle(&state, now: now, balance: balance)
        guard state.energy.current < balance.energy.max else { return 0 }
        return max(0, balance.energy.regenIntervalMs - (now - state.energy.updatedAt))
    }

    public static func view(_ state: DiaryGameState, now: Int64, balance: DiaryBalance = .default) -> (current: Int, msToNext: Int64) {
        var copy = state
        let current = settle(&copy, now: now, balance: balance)
        let ms = msToNext(&copy, now: now, balance: balance)
        return (current, ms)
    }

    public static func spend(_ state: inout DiaryGameState, amount: Int, now: Int64, balance: DiaryBalance = .default) -> Bool {
        if state.tutorialActive { return true }
        settle(&state, now: now, balance: balance)
        guard state.energy.current >= amount else { return false }
        if state.energy.current >= balance.energy.max {
            state.energy.updatedAt = now
        }
        state.energy.current -= amount
        return true
    }
}

// MARK: - Board

public enum MoveItemResult: Equatable, Sendable {
    case moved
    case merged(MergeItem)
    case swapped
    case invalid
}

public enum GeneratorTapResult: Equatable, Sendable {
    case generated(item: MergeItem, cell: Int)
    case locked
    case noEnergy
}

public enum DiaryBoard {
    @discardableResult
    public static func placeItem(_ state: inout DiaryGameState, item: MergeItem) -> Int {
        if let idx = state.board.cells.firstIndex(where: { $0 == nil }) {
            state.board.cells[idx] = item
            return idx
        }
        state.board.pending.append(item)
        return -1
    }

    public static func moveItem(_ state: inout DiaryGameState, from: Int, to: Int) -> MoveItemResult {
        guard from != to,
              state.board.cells.indices.contains(from),
              state.board.cells.indices.contains(to),
              let a = state.board.cells[from] else {
            return .invalid
        }
        guard let b = state.board.cells[to] else {
            state.board.cells[to] = a
            state.board.cells[from] = nil
            return .moved
        }
        if a == b, let merged = a.nextLevel {
            state.board.cells[to] = merged
            state.board.cells[from] = nil
            return .merged(merged)
        }
        state.board.cells[to] = a
        state.board.cells[from] = b
        return .swapped
    }

    public static func claimPending(_ state: inout DiaryGameState) -> MergeItem? {
        guard !state.board.pending.isEmpty,
              let idx = state.board.cells.firstIndex(where: { $0 == nil }) else {
            return nil
        }
        let item = state.board.pending.removeFirst()
        state.board.cells[idx] = item
        return item
    }

    public static func sellPrice(of item: MergeItem, balance: DiaryBalance = .default) -> Int {
        let full = Double(item.energyValue) * balance.orders.wagePerEnergy
        return max(1, Int(floor(full * balance.sellRatio)))
    }

    public static func sellItem(_ state: inout DiaryGameState, at index: Int, balance: DiaryBalance = .default) -> Int {
        guard state.board.cells.indices.contains(index), let item = state.board.cells[index] else { return 0 }
        let price = sellPrice(of: item, balance: balance)
        state.board.cells[index] = nil
        state.coins += price
        return price
    }

    public static func tapGenerator<R: RandomSource>(
        _ state: inout DiaryGameState,
        chain: MergeChain,
        now: Int64,
        rng: inout R,
        balance: DiaryBalance = .default
    ) -> GeneratorTapResult {
        guard DiaryProgression.chainUnlocked(state, chain: chain, balance: balance) else { return .locked }
        guard DiaryEnergy.spend(&state, amount: balance.generator.cost, now: now, balance: balance) else {
            return .noEnergy
        }
        let level = (!state.tutorialActive && rng.nextUnit() < balance.generator.level2Chance) ? 2 : 1
        let item = MergeItem(chain: chain, level: level)
        let cell = placeItem(&state, item: item)
        return .generated(item: item, cell: cell)
    }

    public static func countOnBoard(_ state: DiaryGameState) -> [MergeItem: Int] {
        var counts: [MergeItem: Int] = [:]
        for item in state.board.cells.compactMap({ $0 }) {
            counts[item, default: 0] += 1
        }
        return counts
    }

    @discardableResult
    public static func takeFromBoard(_ state: inout DiaryGameState, item: MergeItem) -> Bool {
        guard let idx = state.board.cells.firstIndex(of: item) else { return false }
        state.board.cells[idx] = nil
        return true
    }

    /// Finds the first pair of identical mergeable cells for idle visual hint.
    public static func findMergeablePair(_ state: DiaryGameState) -> (Int, Int)? {
        var seen: [MergeItem: Int] = [:]
        for (idx, cell) in state.board.cells.enumerated() {
            guard let item = cell, item.nextLevel != nil else { continue }
            if let first = seen[item] { return (first, idx) }
            seen[item] = idx
        }
        return nil
    }
}

// MARK: - Orders & Furniture Shop

public enum DeliverOrderResult: Equatable, Sendable {
    case delivered(order: CustomerOrder, wage: Int, gift: FurnitureID?, replacement: CustomerOrder)
    case notFound
    case missingItems
}

public enum BuyFurnitureResult: Equatable, Sendable {
    case bought(furniture: FurnitureID, price: Int)
    case notForSale
    case owned
    case roomLocked(RoomID)
    case notEnoughCoins
}

public enum DiaryOrders {
    public static func wage(for items: [MergeItem], balance: DiaryBalance = .default) -> Int {
        let energy = items.reduce(0) { $0 + $1.energyValue }
        let raw = Double(energy) * balance.orders.wagePerEnergy
        let step = Double(balance.orders.wageRoundTo)
        return max(balance.orders.wageRoundTo, Int((raw / step).rounded()) * balance.orders.wageRoundTo)
    }

    public static func generateOrder<R: RandomSource>(
        _ state: inout DiaryGameState,
        rng: inout R,
        balance: DiaryBalance = .default
    ) -> CustomerOrder {
        let busy = Set(state.orders.active.map(\.customer))
        let all = DiaryProgression.unlockedCustomers(state, balance: balance)
        let free = all.filter { !busy.contains($0) }
        let customer = rng.pick(from: free.isEmpty ? all : free) ?? .ajian

        let chains = MergeChain.allCases.filter { DiaryProgression.chainUnlocked(state, chain: $0, balance: balance) }
        let count = rng.nextInt(in: balance.orders.minItems...balance.orders.maxItems)
        let maxLevel = state.progressLevel >= balance.orders.fullLevelFromCatLevel
            ? balance.orders.maxLevel
            : (balance.orders.maxLevel - 1)
        var items: [MergeItem] = []
        for _ in 0..<count {
            let chain = rng.pick(from: chains) ?? .cloth
            let level = rng.nextInt(in: balance.orders.minLevel...maxLevel)
            items.append(MergeItem(chain: chain, level: level))
        }
        items.sort()
        let id = "o\(state.orders.nextID)"
        state.orders.nextID += 1
        return CustomerOrder(id: id, customer: customer, items: items, wage: wage(for: items, balance: balance))
    }

    public static func ensureOrders<R: RandomSource>(
        _ state: inout DiaryGameState,
        rng: inout R,
        balance: DiaryBalance = .default
    ) {
        while state.orders.active.count < balance.orders.activeCount {
            state.orders.active.append(generateOrder(&state, rng: &rng, balance: balance))
        }
    }

    public static func canDeliver(_ state: DiaryGameState, order: CustomerOrder) -> Bool {
        let have = DiaryBoard.countOnBoard(state)
        var need: [MergeItem: Int] = [:]
        for item in order.items { need[item, default: 0] += 1 }
        return need.allSatisfy { (have[$0.key] ?? 0) >= $0.value }
    }

    public static func orderItemsOnBoard(_ state: DiaryGameState, order: CustomerOrder) -> [Bool] {
        var have = DiaryBoard.countOnBoard(state)
        return order.items.map { item in
            let n = have[item] ?? 0
            guard n > 0 else { return false }
            have[item] = n - 1
            return true
        }
    }

    public static func deliverOrder<R: RandomSource>(
        _ state: inout DiaryGameState,
        orderID: String,
        rng: inout R,
        balance: DiaryBalance = .default
    ) -> DeliverOrderResult {
        guard let idx = state.orders.active.firstIndex(where: { $0.id == orderID }) else { return .notFound }
        let order = state.orders.active[idx]
        guard canDeliver(state, order: order) else { return .missingItems }

        for item in order.items { DiaryBoard.takeFromBoard(&state, item: item) }
        state.coins += order.wage
        state.orders.completedTotal += 1
        let gift = advanceCustomer(&state, customer: order.customer, balance: balance)
        if state.target?.orderID == order.id { state.target = nil }

        let replacement = generateOrder(&state, rng: &rng, balance: balance)
        state.orders.active[idx] = replacement
        return .delivered(order: order, wage: order.wage, gift: gift, replacement: replacement)
    }

    private static func advanceCustomer(
        _ state: inout DiaryGameState,
        customer: CustomerID,
        balance: DiaryBalance
    ) -> FurnitureID? {
        let progress = (state.orders.customerProgress[customer] ?? 0) + 1
        state.orders.customerProgress[customer] = progress
        let gift = DiaryCatalog.customer(customer).gift
        if progress >= balance.orders.giftEveryOrders, !state.home.furnitureOwned.contains(gift) {
            state.home.furnitureOwned.append(gift)
            placeNewFurniture(&state, id: gift)
            return gift
        }
        return nil
    }

    public static func rerollOrder<R: RandomSource>(
        _ state: inout DiaryGameState,
        orderID: String,
        rng: inout R,
        balance: DiaryBalance = .default
    ) -> CustomerOrder? {
        guard state.orders.rerollsUsedToday < balance.orders.freeRerollsPerDay else { return nil }
        guard let idx = state.orders.active.firstIndex(where: { $0.id == orderID }) else { return nil }
        let fresh = generateOrder(&state, rng: &rng, balance: balance)
        state.orders.active[idx] = fresh
        if state.target?.orderID == orderID { state.target = nil }
        state.orders.rerollsUsedToday += 1
        return fresh
    }

    public static func setTarget(_ state: inout DiaryGameState, item: MergeItem, orderID: String? = nil) {
        state.target = CraftTarget(id: state.nextTargetID, item: item, orderID: orderID)
        state.nextTargetID += 1
    }

    public static func clearTarget(_ state: inout DiaryGameState) {
        state.target = nil
    }

    public static func placeNewFurniture(_ state: inout DiaryGameState, id: FurnitureID) {
        guard !state.home.layout.contains(where: { $0.id == id }),
              let def = DiaryCatalog.furnitureDef(id) else { return }
        state.home.layout.append(
            PlacedFurniture(id: id, room: def.room, x: def.defaultX, bottom: def.defaultBottom)
        )
    }

    public static func buyFurniture(
        _ state: inout DiaryGameState,
        id: FurnitureID,
        balance: DiaryBalance = .default
    ) -> BuyFurnitureResult {
        guard let def = DiaryCatalog.furnitureDef(id), let price = def.price else { return .notForSale }
        if state.home.furnitureOwned.contains(id) { return .owned }
        if !DiaryProgression.roomUnlocked(state, room: def.room, balance: balance) {
            return .roomLocked(def.room)
        }
        guard state.coins >= price else { return .notEnoughCoins }
        state.coins -= price
        state.home.furnitureOwned.append(id)
        placeNewFurniture(&state, id: id)
        if state.home.wishlist == id { state.home.wishlist = nil }
        return .bought(furniture: id, price: price)
    }

    public static func wishlistShortfall(_ state: DiaryGameState, balance: DiaryBalance = .default) -> Int? {
        guard let id = state.home.wishlist,
              let def = DiaryCatalog.furnitureDef(id),
              let price = def.price,
              !state.home.furnitureOwned.contains(id),
              DiaryProgression.roomUnlocked(state, room: def.room, balance: balance) else {
            return nil
        }
        return max(0, price - state.coins)
    }
}
