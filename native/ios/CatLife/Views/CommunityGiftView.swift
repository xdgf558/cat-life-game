import SwiftUI
import CatGameCore

/// Shared by the neighbor's gift picker and the shop's gift shelf.
@MainActor
struct CommunityGiftView: View {
    @Bindable var store: GameStore
    var neighborID: String? = nil
    var onGift: ((String) -> Void)? = nil
    var onClose: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isWorking = false
    @State private var failed = false
    @State private var purchasedID: String?

    private var neighbor: NeighborDefinition? { neighborID.flatMap(CommunityCatalog.neighbor) }
    private var gold: Int { store.snapshot?.player.gold ?? 0 }
    private var remainingGifts: Int {
        guard let neighborID else { return 0 }
        return store.snapshot?.community.relationship(for: neighborID).remainingGiftsToday ?? 0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(GameStrings.text(neighbor == nil ? "community.giftShop" : "community.chooseGift"))
                            .font(.title2.weight(.heavy)).accessibilityAddTraits(.isHeader)
                        if let neighbor {
                            Text(GameStrings.format("community.giftFor", GameStrings.text(neighbor.nameKey)))
                                .font(.subheadline.weight(.bold)).foregroundStyle(RoomTheme.secondary)
                        }
                    }
                    Spacer(minLength: 8)
                    Button { close() } label: {
                        Text(GameStrings.text("common.done")).font(.subheadline.weight(.heavy))
                    }
                    .buttonStyle(SoftButtonStyle()).fixedSize(horizontal: true, vertical: false).disabled(isWorking)
                    .accessibilityIdentifier("communityGiftCloseButton")
                }
                Label(GameStrings.format("shop.balance", gold), systemImage: "dollarsign.circle.fill")
                    .font(.subheadline.weight(.heavy)).foregroundStyle(RoomTheme.gold)
                    .accessibilityIdentifier("communityGiftBalance").accessibilityValue("\(gold)")
                if neighbor != nil {
                    Text(GameStrings.format("community.giftsRemaining", remainingGifts, CommunityCatalog.dailyGiftLimit))
                        .font(.caption.weight(.bold)).foregroundStyle(RoomTheme.secondary)
                        .accessibilityIdentifier("communityGiftDailyLimit")
                }
                if failed {
                    Text(GameStrings.text(store.hasSaveFailure ? "save.writeTitle" : "community.actionFailed"))
                        .font(.subheadline.weight(.bold)).foregroundStyle(RoomTheme.coralDeep)
                        .accessibilityIdentifier("communityGiftFailure")
                }
                if let gift = purchasedID.flatMap(CommunityCatalog.gift) {
                    Label(GameStrings.format("community.purchaseSuccess", GameStrings.text(gift.nameKey)),
                          systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.bold)).foregroundStyle(RoomTheme.darkMint)
                        .accessibilityIdentifier("communityGiftPurchased")
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12),
                                         count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 14) {
                    ForEach(CommunityCatalog.gifts) { gift in giftCard(gift) }
                }
                Text(GameStrings.text("community.giftShelfHint")).font(.caption.weight(.bold))
                    .foregroundStyle(RoomTheme.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(16).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize).background(RoomTheme.cream)
        .fontDesign(.rounded).foregroundStyle(RoomTheme.ink).tint(RoomTheme.darkMint)
        .environment(\.locale, Locale(identifier: store.language.rawValue))
        .accessibilityIdentifier("communityGiftShelf")
    }

    private func giftCard(_ gift: CommunityGift) -> some View {
        let stock = store.snapshot?.inventory.giftCount(gift.id) ?? 0
        let favorite = neighbor?.favoriteGiftIDs.contains(gift.id) == true
        return VStack(alignment: .leading, spacing: 10) {
            GameIcon(asset: gift.assetName, symbol: gift.symbol, size: 84, tint: RoomTheme.darkMint)
                .frame(height: 96).frame(maxWidth: .infinity)
                .background(favorite ? RoomTheme.paleMint : RoomTheme.chipBg, in: RoundedRectangle(cornerRadius: 20))
                .accessibilityHidden(true)
            Text(GameStrings.text(gift.nameKey)).font(.headline.weight(.heavy))
                .fixedSize(horizontal: false, vertical: true)
            Text(GameStrings.text(gift.detailKey)).font(.caption).foregroundStyle(RoomTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(GameStrings.format("shop.owned", stock)).font(.caption.weight(.bold))
                .foregroundStyle(RoomTheme.secondary).accessibilityIdentifier("communityGiftStock_\(gift.id)")
                .accessibilityValue("\(stock)")
            if let neighbor {
                let gain = min(CommunityCatalog.giftFriendship(neighborID: neighbor.id, giftID: gift.id),
                               100 - (store.snapshot?.community.relationship(for: neighbor.id).friendship ?? 0))
                Label(GameStrings.format(favorite ? "community.favoriteGain" : "community.ordinaryGain", gain),
                      systemImage: favorite ? "heart.fill" : "heart")
                    .font(.caption.weight(.bold)).foregroundStyle(favorite ? RoomTheme.darkMint : RoomTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button { give(gift) } label: {
                    Text(GameStrings.text("community.giveAction")).font(.subheadline.weight(.heavy))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(MintButtonStyle())
                .disabled(isWorking || store.isBusy || remainingGifts == 0 || stock == 0)
                .accessibilityIdentifier("giveCommunityGift_\(gift.id)")
            }
            Button { buy(gift) } label: {
                Label(GameStrings.format("shop.buy", gift.price), systemImage: "dollarsign.circle.fill")
                    .font(.subheadline.weight(.heavy)).frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(SoftButtonStyle())
            .disabled(isWorking || store.isBusy || gold < gift.price)
            .accessibilityLabel(GameStrings.text("shop.purchase") + " · " + GameStrings.text(gift.nameKey)
                                + " · " + GameStrings.format("shop.buy", gift.price))
            .accessibilityIdentifier("buyCommunityGift_\(gift.id)")
            if gold < gift.price {
                Text(GameStrings.text("shop.goldRequired")).font(.caption).foregroundStyle(RoomTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading).gameCard()
        .accessibilityElement(children: .contain).accessibilityIdentifier("communityGiftCard_\(gift.id)")
    }

    private func give(_ gift: CommunityGift) {
        guard !isWorking, !store.isBusy, let neighborID else { return }
        isWorking = true; failed = false; purchasedID = nil
        Task {
            defer { isWorking = false }
            if await store.giveNeighborGift(neighborID: neighborID, giftID: gift.id) {
                onGift?(gift.id)
                close()
            } else { failed = true }
        }
    }

    private func buy(_ gift: CommunityGift) {
        guard !isWorking, !store.isBusy else { return }
        isWorking = true; failed = false; purchasedID = nil
        Task {
            defer { isWorking = false }
            if await store.buyCommunityGift(id: gift.id) { purchasedID = gift.id }
            else { failed = true }
        }
    }

    private func close() {
        if let onClose { onClose() } else { dismiss() }
    }
}
