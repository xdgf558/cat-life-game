import SwiftUI
import CatGameCore

@MainActor
struct ShopView: View {
    @Bindable var store: GameStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    GamePageHeading(title: GameStrings.text("shop.title"), subtitle: GameStrings.text("shop.subtitle"),
                                    symbol: "storefront.fill", tint: RoomTheme.coral,
                                    background: RoomTheme.coral.opacity(0.18))
                    Spacer(minLength: 0)
                    Label("\(store.snapshot?.player.gold ?? 0)", systemImage: "dollarsign.circle.fill")
                        .font(.system(size: 16, weight: .heavy)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                        .foregroundStyle(RoomTheme.gold).padding(12)
                        .background(RoomTheme.paper, in: Capsule())
                        .accessibilityLabel(GameStrings.text("resource.gold"))
                        .accessibilityIdentifier("shopGoldCount").accessibilityValue("\(store.snapshot?.player.gold ?? 0)")
                }
                if let featured = ShopListing.list(.furniture).last { featuredCard(featured) }
                HStack(spacing: 4) {
                    ForEach(ShopCategory.allCases, id: \.self) { option in
                        Button { store.shopCategory = option } label: {
                            Text(GameStrings.text("shop.category.\(option.rawValue)"))
                                .font(.system(size: 14, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.8)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .foregroundStyle(store.shopCategory == option ? RoomTheme.darkMint : RoomTheme.secondary)
                                .background(store.shopCategory == option ? RoomTheme.paper : .clear, in: Capsule())
                        }
                        .buttonStyle(.plain).accessibilityIdentifier("shopCategory_\(option.rawValue)")
                        .accessibilityAddTraits(store.shopCategory == option ? .isSelected : [])
                    }
                }
                .padding(4).background(RoomTheme.chipBg, in: Capsule())
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 14) {
                    ForEach(ShopListing.list(store.shopCategory)) { product in productCard(product) }
                }
            }
            .padding(16).padding(.bottom, 8).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .background(RoomTheme.cream)
        .accessibilityIdentifier("destinationScroll")
        .navigationDestination(for: ShopListing.self) { product in ShopDetailView(product: product, store: store) }
    }

    private func featuredCard(_ product: ShopListing) -> some View {
        HStack(spacing: 14) {
            NavigationLink(value: product) {
                GameIcon(asset: product.asset, symbol: product.symbol, size: 96, tint: RoomTheme.darkMint)
                    .padding(8).background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white, lineWidth: 3))
            }
            .buttonStyle(.plain).accessibilityLabel(GameStrings.text(product.nameKey))
            .accessibilityIdentifier("shopFeaturedDetails")
            VStack(alignment: .leading, spacing: 8) {
                Text(GameStrings.text("redesign.shop.featured"))
                    .font(.system(size: 11, weight: .heavy)).foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(RoomTheme.coral, in: Capsule())
                Text(GameStrings.text(product.nameKey)).font(.system(size: 19, weight: .heavy))
                    .lineLimit(2).minimumScaleFactor(0.8)
                Text(GameStrings.text(product.detailKey)).font(.system(size: 11, weight: .bold))
                    .foregroundStyle(RoomTheme.secondary).lineLimit(3)
                NavigationLink(value: product) {
                    Label(GameStrings.format("shop.buy", product.price), systemImage: "dollarsign.circle.fill")
                        .font(.system(size: 13, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(MintButtonStyle()).accessibilityIdentifier("shopFeaturedButton")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 28).fill(RoomTheme.wood)
                .shadow(color: RoomTheme.ink.opacity(0.22), radius: 0, y: 5)
        }
        .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(RoomTheme.ink.opacity(0.24), lineWidth: 2))
    }

    private func productCard(_ product: ShopListing) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if store.shopCategory == .supplies {
                productContents(product)
            } else {
                NavigationLink(value: product) { productContents(product) }
                    .buttonStyle(.plain)
                    .accessibilityLabel(GameStrings.text(product.nameKey) + ", " + GameStrings.format("shop.buy", product.price))
                    .accessibilityValue(product.status(in: store.snapshot))
                    .accessibilityIdentifier("shopItem_\(product.id)")
            }
            Button { product.purchase(in: store) } label: {
                HStack(spacing: 5) {
                    if !product.isOwned(in: store.snapshot) {
                        Image(systemName: "dollarsign.circle.fill").font(.system(size: 12)).accessibilityHidden(true)
                    }
                    Text(product.isOwned(in: store.snapshot) ? GameStrings.text("gear.owned")
                         : GameStrings.format("shop.buy", product.price))
                        .font(.system(size: 14, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.7)
                }.frame(maxWidth: .infinity)
            }
            .buttonStyle(ShopPriceButtonStyle())
            .disabled(store.isBusy || !product.canPurchase(in: store.snapshot))
            .accessibilityIdentifier(product.purchaseIdentifier(prefix: "shopQuickBuy_"))
        }
        .padding(12).gameCard(cornerRadius: 24)
    }

    private func productContents(_ product: ShopListing) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            GameIcon(asset: product.asset, symbol: product.symbol, size: 76, tint: product.tint)
                .frame(maxWidth: .infinity).frame(height: 96)
                .background(product.tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 18))
                .overlay(alignment: .topTrailing) {
                    if product.isOwned(in: store.snapshot) || product.unlockLevel > (store.snapshot?.player.level ?? 1) {
                        Text(product.isOwned(in: store.snapshot) ? GameStrings.text("gear.owned") : "Lv.\(product.unlockLevel)")
                            .font(.system(size: 10, weight: .heavy)).foregroundStyle(.white)
                            .padding(.horizontal, 7).padding(.vertical, 5)
                            .background(RoomTheme.secondary, in: Capsule()).padding(5)
                    }
                }
            Text(GameStrings.text(product.nameKey)).font(.system(size: 15, weight: .heavy))
                .foregroundStyle(RoomTheme.ink).lineLimit(2).frame(minHeight: 36, alignment: .topLeading)
            Text(product.status(in: store.snapshot))
                .font(.system(size: 11, weight: .bold)).foregroundStyle(RoomTheme.secondary)
                .lineLimit(2).frame(minHeight: 27, alignment: .topLeading)
                .accessibilityIdentifier((store.snapshot?.player.gold ?? 0) < product.price
                    ? "shopInsufficientGold_\(product.id)" : "shopItemStatus_\(product.id)")
        }
        .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
    }
}

private struct ShopPriceButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? .white : RoomTheme.secondary)
            .padding(.horizontal, 8).frame(minHeight: 44)
            .background {
                RoundedRectangle(cornerRadius: 16).fill(isEnabled ? RoomTheme.mint : RoomTheme.track)
                    .shadow(color: isEnabled ? RoomTheme.darkMint : .clear, radius: 0, y: configuration.isPressed ? 1 : 4)
            }
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.45), lineWidth: 2))
            .offset(y: configuration.isPressed ? 3 : 0)
            .opacity(isEnabled ? 1 : 0.6)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

enum ShopCategory: String, CaseIterable { case supplies, furniture, equipment }

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

    var tint: Color {
        switch kind {
        case .food: RoomTheme.gold
        case .litter: RoomTheme.sky
        case .toy: RoomTheme.coral
        case .equipment: RoomTheme.lilac
        case .furniture: RoomTheme.darkMint
        }
    }

    func canPurchase(in snapshot: GameSnapshot?) -> Bool {
        guard let snapshot else { return false }
        return !isOwned(in: snapshot) && !(limit.map { count(in: snapshot) >= $0 } ?? false)
            && snapshot.player.level >= unlockLevel && snapshot.player.gold >= price
    }

    @MainActor func status(in snapshot: GameSnapshot?) -> String {
        if isOwned(in: snapshot) { return GameStrings.text("gear.owned") }
        if let limit, count(in: snapshot) >= limit { return GameStrings.format("shop.furnitureLimit", limit) }
        if (snapshot?.player.level ?? 1) < unlockLevel { return GameStrings.format("career.unlock", unlockLevel) }
        if (snapshot?.player.gold ?? 0) < price { return GameStrings.text("action.insufficientGold") }
        if kind == .food || kind == .litter || kind == .toy { return GameStrings.format("shop.owned", count(in: snapshot)) }
        return GameStrings.text(detailKey)
    }

    func purchaseIdentifier(prefix: String = "shopBuy_") -> String {
        switch kind {
        case .food: "buyFoodButton"
        case .litter: "buyLitterButton"
        case .toy: "buyToyButton"
        case .equipment, .furniture: prefix + id
        }
    }

    @MainActor func purchase(in store: GameStore) {
        switch kind {
        case .food: store.buyFood()
        case .litter: store.buyLitter()
        case .toy: store.buyToy()
        case .equipment: store.buyEquipment(itemID: id)
        case .furniture: store.buyFurniture(offerID: id)
        }
    }

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
    private var canBuy: Bool { !store.isBusy && product.canPurchase(in: store.snapshot) }

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
                Button { product.purchase(in: store) } label: {
                    HStack(spacing: 5) {
                        if !alreadyOwned {
                            Image(systemName: "dollarsign.circle.fill").accessibilityHidden(true)
                        }
                        Text(alreadyOwned ? GameStrings.text("gear.owned") : GameStrings.format("shop.buy", product.price))
                    }
                    .font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(ShopPriceButtonStyle()).disabled(!canBuy)
                .accessibilityIdentifier(product.purchaseIdentifier())
                Label(GameStrings.format("shop.balance", store.snapshot?.player.gold ?? 0), systemImage: "dollarsign.circle.fill")
                    .font(.footnote).foregroundStyle(RoomTheme.secondary)
                    .accessibilityIdentifier("shopGoldCount").accessibilityValue("\(store.snapshot?.player.gold ?? 0)")
            }
            .padding(20).frame(maxWidth: 520, alignment: .leading).frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("shopDetailScroll").background(RoomTheme.cream)
        .navigationTitle(GameStrings.text("shop.detail.title")).navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar(.visible, for: .navigationBar)
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

    private func detail(_ key: String, value: String, id: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(GameStrings.text(key)).font(.caption).foregroundStyle(RoomTheme.secondary)
            Text(value).font(.headline)
        }
        .accessibilityElement(children: .combine).accessibilityIdentifier(id)
    }
}
