import SwiftUI
import CatGameCore

@MainActor
struct CatCollectionView: View {
    @Bindable var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var path: [Route]
    @State private var page = 0
    @State private var isSavingName = false

    private enum Route: Hashable { case profile(String), name(String) }
    private let pageSize = 4
    private var cats: [CatState] { store.snapshot?.cats ?? [] }
    private var pageCount: Int { max(1, (cats.count + pageSize - 1) / pageSize) }
    private var currentPage: Int { min(page, pageCount - 1) }
    private var visibleCats: [CatState] { Array(cats.dropFirst(currentPage * pageSize).prefix(pageSize)) }

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
                        CatProfileView(store: store, catID: id) { path.append(.name(id)) }
                            .navigationBarBackButtonHidden()
                            .toolbar {
                                backButton("catProfileBackButton")
                                doneButton
                            }
                    case .name(let id):
                        CatNameEditorView(store: store, catID: id, isSaving: $isSavingName)
                            .navigationBarBackButtonHidden()
                            .toolbar {
                                backButton("catNameBackButton")
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
        .interactiveDismissDisabled(isSavingName)
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
                if cats.isEmpty {
                    Text(GameStrings.text("catDirectory.empty"))
                        .font(.body).foregroundStyle(RoomTheme.secondary)
                        .padding(24).frame(maxWidth: .infinity)
                        .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 24))
                        .accessibilityIdentifier("catCollectionEmpty")
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12),
                                             count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
                        ForEach(visibleCats) { cat in catCard(cat) }
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
                GameIcon(asset: "cat-avatar", symbol: "cat.fill", size: 64, tint: RoomTheme.gold)
                    .background(RoomTheme.wood.opacity(0.12), in: Circle())
                Text(verbatim: GameStrings.catName(cat))
                    .font(.headline).lineLimit(2).minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)
                Text(CatProfileView.status(for: cat))
                    .font(.caption).foregroundStyle(RoomTheme.secondary)
                    .lineLimit(2).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(14)
            .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 24))
            .contentShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: GameStrings.catName(cat)))
        .accessibilityValue(CatProfileView.status(for: cat))
        .accessibilityIdentifier("catProfile_\(cat.id)")
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
                guard !isSavingName else { return }
                dismiss()
            }
            .foregroundStyle(RoomTheme.darkMint).disabled(isSavingName)
            .accessibilityIdentifier("closeSheetButton")
        }
    }

    private func backButton(_ identifier: String) -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                guard !isSavingName, !path.isEmpty else { return }
                path.removeLast()
            } label: {
                Label(GameStrings.text("common.back"), systemImage: "chevron.left").frame(minHeight: 44)
            }
            .foregroundStyle(RoomTheme.darkMint).disabled(isSavingName)
            .accessibilityIdentifier(identifier)
        }
    }
}
