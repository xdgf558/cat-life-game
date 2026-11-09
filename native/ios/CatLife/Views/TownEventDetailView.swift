import SwiftUI
import CatGameCore

@MainActor
struct TownEventDetailView: View {
    @Bindable var store: GameStore
    let eventID: String
    let dayKey: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false
    @State private var isWorking = false
    @State private var failed = false
    @State private var result: TownEventReceipt?
    private var event: TownEventDefinition? { TownEventCatalog.event(id: eventID) }
    private var receipt: TownEventReceipt? {
        result ?? store.snapshot?.community.events.letters.first { $0.dayKey == dayKey && $0.eventID == eventID }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Color.clear.frame(height: 1).id("eventTop")
                    if let receipt {
                        Label(GameStrings.text("townEvents.resultTitle"), systemImage: "envelope.open.fill")
                            .font(.headline.weight(.heavy)).foregroundStyle(RoomTheme.darkMint)
                            .accessibilityAddTraits(.isHeader)
                        TownEventLetterView(receipt: receipt)
                        Text(GameStrings.text("townEvents.refreshHint")).font(.caption.weight(.semibold))
                            .foregroundStyle(RoomTheme.secondary).fixedSize(horizontal: false, vertical: true)
                    } else if let event {
                        introduction(event)
                        Text(GameStrings.text("townEvents.choiceHint")).font(.subheadline.weight(.bold))
                            .foregroundStyle(RoomTheme.secondary)
                        if failed {
                            Label(GameStrings.text("townEvents.saveFailed"), systemImage: "exclamationmark.triangle.fill")
                                .font(.caption.weight(.bold)).foregroundStyle(RoomTheme.coralDeep)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("townEventSaveFailed")
                        }
                        ForEach(event.choices) { choice in choiceCard(choice, event: event) }
                    } else {
                        ContentUnavailableView(GameStrings.text("townEvents.empty"), systemImage: "envelope")
                    }
                }
                .padding(16).frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize).background(RoomTheme.cream)
            .accessibilityIdentifier("townEventDetail")
            .onChange(of: result?.id) { _, _ in proxy.scrollTo("eventTop", anchor: .top) }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            CommunityHeader(title: GameStrings.text("townEvents.detailTitle"), backTitle: "common.back",
                            gold: store.snapshot?.player.gold ?? 0, symbol: "envelope.open.fill",
                            backID: "townEventBackButton") { dismiss() }
        }
        .navigationBarBackButtonHidden(true).toolbar(.hidden, for: .navigationBar)
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .onChange(of: store.saveSceneGeneration) { _, _ in result = nil; failed = false; dismiss() }
    }

    private func introduction(_ event: TownEventDefinition) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                if let neighbor = CommunityCatalog.neighbor(id: event.neighborID) {
                    CommunityPortrait(neighbor: neighbor, size: 72)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(TownEventPresentation.sender(event.neighborID)).font(.subheadline.weight(.heavy))
                        .foregroundStyle(RoomTheme.secondary)
                    Text(GameStrings.text(event.titleKey)).font(.title2.weight(.heavy))
                        .accessibilityAddTraits(.isHeader).accessibilityIdentifier("townEventTitle")
                }
            }
            Text(GameStrings.text(event.bodyKey)).font(.body.weight(.medium)).lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading).gameCard(cornerRadius: 26)
    }

    private func choiceCard(_ choice: TownEventChoice, event: TownEventDefinition) -> some View {
        let friendship = store.snapshot?.community.relationship(for: event.neighborID).friendship ?? 0
        let friendshipGain = min(choice.friendshipReward, max(0, 100 - friendship))
        let failure = store.snapshot.flatMap {
            TownEventCatalog.eligibility(eventID: event.id, choiceID: choice.id, dayKey: dayKey, in: $0)
        }
        return Button { participate(choice) } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: choice.id == "help" ? "hands.sparkles.fill" : "gift.fill")
                        .font(.title2).foregroundStyle(RoomTheme.darkMint)
                        .frame(width: 44, height: 44).background(RoomTheme.paleMint, in: RoundedRectangle(cornerRadius: 14))
                        .accessibilityHidden(true)
                    Text(GameStrings.text(choice.titleKey)).font(.headline.weight(.heavy))
                        .frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
                    Image(systemName: "chevron.right").font(.subheadline.weight(.heavy)).accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(TownEventPresentation.costs(choice), id: \.self) { cost in
                        Text(GameStrings.text("townEvents.cost") + " · " + cost)
                    }
                    Text(friendshipGain > 0 ? GameStrings.format("townEvents.friendshipGain", friendshipGain)
                         : GameStrings.text("community.closestShort"))
                        .foregroundStyle(RoomTheme.friendshipDeep)
                    Text(GameStrings.text("townEvents.rewards") + " · " + TownEventPresentation.rewards(choice.rewards))
                }
                .font(.caption.weight(.bold)).foregroundStyle(RoomTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
                if isWorking {
                    Label(GameStrings.text("townEvents.working"), systemImage: "hourglass")
                        .font(.caption.weight(.heavy)).foregroundStyle(RoomTheme.darkMint)
                } else if let failure {
                    Text(GameActionNotice.message(for: ActionOutcome(failure: failure), snapshot: store.snapshot))
                        .font(.caption.weight(.bold)).foregroundStyle(RoomTheme.coralDeep)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16).frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
            .gameCard(cornerRadius: 24)
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(RoomTheme.mint.opacity(0.3), lineWidth: 2))
            .opacity(failure == nil ? 1 : 0.65)
            .contentShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain).disabled(isWorking || store.isBusy || failure != nil || store.snapshot == nil)
        .accessibilityElement(children: .combine).accessibilityIdentifier("townEventChoice_\(choice.id)")
    }

    private func participate(_ choice: TownEventChoice) {
        guard !isWorking, !store.isBusy else { return }
        isWorking = true; failed = false
        let generation = store.saveSceneGeneration
        Task {
            let saved = await store.resolveTownEvent(eventID: eventID, choiceID: choice.id, dayKey: dayKey) { receipt in
                guard isVisible, scenePhase == .active, store.activeSheet == .town, store.isShowingTownBoard,
                      store.saveSceneGeneration == generation, receipt.eventID == eventID, receipt.dayKey == dayKey else { return false }
                result = receipt
                return true
            }
            isWorking = false
            if saved == nil, store.saveSceneGeneration == generation { failed = store.hasSaveFailure }
        }
    }
}
