import SwiftUI
import CatGameCore

struct ShopSheetView: View {
    @Bindable var store: DiaryAppStore
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(DiaryCatalog.shopFurniture, id: \.id) { def in
                        furnitureCard(def)
                    }
                }
                .padding(16)
            }
            .background(RoomTheme.cream.ignoresSafeArea())
            .navigationTitle(GameStrings.text("shop.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 5) {
                        AssetOrSymbol(asset: "ui_coin", symbol: "dollarsign.circle.fill", size: 18, tint: RoomTheme.gold)
                        Text("\(store.state.coins)")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(RoomTheme.ink)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 6)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(GameStrings.text("common.done")) { dismiss() }
                        .fontWeight(.bold)
                        .foregroundStyle(RoomTheme.coralDeep)
                }
            }
        }
    }

    private func furnitureCard(_ def: FurnitureDef) -> some View {
        let owned = store.state.home.furnitureOwned.contains(def.id)
        let roomOpen = DiaryProgression.roomUnlocked(store.state, room: def.room)
        let price = def.price ?? 0
        let canAfford = store.state.coins >= price
        let isWish = store.state.home.wishlist == def.id

        return VStack(spacing: 9) {
            // Illustrated Studio Pedestal
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [RoomTheme.rewardPaper, RoomTheme.cream],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 108)

                Ellipse()
                    .fill(RoomTheme.wood.opacity(0.32))
                    .frame(width: 72, height: 14)
                    .blur(radius: 3)
                    .offset(y: 34)

                Image(def.id.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 82, height: 82)
                    .opacity(roomOpen ? 1.0 : 0.45)

                // Top badges: Room pill left, Wishlist heart right
                VStack {
                    HStack {
                        Text(GameStrings.roomName(def.room))
                            .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(RoomTheme.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(RoomTheme.paper.opacity(0.9), in: Capsule())
                        Spacer()
                        if !owned && roomOpen {
                            Button {
                                store.toggleWishlist(def.id)
                            } label: {
                                Image(systemName: isWish ? "heart.fill" : "heart")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(isWish ? RoomTheme.heartPink : RoomTheme.secondary.opacity(0.65))
                                    .frame(width: 28, height: 28)
                                    .background(RoomTheme.paper.opacity(0.92), in: Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Spacer()
                }
                .padding(7)
            }

            VStack(spacing: 2) {
                Text(GameStrings.furnitureName(def.id))
                    .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(RoomTheme.ink)
                    .lineLimit(1)

                if isWish && !owned {
                    Text(GameStrings.text("shop.wishlistTag"))
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(RoomTheme.coralDeep)
                }
            }

            // Action pill
            if owned {
                Label(GameStrings.text("shop.owned"), systemImage: "checkmark.seal.fill")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(RoomTheme.darkMint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(RoomTheme.paleMint, in: Capsule())
            } else if !roomOpen {
                let lv = DiaryProgression.unlockLevel(for: .room(def.room))
                Label(GameStrings.format("common.lvFormat", lv), systemImage: "lock.fill")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(RoomTheme.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(RoomTheme.track, in: Capsule())
            } else {
                Button {
                    store.buyFurniture(def.id)
                } label: {
                    HStack(spacing: 4) {
                        AssetOrSymbol(asset: "ui_coin", symbol: "dollarsign.circle.fill", size: 14, tint: canAfford ? .white : RoomTheme.gold)
                        Text(canAfford ? "\(price)" : GameStrings.format("shop.shortCoins", price - store.state.coins))
                            .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                    }
                    .foregroundStyle(canAfford ? .white : RoomTheme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8.5)
                    .background(
                        Capsule().fill(canAfford ? RoomTheme.mint : RoomTheme.chipBg)
                            .shadow(color: canAfford ? RoomTheme.darkMint.opacity(0.6) : .clear, radius: 0, y: 2)
                    )
                }
                .buttonStyle(CraftIconBadgeButtonStyle())
            }
        }
        .padding(10)
        .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isWish && !owned ? RoomTheme.coral : RoomTheme.wood.opacity(0.65), lineWidth: isWish && !owned ? 1.8 : 1.1)
        )
        .shadow(color: RoomTheme.ink.opacity(0.08), radius: 5, y: 3)
    }
}
