import SwiftUI
import CatGameCore

@MainActor
struct TownView: View {
    @Bindable var store: GameStore
    @State private var selectedPlace: TownPlace = .plaza
    @State private var layer: TownLayer = .all
    @State private var presentedCollection: CollectionRequest?

    private struct CollectionRequest: Identifiable {
        let id = UUID()
        var adoptionID: String?
    }
    private var cats: [CatState] { store.snapshot?.cats ?? [] }
    private var sickCount: Int { cats.filter { $0.healthState?.illness != nil }.count }
    private var availableOffer: CatAdoptionOffer? {
        CatCatalog.adoptionOffers.first { offer in !cats.contains { $0.id == offer.id } }
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    header
                    plots
                    detail
                        .frame(minHeight: max(230, geometry.size.height - 454), alignment: .top)
                        .background(RoomTheme.cream, in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
                        .padding(.top, -8)
                }
                .frame(maxWidth: 640).frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(TownPalette.grass)
            .accessibilityIdentifier("townMapScroll")
        }
        .saveRecoveryAlert(store: store, isActive: presentedCollection == nil)
        .sheet(item: $presentedCollection) { request in
            CatCollectionView(store: store, initialAdoptionID: request.adoptionID)
        }
    }

    private var header: some View {
        VStack(spacing: 5) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Text(GameStrings.text("tab.town"))
                    Image(systemName: "map.fill").font(.system(size: 15)).foregroundStyle(RoomTheme.darkMint)
                }
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .padding(.horizontal, 14).frame(height: 46)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(colors: [RoomTheme.wood, Color(red: 0.91, green: 0.72, blue: 0.47)],
                                             startPoint: .top, endPoint: .bottom))
                        .shadow(color: TownPalette.woodEdge, radius: 0, y: 4)
                }
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(TownPalette.woodEdge, lineWidth: 3))
                .accessibilityIdentifier("townMapTitle").accessibilityAddTraits(.isHeader)

                Button { openCollection() } label: {
                    Label(GameStrings.format("town.yourCatsCount", cats.count), systemImage: "pawprint.fill")
                        .font(.system(size: 12, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.75)
                        .padding(.horizontal, 10).frame(minHeight: 44)
                        .foregroundStyle(RoomTheme.darkMint)
                        .background(RoomTheme.paper, in: Capsule())
                        .overlay(Capsule().strokeBorder(.white, lineWidth: 2))
                }
                .buttonStyle(.plain).accessibilityIdentifier("townCollectionButton")
                .accessibilityLabel(GameStrings.text("town.myCats"))
                .accessibilityValue(GameStrings.format("catDirectory.count", cats.count))
                Spacer(minLength: 0)
                Button { choose(.plaza) } label: {
                    Image(systemName: "bell.fill").font(.system(size: 21))
                        .foregroundStyle(RoomTheme.lilac).frame(width: 44, height: 44)
                        .background(RoomTheme.paper, in: Circle())
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                }
                .buttonStyle(.plain).accessibilityLabel(GameStrings.text("town.communityPreview"))
                .accessibilityIdentifier("townCommunityPreviewButton")
            }
            HStack(spacing: 5) {
                ForEach(TownLayer.allCases) { item in
                    Button {
                        store.playNavigationSound()
                        layer = item
                    } label: {
                        Label(GameStrings.text(item.titleKey), systemImage: item.symbol)
                            .font(.system(size: 12, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity).frame(height: 28)
                            .foregroundStyle(layer == item ? .white : RoomTheme.ink)
                            .background(layer == item ? RoomTheme.mint : RoomTheme.paper, in: Capsule())
                            .overlay(Capsule().strokeBorder(.white, lineWidth: 2))
                            .frame(height: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("townLayer_\(item.rawValue)")
                    .accessibilityAddTraits(layer == item ? .isSelected : [])
                }
            }
        }
        .padding(.horizontal, 14).padding(.top, 8)
    }

    private var plots: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 14) {
            ForEach(TownPlace.allCases) { place in
                TownPlot(place: place, selected: selectedPlace == place,
                         inLayer: layer == .all || place.layer == layer || place.isEmpty,
                         sickCount: sickCount) { choose(place) }
            }
        }
        .padding(.horizontal, 8).padding(.top, 8).padding(.bottom, 24)
        .background {
            TownPalette.road
            GeometryReader { geometry in
                Path { path in
                    for row in 1...3 {
                        let y = CGFloat(row) * 86 + 1
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                }
                .stroke(.white.opacity(0.8), style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
            }
        }
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: 13) {
            Capsule().fill(RoomTheme.wood.opacity(0.7)).frame(width: 40, height: 5)
                .frame(maxWidth: .infinity).accessibilityHidden(true)
            HStack(alignment: .top, spacing: 10) {
                GameIconTile(symbol: selectedPlace.symbol, tint: selectedPlace.tint,
                             background: selectedPlace.tile, size: 50)
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white, lineWidth: 2))
                VStack(alignment: .leading, spacing: 5) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 7) { detailTitle; statusChip }
                        VStack(alignment: .leading, spacing: 5) { detailTitle; statusChip }
                    }
                    Text(detailDescription).font(.system(size: 13, weight: .bold))
                        .foregroundStyle(RoomTheme.secondary).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if selectedPlace.isFuture {
                Label(GameStrings.text("town.futureNotice"), systemImage: "sparkles")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(RoomTheme.lilac)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(TownPalette.community, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(TownPalette.communityEdge, style: StrokeStyle(lineWidth: 2, dash: [5, 4])))
            }
            Spacer(minLength: 4)
            Group {
                if selectedPlace.isFuture || selectedPlace.isEmpty {
                    Button(action: {}) { primaryLabel }
                        .buttonStyle(SoftButtonStyle()).disabled(true)
                } else {
                    Button(action: enterPlace) { primaryLabel }.buttonStyle(MintButtonStyle())
                }
            }
            .accessibilityIdentifier(primaryIdentifier)
        }
        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 16)
        .accessibilityElement(children: .contain).accessibilityIdentifier("townPlaceDetail")
        .accessibilityValue(selectedPlace.rawValue)
    }

    private var detailTitle: some View {
        Text(GameStrings.text(selectedPlace.titleKey)).font(.system(size: 19, weight: .heavy))
            .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
    }

    private var primaryLabel: some View {
        Label(GameStrings.text(primaryKey), systemImage: selectedPlace.symbol)
            .font(.system(size: 16, weight: .heavy)).frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var statusChip: some View {
        Text(GameStrings.text(selectedPlace.statusKey(sickCount: sickCount)))
            .font(.system(size: 11, weight: .heavy)).fixedSize()
            .foregroundStyle(selectedPlace.isFuture ? RoomTheme.lilac :
                (selectedPlace == .hospital && sickCount > 0 ? RoomTheme.coral : RoomTheme.darkMint))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(selectedPlace.isFuture ? TownPalette.community : selectedPlace.tile, in: Capsule())
    }

    private var detailDescription: String {
        if selectedPlace == .hospital, sickCount > 0 { return GameStrings.format("town.hospitalAttention", sickCount) }
        if selectedPlace == .home { return GameStrings.format("town.homeDescription", store.homeDisplayName) }
        return GameStrings.text(selectedPlace.descriptionKey)
    }

    private var primaryKey: String {
        if selectedPlace == .adoption, availableOffer == nil { return "town.viewCats" }
        return selectedPlace.actionKey
    }

    private var primaryIdentifier: String {
        switch selectedPlace {
        case .hospital: "townHospitalButton"
        case .adoption: availableOffer == nil ? "townAdoptionCollectionButton" : "townMeetCatButton"
        default: "townEnter_\(selectedPlace.rawValue)"
        }
    }

    private func choose(_ place: TownPlace) {
        store.playFeedback(.pin)
        selectedPlace = place
    }

    private func openCollection(adoptionID: String? = nil) {
        store.playNavigationSound()
        presentedCollection = CollectionRequest(adoptionID: adoptionID)
    }

    private func enterPlace() {
        switch selectedPlace {
        case .hospital: store.openHospital()
        case .adoption: openCollection(adoptionID: availableOffer?.id)
        case .home, .work, .shop:
            store.isShowingSettings = false
            store.inspectedCatID = nil
            store.activeSheet = selectedPlace == .work ? .work : (selectedPlace == .shop ? .shop : nil)
        default: break
        }
    }
}
