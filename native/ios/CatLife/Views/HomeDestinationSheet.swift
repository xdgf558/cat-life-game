import SwiftUI
import CatGameCore

@MainActor
struct HomeDestinationSheet: View {
    let destination: HomeSheet
    @Bindable var store: GameStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    switch destination {
                    case .shop: shop
                    case .inventory: InventoryView(store: store)
                    case .work: EmptyView()
                    case .town: cats
                    case .player: EmptyView()
                    }
                }
                .padding(20)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("destinationScroll")
            .background(RoomTheme.cream)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(GameStrings.text("common.done")) { dismiss() }
                        .foregroundStyle(RoomTheme.darkMint)
                        .accessibilityIdentifier("closeSheetButton")
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    SaveStatusBanner(store: store)
                    if let toast = store.toast, !toast.isEmpty {
                        Text(toast)
                            .font(.system(size: 14, weight: .medium))
                            .multilineTextAlignment(.center)
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(RoomTheme.paper)
                            .accessibilityIdentifier("sheetToast")
                    }
                }
            }
        }
        .saveRecoveryAlert(store: store)
        .fontDesign(.rounded)
        .foregroundStyle(RoomTheme.ink)
        .presentationDetents(destination == .town ? [.medium, .large] : [.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(RoomTheme.cream)
        #if DEBUG
        .overlay(alignment: .topLeading) { AudioDiagnosticsView(store: store) }
        #endif
    }

    private var title: String {
        switch destination {
        case .work: return GameStrings.text("work.title")
        case .shop: return GameStrings.text("shop.title")
        case .inventory: return GameStrings.text("inventory.title")
        case .town: return GameStrings.text("town.title")
        case .player: return GameStrings.text("player.title")
        }
    }

    private var shop: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(GameStrings.text("shop.subtitle"))
                .font(.system(size: 25, weight: .bold, design: .rounded))
            Label(GameStrings.format("shop.balance", store.snapshot?.player.gold ?? 0), systemImage: "circle.fill")
                .foregroundStyle(RoomTheme.secondary)
                .font(.system(size: 16, weight: .semibold))
                .accessibilityIdentifier("shopGoldCount")
                .accessibilityValue("\(store.snapshot?.player.gold ?? 0)")

            VStack(spacing: 0) {
                shopRow(name: "shop.food", detail: "shop.foodDetail", symbol: "takeoutbag.and.cup.and.straw.fill",
                        asset: "bowl-full", count: store.snapshot?.inventory.food ?? 0, price: 20,
                        identifier: "buyFoodButton", action: store.buyFood)
                Divider().overlay(RoomTheme.wood.opacity(0.4)).padding(.horizontal, 16)
                shopRow(name: "shop.litter", detail: "shop.litterDetail", symbol: "sparkles",
                        asset: "icon-clean", count: store.snapshot?.inventory.litter ?? 0, price: 18,
                        identifier: "buyLitterButton", action: store.buyLitter)
                Divider().overlay(RoomTheme.wood.opacity(0.4)).padding(.horizontal, 16)
                shopRow(name: "shop.toy", detail: "shop.toyDetail", symbol: "party.popper.fill",
                        asset: "icon-play", count: store.snapshot?.inventory.toys ?? 0, price: 35,
                        identifier: "buyToyButton", action: store.buyToy)
            }
            .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 24))
        }
    }

    private func shopRow(name: String, detail: String, symbol: String, asset: String, count: Int, price: Int,
                         identifier: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                GameIcon(asset: asset, symbol: symbol, size: 50, tint: RoomTheme.gold)
                VStack(alignment: .leading, spacing: 5) {
                    Text(GameStrings.text(name)).font(.system(size: 20, weight: .bold))
                    Text(GameStrings.text(detail)).font(.system(size: 14)).foregroundStyle(RoomTheme.secondary)
                }
                Spacer(minLength: 0)
            }
            HStack {
                Text(GameStrings.format("shop.owned", count)).font(.system(size: 14)).foregroundStyle(RoomTheme.secondary)
                Spacer()
                Button(action: action) {
                    Text(GameStrings.format("shop.buy", price)).font(.system(size: 16, weight: .bold))
                }
                .buttonStyle(MintButtonStyle())
                .disabled(store.isBusy)
                .accessibilityIdentifier(identifier)
            }
        }
        .padding(16)
    }

    private var cats: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(GameStrings.text("town.subtitle"))
                .font(.system(size: 16)).foregroundStyle(RoomTheme.secondary)
            ForEach(store.snapshot?.cats ?? []) { cat in
                VStack(spacing: 18) {
                    HStack(spacing: 16) {
                        GameIcon(asset: "cat-avatar", symbol: "cat.fill", size: 70, tint: RoomTheme.gold)
                        Text(GameStrings.catName(cat)).font(.system(size: 29, weight: .heavy, design: .rounded))
                        Spacer()
                    }
                    stat("stat.satiety", value: cat.satiety)
                    stat("stat.cleanliness", value: cat.cleanliness)
                    stat("stat.mood", value: cat.mood)
                    stat("stat.bond", value: cat.intimacy)
                    stat("rest.energy", value: cat.energy)
                        .accessibilityIdentifier(cat.id == store.cat?.id ? "catEnergy" : "catEnergy_\(cat.id)")
                }
                .padding(20)
                .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 24))
            }
        }
    }

    private func stat(_ title: String, value: Int) -> some View {
        HStack(spacing: 16) {
            Text(GameStrings.text(title)).font(.system(size: 15, weight: .semibold))
                .frame(width: 76, alignment: .leading)
                .lineLimit(1).minimumScaleFactor(0.8)
            ProgressView(value: Double(value), total: 100).tint(RoomTheme.mint)
            Text("\(value)").font(.system(size: 15, weight: .semibold)).monospacedDigit().frame(width: 30, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(GameStrings.text(title))
        .accessibilityValue("\(value)")
    }
}
