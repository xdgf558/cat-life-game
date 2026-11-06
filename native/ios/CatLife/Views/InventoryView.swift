import SwiftUI
import CatGameCore

/// Every tile reads the saved inventory; selecting one never consumes an item.
@MainActor
struct InventoryView: View {
    @Bindable var store: GameStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selection: Selection = .supply(.food)
    @State private var showsGifts = false

    private enum Selection: Equatable {
        case supply(Supply), furniture(String), equipment(String)
    }
    private enum Supply: String, CaseIterable {
        case food, litter, toy
        var asset: String { switch self { case .food: "bowl-full"; case .litter: "icon-clean"; case .toy: "icon-play" } }
        var symbol: String { switch self { case .food: "takeoutbag.and.cup.and.straw.fill"; case .litter: "sparkles"; case .toy: "party.popper.fill" } }
        var tint: Color { switch self { case .food: RoomTheme.gold; case .litter: RoomTheme.sky; case .toy: RoomTheme.coral } }
        var nameKey: String { "shop.\(rawValue)" }
        var countID: String { switch self { case .food: "inventoryFoodCount"; case .litter: "inventoryLitterCount"; case .toy: "inventoryToyUses" } }
        var countKey: String { switch self { case .food: "inventory.foodCount"; case .litter: "inventory.litterCount"; case .toy: "inventory.toyUses" } }
        var actionKey: String { switch self { case .food: "care.feed"; case .litter: "care.clean"; case .toy: "care.play" } }
        var useID: String { switch self { case .food: "useFoodButton"; case .litter: "useLitterButton"; case .toy: "useToyButton" } }
        var restockID: String { switch self { case .food: "restockFoodButton"; case .litter: "restockLitterButton"; case .toy: "restockToyButton" } }
    }
    private var furniture: [FurnitureItem] { store.snapshot?.inventory.furniture ?? [] }
    private var equipment: [EquipmentItem] {
        (store.snapshot?.player.profile.ownedEquipmentIDs ?? []).compactMap(PlayerCatalog.item(id:))
    }
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: dynamicTypeSize.isAccessibilitySize ? 2 : 3)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    GamePageHeading(title: GameStrings.text("tab.inventory"),
                        subtitle: GameStrings.text("bag.subtitle"), asset: "icon-inventory", symbol: "backpack.fill",
                        tint: RoomTheme.gold, background: RoomTheme.gold.opacity(0.18))
                    CommunityGiftEntry(store: store) { showsGifts = true }
                    sectionHeading("inventory.supplies", identifier: "inventorySuppliesTab") {
                        store.inventoryCategory = .supplies
                        selection = .supply(.food)
                        proxy.scrollTo("supplies", anchor: .top)
                    }.id("supplies")
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Supply.allCases, id: \.self) { supply in supplyTile(supply) }
                    }
                    sectionHeading("inventory.furniture", identifier: "inventoryFurnitureTab") {
                        store.inventoryCategory = .furniture
                        if let first = store.storedFurniture.first ?? furniture.first { selection = .furniture(first.id) }
                        proxy.scrollTo("furniture", anchor: .top)
                    }.id("furniture")
                    furnitureSummary
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(furniture) { item in furnitureTile(item) }
                    }
                    if furniture.isEmpty {
                        Text(GameStrings.text("inventory.furnitureEmpty"))
                            .font(.subheadline).foregroundStyle(RoomTheme.secondary)
                            .accessibilityIdentifier("inventoryFurnitureEmpty")
                    }
                    sectionHeading("bag.equipment", identifier: "inventoryEquipmentTab") {
                        if let first = equipment.first { selection = .equipment(first.id) }
                        proxy.scrollTo("equipment", anchor: .top)
                    }.id("equipment")
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(equipment) { item in equipmentTile(item) }
                    }
                    Button { store.activeSheet = .shop } label: {
                        Label(GameStrings.text("inventory.visitShop"), systemImage: "basket.fill")
                            .font(.subheadline.weight(.bold))
                    }
                    .buttonStyle(SoftButtonStyle()).disabled(store.isBusy)
                    .accessibilityIdentifier("inventoryShopButton")
                }
                .padding(16).frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(RoomTheme.cream)
            .navigationDestination(isPresented: $showsGifts) {
                CommunityGiftView(store: store, onClose: { showsGifts = false })
            }
            .accessibilityIdentifier("destinationScroll")
            .safeAreaInset(edge: .bottom, spacing: 0) {
                selectedItemBar.padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 12)
                    .background(RoomTheme.cream.opacity(0.96))
            }
            .onAppear {
                if store.inventoryCategory == .furniture {
                    if let first = store.storedFurniture.first ?? furniture.first { selection = .furniture(first.id) }
                    proxy.scrollTo("furniture", anchor: .top)
                }
            }
        }
    }

    private func sectionHeading(_ key: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(GameStrings.text(key)).font(.system(size: 17, weight: .heavy, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityIdentifier(identifier)
    }

    private func supplyTile(_ supply: Supply) -> some View {
        tile(name: GameStrings.text(supply.nameKey), asset: supply.asset, symbol: supply.symbol,
             badge: nil, tint: count(supply) == 0 ? RoomTheme.coral : RoomTheme.gold,
             selected: selection == .supply(supply)) { selection = .supply(supply) }
            .accessibilityIdentifier("inventoryItem_\(supply.rawValue)")
            .accessibilityElement(children: .contain)
            .overlay(alignment: .topTrailing) {
                // Keep the resource values independently readable by VoiceOver and UI tests.
                Text("\(count(supply))")
                    .font(.system(size: 12, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                    .padding(.horizontal, 10).frame(minHeight: 25)
                    .background(count(supply) == 0 ? RoomTheme.coral : RoomTheme.gold, in: Capsule())
                    .overlay(Capsule().strokeBorder(RoomTheme.paper, lineWidth: 2))
                    .offset(x: 2, y: -2).allowsHitTesting(false)
                    .accessibilityLabel(GameStrings.text(supply.countKey)).accessibilityValue("\(count(supply))")
                    .accessibilityIdentifier(supply.countID)
            }
    }

    private func furnitureTile(_ item: FurnitureItem) -> some View {
        let metadata = FurnitureCatalog.metadata(for: item.kind)
        return tile(name: GameStrings.furnitureName(item), asset: metadata.assetName, symbol: "sofa.fill",
                    badge: GameStrings.text(isPlaced(item.id) ? "bag.placedBadge" : "bag.storedBadge"),
                    tint: RoomTheme.mint, selected: selection == .furniture(item.id)) {
            selection = .furniture(item.id)
        }
        .accessibilityIdentifier("inventoryFurniture_\(item.id)")
        .accessibilityValue(GameStrings.text(isPlaced(item.id) ? "bag.placed" : "bag.stored"))
    }

    private func equipmentTile(_ item: EquipmentItem) -> some View {
        let equipped = store.snapshot?.player.profile.equipped[item.slot] == item.id
        return tile(name: GameStrings.text(item.nameKey), asset: item.displayAssetName, symbol: "tshirt.fill",
                    badge: equipped ? GameStrings.text("bag.equippedBadge") : nil,
                    tint: RoomTheme.lilac, selected: selection == .equipment(item.id)) {
            selection = .equipment(item.id)
        }
        .accessibilityIdentifier("inventoryEquipment_\(item.id)")
        .accessibilityValue(GameStrings.text(equipped ? "bag.equipped" : "bag.owned"))
    }

    private func tile(name: String, asset: String, symbol: String, badge: String?, tint: Color,
                      selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                GameIcon(asset: asset, symbol: symbol, size: 40, tint: tint)
                Text(name).font(.system(size: 12, weight: .heavy, design: .rounded))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? 122 : 100)
            .padding(.horizontal, 7).padding(.vertical, 7)
            .gameCard(cornerRadius: 20)
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(selected ? RoomTheme.mint : .clear, lineWidth: 3))
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(badge).font(.system(size: 12, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                        .padding(.horizontal, 10).frame(minHeight: 25).background(tint, in: Capsule())
                        .overlay(Capsule().strokeBorder(RoomTheme.paper, lineWidth: 2))
                        .offset(x: 2, y: -2).accessibilityHidden(true)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain).accessibilityLabel(name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var furnitureSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(GameStrings.format("inventory.furnitureStoredCount", store.storedFurniture.count))
                    .accessibilityValue("\(store.storedFurniture.count)")
                    .accessibilityIdentifier("inventoryStoredFurnitureCount")
                Spacer(minLength: 4)
                Text(GameStrings.format("inventory.furniturePlacedCount", store.placedFurnitureCount))
                    .accessibilityValue("\(store.placedFurnitureCount)")
                    .accessibilityIdentifier("inventoryPlacedFurnitureCount")
            }
            .font(.caption.weight(.bold)).foregroundStyle(RoomTheme.secondary)
            if store.isDecorating {
                Text(GameStrings.text("inventory.layoutDraft")).font(.caption)
                    .foregroundStyle(RoomTheme.darkMint).accessibilityIdentifier("inventoryLayoutDraft")
            }
            if !store.canPlaceMoreFurniture && !store.storedFurniture.isEmpty {
                Text(store.furnitureCapacityNotice).font(.caption).foregroundStyle(RoomTheme.secondary)
                if store.canUpgradeHome {
                    Button(GameStrings.text("homeUpgrade.entry")) { store.openHomeUpgrade() }
                        .buttonStyle(SoftButtonStyle()).disabled(store.isBusy || store.isResolvingLayout)
                        .accessibilityIdentifier("inventoryUpgradeButton")
                }
            }
        }
    }

    @ViewBuilder private var selectedItemBar: some View {
        switch selection {
        case .supply(let supply):
            actionBar(name: GameStrings.text(supply.nameKey), asset: supply.asset, symbol: supply.symbol,
                      detail: supplyDetail(supply), tint: supply.tint) {
                Button(GameStrings.text(canUse(supply) ? supply.actionKey : "inventory.restock")) {
                    if canUse(supply) { use(supply) } else { store.activeSheet = .shop }
                }
                .buttonStyle(MintButtonStyle())
                .disabled(store.isBusy || store.isDecorating)
                .accessibilityIdentifier(canUse(supply) ? supply.useID : supply.restockID)
            }
        case .furniture(let id):
            if let item = furniture.first(where: { $0.id == id }) {
                actionBar(name: GameStrings.furnitureName(item), asset: FurnitureCatalog.metadata(for: item.kind).assetName,
                          symbol: "sofa.fill", detail: GameStrings.text(isPlaced(id) ? "bag.placed" : "bag.stored"),
                          tint: RoomTheme.mint) {
                    Button(GameStrings.text(isPlaced(id) ? "inventory.arrangeRoom" : "inventory.placeFurniture")) {
                        if isPlaced(id) {
                            store.beginDecorating()
                            store.selectFurniture(id: id)
                            store.activeSheet = nil
                        } else { store.placeFurniture(id: id) }
                    }
                    .buttonStyle(MintButtonStyle())
                    .disabled(store.isBusy || store.isResolvingLayout || (!isPlaced(id) && !store.canPlaceMoreFurniture))
                    .accessibilityIdentifier(isPlaced(id) ? "inventoryArrangeButton" : "placeFurniture_\(id)")
                }
            }
        case .equipment(let id):
            if let item = PlayerCatalog.item(id: id) {
                actionBar(name: GameStrings.text(item.nameKey), asset: item.displayAssetName, symbol: "tshirt.fill",
                          detail: GameStrings.text(item.detailKey), tint: RoomTheme.lilac) {
                    Button(GameStrings.text("bag.dressUp")) { store.activeSheet = .player }
                        .buttonStyle(MintButtonStyle()).disabled(store.isBusy || store.isDecorating)
                        .accessibilityIdentifier("inventoryDressUpButton")
                }
            }
        }
    }

    private func actionBar<Action: View>(name: String, asset: String, symbol: String, detail: String,
                                         tint: Color, @ViewBuilder action: () -> Action) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    actionDescription(name: name, asset: asset, symbol: symbol, detail: detail, tint: tint)
                    action().font(.system(size: 14, weight: .heavy, design: .rounded)).fixedSize(horizontal: true, vertical: false)
                }
                VStack(alignment: .leading, spacing: 10) {
                    actionDescription(name: name, asset: asset, symbol: symbol, detail: detail, tint: tint)
                    action().font(.subheadline.weight(.bold)).frame(maxWidth: .infinity)
                }
            }
            if store.isDecorating {
                Text(GameStrings.text("inventory.finishLayoutForCare"))
                    .font(.caption).foregroundStyle(RoomTheme.secondary)
            }
        }
        .padding(14).gameCard(cornerRadius: 26)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("inventorySelectedItemBar")
    }

    private func actionDescription(name: String, asset: String, symbol: String, detail: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            GameIconTile(asset: asset, symbol: symbol, tint: tint, background: tint.opacity(0.16), size: 46)
            VStack(alignment: .leading, spacing: 4) {
                Text(name).font(.system(size: 15, weight: .heavy, design: .rounded)).lineLimit(2)
                Text(detail).font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(RoomTheme.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func count(_ supply: Supply) -> Int {
        switch supply {
        case .food: store.snapshot?.inventory.food ?? 0
        case .litter: store.snapshot?.inventory.litter ?? 0
        case .toy: store.snapshot?.inventory.toys ?? 0
        }
    }
    private func canUse(_ supply: Supply) -> Bool { supply == .food ? store.hasFood : count(supply) > 0 }
    private func supplyDetail(_ supply: Supply) -> String {
        switch supply {
        case .food: GameStrings.format("inventory.foodDetail", store.foodRequired)
        case .litter: GameStrings.text("inventory.litterDetail")
        case .toy: GameStrings.format("inventory.toyDetail", GameEngine.toyUsesPerPurchase)
        }
    }
    private func use(_ supply: Supply) {
        switch supply { case .food: store.feed(); case .litter: store.clean(); case .toy: store.play() }
    }
    private func isPlaced(_ id: String) -> Bool { store.sceneSnapshot?.home.furniture.contains { $0.itemID == id } == true }
}
