import SwiftUI
import CatGameCore

@MainActor
struct CatGrowthView: View {
    @Bindable var store: GameStore
    let catID: String
    @Binding var isSaving: Bool
    let home: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var cat: CatState? { store.snapshot?.cats.first { $0.id == catID } }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let cat, let growth = cat.growthState, let now = store.snapshot?.meta.lastSyncAt {
                    identity(cat)
                    growthCard(growth, now: now)
                    bondCard(cat)
                    historyCard(growth, now: now)
                    Button { goHome() } label: {
                        Label(GameStrings.text(isSaving ? "common.saving" : "catGrowth.goHome"), systemImage: "house.fill")
                            .font(.headline).frame(maxWidth: .infinity).fixedSize(horizontal: false, vertical: true)
                    }
                    .buttonStyle(MintButtonStyle()).disabled(isSaving || store.isBusy)
                    .accessibilityIdentifier("catGrowthGoHome")
                    Text(GameStrings.text("catGrowth.goHomeHint"))
                        .font(.footnote).foregroundStyle(RoomTheme.secondary).fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(GameStrings.text("catProfile.missing")).foregroundStyle(RoomTheme.secondary).padding(24)
                }
            }
            .padding(16).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .background(RoomTheme.cream)
        .accessibilityIdentifier("catGrowthScroll").accessibilityValue(catID)
        .navigationTitle(GameStrings.text("catGrowth.title")).navigationBarTitleDisplayMode(.inline)
    }

    private func identity(_ cat: CatState) -> some View {
        HStack(spacing: 16) {
            GameIcon(asset: CatArtwork.asset("cat-idle", appearance: cat.appearance), symbol: "cat.fill", size: 76, tint: RoomTheme.gold)
                .background(RoomTheme.paleMint, in: Circle()).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: GameStrings.catName(cat)).font(.title2.weight(.bold))
                    .accessibilityIdentifier("catGrowthName").accessibilityValue(Text(verbatim: GameStrings.catName(cat)))
                Text(GameStrings.text("hospital.coat.\(cat.appearance.rawValue)"))
                    .font(.subheadline).foregroundStyle(RoomTheme.secondary)
            }.fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
        }.padding(16).background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 24))
    }

    private func growthCard(_ growth: CatGrowthState, now: Date) -> some View {
        let age = growth.ageDays(at: now)
        let stage = growth.stage(at: now)
        return section("catGrowth.growth", symbol: "leaf.fill") {
            field("catGrowth.gameAge", value: CatGrowthPresentation.age(age), identifier: "catGrowthAge")
            field("catGrowth.sex", value: GameStrings.text("catGrowth.sex.\(growth.sex.rawValue)"), identifier: "catGrowthSex")
            field("catGrowth.stage", value: GameStrings.text("catGrowth.stage.\(stage.rawValue)"), identifier: "catGrowthStage")
            if let next = stage.next {
                ProgressView(value: Double(age - stage.minimumAgeDays), total: Double(next.minimumAgeDays - stage.minimumAgeDays))
                    .tint(RoomTheme.mint).accessibilityHidden(true)
            }
            Text(CatGrowthPresentation.nextGrowth(growth, at: now))
                .font(.subheadline.weight(.semibold)).foregroundStyle(RoomTheme.darkMint)
                .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("catGrowthNextStage")
            Text(GameStrings.format("catGrowth.clockHint", CatGrowthCatalog.ageMultiplier))
                .font(.footnote).foregroundStyle(RoomTheme.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func bondCard(_ cat: CatState) -> some View {
        let stage = CatBondStage.stage(for: cat.intimacy)
        return section("catGrowth.bond", symbol: "heart.fill") {
            field("catGrowth.relationship", value: GameStrings.text("catGrowth.bond.\(stage.rawValue)"), identifier: "catGrowthBondStage")
            field("stat.bond", value: "\(cat.intimacy) / 100", identifier: "catGrowthBondValue")
            ProgressView(value: Double(cat.intimacy), total: 100).tint(RoomTheme.friendship).accessibilityHidden(true)
            Text(CatGrowthPresentation.nextBond(cat.intimacy))
                .font(.subheadline.weight(.semibold)).foregroundStyle(RoomTheme.darkMint)
                .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("catGrowthNextBond")
            Text(GameStrings.text("catGrowth.bondHint"))
                .font(.footnote).foregroundStyle(RoomTheme.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func historyCard(_ growth: CatGrowthState, now: Date) -> some View {
        section("catGrowth.memory", symbol: "calendar") {
            field("catGrowth.joined", value: growth.adoptedAt.map(CatGrowthPresentation.date) ?? GameStrings.text("catGrowth.joinedEarlier"),
                  identifier: "catGrowthJoined")
            field("catGrowth.recordedSince", value: CatGrowthPresentation.date(growth.recordedSince), identifier: "catGrowthRecordedSince")
            field("catGrowth.companionship", value: GameStrings.format("catGrowth.days", growth.companionshipDays(at: now)),
                  identifier: "catGrowthCompanionship")
            Text(GameStrings.text(growth.isLegacyRecord ? "catGrowth.legacyHint" : "catGrowth.newHint"))
                .font(.footnote).foregroundStyle(RoomTheme.secondary).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("catGrowthRecordHint")
                .accessibilityValue(growth.isLegacyRecord ? "legacy" : "adopted")
        }
    }

    private func section<Content: View>(_ title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(GameStrings.text(title), systemImage: symbol).font(.headline).foregroundStyle(RoomTheme.darkMint)
                .accessibilityAddTraits(.isHeader)
            content()
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 24))
    }

    private func field(_ title: String, value: String, identifier: String) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 5) { fieldTitle(title); fieldValue(value) }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) { fieldTitle(title); Spacer(minLength: 8); fieldValue(value) }
                    VStack(alignment: .leading, spacing: 5) { fieldTitle(title); fieldValue(value) }
                }
            }
        }
        .accessibilityElement(children: .ignore).accessibilityLabel(GameStrings.text(title)).accessibilityValue(value)
        .accessibilityIdentifier(identifier)
    }

    private func fieldTitle(_ key: String) -> some View {
        Text(GameStrings.text(key)).font(.subheadline).foregroundStyle(RoomTheme.secondary).fixedSize(horizontal: false, vertical: true)
    }
    private func fieldValue(_ value: String) -> some View {
        Text(verbatim: value).font(.subheadline.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
    }

    private func goHome() {
        guard !isSaving, !store.isBusy, cat != nil else { return }
        if store.cat?.id == catID { home(); return }
        let generation = store.saveSceneGeneration
        isSaving = true
        Task {
            let succeeded = await store.selectCompanion(catID: catID)
            isSaving = false
            if succeeded, store.saveSceneGeneration == generation, store.cat?.id == catID { home() }
        }
    }
}

@MainActor
enum CatGrowthPresentation {
    static func age(_ days: Int) -> String {
        GameStrings.format("catGrowth.monthsAndDays", days / 30, days % 30)
    }
    static func nextGrowth(_ growth: CatGrowthState, at date: Date) -> String {
        guard let next = growth.stage(at: date).next else { return GameStrings.text("catGrowth.adultHint") }
        return GameStrings.format("catGrowth.nextStage", next.minimumAgeDays - growth.ageDays(at: date),
                                  GameStrings.text("catGrowth.stage.\(next.rawValue)"))
    }
    static func nextBond(_ intimacy: Int) -> String {
        guard let next = CatBondStage.stage(for: intimacy).next else { return GameStrings.text("catGrowth.closestHint") }
        return GameStrings.format("catGrowth.nextBond", next.minimumIntimacy - intimacy,
                                  GameStrings.text("catGrowth.bond.\(next.rawValue)"))
    }
    static func date(_ value: Date) -> String {
        value.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted)
            .locale(Locale(identifier: GameLocalization.shared.language.rawValue)))
    }
}
