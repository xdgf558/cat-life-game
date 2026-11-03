import SwiftUI
import CatGameCore

@MainActor
struct ShopView: View {
    @Bindable var store: GameStore
    @State private var category = ShopCategory.supplies

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(GameStrings.text("shop.subtitle")).font(.title2.bold())
                Label(GameStrings.format("shop.balance", store.snapshot?.player.gold ?? 0), systemImage: "circle.fill")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(RoomTheme.secondary)
                    .accessibilityIdentifier("shopGoldCount")
                    .accessibilityValue("\(store.snapshot?.player.gold ?? 0)")
                HStack(spacing: 6) {
                    ForEach(ShopCategory.allCases, id: \.self) { option in
                        Button { category = option } label: {
                            Text(GameStrings.text("shop.category.\(option.rawValue)"))
                                .font(.subheadline.weight(.semibold))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .padding(.vertical, 4)
                                .background(category == option ? RoomTheme.paleMint : RoomTheme.paper,
                                            in: RoundedRectangle(cornerRadius: 15))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("shopCategory_\(option.rawValue)")
                        .accessibilityAddTraits(category == option ? .isSelected : [])
                    }
                }
                ForEach(ShopListing.list(category)) { product in
                    if category == .supplies {
                        supplyRow(product)
                    } else {
                        NavigationLink(value: product) {
                            HStack(spacing: 14) {
                                GameIcon(asset: product.asset, symbol: product.symbol, size: 52, tint: RoomTheme.darkMint)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(GameStrings.text(product.nameKey)).font(.headline)
                                    Text(GameStrings.format("shop.buy", product.price))
                                        .font(.subheadline).foregroundStyle(RoomTheme.secondary)
                                    if product.isOwned(in: store.snapshot) {
                                        Text(GameStrings.text("gear.owned")).font(.caption).foregroundStyle(RoomTheme.darkMint)
                                    } else if product.unlockLevel > (store.snapshot?.player.level ?? 1) {
                                        Text(GameStrings.format("career.unlock", product.unlockLevel))
                                            .font(.caption).foregroundStyle(RoomTheme.secondary)
                                    }
                                }
                                Spacer(minLength: 4)
                                Image(systemName: "chevron.right").font(.caption.bold()).accessibilityHidden(true)
                            }
                            .multilineTextAlignment(.leading)
                            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 22))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("shopItem_\(product.id)")
                    }
                }
            }
            .padding(20).frame(maxWidth: 520).frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("destinationScroll")
        .navigationDestination(for: ShopListing.self) { product in
            ShopDetailView(product: product, store: store)
        }
    }

    private func supplyRow(_ product: ShopListing) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { supplyLabel(product); Spacer(minLength: 4); supplyButton(product) }
            VStack(alignment: .leading, spacing: 12) { supplyLabel(product); supplyButton(product) }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 22))
    }

    private func supplyLabel(_ product: ShopListing) -> some View {
        HStack(spacing: 12) {
            GameIcon(asset: product.asset, symbol: product.symbol, size: 48, tint: RoomTheme.gold)
            VStack(alignment: .leading, spacing: 5) {
                Text(GameStrings.text(product.nameKey)).font(.headline)
                Text(GameStrings.text(product.detailKey)).font(.caption).foregroundStyle(RoomTheme.secondary)
                Text(GameStrings.format("shop.owned", product.count(in: store.snapshot)))
                    .font(.caption).foregroundStyle(RoomTheme.secondary)
            }
        }
    }

    private func supplyButton(_ product: ShopListing) -> some View {
        Button {
            switch product.kind {
            case .food: store.buyFood()
            case .litter: store.buyLitter()
            case .toy: store.buyToy()
            case .equipment, .furniture: break
            }
        } label: {
            Text(GameStrings.format("shop.buy", product.price)).font(.subheadline.bold())
        }
        .buttonStyle(MintButtonStyle()).disabled(store.isBusy)
        .accessibilityIdentifier(product.kind == .food ? "buyFoodButton" :
                                    (product.kind == .litter ? "buyLitterButton" : "buyToyButton"))
    }
}

private enum ShopCategory: String, CaseIterable { case supplies, furniture, equipment }

private struct ShopListing: Identifiable, Hashable {
    enum Kind: Hashable { case food, litter, toy, equipment, furniture }
    let id: String
    let kind: Kind
    let nameKey: String
    let detailKey: String
    let asset: String
    let symbol: String
    let price: Int
    let unlockLevel: Int
    var limit: Int? = nil

    @MainActor static func list(_ category: ShopCategory) -> [Self] {
        switch category {
        case .supplies:
            return [
                .init(id: "food", kind: .food, nameKey: "shop.food", detailKey: "shop.foodDetail",
                      asset: "bowl-full", symbol: "takeoutbag.and.cup.and.straw.fill", price: GameEngine.foodPrice, unlockLevel: 1),
                .init(id: "litter", kind: .litter, nameKey: "shop.litter", detailKey: "shop.litterDetail",
                      asset: "icon-clean", symbol: "sparkles", price: GameEngine.litterPrice, unlockLevel: 1),
                .init(id: "toy", kind: .toy, nameKey: "shop.toy", detailKey: "shop.toyDetail",
                      asset: "icon-play", symbol: "party.popper.fill", price: GameEngine.toyPrice, unlockLevel: 1)
            ]
        case .equipment:
            return ShopCatalog.equipmentOffers.compactMap { offer in
                guard let item = PlayerCatalog.item(id: offer.itemID) else { return nil }
                return .init(id: item.id, kind: .equipment, nameKey: item.nameKey, detailKey: item.detailKey,
                             asset: item.displayAssetName, symbol: "tshirt.fill", price: offer.price,
                             unlockLevel: offer.unlockLevel)
            }
        case .furniture:
            return ShopCatalog.furnitureOffers.map { offer in
                .init(id: offer.id, kind: .furniture, nameKey: offer.nameKey, detailKey: offer.detailKey,
                      asset: offer.assetName, symbol: "sofa.fill", price: offer.price,
                      unlockLevel: offer.unlockLevel, limit: offer.maxOwned)
            }
        }
    }

    func count(in snapshot: GameSnapshot?) -> Int {
        guard let snapshot else { return 0 }
        switch kind {
        case .food: return snapshot.inventory.food
        case .litter: return snapshot.inventory.litter
        case .toy: return snapshot.inventory.toys
        case .equipment: return snapshot.player.profile.ownedEquipmentIDs.contains(id) ? 1 : 0
        case .furniture: return ShopCatalog.ownedFurnitureCount(offerID: id, in: snapshot.inventory.furniture)
        }
    }

    func isOwned(in snapshot: GameSnapshot?) -> Bool { kind == .equipment && count(in: snapshot) > 0 }
}

@MainActor
private struct ShopDetailView: View {
    let product: ShopListing
    @Bindable var store: GameStore
    @Environment(\.dismiss) private var dismiss

    private var count: Int { product.count(in: store.snapshot) }
    private var alreadyOwned: Bool { product.isOwned(in: store.snapshot) }
    private var atLimit: Bool { product.limit.map { count >= $0 } ?? false }
    private var levelLocked: Bool { (store.snapshot?.player.level ?? 1) < product.unlockLevel }
    private var lacksGold: Bool { (store.snapshot?.player.gold ?? 0) < product.price }
    private var canBuy: Bool { store.snapshot != nil && !store.isBusy && !alreadyOwned && !atLimit && !levelLocked && !lacksGold }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(spacing: 16) {
                    GameIcon(asset: product.asset, symbol: product.symbol, size: 112, tint: RoomTheme.darkMint)
                    Text(GameStrings.text(product.nameKey)).font(.title2.bold()).multilineTextAlignment(.center)
                        .accessibilityIdentifier("shopDetailName")
                }.frame(maxWidth: .infinity)
                Text(GameStrings.text(product.detailKey)).font(.body).foregroundStyle(RoomTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 14) {
                    detail("shop.price", value: GameStrings.format("shop.buy", product.price), id: "shopDetailPrice")
                    detail("shop.requirements", value: GameStrings.format("career.unlock", product.unlockLevel), id: "shopDetailRequirement")
                    Text(GameStrings.format(product.kind == .toy ? "inventory.playUses" : "shop.owned", count))
                        .font(.subheadline).foregroundStyle(RoomTheme.secondary)
                        .accessibilityIdentifier("shopOwned_\(product.id)").accessibilityValue("\(count)")
                    if let limit = product.limit {
                        Text(GameStrings.format("shop.limit", limit)).font(.footnote).foregroundStyle(RoomTheme.secondary)
                    }
                }
                .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 22))
                if product.kind == .equipment, let item = PlayerCatalog.item(id: product.id) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(GameStrings.text("shop.effects")).font(.headline)
                        Text(GameStrings.text("gear.slot.\(item.slot.rawValue)")).font(.subheadline)
                        if item.bonuses.durationReductionPercent > 0 {
                            Text(GameStrings.format("player.bonus.duration", item.bonuses.durationReductionPercent))
                        }
                        if item.bonuses.staminaReductionPercent > 0 {
                            Text(GameStrings.format("player.bonus.stamina", item.bonuses.staminaReductionPercent))
                        }
                        if item.bonuses.moodReductionPercent > 0 {
                            Text(GameStrings.format("player.bonus.mood", item.bonuses.moodReductionPercent))
                        }
                    }.font(.subheadline).foregroundStyle(RoomTheme.darkMint)
                }
                Text(GameStrings.text(product.kind == .equipment ? "shop.equipmentHint" :
                    (product.kind == .furniture ? "shop.furnitureHint" : "shop.suppliesHint")))
                    .font(.footnote).foregroundStyle(RoomTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let message = unavailableMessage {
                    Text(message).font(.subheadline).foregroundStyle(RoomTheme.secondary)
                        .accessibilityIdentifier("shopPurchaseStatus")
                }
                Button(action: purchase) {
                    Text(GameStrings.text(alreadyOwned ? "gear.owned" : "shop.purchase"))
                        .font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(MintButtonStyle()).disabled(!canBuy).opacity(canBuy ? 1 : 0.45)
                .accessibilityIdentifier(purchaseIdentifier)
                Label(GameStrings.format("shop.balance", store.snapshot?.player.gold ?? 0), systemImage: "circle.fill")
                    .font(.footnote).foregroundStyle(RoomTheme.secondary)
                    .accessibilityIdentifier("shopGoldCount").accessibilityValue("\(store.snapshot?.player.gold ?? 0)")
            }
            .padding(20).frame(maxWidth: 520, alignment: .leading).frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("shopDetailScroll").background(RoomTheme.cream)
        .navigationTitle(GameStrings.text("shop.detail.title")).navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: { Label(GameStrings.text("common.back"), systemImage: "chevron.left") }
                    .foregroundStyle(RoomTheme.darkMint).accessibilityIdentifier("shopDetailBackButton")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(GameStrings.text("common.done")) { store.activeSheet = nil }
                    .foregroundStyle(RoomTheme.darkMint).accessibilityIdentifier("closeSheetButton")
            }
        }
    }

    private var unavailableMessage: String? {
        if alreadyOwned { return GameStrings.text("shop.equipmentPurchased") }
        if atLimit { return GameStrings.format("shop.furnitureLimit", product.limit ?? 0) }
        if levelLocked { return GameStrings.format("shop.levelRequired", product.unlockLevel) }
        if lacksGold { return GameStrings.text("action.insufficientGold") }
        return nil
    }

    private var purchaseIdentifier: String {
        switch product.kind {
        case .food: "buyFoodButton"
        case .litter: "buyLitterButton"
        case .toy: "buyToyButton"
        case .equipment, .furniture: "shopBuy_\(product.id)"
        }
    }

    private func purchase() {
        switch product.kind {
        case .food: store.buyFood()
        case .litter: store.buyLitter()
        case .toy: store.buyToy()
        case .equipment: store.buyEquipment(itemID: product.id)
        case .furniture: store.buyFurniture(offerID: product.id)
        }
    }

    private func detail(_ key: String, value: String, id: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(GameStrings.text(key)).font(.caption).foregroundStyle(RoomTheme.secondary)
            Text(value).font(.headline)
        }
        .accessibilityElement(children: .combine).accessibilityIdentifier(id)
    }
}
