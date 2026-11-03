import SwiftUI
import CatGameCore

@MainActor
struct HomeDestinationSheet: View {
    let destination: HomeSheet
    @Bindable var store: GameStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            destinationContent
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

    @ViewBuilder private var destinationContent: some View {
        switch destination {
        case .shop: ShopView(store: store)
        case .upgrade: HomeUpgradeView(store: store)
        default:
            ScrollView {
                VStack(spacing: 22) {
                    switch destination {
                    case .inventory: InventoryView(store: store)
                    case .town: cats
                    case .work, .player, .shop, .upgrade: EmptyView()
                    }
                }
                .padding(20).frame(maxWidth: 520).frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("destinationScroll")
        }
    }

    private var title: String {
        switch destination {
        case .work: return GameStrings.text("work.title")
        case .shop: return GameStrings.text("shop.title")
        case .inventory: return GameStrings.text("inventory.title")
        case .town: return GameStrings.text("town.title")
        case .player: return GameStrings.text("player.title")
        case .upgrade: return GameStrings.text("homeUpgrade.title")
        }
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
