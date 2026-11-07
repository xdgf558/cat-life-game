import SwiftUI
import CatGameCore

@MainActor
struct ExchangeMarketView: View {
    @Bindable var store: GameStore
    var initialNeighborID: String? = nil
    let onClose: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var neighborID: String?
    @State private var page = 0
    @State private var selectedID: String?
    @State private var isWorking = false
    @State private var failed = false
    private var pageSize: Int { dynamicTypeSize.isAccessibilitySize ? 2 : 4 }

    private var offers: [ExchangeOffer] {
        ExchangeCatalog.offers.filter { neighborID == nil || $0.neighborID == neighborID }
    }
    private var pageCount: Int { max(1, (offers.count + pageSize - 1) / pageSize) }
    private var visibleOffers: [ExchangeOffer] { Array(offers.dropFirst(page * pageSize).prefix(pageSize)) }
    private var selectedOffer: ExchangeOffer? { selectedID.flatMap(ExchangeCatalog.offer) }

    var body: some View {
        Group {
            if let offer = selectedOffer, let snapshot = store.snapshot {
                ExchangeConfirmationView(offer: offer, snapshot: snapshot, isWorking: isWorking || store.isBusy,
                                         failed: failed, hasSaveFailure: store.hasSaveFailure,
                                         confirm: { exchange(offer) }, cancel: { selectedID = nil; failed = false })
            } else { listings }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            CommunityHeader(title: GameStrings.text(selectedOffer == nil ? "market.title" : "market.confirmTitle"),
                            backTitle: selectedOffer == nil ? (initialNeighborID == nil ? "tab.town" : "community.title") : "market.title",
                            gold: store.snapshot?.player.gold ?? 0, symbol: "arrow.left.arrow.right",
                            backID: "marketBackButton", disabled: isWorking || store.isBusy) {
                if selectedOffer != nil { selectedID = nil; failed = false } else { onClose() }
            }
            .accessibilityElement(children: .contain).accessibilityIdentifier("marketHeader")
        }
        .fontDesign(.rounded).foregroundStyle(RoomTheme.ink).tint(RoomTheme.darkMint)
        .environment(\.locale, Locale(identifier: store.language.rawValue))
        .toolbar(.hidden, for: .navigationBar).navigationBarBackButtonHidden(true)
        .background(RoomTheme.cream)
        .onAppear { neighborID = initialNeighborID }
        .onChange(of: dynamicTypeSize) { _, _ in page = min(page, pageCount - 1) }
        .onChange(of: store.saveSceneGeneration) { _, _ in selectedID = nil; failed = false; page = 0 }
    }

    private var listings: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    intro.id("marketTop")
                    filters
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12),
                                             count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 14) {
                        ForEach(visibleOffers) { offer in
                            if let snapshot = store.snapshot {
                                ExchangeOfferCard(offer: offer, snapshot: snapshot,
                                                  disabled: isWorking || store.isBusy) {
                                    store.playNavigationSound(); selectedID = offer.id; failed = false
                                }
                            }
                        }
                    }
                }.padding(16).frame(maxWidth: 640).frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize).accessibilityIdentifier("exchangeMarketScroll")
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if pageCount > 1 {
                    HStack(spacing: 16) {
                        Button { page -= 1; proxy.scrollTo("marketTop", anchor: .top) } label: {
                            Label(GameStrings.text("market.previous"), systemImage: "chevron.left")
                        }
                        .buttonStyle(SoftButtonStyle()).disabled(page == 0 || store.isBusy)
                        .accessibilityIdentifier("marketPreviousPage")
                        Text(GameStrings.format("market.page", page + 1, pageCount))
                            .font(.caption.weight(.heavy)).monospacedDigit()
                            .accessibilityIdentifier("marketPage").accessibilityValue("\(page + 1)/\(pageCount)")
                        Button { page += 1; proxy.scrollTo("marketTop", anchor: .top) } label: {
                            Label(GameStrings.text("market.next"), systemImage: "chevron.right")
                        }
                        .buttonStyle(SoftButtonStyle()).disabled(page + 1 >= pageCount || store.isBusy)
                        .accessibilityIdentifier("marketNextPage")
                    }
                    .font(.caption.weight(.heavy)).dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .padding(12).frame(maxWidth: .infinity).background(RoomTheme.cream)
                    .accessibilityElement(children: .contain).accessibilityIdentifier("marketPaginationBar")
                }
            }
        }
    }

    private var intro: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    Text(GameStrings.text("market.subtitle")).font(.headline.weight(.heavy))
                    dailyHint
                }
            } else {
                HStack(spacing: 12) {
                    GameIcon(asset: "town-market-cartoon", symbol: "arrow.left.arrow.right", size: 60, tint: RoomTheme.darkMint)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(GameStrings.text("market.subtitle")).font(.headline.weight(.heavy))
                        dailyHint
                    }
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).gameCard(cornerRadius: 24)
    }

    private var dailyHint: some View {
        Text(GameStrings.format("market.dailyHint", ExchangeCatalog.dailyLimit, ExchangeCatalog.friendship))
            .font(.caption.weight(.bold)).foregroundStyle(RoomTheme.secondary)
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filter(nil, name: GameStrings.text("market.all"))
                ForEach(CommunityCatalog.neighbors) { neighbor in
                    filter(neighbor.id, name: GameStrings.text(neighbor.nameKey))
                }
            }.padding(.vertical, 4)
        }.accessibilityIdentifier("marketFilters")
    }

    private func filter(_ id: String?, name: String) -> some View {
        Button { store.playNavigationSound(); neighborID = id; page = 0 } label: {
            Text(name).font(.subheadline.weight(.bold)).padding(.horizontal, 17).frame(minHeight: 44)
                .foregroundStyle(neighborID == id ? .white : RoomTheme.ink)
                .background(neighborID == id ? RoomTheme.mint : RoomTheme.paper, in: Capsule())
                .overlay(Capsule().strokeBorder(.white, lineWidth: 2))
        }
        .buttonStyle(.plain).disabled(store.isBusy)
        .accessibilityIdentifier("marketFilter_\(id ?? "all")")
        .accessibilityAddTraits(neighborID == id ? .isSelected : [])
    }

    private func exchange(_ offer: ExchangeOffer) {
        guard !isWorking, !store.isBusy else { return }
        isWorking = true; failed = false
        Task {
            defer { isWorking = false }
            if await store.exchange(offerID: offer.id) { selectedID = nil }
            else { failed = true }
        }
    }
}

@MainActor
private struct ExchangeOfferCard: View {
    let offer: ExchangeOffer
    let snapshot: GameSnapshot
    let disabled: Bool
    let select: () -> Void
    private var neighbor: NeighborDefinition? { CommunityCatalog.neighbor(id: offer.neighborID) }
    private var failure: ActionFailure? { ExchangeCatalog.eligibility(of: offer, in: snapshot) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let neighbor {
                HStack(spacing: 7) {
                    CommunityPortrait(neighbor: neighbor, size: 34)
                    Text(GameStrings.text(neighbor.nameKey)).font(.caption.weight(.heavy))
                    Spacer(minLength: 0)
                }
            }
            Text(GameStrings.text(offer.nameKey)).font(.subheadline.weight(.heavy))
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 6) {
                Text(GameStrings.text("market.give")).font(.caption2.weight(.bold)).foregroundStyle(RoomTheme.secondary)
                ForEach(Array(offer.inputs.enumerated()), id: \.offset) { _, stack in ExchangeItemRow(stack: stack) }
                Image(systemName: "arrow.down").font(.caption.weight(.bold)).foregroundStyle(RoomTheme.mint)
                Text(GameStrings.text("market.receive")).font(.caption2.weight(.bold)).foregroundStyle(RoomTheme.secondary)
                ForEach(Array(offer.outputs.enumerated()), id: \.offset) { _, stack in ExchangeItemRow(stack: stack) }
            }.accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            Text(ExchangePresentation.status(offer, snapshot: snapshot))
                .font(.caption2.weight(.bold)).foregroundStyle(failure == nil ? RoomTheme.darkMint : RoomTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("marketStatus_\(offer.id)")
            Button(GameStrings.text("market.preview"), action: select)
                .buttonStyle(SoftButtonStyle()).font(.caption.weight(.heavy)).disabled(disabled)
                .accessibilityIdentifier("marketOffer_\(offer.id)")
        }
        .padding(13).frame(maxWidth: .infinity, alignment: .leading).gameCard(cornerRadius: 24)
        .accessibilityElement(children: .contain)
    }
}

struct ExchangeItemRow: View {
    let stack: ExchangeStack
    var owned: Int? = nil
    var body: some View {
        HStack(spacing: 6) {
            GameIcon(asset: stack.item.assetName, symbol: stack.item.symbol, size: 27, tint: RoomTheme.gold)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(stack.item == .supply(.toy) ? GameStrings.format("market.toyUses", stack.quantity)
                     : GameStrings.format("market.itemQuantity", GameStrings.text(stack.item.nameKey), stack.quantity))
                    .font(.caption.weight(.heavy)).fixedSize(horizontal: false, vertical: true)
                if let owned {
                    Text(GameStrings.format("market.stock", owned)).font(.caption2.weight(.bold))
                        .foregroundStyle(owned >= stack.quantity ? RoomTheme.secondary : RoomTheme.coralDeep)
                        .accessibilityIdentifier("marketStock_\(stockID)").accessibilityValue("\(owned)")
                }
            }
        }.accessibilityElement(children: .contain)
    }

    private var stockID: String {
        switch stack.item { case .supply(let kind): kind.rawValue; case .gift(let id): id }
    }
}

@MainActor
enum ExchangePresentation {
    static func status(_ offer: ExchangeOffer, snapshot: GameSnapshot) -> String {
        if let failure = ExchangeCatalog.eligibility(of: offer, in: snapshot) {
            if failure == .exchangeStageRequired {
                let stage = CommunityCatalog.stages.first { $0.level == offer.requiredStage }
                return GameStrings.format("market.stageRequired", GameStrings.text(stage?.nameKey ?? "community.stage.3"))
            }
            if failure == .shopInventoryFull { return GameStrings.text("action.inventoryFull") }
            return GameStrings.text(failure.rawValue)
        }
        let remaining = max(0, ExchangeCatalog.dailyLimit - snapshot.community.exchangeCount(for: offer.neighborID).today)
        return GameStrings.format("market.remaining", remaining, ExchangeCatalog.dailyLimit)
    }
}
