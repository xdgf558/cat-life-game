import SwiftUI
import CatGameCore

struct ShopPriceButtonStyle: ButtonStyle {
    var gold = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? .white : RoomTheme.secondary)
            .padding(.horizontal, 10).padding(.vertical, 10).frame(minHeight: 44)
            .background {
                RoundedRectangle(cornerRadius: 16).fill(isEnabled ? (gold ? RoomTheme.gold : RoomTheme.mint) : RoomTheme.track)
                    .shadow(color: isEnabled ? (gold ? PremiumSupplyStyle.effectText : RoomTheme.darkMint) : .clear,
                            radius: 0, y: configuration.isPressed ? 1 : 3)
            }
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.45), lineWidth: 2))
            .offset(y: configuration.isPressed ? 2 : 0)
            .opacity(isEnabled ? 1 : 0.6)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

@MainActor
struct FurniturePurchaseBanner: View {
    @Bindable var store: GameStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if let id = store.furniturePurchaseNotice, let offer = ShopCatalog.furnitureOffer(id: id) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 10) { contents(offer); decorateButton }
                } else {
                    HStack(spacing: 10) { contents(offer); decorateButton.fixedSize(horizontal: true, vertical: false) }
                }
            }
            .padding(12).background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(RoomTheme.paleMint, lineWidth: 2))
            .padding(.horizontal, 12).padding(.vertical, 8).background(RoomTheme.cream)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .accessibilityElement(children: .contain).accessibilityIdentifier("furniturePurchaseBanner")
        }
    }

    private func contents(_ offer: FurnitureOffer) -> some View {
        HStack(spacing: 10) {
            GameIcon(asset: offer.assetName, symbol: "sofa.fill", size: 38, tint: RoomTheme.darkMint)
                .frame(width: 44, height: 44).background(RoomTheme.paleMint, in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) {
                Text(GameStrings.format("shop.design.purchased", GameStrings.text(offer.nameKey)))
                    .font(.subheadline.weight(.heavy))
                Text(GameStrings.text(offer.kind.supportsMirroring ? "shop.design.placeFloorHint" : "shop.design.placeWallHint"))
                    .font(.caption.weight(.bold)).foregroundStyle(RoomTheme.secondary)
            }.fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var decorateButton: some View {
        Button { store.decoratePurchasedFurniture() } label: {
            Text(GameStrings.text("shop.design.decorate")).font(.subheadline.weight(.heavy))
        }
        .buttonStyle(ShopPriceButtonStyle()).disabled(store.isBusy)
        .accessibilityIdentifier("shopDecoratePurchaseButton")
    }
}
