import SwiftUI
import CatGameCore

/// The bag is another view of the saved inventory, never a separate item store.
@MainActor
struct InventoryView: View {
    @Bindable var store: GameStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                GameIcon(asset: "icon-inventory", symbol: "backpack.fill", size: 48, tint: RoomTheme.darkMint)
                    .padding(12)
                    .background(RoomTheme.paleMint, in: RoundedRectangle(cornerRadius: 23))
                VStack(alignment: .leading, spacing: 6) {
                    Text(GameStrings.text(store.inventoryCategory == .supplies ? "inventory.subtitle" : "inventory.furnitureSubtitle"))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text(GameStrings.text(store.inventoryCategory == .supplies ? "inventory.hint" : "inventory.furnitureHint"))
                        .font(.system(size: 14))
                        .foregroundStyle(RoomTheme.secondary)
                }
            }

            HStack(spacing: 4) {
                categoryButton(.supplies, title: "inventory.supplies", identifier: "inventorySuppliesTab")
                categoryButton(.furniture, title: "inventory.furniture", identifier: "inventoryFurnitureTab")
            }
            .padding(4)
            .background(RoomTheme.paleMint.opacity(0.6), in: RoundedRectangle(cornerRadius: 18))

            if store.inventoryCategory == .supplies { supplies } else { furniture }
        }
    }

    private func categoryButton(_ category: InventoryCategory, title: String, identifier: String) -> some View {
        Button { store.inventoryCategory = category } label: {
            Text(GameStrings.text(title))
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(store.inventoryCategory == category ? RoomTheme.paper : .clear,
                            in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .foregroundStyle(store.inventoryCategory == category ? RoomTheme.darkMint : RoomTheme.secondary)
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(store.inventoryCategory == category ? .isSelected : [])
    }

    private var supplies: some View {
        VStack(alignment: .leading, spacing: 18) {
            if store.isDecorating {
                Text(GameStrings.text("inventory.finishLayoutForCare"))
                    .font(.system(size: 14))
                    .foregroundStyle(RoomTheme.secondary)
            }
            item(name: "shop.food", asset: "bowl-full", symbol: "takeoutbag.and.cup.and.straw.fill",
                 count: store.snapshot?.inventory.food ?? 0, countKey: "inventory.portions",
                 countLabel: "inventory.foodCount", countIdentifier: "inventoryFoodCount",
                 detail: GameStrings.format("inventory.foodDetail", store.foodRequired),
                 canUse: store.hasFood, actionKey: "care.feed", actionIdentifier: "useFoodButton",
                 restockIdentifier: "restockFoodButton", action: store.feed)

            item(name: "shop.litter", asset: "icon-clean", symbol: "sparkles",
                 count: store.snapshot?.inventory.litter ?? 0, countKey: "inventory.portions",
                 countLabel: "inventory.litterCount", countIdentifier: "inventoryLitterCount",
                 detail: GameStrings.text("inventory.litterDetail"),
                 canUse: (store.snapshot?.inventory.litter ?? 0) > 0,
                 actionKey: "care.clean", actionIdentifier: "useLitterButton",
                 restockIdentifier: "restockLitterButton", action: store.clean)

            item(name: "shop.toy", asset: "icon-play", symbol: "party.popper.fill",
                 count: store.snapshot?.inventory.toys ?? 0, countKey: "inventory.playUses",
                 countLabel: "inventory.toyUses", countIdentifier: "inventoryToyUses",
                 detail: GameStrings.format("inventory.toyDetail", GameEngine.toyUsesPerPurchase),
                 canUse: (store.snapshot?.inventory.toys ?? 0) > 0,
                 actionKey: "care.play", actionIdentifier: "useToyButton",
                 restockIdentifier: "restockToyButton", action: store.play)

            Button { store.activeSheet = .shop } label: {
                Label(GameStrings.text("inventory.visitShop"), systemImage: "basket.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SoftButtonStyle())
            .disabled(store.isBusy)
            .accessibilityIdentifier("inventoryShopButton")
        }
    }

    private var furniture: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Text(GameStrings.format("inventory.furnitureStoredCount", store.storedFurniture.count))
                    .font(.system(size: 18, weight: .bold))
                    .accessibilityValue("\(store.storedFurniture.count)")
                    .accessibilityIdentifier("inventoryStoredFurnitureCount")
                Spacer(minLength: 0)
                Text(GameStrings.format("inventory.furniturePlacedCount", store.placedFurnitureCount))
                    .font(.system(size: 14))
                    .foregroundStyle(RoomTheme.secondary)
                    .accessibilityValue("\(store.placedFurnitureCount)")
                    .accessibilityIdentifier("inventoryPlacedFurnitureCount")
            }
            if store.isDecorating {
                Label(GameStrings.text("inventory.layoutDraft"), systemImage: "pencil")
                    .font(.system(size: 13))
                    .foregroundStyle(RoomTheme.darkMint)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("inventoryLayoutDraft")
            }
            if !store.canPlaceMoreFurniture && !store.storedFurniture.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(store.furnitureCapacityNotice)
                        .font(.footnote).foregroundStyle(RoomTheme.secondary)
                    if store.canUpgradeHome {
                        Button(GameStrings.text("homeUpgrade.entry")) { store.openHomeUpgrade() }
                            .buttonStyle(SoftButtonStyle())
                            .disabled(store.isBusy || store.isResolvingLayout)
                            .accessibilityIdentifier("inventoryUpgradeButton")
                    }
                }
            }

            if store.storedFurniture.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "sofa.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(RoomTheme.wood)
                        .accessibilityHidden(true)
                    Text(GameStrings.text("inventory.furnitureEmpty"))
                        .font(.system(size: 18, weight: .semibold))
                        .accessibilityIdentifier("inventoryFurnitureEmpty")
                    Text(GameStrings.text("inventory.furnitureEmptyHint"))
                        .font(.system(size: 14))
                        .foregroundStyle(RoomTheme.secondary)
                        .multilineTextAlignment(.center)
                    Button(GameStrings.text("inventory.arrangeRoom")) {
                        store.beginDecorating()
                        store.activeSheet = nil
                    }
                    .buttonStyle(MintButtonStyle())
                    .disabled(store.isBusy || store.isResolvingLayout)
                    .accessibilityIdentifier("inventoryArrangeButton")
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 24))
            } else {
                ForEach(store.storedFurniture) { item in
                    furnitureRow(item)
                }
            }
        }
    }

    private func furnitureRow(_ item: FurnitureItem) -> some View {
        let metadata = FurnitureCatalog.metadata(for: item.kind)
        return HStack(spacing: 14) {
            Image(metadata.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(GameStrings.furnitureName(item))
                    .font(.system(size: 17, weight: .bold))
                    .accessibilityIdentifier("storedFurniture_\(item.id)")
                Text(GameStrings.text(metadata.isWall ? "inventory.wallFurniture" : "inventory.floorFurniture"))
                    .font(.system(size: 13))
                    .foregroundStyle(RoomTheme.secondary)
            }
            Spacer(minLength: 0)
            Button(GameStrings.text("inventory.placeFurniture")) { store.placeFurniture(id: item.id) }
                .font(.system(size: 15, weight: .semibold))
                .buttonStyle(MintButtonStyle())
                .disabled(store.isBusy || store.isResolvingLayout || !store.canPlaceMoreFurniture)
                .accessibilityIdentifier("placeFurniture_\(item.id)")
        }
        .padding(16)
        .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 24))
    }

    private func item(name: String, asset: String, symbol: String, count: Int, countKey: String,
                      countLabel: String, countIdentifier: String, detail: String, canUse: Bool,
                      actionKey: String, actionIdentifier: String, restockIdentifier: String,
                      action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                GameIcon(asset: asset, symbol: symbol, size: 48, tint: RoomTheme.gold)
                VStack(alignment: .leading, spacing: 6) {
                    Text(GameStrings.text(name)).font(.system(size: 19, weight: .bold))
                    Text(detail)
                        .font(.system(size: 13))
                        .foregroundStyle(RoomTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 2)
                Text(GameStrings.format(countKey, count))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(canUse ? RoomTheme.darkMint : RoomTheme.secondary)
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(RoomTheme.paleMint.opacity(canUse ? 0.8 : 0.35), in: Capsule())
                    .fixedSize()
                    .accessibilityLabel(GameStrings.text(countLabel))
                    .accessibilityValue("\(count)")
                    .accessibilityIdentifier(countIdentifier)
            }

            HStack(spacing: 12) {
                if !canUse {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(GameStrings.text(count == 0 ? "inventory.empty" : "inventory.insufficient"))
                            .font(.system(size: 13))
                            .foregroundStyle(RoomTheme.secondary)
                        Button(GameStrings.text("inventory.restock")) { store.activeSheet = .shop }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(RoomTheme.darkMint)
                            .disabled(store.isBusy)
                            .accessibilityIdentifier(restockIdentifier)
                    }
                }
                Spacer(minLength: 0)
                Button(action: action) {
                    Text(GameStrings.text(actionKey))
                        .font(.system(size: 16, weight: .bold))
                        .frame(minWidth: 56)
                }
                .buttonStyle(MintButtonStyle())
                .disabled(store.isBusy || store.isDecorating || !canUse)
                .opacity(canUse && !store.isDecorating ? 1 : 0.42)
                .accessibilityIdentifier(actionIdentifier)
            }
        }
        .padding(16)
        .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 24))
    }
}
