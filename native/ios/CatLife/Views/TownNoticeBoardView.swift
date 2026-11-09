import SwiftUI
import CatGameCore

@MainActor
struct TownNoticeBoardView: View {
    @Bindable var store: GameStore
    let onClose: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var section: Section = .today
    @State private var page = 0
    @State private var claiming = false
    private enum Section: String, CaseIterable, Identifiable {
        case today, letters, memento
        var id: String { rawValue }
        var titleKey: String { "townEvents.\(rawValue)" }
    }
    private enum Destination: Hashable {
        case event(String, String)
        case letter(String)
    }
    private var letters: [TownEventReceipt] { Array((store.snapshot?.community.events.letters ?? []).reversed()) }
    private var pageSize: Int { dynamicTypeSize.isAccessibilitySize ? 2 : 4 }
    private var pageCount: Int { max(1, (letters.count + pageSize - 1) / pageSize) }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Color.clear.frame(height: 1).id("boardTop")
                        switch section {
                        case .today: introduction; today
                        case .letters: letterList
                        case .memento: mementos
                        }
                    }.padding(16).frame(maxWidth: 560).frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize).background(RoomTheme.cream)
                .accessibilityIdentifier("townBoardScroll")
                .onChange(of: section) { _, _ in proxy.scrollTo("boardTop", anchor: .top) }
                .onChange(of: page) { _, _ in proxy.scrollTo("boardTop", anchor: .top) }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    CommunityHeader(title: GameStrings.text("townEvents.title"), backTitle: "tab.town",
                                    gold: store.snapshot?.player.gold ?? 0, symbol: "envelope.fill",
                                    backID: "townBoardBackButton", back: onClose)
                    tabs.padding(.horizontal, 16).padding(.bottom, 12)
                }.background(RoomTheme.cream)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case let .event(id, day): TownEventDetailView(store: store, eventID: id, dayKey: day)
                case let .letter(id):
                    if let receipt = letters.first(where: { $0.id == id }) {
                        TownLetterDestination(store: store, receipt: receipt)
                    } else {
                        ContentUnavailableView(GameStrings.text("townEvents.empty"), systemImage: "envelope")
                    }
                }
            }
        }
        .id(store.saveSceneGeneration)
        .fontDesign(.rounded).foregroundStyle(RoomTheme.ink).tint(RoomTheme.darkMint)
        .environment(\.locale, Locale(identifier: store.language.rawValue))
        .onChange(of: dynamicTypeSize) { _, _ in page = min(page, pageCount - 1) }
        .onChange(of: letters.count) { _, _ in page = min(page, pageCount - 1) }
    }

    private var introduction: some View {
        HStack(spacing: 12) {
            GameIcon(asset: "town-board-cartoon", symbol: "envelope.fill", size: 78, tint: RoomTheme.darkMint)
            VStack(alignment: .leading, spacing: 6) {
                Text(GameStrings.text("townEvents.subtitle")).font(.title3.weight(.heavy))
                    .accessibilityAddTraits(.isHeader)
                Text(GameStrings.text("townEvents.refreshHint")).font(.caption.weight(.semibold))
                    .foregroundStyle(RoomTheme.secondary)
            }.fixedSize(horizontal: false, vertical: true)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoomTheme.paleMint.opacity(0.65), in: RoundedRectangle(cornerRadius: 26))
        .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(.white, lineWidth: 3))
    }

    private var tabs: some View {
        HStack(spacing: 5) { tabButtons }
        .padding(5).background(RoomTheme.track, in: RoundedRectangle(cornerRadius: 23))
        .accessibilityElement(children: .contain)
    }
    private var tabButtons: some View {
        ForEach(Section.allCases) { item in
            Button { store.playNavigationSound(); section = item } label: {
                Text(GameStrings.text(item.titleKey)).font(.subheadline.weight(.heavy))
                    .fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(section == item ? RoomTheme.darkMint : RoomTheme.secondary)
                    .background(section == item ? RoomTheme.paper : .clear, in: RoundedRectangle(cornerRadius: 19))
                    .contentShape(RoundedRectangle(cornerRadius: 19))
            }.buttonStyle(.plain).accessibilityIdentifier("townBoardTab_\(item.rawValue)")
                .accessibilityAddTraits(section == item ? .isSelected : [])
        }
    }

    private var today: some View {
        Group {
            if let snapshot = store.snapshot, let receipt = snapshot.community.events.todayReceipt {
                NavigationLink(value: Destination.letter(receipt.id)) {
                    eventCard(title: TownEventPresentation.title(receipt), neighborID: receipt.neighborID,
                              status: "townEvents.completed", completed: true)
                }.buttonStyle(.plain).accessibilityIdentifier("townEventTodayLetter")
            } else if let snapshot = store.snapshot, let event = TownEventCatalog.current(in: snapshot),
                      let day = snapshot.community.events.dayKey {
                NavigationLink(value: Destination.event(event.id, day)) {
                    eventCard(title: GameStrings.text(event.titleKey), neighborID: event.neighborID,
                              status: "townEvents.available", completed: false)
                }.buttonStyle(.plain).accessibilityIdentifier("townEventOpenToday")
            } else {
                ContentUnavailableView(GameStrings.text("townEvents.empty"), systemImage: "sun.horizon.fill")
            }
        }
        .accessibilityElement(children: .contain).accessibilityIdentifier("townEventToday")
        .accessibilityValue(TownEventAccessibility.value(
            GameStrings.text(store.snapshot?.community.events.todayReceipt == nil ? "townEvents.available" : "townEvents.completed"),
            diagnostic: "\(store.snapshot?.community.events.eventID ?? "")|\(store.snapshot?.community.events.dayKey ?? "")|\(store.snapshot?.community.events.totalCompleted ?? 0)"))
    }

    private func eventCard(title: String, neighborID: String, status: String, completed: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                if let neighbor = CommunityCatalog.neighbor(id: neighborID) { CommunityPortrait(neighbor: neighbor, size: 64) }
                VStack(alignment: .leading, spacing: 6) {
                    Text(TownEventPresentation.sender(neighborID)).font(.caption.weight(.bold)).foregroundStyle(RoomTheme.secondary)
                    Text(title).font(.title3.weight(.heavy)).fixedSize(horizontal: false, vertical: true)
                    Label(GameStrings.text(status), systemImage: completed ? "checkmark.seal.fill" : "sun.max.fill")
                        .font(.caption.weight(.heavy)).foregroundStyle(completed ? RoomTheme.darkMint : RoomTheme.gold)
                }
                Spacer(minLength: 0)
            }
            HStack {
                Text(GameStrings.text(completed ? "townEvents.letters" : "townEvents.enter"))
                    .font(.subheadline.weight(.heavy))
                Spacer()
                Image(systemName: "chevron.right").font(.subheadline.weight(.heavy))
            }
            .foregroundStyle(.white).padding(.horizontal, 16).frame(minHeight: 44)
            .background(RoomTheme.mint, in: RoundedRectangle(cornerRadius: 17))
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading).gameCard(cornerRadius: 27)
        .accessibilityElement(children: .combine)
    }

    private var letterList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(GameStrings.text("townEvents.lettersHint")).font(.caption.weight(.semibold)).foregroundStyle(RoomTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if letters.isEmpty {
                ContentUnavailableView(GameStrings.text("townEvents.empty"), systemImage: "envelope.open")
            } else {
                ForEach(Array(letters.dropFirst(page * pageSize).prefix(pageSize))) { receipt in
                    NavigationLink(value: Destination.letter(receipt.id)) {
                        HStack(spacing: 12) {
                            if let neighbor = CommunityCatalog.neighbor(id: receipt.neighborID) {
                                CommunityPortrait(neighbor: neighbor, size: 52)
                            }
                            VStack(alignment: .leading, spacing: 5) {
                                Text(TownEventPresentation.title(receipt)).font(.subheadline.weight(.heavy))
                                Text(GameStrings.format("townEvents.letterFrom", TownEventPresentation.sender(receipt.neighborID)))
                                    .font(.caption.weight(.bold)).foregroundStyle(RoomTheme.secondary)
                                Text(receipt.completedAt, format: .dateTime.month().day())
                                    .font(.caption2.weight(.bold)).foregroundStyle(RoomTheme.secondary)
                            }.fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "chevron.right").font(.caption.weight(.heavy))
                        }
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading).gameCard(cornerRadius: 23)
                    }.buttonStyle(.plain).accessibilityElement(children: .combine)
                        .accessibilityIdentifier("townLetter_\(receipt.id)")
                }
                if pageCount > 1 {
                    HStack(spacing: 12) {
                        Button { page -= 1 } label: {
                            Label(GameStrings.text("townEvents.previous"), systemImage: "chevron.left")
                        }.disabled(page == 0)
                        Spacer(minLength: 0)
                        Text(GameStrings.format("townEvents.page", page + 1, pageCount)).monospacedDigit()
                        Spacer(minLength: 0)
                        Button { page += 1 } label: {
                            Label(GameStrings.text("townEvents.next"), systemImage: "chevron.right")
                        }.disabled(page + 1 >= pageCount)
                    }
                    .font(.caption.weight(.heavy)).buttonStyle(.plain).frame(minHeight: 44)
                    .foregroundStyle(RoomTheme.darkMint)
                }
            }
        }.accessibilityElement(children: .contain).accessibilityIdentifier("townEventLetters")
    }

    @ViewBuilder private var mementos: some View {
        if let snapshot = store.snapshot {
            ForEach(TownEventCatalog.milestones) { milestone in
                let claimed = snapshot.community.events.claimedMilestoneIDs.contains(milestone.id)
                let failure = TownEventCatalog.milestoneEligibility(id: milestone.id, in: snapshot)
                VStack(alignment: .leading, spacing: 14) {
                    Image("furniture-town-memory-frame").resizable().scaledToFit().frame(height: 154)
                        .frame(maxWidth: .infinity).accessibilityHidden(true)
                    Text(GameStrings.text(milestone.titleKey)).font(.title3.weight(.heavy)).accessibilityAddTraits(.isHeader)
                    Text(GameStrings.text(milestone.bodyKey)).font(.subheadline.weight(.semibold)).foregroundStyle(RoomTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    ProgressView(value: Double(min(snapshot.community.events.totalCompleted, milestone.target)), total: Double(milestone.target))
                        .tint(RoomTheme.mint)
                    Text(GameStrings.format("townEvents.progress", min(snapshot.community.events.totalCompleted, milestone.target), milestone.target))
                        .font(.caption.weight(.bold)).foregroundStyle(RoomTheme.secondary)
                    if claimed {
                        Label(GameStrings.text("townEvents.claimed"), systemImage: "checkmark.seal.fill")
                            .font(.subheadline.weight(.heavy)).foregroundStyle(RoomTheme.darkMint)
                        Text(GameStrings.text("townEvents.mementoStored")).font(.caption.weight(.semibold))
                            .foregroundStyle(RoomTheme.secondary).fixedSize(horizontal: false, vertical: true)
                    } else {
                        Button { claim(milestone.id) } label: {
                            Label(GameStrings.text(claiming ? "townEvents.working" : "townEvents.claim"), systemImage: "gift.fill")
                                .font(.subheadline.weight(.heavy)).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(MintButtonStyle()).disabled(claiming || store.isBusy || failure != nil)
                        .accessibilityIdentifier("townEventClaim_\(milestone.id)")
                        if snapshot.community.events.totalCompleted >= milestone.target, let failure {
                            Text(GameActionNotice.message(for: ActionOutcome(failure: failure), snapshot: store.snapshot))
                                .font(.caption.weight(.bold)).foregroundStyle(RoomTheme.coralDeep)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(18).frame(maxWidth: .infinity, alignment: .leading).gameCard(cornerRadius: 27)
                .accessibilityElement(children: .contain).accessibilityIdentifier("townEventMilestone_\(milestone.id)")
                .accessibilityValue(TownEventAccessibility.value(
                    claimed ? GameStrings.text("townEvents.claimed")
                        : GameStrings.format("townEvents.progress", min(snapshot.community.events.totalCompleted, milestone.target), milestone.target),
                    diagnostic: claimed ? "claimed" : failure == nil ? "ready" : "locked"))
            }
        }
    }

    private func claim(_ id: String) {
        guard !claiming, !store.isBusy else { return }
        claiming = true
        Task { _ = await store.claimTownMilestone(milestoneID: id); claiming = false }
    }
}

@MainActor
private struct TownLetterDestination: View {
    let store: GameStore
    let receipt: TownEventReceipt
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            TownEventLetterView(receipt: receipt).padding(16).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize).background(RoomTheme.cream)
        .safeAreaInset(edge: .top, spacing: 0) {
            CommunityHeader(title: GameStrings.text("townEvents.letters"), backTitle: "townEvents.title",
                            gold: store.snapshot?.player.gold ?? 0, symbol: "envelope.open.fill",
                            backID: "townLetterBackButton") { dismiss() }
        }
        .navigationBarBackButtonHidden(true).toolbar(.hidden, for: .navigationBar)
    }
}
