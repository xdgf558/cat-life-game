import SwiftUI
import CatGameCore

@MainActor
struct GameBottomBar: View {
    let store: GameStore
    @Binding var moreVisible: Bool
    let select: (HomeSheet?) -> Void

    var body: some View {
        HStack(spacing: 2) {
            tab("tab.home", english: "Home", symbol: "house.fill", id: "tabHome",
                selected: store.activeSheet == nil && !store.isShowingSettings && !moreVisible) { select(nil) }
            tab("tab.work", english: "Work", symbol: "briefcase.fill", id: "tabWork",
                selected: store.activeSheet == .work && !store.isShowingSettings && !moreVisible) { select(.work) }
            tab("tab.shop", english: "Shop", symbol: "storefront.fill", id: "tabShop",
                selected: store.activeSheet == .shop && !store.isShowingSettings && !moreVisible) { select(.shop) }
            tab("tab.town", english: "Cats", symbol: "pawprint.fill", id: "tabTown",
                selected: store.activeSheet == .town && !store.isShowingSettings && !moreVisible) { select(.town) }
            tab("tab.more", english: "More", symbol: "ellipsis.circle.fill", id: "tabMore",
                selected: moreVisible || store.isShowingSettings || [.inventory, .player, .upgrade].contains(store.activeSheet)) {
                store.playNavigationSound()
                withAnimation(.easeOut(duration: 0.18)) { moreVisible.toggle() }
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(RoomTheme.paper, in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("homeNavigationBar")
    }

    private func tab(_ key: String, english: String, symbol: String, id: String,
                     selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Image(systemName: symbol).font(.system(size: 23, weight: .bold))
                    .symbolRenderingMode(.hierarchical).foregroundStyle(selected ? RoomTheme.mint : RoomTheme.secondary.opacity(0.7))
                Text(GameStrings.text(key)).font(.system(size: 12, weight: .heavy))
                    .lineLimit(1).minimumScaleFactor(0.75)
                if store.language != .english {
                    Text(english).font(.system(size: 9, weight: .bold)).opacity(0.75).accessibilityHidden(true)
                }
            }
            .foregroundStyle(selected ? RoomTheme.darkMint : RoomTheme.ink)
            .frame(maxWidth: .infinity).frame(height: 56)
            .background(selected ? RoomTheme.paleMint : .clear, in: RoundedRectangle(cornerRadius: 18))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityIdentifier(id)
        .accessibilityLabel(GameStrings.text(key)).accessibilityAddTraits(selected ? .isSelected : [])
    }
}

@MainActor
struct GameMoreMenu: View {
    let store: GameStore
    let close: () -> Void
    let select: (HomeSheet?) -> Void
    private var avatar: PlayerAvatar? { store.snapshot?.player.profile.avatarID.flatMap(PlayerCatalog.avatar(id:)) }

    var body: some View {
        ZStack(alignment: .bottom) {
            RoomTheme.ink.opacity(0.28).ignoresSafeArea(edges: .top).onTapGesture(perform: close)
                .accessibilityHidden(true)
            VStack(spacing: 12) {
                HStack {
                    Text(GameStrings.text("tab.more")).font(.headline)
                    Spacer()
                    Button(action: close) { Image(systemName: "xmark").frame(width: 44, height: 44) }
                        .accessibilityLabel(GameStrings.text("common.close")).accessibilityIdentifier("moreCloseButton")
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    tile("tab.inventory", asset: "icon-inventory", symbol: "backpack.fill", id: "tabInventory") {
                        store.inventoryCategory = .supplies; select(.inventory)
                    }
                    tile("tab.player", asset: "", symbol: "person.crop.circle.fill", id: "tabPlayer", portrait: true) { select(.player) }
                        .accessibilityValue(GameStrings.text(avatar?.nameKey ?? "player.avatar.unselected"))
                    tile("layout.edit", asset: "", symbol: "sofa.fill", id: "decorateButton") {
                        select(nil); store.beginDecorating()
                    }.disabled(store.isBusy)
                    tile("settings.title", asset: "", symbol: "gearshape.fill", id: "settingsButton") {
                        select(nil); store.openSettings()
                    }.disabled(store.isBusy)
                }
            }
            .padding(16).background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 28))
            .shadow(color: RoomTheme.ink.opacity(0.18), radius: 16, y: 6)
            .padding(10).accessibilityElement(children: .contain).accessibilityIdentifier("moreMenu")
        }
    }

    private func tile(_ key: String, asset: String, symbol: String, id: String, portrait: Bool = false,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if portrait, let avatar {
                    Circle().fill(RoomTheme.paleMint).frame(width: 40, height: 40)
                        .overlay {
                            Image(avatar.assetName).resizable().scaledToFit()
                                .frame(width: 74, height: 74).offset(y: 18.5)
                        }.clipShape(Circle()).accessibilityHidden(true)
                } else {
                    GameIconTile(asset: asset, symbol: symbol, tint: RoomTheme.darkMint,
                                 background: RoomTheme.paleMint, size: 40)
                }
                Text(GameStrings.text(key)).font(.system(size: 14, weight: .heavy))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(12).frame(maxWidth: .infinity, minHeight: 76)
            .background(RoomTheme.cream, in: RoundedRectangle(cornerRadius: 20)).contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityIdentifier(id)
    }
}
