import SwiftUI
import CatGameCore

@MainActor
struct CatCollectionView: View {
    @Bindable var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var path: [Route]
    @State private var filter: Filter
    @State private var page = 0
    @State private var isSaving = false

    private enum Route: Hashable { case profile(String), name(String), adoption(String), health(String) }
    enum Filter: String, CaseIterable { case all, owned, unowned }
    private enum Entry: Identifiable {
        case owned(CatState), adoption(CatAdoptionOffer)
        var id: String {
            switch self { case .owned(let cat): cat.id; case .adoption(let offer): offer.id }
        }
    }
    private let pageSize = 4
    private var cats: [CatState] { store.snapshot?.cats ?? [] }
    private var collectedCount: Int { Set(cats.map(\.appearance)).count }
    private var entries: [Entry] {
        guard store.snapshot != nil else { return [] }
        let owned = cats.map(Entry.owned)
        let unowned = CatCatalog.adoptionOffers
            .filter { offer in !cats.contains { $0.id == offer.id } }.map(Entry.adoption)
        switch filter {
        case .all: return owned + unowned
        case .owned: return owned
        case .unowned: return unowned
        }
    }
    private var pageCount: Int { max(1, (entries.count + pageSize - 1) / pageSize) }
    private var currentPage: Int { min(page, pageCount - 1) }
    private var visibleEntries: [Entry] { Array(entries.dropFirst(currentPage * pageSize).prefix(pageSize)) }

    init(store: GameStore, initialCatID: String? = nil, initialFilter: Filter = .all) {
        self.store = store
        _path = State(initialValue: initialCatID.map { [.profile($0)] } ?? [])
        _filter = State(initialValue: initialFilter)
    }

    var body: some View {
        NavigationStack(path: $path) {
            directory
                .navigationTitle(GameStrings.text("town.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { doneButton }
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .profile(let id):
                        CatProfileView(store: store, catID: id, isSaving: $isSaving,
                                       health: { path.append(.health(id)) }, rename: { path.append(.name(id)) })
                            .navigationBarBackButtonHidden()
                            .toolbar {
                                backButton("catProfileBackButton")
                                doneButton
                            }
                    case .health(let id):
                        HospitalCatDetailView(store: store, catID: id, isSaving: $isSaving) {
                            dismiss()
                            store.inspectedCatID = nil
                            store.activeSheet = .work
                        }
                        .navigationBarBackButtonHidden()
                        .toolbar {
                            backButton("catHealthBackButton")
                            doneButton
                        }
                    case .name(let id):
                        CatNameEditorView(store: store, catID: id, isSaving: $isSaving)
                            .navigationBarBackButtonHidden()
                            .toolbar {
                                backButton("catNameBackButton")
                                doneButton
                            }
                    case .adoption(let id):
                        CatAdoptionView(store: store, catID: id, isSaving: $isSaving) {
                            if !path.isEmpty { path[path.count - 1] = .profile(id) }
                        }
                        .navigationBarBackButtonHidden()
                        .toolbar {
                            backButton("catAdoptionBackButton")
                            doneButton
                        }
                    }
                }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                SaveStatusBanner(store: store)
                if let toast = store.toast, !toast.isEmpty {
                    Text(toast).font(.footnote).multilineTextAlignment(.center)
                        .padding(12).frame(maxWidth: .infinity)
                        .background(RoomTheme.paper).accessibilityIdentifier("sheetToast")
                }
            }
        }
        .saveRecoveryAlert(store: store)
        .fontDesign(.rounded).foregroundStyle(RoomTheme.ink)
        .environment(\.locale, Locale(identifier: store.language.rawValue))
        .presentationDetents([.large]).presentationDragIndicator(.visible)
        .presentationBackground(RoomTheme.cream)
        .interactiveDismissDisabled(isSaving)
        .onChange(of: cats.count) { _, _ in page = currentPage }
        .onChange(of: filter) { _, _ in page = 0 }
        #if DEBUG
        .overlay(alignment: .topLeading) { AudioDiagnosticsView(store: store) }
        #endif
    }

    private var directory: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(GameStrings.format("catDirectory.count", cats.count))
                            .foregroundStyle(RoomTheme.secondary)
                            .accessibilityIdentifier("catCount").accessibilityValue("\(cats.count)")
                        Spacer(minLength: 0)
                        Text(GameStrings.format("catDirectory.collected", collectedCount, CatAppearance.allCases.count))
                            .foregroundStyle(RoomTheme.darkMint).multilineTextAlignment(.trailing)
                    }
                    .font(.caption.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                    ProgressView(value: Double(collectedCount), total: Double(CatAppearance.allCases.count))
                        .tint(RoomTheme.mint)
                        .accessibilityLabel(GameStrings.text("town.title"))
                        .accessibilityIdentifier("catCollectionProgress")
                        .accessibilityValue("\(collectedCount)/\(CatAppearance.allCases.count)")
                }
                filters
                if entries.isEmpty {
                    Text(GameStrings.text(filter == .unowned ? "catDirectory.allAdopted" : "catDirectory.empty"))
                        .font(.body).foregroundStyle(RoomTheme.secondary)
                        .padding(24).frame(maxWidth: .infinity)
                        .gameCard(cornerRadius: 24)
                        .accessibilityIdentifier("catCollectionEmpty")
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12),
                                             count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
                        ForEach(visibleEntries) { entry in
                            switch entry {
                            case .owned(let cat): catCard(cat)
                            case .adoption(let offer): adoptionCard(offer)
                            }
                        }
                    }
                    pagination
                }
            }
            .padding(16).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .background(RoomTheme.cream)
        .accessibilityIdentifier("catCollectionScroll")
    }

    private var filters: some View {
        HStack(spacing: 6) {
            ForEach(Filter.allCases, id: \.self) { option in
                Button { filter = option } label: {
                    Text(GameStrings.text("catDirectory.filter.\(option.rawValue)"))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .lineLimit(2).minimumScaleFactor(0.8).multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.horizontal, 5)
                        .foregroundStyle(filter == option ? .white : RoomTheme.ink)
                        .background(filter == option ? RoomTheme.mint : RoomTheme.paper, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(filter == option ? .isSelected : [])
                .accessibilityIdentifier("catFilter_\(option.rawValue)")
            }
        }
    }

    private func catCard(_ cat: CatState) -> some View {
        Button { path.append(.profile(cat.id)) } label: {
            VStack(spacing: 5) {
                GameIcon(asset: CatArtwork.asset("cat-idle", appearance: cat.appearance),
                         symbol: "cat.fill", size: 52, tint: RoomTheme.gold)
                    .background(RoomTheme.wood.opacity(0.12), in: Circle())
                Text(verbatim: GameStrings.catName(cat))
                    .font(.headline).lineLimit(2).minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)
                Text(GameStrings.text(cat.id == store.cat?.id ? "cat.companionActive" : "cat.adoptionOwned"))
                    .font(.caption.weight(.semibold)).foregroundStyle(RoomTheme.darkMint)
                    .lineLimit(2).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(12)
            .gameCard(cornerRadius: 24)
            .contentShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: GameStrings.catName(cat)))
        .accessibilityValue(GameStrings.text(cat.id == store.cat?.id ? "cat.companionActive" : "cat.adoptionOwned")
                            + " · " + CatProfileView.status(for: cat))
        .accessibilityIdentifier("catProfile_\(cat.id)")
    }

    private func adoptionCard(_ offer: CatAdoptionOffer) -> some View {
        let available = store.snapshot.map {
            $0.player.level >= offer.requiredPlayerLevel && $0.home.roomLevel >= offer.requiredRoomLevel
                && $0.player.gold >= offer.price
        } ?? false
        return Button { path.append(.adoption(offer.id)) } label: {
            VStack(spacing: 5) {
                GameIcon(asset: CatArtwork.asset("cat-idle", appearance: offer.appearance), symbol: "cat.fill", size: 52, tint: RoomTheme.gold)
                    .background(RoomTheme.paleMint.opacity(0.5), in: Circle())
                Text(GameStrings.catAdoptionName(offer)).font(.headline)
                Label(GameStrings.text(available ? "cat.adoptionAvailable" : "cat.adoptionRequirements"),
                      systemImage: available ? "heart.fill" : "lock.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(available ? RoomTheme.darkMint : RoomTheme.secondary)
                    .lineLimit(2).multilineTextAlignment(.center)
                Text(GameStrings.format("cat.adoptionSummary", offer.requiredPlayerLevel, offer.requiredRoomLevel, offer.price))
                    .font(.caption2).foregroundStyle(RoomTheme.secondary)
                    .lineLimit(2).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(12)
            .gameCard(cornerRadius: 24)
            .contentShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain).accessibilityElement(children: .combine)
        .accessibilityValue(GameStrings.text(available ? "cat.adoptionAvailable" : "cat.adoptionRequirements"))
        .accessibilityIdentifier("catAdoption_\(offer.id)")
    }

    private var pagination: some View {
        HStack(spacing: 10) {
            Button { page = max(0, currentPage - 1) } label: {
                Label(GameStrings.text("catDirectory.previous"), systemImage: "chevron.left")
                    .font(.footnote.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain).disabled(currentPage == 0).opacity(currentPage == 0 ? 0.4 : 1)
            .accessibilityIdentifier("catPagePrevious")
            Text(GameStrings.format("catDirectory.page", currentPage + 1, pageCount))
                .font(.footnote.monospacedDigit()).fixedSize()
                .accessibilityIdentifier("catPageSummary").accessibilityValue("\(currentPage + 1)/\(pageCount)")
            Button { page = min(pageCount - 1, currentPage + 1) } label: {
                HStack(spacing: 5) {
                    Text(GameStrings.text("catDirectory.next"))
                    Image(systemName: "chevron.right")
                }
                .font(.footnote.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain).disabled(currentPage == pageCount - 1)
            .opacity(currentPage == pageCount - 1 ? 0.4 : 1).accessibilityIdentifier("catPageNext")
        }
        .foregroundStyle(RoomTheme.darkMint)
    }

    private var doneButton: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button(GameStrings.text("common.done")) {
                guard !isSaving else { return }
                dismiss()
            }
            .foregroundStyle(RoomTheme.darkMint).disabled(isSaving)
            .accessibilityIdentifier("closeSheetButton")
        }
    }

    private func backButton(_ identifier: String) -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                guard !isSaving, !path.isEmpty else { return }
                path.removeLast()
            } label: {
                Label(GameStrings.text("common.back"), systemImage: "chevron.left").frame(minHeight: 44)
            }
            .foregroundStyle(RoomTheme.darkMint).disabled(isSaving)
            .accessibilityIdentifier(identifier)
        }
    }
}
