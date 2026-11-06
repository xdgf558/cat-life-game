import SwiftUI
import CatGameCore

struct CommunityGiftEntry: View {
    @Bindable var store: GameStore
    let open: () -> Void

    private var count: Int {
        CommunityCatalog.gifts.reduce(0) { $0 + (store.snapshot?.inventory.giftCount($1.id) ?? 0) }
    }

    var body: some View {
        Button(action: open) {
            HStack(spacing: 12) {
                GameIcon(asset: "gift-flower", symbol: "gift.fill", size: 44, tint: RoomTheme.coral)
                VStack(alignment: .leading, spacing: 3) {
                    Text(GameStrings.text("community.giftEntry")).font(.subheadline.weight(.heavy))
                    Text(GameStrings.format("community.giftEntryCount", count))
                        .font(.caption.weight(.bold)).foregroundStyle(RoomTheme.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.heavy))
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading).gameCard(cornerRadius: 20)
        }
        .buttonStyle(.plain).disabled(store.isBusy)
        .accessibilityIdentifier("communityGiftEntry")
    }
}
