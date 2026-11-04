import SwiftUI
import CatGameCore

@MainActor
struct HospitalView: View {
    @Bindable var store: GameStore
    @State private var path: [String]
    @State private var page = 0
    @State private var isSaving = false

    private let pageSize = 4
    private var cats: [CatState] { store.snapshot?.cats ?? [] }
    private var pageCount: Int { max(1, (cats.count + pageSize - 1) / pageSize) }
    private var currentPage: Int { min(page, pageCount - 1) }
    private var visibleCats: [CatState] { Array(cats.dropFirst(currentPage * pageSize).prefix(pageSize)) }
    private var sickCount: Int { cats.filter { $0.healthState?.illness != nil }.count }

    init(store: GameStore, initialCatID: String? = nil) {
        self.store = store
        _path = State(initialValue: initialCatID.map { [$0] } ?? [])
    }

    var body: some View {
        NavigationStack(path: $path) {
            directory
                .navigationTitle(GameStrings.text("hospital.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { store.activeSheet = .town } label: {
                            Label(GameStrings.text("hospital.backToTown"), systemImage: "chevron.left")
                                .frame(minHeight: 44)
                        }
                        .accessibilityIdentifier("hospitalBackToTown")
                    }
                }
                .navigationDestination(for: String.self) { catID in
                    HospitalCatDetailView(store: store, catID: catID, isSaving: $isSaving) {
                        store.activeSheet = .work
                    }
                    .navigationBarBackButtonHidden()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                guard !isSaving, !path.isEmpty else { return }
                                path.removeLast()
                            } label: {
                                Label(GameStrings.text("common.back"), systemImage: "chevron.left")
                                    .frame(minHeight: 44)
                            }
                            .disabled(isSaving).accessibilityIdentifier("hospitalBackButton")
                        }
                    }
                }
        }
        .tint(RoomTheme.darkMint)
        .onChange(of: cats.count) { _, _ in page = currentPage }
    }

    private var directory: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    GameIconTile(symbol: "cross.case.fill", tint: RoomTheme.coral,
                                 background: RoomTheme.coral.opacity(0.12), size: 54)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(GameStrings.text("hospital.subtitle"))
                            .font(.headline).fixedSize(horizontal: false, vertical: true)
                        Text(GameStrings.format("hospital.summary", sickCount, cats.count))
                            .font(.subheadline).foregroundStyle(RoomTheme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("hospitalSummary").accessibilityValue("\(sickCount)/\(cats.count)")
                    }
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading).gameCard()
                Text(GameStrings.text("hospital.selectCat"))
                    .font(.subheadline.weight(.semibold)).foregroundStyle(RoomTheme.secondary)
                if cats.isEmpty {
                    Text(GameStrings.text("hospital.empty"))
                        .font(.body).foregroundStyle(RoomTheme.secondary)
                        .padding(24).frame(maxWidth: .infinity).gameCard()
                        .accessibilityIdentifier("hospitalEmpty")
                } else {
                    ForEach(visibleCats) { cat in
                        Button { path.append(cat.id) } label: { catRow(cat) }
                            .buttonStyle(.plain).accessibilityIdentifier("hospitalCat_\(cat.id)")
                    }
                    if pageCount > 1 { pagination }
                }
                Text(GameStrings.text("hospital.gentleHint"))
                    .font(.footnote).foregroundStyle(RoomTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .background(RoomTheme.cream).accessibilityIdentifier("hospitalDirectoryScroll")
    }

    private func catRow(_ cat: CatState) -> some View {
        HStack(spacing: 12) {
            GameIcon(asset: CatArtwork.asset("cat-avatar", appearance: cat.appearance),
                     symbol: "cat.fill", size: 50, tint: RoomTheme.gold)
                .frame(width: 58, height: 58).background(RoomTheme.paleMint, in: Circle())
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: GameStrings.catName(cat)).font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(CatHealthPresentation.status(for: cat, now: store.now))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(cat.healthState?.illness == nil ? RoomTheme.darkMint : RoomTheme.coral)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(RoomTheme.secondary)
                .accessibilityHidden(true)
        }
        .padding(14).frame(maxWidth: .infinity, minHeight: 86, alignment: .leading).gameCard(cornerRadius: 22)
        .contentShape(RoundedRectangle(cornerRadius: 22))
        .accessibilityElement(children: .combine)
    }

    private var pagination: some View {
        HStack(spacing: 10) {
            Button { page = max(0, currentPage - 1) } label: {
                Label(GameStrings.text("catDirectory.previous"), systemImage: "chevron.left")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .disabled(currentPage == 0).accessibilityIdentifier("hospitalPagePrevious")
            Text(GameStrings.format("catDirectory.page", currentPage + 1, pageCount))
                .font(.footnote.monospacedDigit()).fixedSize()
                .accessibilityIdentifier("hospitalPageSummary").accessibilityValue("\(currentPage + 1)/\(pageCount)")
            Button { page = min(pageCount - 1, currentPage + 1) } label: {
                HStack(spacing: 5) {
                    Text(GameStrings.text("catDirectory.next"))
                    Image(systemName: "chevron.right")
                }.frame(maxWidth: .infinity, minHeight: 44)
            }
            .disabled(currentPage == pageCount - 1).accessibilityIdentifier("hospitalPageNext")
        }
        .font(.footnote.weight(.semibold)).buttonStyle(.plain).foregroundStyle(RoomTheme.darkMint)
    }
}

/// Shared by the hospital and the cat's existing profile navigation stack.
@MainActor
struct HospitalCatDetailView: View {
    @Bindable var store: GameStore
    let catID: String
    @Binding var isSaving: Bool
    let goToWork: () -> Void
    @State private var treatmentFailed = false
    @State private var treatmentCompleted = false
    private var cat: CatState? { store.snapshot?.cats.first { $0.id == catID } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let cat {
                    identity(cat)
                    if let illness = cat.healthState?.illness {
                        treatment(illness)
                    } else {
                        Label(GameStrings.text(treatmentCompleted ? "hospital.recovered" : "hospital.healthy"),
                              systemImage: "checkmark.seal.fill")
                            .font(.headline).foregroundStyle(RoomTheme.darkMint)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(18).frame(maxWidth: .infinity, alignment: .leading).gameCard()
                            .accessibilityIdentifier("hospitalHealthyState")
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Label(GameStrings.text("hospital.careAdvice"), systemImage: "heart.fill")
                            .font(.subheadline).foregroundStyle(RoomTheme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let health = cat.healthState, health.protectedUntil > store.now {
                            Text(GameStrings.text("hospital.protectionHint"))
                                .font(.footnote.weight(.semibold)).foregroundStyle(RoomTheme.darkMint)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("hospitalProtectionHint")
                        }
                    }
                    .padding(18).frame(maxWidth: .infinity, alignment: .leading).gameCard()
                    Text(GameStrings.text("hospital.gentleHint"))
                        .font(.footnote).foregroundStyle(RoomTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(GameStrings.text("catProfile.missing")).foregroundStyle(RoomTheme.secondary)
                        .padding(24).frame(maxWidth: .infinity).accessibilityIdentifier("hospitalMissingCat")
                }
            }
            .padding(16).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .background(RoomTheme.cream).accessibilityIdentifier("hospitalDetailScroll").accessibilityValue(catID)
        .navigationTitle(GameStrings.text("hospital.healthDetails")).navigationBarTitleDisplayMode(.inline)
    }

    private func identity(_ cat: CatState) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                GameIcon(asset: CatArtwork.asset("cat-avatar", appearance: cat.appearance),
                         symbol: "cat.fill", size: 64, tint: RoomTheme.gold)
                    .frame(width: 72, height: 72).background(RoomTheme.paleMint, in: Circle())
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: GameStrings.catName(cat)).font(.title2.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("hospitalCatName")
                    Text(CatHealthPresentation.status(for: cat, now: store.now))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(cat.healthState?.illness == nil ? RoomTheme.darkMint : RoomTheme.coral)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("hospitalCondition")
                        .accessibilityValue(cat.healthState?.illness?.rawValue ?? "healthy")
                }
            }
            VStack(spacing: 8) {
                HStack {
                    Text(GameStrings.text("stat.health")).font(.subheadline.weight(.semibold))
                    Spacer(minLength: 8)
                    Text("\(cat.health) / 100").font(.subheadline.monospacedDigit())
                }
                ProgressView(value: Double(cat.health), total: 100)
                    .tint(cat.healthState?.illness == nil ? RoomTheme.mint : RoomTheme.coral)
            }
            .accessibilityElement(children: .ignore).accessibilityLabel(GameStrings.text("stat.health"))
            .accessibilityValue("\(cat.health)/100").accessibilityIdentifier("hospitalHealth")
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading).gameCard()
    }

    private func treatment(_ illness: CatIllness) -> some View {
        let definition = CatHealthCatalog.definition(for: illness)
        let cost = definition.treatmentCost
        let gold = store.snapshot?.player.gold ?? 0
        return VStack(alignment: .leading, spacing: 14) {
            Label(GameStrings.text("hospital.treatment"), systemImage: "cross.case.fill")
                .font(.headline).foregroundStyle(RoomTheme.coral)
            Text(GameStrings.text(definition.detailKey))
                .font(.subheadline).foregroundStyle(RoomTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .firstTextBaseline) {
                Text(GameStrings.text("hospital.treatmentPrice")).font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                Label("\(cost)", systemImage: "dollarsign.circle.fill")
                    .font(.headline.monospacedDigit()).foregroundStyle(RoomTheme.gold)
                    .accessibilityLabel(GameStrings.format("shop.buy", cost))
                    .accessibilityIdentifier("hospitalTreatmentCost").accessibilityValue("\(cost)")
            }
            Text(GameStrings.text("hospital.treatmentBenefit"))
                .font(.footnote).foregroundStyle(RoomTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                guard !isSaving, !store.isBusy else { return }
                isSaving = true
                treatmentFailed = false
                Task {
                    let completed = await store.treatCat(catID: catID)
                    treatmentCompleted = completed
                    treatmentFailed = !completed
                    isSaving = false
                }
            } label: {
                Label(GameStrings.text(isSaving ? "common.saving" : "hospital.treat"), systemImage: "cross.case.fill")
                    .font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(MintButtonStyle()).disabled(isSaving || store.isBusy || gold < cost)
            .accessibilityIdentifier("hospitalTreatButton")
            Label(GameStrings.format("shop.balance", gold), systemImage: "dollarsign.circle.fill")
                .font(.footnote.monospacedDigit()).foregroundStyle(RoomTheme.secondary)
                .accessibilityIdentifier("hospitalGoldCount").accessibilityValue("\(gold)")
            if gold < cost {
                Text(GameStrings.format("hospital.goldRequired", cost))
                    .font(.subheadline.weight(.semibold)).foregroundStyle(RoomTheme.coral)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("hospitalInsufficientGold")
                Button(action: goToWork) {
                    Label(GameStrings.text("hospital.goToWork"), systemImage: "briefcase.fill")
                        .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity)
                }
                .buttonStyle(SoftButtonStyle()).disabled(isSaving || store.isBusy)
                .accessibilityIdentifier("hospitalWorkButton")
            }
            if treatmentFailed {
                Text(GameStrings.text("hospital.treatmentFailed"))
                    .font(.subheadline.weight(.semibold)).foregroundStyle(RoomTheme.coral)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("hospitalTreatmentStatus")
            }
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading).gameCard()
    }
}

@MainActor
enum CatHealthPresentation {
    static func status(for cat: CatState, now: Date) -> String {
        if let illness = cat.healthState?.illness {
            return GameStrings.text(CatHealthCatalog.definition(for: illness).nameKey)
        }
        if let health = cat.healthState, health.protectedUntil > now {
            return GameStrings.text("hospital.protected")
        }
        return GameStrings.text((cat.healthState?.riskPoints ?? 0) > 0 ? "hospital.atRisk" : "hospital.well")
    }
}
