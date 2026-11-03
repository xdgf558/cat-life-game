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
        .presentationDetents([.large])
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
                    case .town, .work, .player, .shop, .upgrade: EmptyView()
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

}
