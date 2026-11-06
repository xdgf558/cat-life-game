import SwiftUI
import CatGameCore

@MainActor
struct CommunityView: View {
    @Bindable var store: GameStore
    let onClose: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Button(action: onClose) {
                        Label(GameStrings.text("tab.town"), systemImage: "chevron.left")
                            .font(.subheadline.weight(.heavy))
                    }
                    .buttonStyle(SoftButtonStyle()).accessibilityIdentifier("communityBackButton")
                    VStack(alignment: .leading, spacing: 7) {
                        Text(GameStrings.text("community.title")).font(.largeTitle.weight(.heavy))
                            .accessibilityAddTraits(.isHeader)
                        Text(GameStrings.text("community.subtitle")).font(.subheadline.weight(.bold))
                            .foregroundStyle(RoomTheme.secondary)
                    }
                    Label(GameStrings.format("community.visitsToday", store.snapshot?.community.dailyVisitCount ?? 0,
                                             CommunityCatalog.neighbors.count), systemImage: "sun.max.fill")
                        .font(.subheadline.weight(.bold)).foregroundStyle(RoomTheme.darkMint)
                        .accessibilityIdentifier("communityVisitsToday")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12),
                                             count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 14) {
                        ForEach(CommunityCatalog.neighbors) { neighbor in
                            NavigationLink(value: neighbor.id) { card(neighbor) }
                                .buttonStyle(.plain).accessibilityIdentifier("neighborCard_\(neighbor.id)")
                        }
                    }
                    Text(GameStrings.text("community.dailyHint")).font(.caption.weight(.bold))
                        .foregroundStyle(RoomTheme.secondary).fixedSize(horizontal: false, vertical: true)
                }
                .padding(16).frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize).background(RoomTheme.cream)
            .accessibilityIdentifier("communityDirectory")
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { id in
                NeighborDetailView(store: store, neighborID: id)
                    .toolbar(.hidden, for: .navigationBar)
            }
        }
        .fontDesign(.rounded).foregroundStyle(RoomTheme.ink).tint(RoomTheme.darkMint)
        .environment(\.locale, Locale(identifier: store.language.rawValue))
    }

    private func card(_ neighbor: NeighborDefinition) -> some View {
        let relationship = store.snapshot?.community.relationship(for: neighbor.id) ?? NeighborRelationship()
        return VStack(alignment: .leading, spacing: 9) {
            Image(neighbor.portraitAssetName).resizable().scaledToFit().frame(height: 112)
                .frame(maxWidth: .infinity).padding(.top, 7)
                .background(RoomTheme.paleMint.opacity(0.65), in: RoundedRectangle(cornerRadius: 20))
                .accessibilityHidden(true)
            Text(GameStrings.text(neighbor.nameKey)).font(.title3.weight(.heavy))
                .fixedSize(horizontal: false, vertical: true)
            Text(GameStrings.text(relationship.stage.nameKey)).font(.caption.weight(.heavy))
                .foregroundStyle(RoomTheme.darkMint)
            ProgressView(value: Double(relationship.friendship), total: 100).tint(RoomTheme.mint)
                .accessibilityHidden(true)
            HStack(alignment: .firstTextBaseline) {
                Text(GameStrings.format("community.friendshipValue", relationship.friendship))
                    .font(.caption.weight(.bold)).foregroundStyle(RoomTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 3)
                Image(systemName: "chevron.right").font(.caption.weight(.heavy)).accessibilityHidden(true)
            }
            Label(GameStrings.text(relationship.visitedToday ? "community.visitedToday" : "community.readyToVisit"),
                  systemImage: relationship.visitedToday ? "checkmark.circle.fill" : "bubble.left.fill")
                .font(.caption.weight(.bold)).foregroundStyle(relationship.visitedToday ? RoomTheme.secondary : RoomTheme.darkMint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading).gameCard(cornerRadius: 25)
        .accessibilityElement(children: .combine)
    }
}
