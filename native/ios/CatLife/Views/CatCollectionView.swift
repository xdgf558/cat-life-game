import SwiftUI
import CatGameCore

@MainActor
struct CatCollectionView: View {
    @Bindable var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var path: [Route]
    @State private var page = 0
    @State private var isSaving = false

    private enum Route: Hashable { case profile(String), name(String), adoption(String) }
    private enum Entry: Identifiable {
        case owned(CatState), adoption(CatAdoptionOffer)
        var id: String {
            switch self { case .owned(let cat): cat.id; case .adoption(let offer): offer.id }
        }
    }
    private let pageSize = 4
    private var cats: [CatState] { store.snapshot?.cats ?? [] }
    private var entries: [Entry] {
        guard store.snapshot != nil else { return [] }
        return cats.map(Entry.owned) + CatCatalog.adoptionOffers
            .filter { offer in !cats.contains { $0.id == offer.id } }.map(Entry.adoption)
    }
    private var pageCount: Int { max(1, (entries.count + pageSize - 1) / pageSize) }
    private var currentPage: Int { min(page, pageCount - 1) }
    private var visibleEntries: [Entry] { Array(entries.dropFirst(currentPage * pageSize).prefix(pageSize)) }

    init(store: GameStore, initialCatID: String? = nil) {
        self.store = store
        _path = State(initialValue: initialCatID.map { [.profile($0)] } ?? [])
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
                        CatProfileView(store: store, catID: id, isSaving: $isSaving) { path.append(.name(id)) }
                            .navigationBarBackButtonHidden()
                            .toolbar {
                                backButton("catProfileBackButton")
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
        #if DEBUG
        .overlay(alignment: .topLeading) { AudioDiagnosticsView(store: store) }
        #endif
    }

    private var directory: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(GameStrings.text("town.subtitle"))
                        .font(.subheadline).foregroundStyle(RoomTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(GameStrings.format("catDirectory.count", cats.count))
                        .font(.footnote.weight(.semibold)).foregroundStyle(RoomTheme.darkMint)
                        .accessibilityIdentifier("catCount").accessibilityValue("\(cats.count)")
                }
                if entries.isEmpty {
                    Text(GameStrings.text("catDirectory.empty"))
                        .font(.body).foregroundStyle(RoomTheme.secondary)
                        .padding(24).frame(maxWidth: .infinity)
                        .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 24))
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

    private func catCard(_ cat: CatState) -> some View {
        Button { path.append(.profile(cat.id)) } label: {
            VStack(spacing: 7) {
                GameIcon(asset: cat.appearance == .cow ? "cat-cow-idle" : "cat-idle",
                         symbol: "cat.fill", size: 64, tint: RoomTheme.gold)
                    .background(RoomTheme.wood.opacity(0.12), in: Circle())
                Text(verbatim: GameStrings.catName(cat))
                    .font(.headline).lineLimit(2).minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)
                Text(GameStrings.text(cat.id == store.cat?.id ? "cat.companionActive" : "cat.adoptionOwned"))
                    .font(.caption.weight(.semibold)).foregroundStyle(RoomTheme.darkMint)
                    .lineLimit(2).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(14)
            .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 24))
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
        Button { path.append(.adoption(offer.id)) } label: {
            VStack(spacing: 7) {
                GameIcon(asset: "cat-cow-idle", symbol: "cat.fill", size: 64, tint: RoomTheme.gold)
                    .background(RoomTheme.paleMint.opacity(0.5), in: Circle())
                Text(GameStrings.text("cat.cowName")).font(.headline)
                Label(GameStrings.text("cat.adoptionView"), systemImage: "heart.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(RoomTheme.darkMint)
            }
            .frame(maxWidth: .infinity).padding(14)
            .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 24))
            .contentShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain).accessibilityElement(children: .combine)
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
