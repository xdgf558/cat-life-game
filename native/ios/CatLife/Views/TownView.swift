import SwiftUI
import CatGameCore

/// The map links to available native features without introducing prototype-only neighbors.
@MainActor
struct TownView: View {
    @Bindable var store: GameStore
    @State private var selectedPlace: Place = .cats
    @State private var presentedCollection: CollectionRequest?

    private enum Place { case cats, adoption }
    private struct CollectionRequest: Identifiable {
        let id = UUID()
        var catID: String?
        var adoptionID: String?
    }
    private var cats: [CatState] { store.snapshot?.cats ?? [] }
    private var availableOffers: [CatAdoptionOffer] {
        CatCatalog.adoptionOffers.filter { offer in !cats.contains { $0.id == offer.id } }
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    map(height: max(min(640, geometry.size.width) * 1.16, min(560, geometry.size.height * 0.68)))
                    drawer
                        .padding(16).padding(.top, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoomTheme.cream, in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
                        .padding(.top, -28)
                }
                .frame(maxWidth: 640).frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(RoomTheme.paleMint)
            .accessibilityIdentifier("townMapScroll")
        }
        .sheet(item: $presentedCollection) { request in
            CatCollectionView(store: store, initialCatID: request.catID, initialAdoptionID: request.adoptionID)
        }
    }

    private func map(height: CGFloat) -> some View {
        GeometryReader { geometry in
            Image("town-map")
                .resizable().scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                .accessibilityHidden(true)
            HomeNamePlaque(name: GameStrings.text("town.mapTitle"), height: 64)
                .frame(width: 176).padding(.leading, 12).padding(.top, 4)
                .accessibilityIdentifier("townMapTitle")
            mapMarker(store.homeDisplayName, symbol: "house.fill", tint: RoomTheme.mint, selected: true) {
                store.activeSheet = nil
            }
            .accessibilityIdentifier("townHomeMarker")
            .position(mapPoint(x: 0.50, y: 0.60, in: geometry.size))
            mapMarker(GameStrings.text("town.adoptionHouse"), symbol: "heart.fill", tint: RoomTheme.gold,
                      selected: selectedPlace == .adoption) { selectedPlace = .adoption }
                .accessibilityIdentifier("townAdoptionMarker")
                .position(mapPoint(x: 0.77, y: 0.28, in: geometry.size))
            mapMarker(GameStrings.text("town.catGarden"), symbol: "pawprint.fill", tint: RoomTheme.gold,
                      selected: selectedPlace == .cats) { selectedPlace = .cats }
                .accessibilityIdentifier("townCatsMarker")
                .position(mapPoint(x: 0.20, y: 0.25, in: geometry.size))
        }
        .frame(height: height)
    }

    private func mapPoint(x: CGFloat, y: CGFloat, in size: CGSize) -> CGPoint {
        // Anchors use the supplied 3:4 artwork, including its centered aspect-fill crop.
        let scale = max(size.width / 3, size.height / 4)
        return CGPoint(x: (x * 3 - 1.5) * scale + size.width / 2,
                       y: (y * 4 - 2) * scale + size.height / 2)
    }

    private func mapMarker(_ title: String, symbol: String, tint: Color, selected: Bool,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .lineLimit(2).multilineTextAlignment(.center)
                .padding(.horizontal, 14).frame(minHeight: 44)
                .frame(maxWidth: 144)
                .foregroundStyle(selected ? .white : RoomTheme.ink)
                .background(selected ? tint : RoomTheme.paper, in: Capsule())
                .overlay(Capsule().strokeBorder(.white, lineWidth: 2))
                .shadow(color: RoomTheme.ink.opacity(0.2), radius: 6, y: 4)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var drawer: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(GameStrings.text(selectedPlace == .cats ? "town.title" : "town.adoptionHouse"))
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                Spacer(minLength: 4)
                Text(GameStrings.format("catDirectory.count", cats.count))
                    .font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(RoomTheme.secondary)
                    .accessibilityIdentifier("catCount").accessibilityValue("\(cats.count)")
            }
            if selectedPlace == .adoption, let offer = availableOffers.first {
                destinationCard(asset: CatArtwork.asset("cat-avatar", appearance: offer.appearance),
                                title: GameStrings.text("cat.cowName"), detail: GameStrings.text("cat.adoptionView"),
                                actionKey: "town.meetCat", identifier: "townMeetCatButton") {
                    presentedCollection = CollectionRequest(adoptionID: offer.id)
                }
            } else {
                destinationCard(asset: CatArtwork.asset("cat-avatar", appearance: store.cat?.appearance ?? .orange),
                                title: store.homeDisplayName,
                                detail: GameStrings.text(selectedPlace == .adoption ? "town.allAdopted" : "town.gardenHint"),
                                actionKey: "town.viewCats", identifier: "townCollectionButton") {
                    presentedCollection = CollectionRequest()
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(cats) { cat in
                        Button { presentedCollection = CollectionRequest(catID: cat.id) } label: {
                            catThumbnail(asset: CatArtwork.asset("cat-avatar", appearance: cat.appearance),
                                         name: GameStrings.catName(cat), companion: cat.id == store.cat?.id)
                        }
                        .buttonStyle(.plain).accessibilityLabel(Text(verbatim: GameStrings.catName(cat)))
                        .accessibilityValue(GameStrings.text(cat.id == store.cat?.id ? "cat.companionActive" : "cat.adoptionOwned"))
                        .accessibilityIdentifier("townCat_\(cat.id)")
                    }
                    ForEach(availableOffers) { offer in
                        Button { presentedCollection = CollectionRequest(adoptionID: offer.id) } label: {
                            catThumbnail(asset: CatArtwork.asset("cat-avatar", appearance: offer.appearance),
                                         name: GameStrings.text("cat.adoptionTitle"), companion: false)
                                .overlay(alignment: .topTrailing) {
                                    Image(systemName: "plus.circle.fill").foregroundStyle(RoomTheme.darkMint, RoomTheme.paper)
                                        .font(.system(size: 17)).accessibilityHidden(true)
                                }
                        }
                        .buttonStyle(.plain).accessibilityLabel(GameStrings.text("cat.adoptionTitle"))
                        .accessibilityIdentifier("townAdoption_\(offer.id)")
                    }
                }
                .padding(.vertical, 3)
            }
            Text(GameStrings.text("town.mapHint"))
                .font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(RoomTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func destinationCard(asset: String, title: String, detail: String,
                                 actionKey: String, identifier: String, action: @escaping () -> Void) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                destinationDescription(asset: asset, title: title, detail: detail)
                Button(GameStrings.text(actionKey), action: action)
                    .font(.system(size: 14, weight: .heavy, design: .rounded)).fixedSize()
                    .buttonStyle(MintButtonStyle()).accessibilityIdentifier(identifier)
            }
            VStack(alignment: .leading, spacing: 12) {
                destinationDescription(asset: asset, title: title, detail: detail)
                Button(GameStrings.text(actionKey), action: action)
                    .font(.subheadline.weight(.bold)).buttonStyle(MintButtonStyle()).accessibilityIdentifier(identifier)
            }
        }
        .padding(14).gameCard(cornerRadius: 24)
    }

    private func destinationDescription(asset: String, title: String, detail: String) -> some View {
        HStack(spacing: 10) {
            GameIcon(asset: asset, symbol: "cat.fill", size: 48, tint: RoomTheme.gold)
                .background(RoomTheme.gold.opacity(0.13), in: Circle())
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 16, weight: .heavy, design: .rounded)).lineLimit(2)
                Text(detail).font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(RoomTheme.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func catThumbnail(asset: String, name: String, companion: Bool) -> some View {
        VStack(spacing: 5) {
            GameIcon(asset: asset, symbol: "cat.fill", size: 40, tint: RoomTheme.gold)
                .frame(width: 58, height: 58)
                .background(companion ? RoomTheme.paleMint : RoomTheme.track, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(companion ? RoomTheme.mint : .clear, lineWidth: 2))
            Text(name).font(.system(size: 10, weight: .bold, design: .rounded))
                .lineLimit(1).frame(width: 66)
        }
        .contentShape(Rectangle())
    }
}
