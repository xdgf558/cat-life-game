import SwiftUI
import CatGameCore

// MARK: - Order Detail Sheet

struct OrderDetailSheetView: View {
    @Bindable var store: DiaryAppStore
    let order: CustomerOrder
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let ready = DiaryOrders.canDeliver(store.state, order: order)
        let checks = DiaryOrders.orderItemsOnBoard(store.state, order: order)
        let progress = store.state.orders.customerProgress[order.customer] ?? 0
        let giftEvery = DiaryBalance.default.orders.giftEveryOrders
        let canReroll = store.state.orders.rerollsUsedToday < DiaryBalance.default.orders.freeRerollsPerDay

        NavigationStack {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    Image(order.customer.avatarAssetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 58, height: 58)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(RoomTheme.wood, lineWidth: 2))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(GameStrings.format("order.detailTitle", GameStrings.customerName(order.customer)))
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(RoomTheme.ink)
                        HStack(spacing: 4) {
                            AssetOrSymbol(asset: "ui_coin", symbol: "dollarsign.circle.fill", size: 15, tint: RoomTheme.gold)
                            Text(GameStrings.format("order.wageLabel", order.wage))
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundStyle(RoomTheme.gold)
                        }
                        Text(GameStrings.format("order.customerProgress", min(progress, giftEvery), giftEvery))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(RoomTheme.secondary)
                    }
                    Spacer()
                }
                .padding(14)
                .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(RoomTheme.wood.opacity(0.7), lineWidth: 1.2))

                VStack(spacing: 10) {
                    ForEach(Array(order.items.enumerated()), id: \.offset) { idx, item in
                        let hasIt = idx < checks.count && checks[idx]
                        let isPinned = store.state.target?.item == item && store.state.target?.orderID == order.id
                        HStack(spacing: 12) {
                            Image(item.assetName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 44, height: 44)
                                .padding(4)
                                .background(RoomTheme.cream, in: RoundedRectangle(cornerRadius: 12))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(GameStrings.itemName(item))
                                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                                    .foregroundStyle(RoomTheme.ink)
                                Text(GameStrings.format("common.lvFormat", item.level))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(RoomTheme.secondary)
                            }
                            Spacer()
                            if hasIt {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(RoomTheme.mint)
                            } else {
                                Button(isPinned ? GameStrings.text("workshop.clearTarget") : GameStrings.text("workshop.pinTarget")) {
                                    if isPinned { store.clearTarget() }
                                    else { store.setTarget(item: item, orderID: order.id) }
                                }
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .foregroundStyle(isPinned ? RoomTheme.coralDeep : RoomTheme.ink)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(isPinned ? RoomTheme.paleCoral : RoomTheme.chipBg, in: Capsule())
                            }
                        }
                        .padding(12)
                        .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(RoomTheme.wood.opacity(0.6), lineWidth: 1))
                    }
                }

                Spacer()

                HStack(spacing: 12) {
                    Button(GameStrings.text("order.reroll")) {
                        store.rerollOrder(order.id)
                    }
                    .buttonStyle(SoftPaperButtonStyle())
                    .frame(maxWidth: .infinity)
                    .disabled(!canReroll)

                    Button(GameStrings.text("order.deliver")) {
                        store.deliverOrder(order.id)
                        dismiss()
                    }
                    .buttonStyle(WarmButtonStyle(fill: RoomTheme.mint, shadowColor: RoomTheme.darkMint))
                    .frame(maxWidth: .infinity)
                    .disabled(!ready)
                }
            }
            .padding(16)
            .background(RoomTheme.cream.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(GameStrings.text("common.close")) { dismiss() }
                        .fontWeight(.bold)
                        .foregroundStyle(RoomTheme.coralDeep)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Watercolor Parchment Ad Offer Modal (Fair Equal-Size Buttons)

struct AdOfferOverlayView: View {
    let offer: AdOffer
    let currentCoins: Int
    let onWatch: () -> Void
    let onRefuse: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 16) {
                switch offer {
                case .material(let m):
                    materialContent(m)
                case .wage(let w):
                    wageContent(w)
                }
            }
            .padding(24)
            .background(WatercolorPanelBackground())
            .padding(.horizontal, 24)
        }
    }

    @ViewBuilder
    private func materialContent(_ offer: MaterialOffer) -> some View {
        Text(GameStrings.text("ad.materialTitle"))
            .font(.system(size: 19, weight: .heavy, design: .rounded))
            .foregroundStyle(RoomTheme.ink)

        ZStack {
            Circle()
                .fill(RoomTheme.rewardPaper)
                .frame(width: 88, height: 88)
                .overlay(Circle().stroke(RoomTheme.wood, lineWidth: 1.5))
            Image(offer.target.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 66, height: 66)
        }

        Text(
            offer.catIsHungry
                ? GameStrings.format("ad.materialHungryHeadline", offer.count, GameStrings.itemName(offer.item))
                : GameStrings.format("ad.materialHeadline", offer.count, GameStrings.itemName(offer.item), GameStrings.itemName(offer.target))
        )
        .font(.system(size: 15, weight: .bold, design: .rounded))
        .foregroundStyle(RoomTheme.ink)
        .multilineTextAlignment(.center)

        VStack(spacing: 5) {
            ProgressView(value: Double(offer.completedUnits), total: Double(max(1, offer.totalUnits)))
                .tint(RoomTheme.mint)
            Text(GameStrings.format("ad.materialProgress", GameStrings.itemName(offer.target), offer.completedUnits, offer.totalUnits))
                .font(.caption.weight(.bold))
                .foregroundStyle(RoomTheme.secondary)
        }

        HStack(spacing: 10) {
            Button(GameStrings.text("ad.materialRefuse"), action: onRefuse)
                .buttonStyle(SoftPaperButtonStyle())
                .frame(maxWidth: .infinity)
            Button(GameStrings.format("ad.materialWatch", offer.count, GameStrings.itemName(offer.item)), action: onWatch)
                .buttonStyle(WarmButtonStyle(fill: RoomTheme.mint, shadowColor: RoomTheme.darkMint))
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func wageContent(_ offer: WageOffer) -> some View {
        Text(GameStrings.text("ad.wageTitle"))
            .font(.system(size: 19, weight: .heavy, design: .rounded))
            .foregroundStyle(RoomTheme.ink)

        Text(GameStrings.format("ad.wageHeadline", offer.amount))
            .font(.system(size: 15, weight: .heavy, design: .rounded))
            .foregroundStyle(RoomTheme.darkMint)

        if let furn = offer.furniture, let price = offer.furniturePrice {
            HStack(spacing: 12) {
                Image(furn.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .padding(5)
                    .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 5) {
                    let afterCoins = currentCoins + offer.amount
                    let shortAfter = max(0, price - afterCoins)
                    Text(
                        shortAfter == 0
                            ? GameStrings.format("ad.wageWishComplete", offer.amount, GameStrings.furnitureName(furn))
                            : GameStrings.format("ad.wageWishProgress", GameStrings.furnitureName(furn), offer.amount, shortAfter)
                    )
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(RoomTheme.ink)
                    ProgressView(value: Double(min(price, afterCoins)), total: Double(max(1, price)))
                        .tint(RoomTheme.gold)
                }
            }
            .padding(12)
            .background(RoomTheme.rewardPaper, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(RoomTheme.rewardBorder, lineWidth: 1))
        } else {
            Text(GameStrings.format("ad.wagePlain", offer.amount))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(RoomTheme.secondary)
                .multilineTextAlignment(.center)
        }

        HStack(spacing: 10) {
            Button(GameStrings.text("ad.wageRefuse"), action: onRefuse)
                .buttonStyle(SoftPaperButtonStyle())
                .frame(maxWidth: .infinity)
            Button(GameStrings.format("ad.wageWatch", offer.amount), action: onWatch)
                .buttonStyle(WarmButtonStyle(fill: RoomTheme.coral, shadowColor: RoomTheme.coralDeep))
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - M1 Mock Rewarded Ad Player

struct MockAdPlaybackOverlayView: View {
    let slot: AdSlot
    let onFinish: (AdPlayResult) -> Void
    @State private var remaining = 3

    var body: some View {
        ZStack {
            Color.black.opacity(0.86).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(RoomTheme.gold)
                Text(GameStrings.text("ad.mockTitle"))
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(GameStrings.text("ad.mockSubtitle"))
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)

                if remaining > 0 {
                    Text("\(remaining)s")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(RoomTheme.gold)
                }

                VStack(spacing: 10) {
                    Button(GameStrings.text("ad.mockFinish")) {
                        onFinish(.ended)
                    }
                    .buttonStyle(WarmButtonStyle(fill: RoomTheme.mint, shadowColor: RoomTheme.darkMint))
                    .disabled(remaining > 0)

                    HStack(spacing: 10) {
                        Button(GameStrings.text("ad.mockCloseEarly")) {
                            onFinish(.closed)
                        }
                        .buttonStyle(SoftPaperButtonStyle())

                        Button(GameStrings.text("ad.mockFail")) {
                            onFinish(.failed)
                        }
                        .buttonStyle(SoftPaperButtonStyle())
                    }
                }
            }
            .padding(24)
        }
        .task {
            while remaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                remaining -= 1
            }
        }
    }
}

// MARK: - Polaroid Photo Reveal & Level Up Celebrations

struct PhotoRevealOverlayView: View {
    let photoID: String
    let capturedAt: Int64?
    let onKeep: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.52).ignoresSafeArea()
            VStack(spacing: 18) {
                Text(GameStrings.text("diary.newPhotoTitle"))
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 4, y: 2)

                ZStack(alignment: .top) {
                    VStack(spacing: 12) {
                        Image(photoID)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 230)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Text(GameStrings.photoTitle(photoID))
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundStyle(RoomTheme.ink)

                        Text(GameStrings.photoCaption(photoID))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(RoomTheme.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 4)
                    }
                    .padding(16)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.3), radius: 18, y: 10)
                    .rotationEffect(.degrees(-1.2))

                    WashiTapeStrip(tint: RoomTheme.coral.opacity(0.55), width: 64)
                        .offset(y: -6)
                }

                Button(GameStrings.text("diary.keepPhoto"), action: onKeep)
                    .buttonStyle(WarmButtonStyle(fill: RoomTheme.coral, shadowColor: RoomTheme.coralDeep))
                    .accessibilityIdentifier("photoKeepButton")
            }
            .padding(.horizontal, 28)
        }
    }
}

struct LevelUpOverlayView: View {
    let item: LevelUpModalItem
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.48).ignoresSafeArea()
            VStack(spacing: 14) {
                Image("cat_happy")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 118, height: 118)
                    .shadow(color: RoomTheme.ink.opacity(0.14), radius: 6, y: 4)

                Text(GameStrings.format("diary.levelUpTitle", item.level))
                    .font(.system(size: 21, weight: .heavy, design: .rounded))
                    .foregroundStyle(RoomTheme.ink)

                if !item.unlocks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(item.unlocks, id: \.self) { rule in
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(RoomTheme.gold)
                                Text(GameStrings.unlockDescription(rule))
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(RoomTheme.ink)
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoomTheme.rewardPaper, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(RoomTheme.rewardBorder, lineWidth: 1))
                }

                Button(GameStrings.text("diary.levelUpGreat"), action: onDismiss)
                    .buttonStyle(WarmButtonStyle(fill: RoomTheme.mint, shadowColor: RoomTheme.darkMint))
            }
            .padding(24)
            .background(WatercolorPanelBackground())
            .padding(.horizontal, 26)
        }
    }
}
